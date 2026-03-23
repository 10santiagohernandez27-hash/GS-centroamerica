#!/bin/bash
# ================================================
# Fix: Eliminar workflow draft y reimportar como publicado
# ================================================

set -e

# Cargar variables del .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../.env" ]; then
  export $(grep -v '^#' "${SCRIPT_DIR}/../.env" | xargs)
fi

: "${N8N_URL:?Falta N8N_URL en .env}"
: "${N8N_API_KEY:?Falta N8N_API_KEY en .env}"
: "${TELEGRAM_TOKEN:?Falta TELEGRAM_TOKEN en .env}"

API="${N8N_URL}/api/v1"
AUTH_HEADER="X-N8N-API-KEY: ${N8N_API_KEY}"

echo ""
echo "=== PASO 1: Listar workflows existentes ==="
WORKFLOWS=$(curl -s "${API}/workflows" -H "${AUTH_HEADER}")
echo "$WORKFLOWS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
wfs = data.get('data', data) if isinstance(data, dict) else data
if isinstance(wfs, list):
    for w in wfs:
        print(f\"  ID: {w['id']}  Active: {w.get('active')}  Name: {w['name']}\")
else:
    print('  Response:', json.dumps(data)[:200])
" 2>/dev/null || echo "  Raw: ${WORKFLOWS:0:300}"

echo ""
echo "=== PASO 2: Eliminar TODOS los workflows existentes (limpieza total) ==="
# Extract workflow IDs and delete each one
WORKFLOW_IDS=$(echo "$WORKFLOWS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
wfs = data.get('data', data) if isinstance(data, dict) else data
if isinstance(wfs, list):
    for w in wfs:
        print(w['id'])
" 2>/dev/null)

if [ -n "$WORKFLOW_IDS" ]; then
  for WF_ID in $WORKFLOW_IDS; do
    echo "  Eliminando workflow ${WF_ID}..."
    curl -s -X DELETE "${API}/workflows/${WF_ID}" -H "${AUTH_HEADER}" > /dev/null
    echo "  Eliminado."
  done
else
  echo "  No se encontraron workflows."
fi

echo ""
echo "=== PASO 3: Buscar credenciales existentes ==="
CREDS=$(curl -s "${API}/credentials" -H "${AUTH_HEADER}")
echo "$CREDS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
creds = data.get('data', data) if isinstance(data, dict) else data
if isinstance(creds, list):
    for c in creds:
        print(f\"  ID: {c['id']}  Type: {c.get('type','')}  Name: {c['name']}\")
" 2>/dev/null || echo "  Raw: ${CREDS:0:300}"

# Extract credential IDs by type
TELEGRAM_CRED_ID=$(echo "$CREDS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
creds = data.get('data', data) if isinstance(data, dict) else data
for c in creds:
    if c.get('type') == 'telegramApi':
        print(c['id']); break
" 2>/dev/null)

GROQ_CRED_ID=$(echo "$CREDS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
creds = data.get('data', data) if isinstance(data, dict) else data
for c in creds:
    if c.get('type') == 'groqApi':
        print(c['id']); break
" 2>/dev/null)

GROQ_HEADER_ID=$(echo "$CREDS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
creds = data.get('data', data) if isinstance(data, dict) else data
for c in creds:
    if c.get('type') == 'httpHeaderAuth':
        print(c['id']); break
" 2>/dev/null)

echo ""
echo "  Telegram Cred ID: ${TELEGRAM_CRED_ID:-NOT FOUND}"
echo "  Groq Cred ID: ${GROQ_CRED_ID:-NOT FOUND}"
echo "  Groq Header ID: ${GROQ_HEADER_ID:-NOT FOUND}"

# Create missing credentials if needed
if [ -z "$TELEGRAM_CRED_ID" ]; then
  echo ""
  echo "  Creando credencial Telegram..."
  RESP=$(curl -s -X POST "${API}/credentials" \
    -H "${AUTH_HEADER}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Telegram Barber Shop Bot\",\"type\":\"telegramApi\",\"data\":{\"accessToken\":\"${TELEGRAM_TOKEN}\"}}")
  TELEGRAM_CRED_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
  echo "  Creada: ${TELEGRAM_CRED_ID}"
fi

if [ -z "$GROQ_CRED_ID" ]; then
  echo "  Creando credencial Groq..."
  RESP=$(curl -s -X POST "${API}/credentials" \
    -H "${AUTH_HEADER}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Groq Barber Shop\",\"type\":\"groqApi\",\"data\":{\"apiKey\":\"${GROQ_API_KEY}\"}}")
  GROQ_CRED_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
  echo "  Creada: ${GROQ_CRED_ID}"
fi

if [ -z "$GROQ_HEADER_ID" ]; then
  echo "  Creando credencial Groq Header..."
  RESP=$(curl -s -X POST "${API}/credentials" \
    -H "${AUTH_HEADER}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Groq Header Auth\",\"type\":\"httpHeaderAuth\",\"data\":{\"name\":\"Authorization\",\"value\":\"Bearer ${GROQ_API_KEY}\"}}")
  GROQ_HEADER_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
  echo "  Creada: ${GROQ_HEADER_ID}"
fi

echo ""
echo "=== PASO 4: Preparar e importar workflow con credenciales reales ==="

WORKFLOW_FILE="${SCRIPT_DIR}/../workflows/barbershop-chatbot-groq.json"
if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "ERROR: No se encontro ${WORKFLOW_FILE}"
  exit 1
fi

# Use python to properly update credential IDs in the JSON
WORKFLOW_JSON=$(python3 -c "
import json, sys

with open('${WORKFLOW_FILE}') as f:
    wf = json.load(f)

telegram_id = '${TELEGRAM_CRED_ID}'
groq_id = '${GROQ_CRED_ID}'
groq_header_id = '${GROQ_HEADER_ID}'

# Update credential IDs in all nodes
for node in wf.get('nodes', []):
    creds = node.get('credentials', {})
    if 'telegramApi' in creds:
        creds['telegramApi']['id'] = telegram_id
        creds['telegramApi']['name'] = 'Telegram Barber Shop Bot'
    if 'groqApi' in creds:
        creds['groqApi']['id'] = groq_id
        creds['groqApi']['name'] = 'Groq Barber Shop'
    if 'httpHeaderAuth' in creds:
        creds['httpHeaderAuth']['id'] = groq_header_id
        creds['httpHeaderAuth']['name'] = 'Groq Header Auth'

print(json.dumps(wf))
")

# Import the workflow
IMPORT_RESP=$(curl -s -X POST "${API}/workflows" \
  -H "${AUTH_HEADER}" \
  -H "Content-Type: application/json" \
  -d "$WORKFLOW_JSON")

NEW_WF_ID=$(echo "$IMPORT_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)

if [ -z "$NEW_WF_ID" ]; then
  echo "ERROR al importar workflow:"
  echo "$IMPORT_RESP" | python3 -m json.tool 2>/dev/null || echo "$IMPORT_RESP"
  exit 1
fi

echo "  Workflow importado con ID: ${NEW_WF_ID}"

echo ""
echo "=== PASO 5: Activar workflow (publicarlo) ==="
ACTIVATE_RESP=$(curl -s -X PATCH "${API}/workflows/${NEW_WF_ID}" \
  -H "${AUTH_HEADER}" \
  -H "Content-Type: application/json" \
  -d '{"active": true}')

IS_ACTIVE=$(echo "$ACTIVATE_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('active', False))" 2>/dev/null)
echo "  Active: ${IS_ACTIVE}"

if [ "$IS_ACTIVE" != "True" ]; then
  echo "  WARNING: El workflow no se activo correctamente"
  echo "  Response: $(echo "$ACTIVATE_RESP" | python3 -m json.tool 2>/dev/null || echo "$ACTIVATE_RESP")"
fi

echo ""
echo "=== PASO 6: Verificar estado del webhook ==="
sleep 3

# Check Telegram webhook info
WEBHOOK_INFO=$(curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getWebhookInfo")
echo "$WEBHOOK_INFO" | python3 -c "
import sys, json
info = json.load(sys.stdin)['result']
print(f\"  URL: {info.get('url', 'NOT SET')}\")
print(f\"  Pending updates: {info.get('pending_update_count', 0)}\")
print(f\"  Last error: {info.get('last_error_message', 'None')}\")
" 2>/dev/null

# The Telegram trigger in n8n should have automatically set the webhook URL
# But if it didn't, let's check and set it manually
CURRENT_WEBHOOK_URL=$(echo "$WEBHOOK_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'].get('url',''))" 2>/dev/null)

# Test the webhook endpoint
echo ""
echo "  Probando webhook endpoint..."
WEBHOOK_TEST=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${N8N_URL}/webhook/${NEW_WF_ID}/telegram%20trigger/webhook" \
  -H "Content-Type: application/json" \
  -d '{"message":{"message_id":1,"from":{"id":1,"is_bot":false,"first_name":"Test"},"chat":{"id":1,"type":"private"},"date":1234567890,"text":"/test"}}')
echo "  HTTP Status del webhook: ${WEBHOOK_TEST}"

# Also try the standard webhook path format
WEBHOOK_TEST2=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${N8N_URL}/webhook/${NEW_WF_ID}" \
  -H "Content-Type: application/json" \
  -d '{"test":true}')
echo "  HTTP Status (alt path): ${WEBHOOK_TEST2}"

echo ""
echo "=== PASO 7: Verificar logs de N8N ==="
echo "  (Revisa los logs del container para confirmar que dice '1 published workflows')"
echo ""
echo "=== RESULTADO ==="
echo "  Workflow ID: ${NEW_WF_ID}"
echo "  URL N8N: ${N8N_URL}/workflow/${NEW_WF_ID}"
echo ""

if [ "$WEBHOOK_TEST" = "200" ]; then
  echo "  EXITO: El webhook responde correctamente!"
elif [ "$IS_ACTIVE" = "True" ]; then
  echo "  El workflow esta activo. Si el webhook aun da 404,"
  echo "  puede que N8N necesite un reinicio del container."
  echo "  Ejecuta: docker restart n8n-n8n-1"
else
  echo "  ATENCION: Revisa la configuracion manualmente en:"
  echo "  ${N8N_URL}/workflow/${NEW_WF_ID}"
fi
