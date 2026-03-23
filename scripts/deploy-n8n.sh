#!/bin/bash
# ================================================
# Barber Shop Bot - Deploy automático en N8N
# Ejecuta este script desde tu terminal o VPS
# ================================================

set -e

# Cargar variables del archivo .env si existe
SCRIPT_DIR_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR_ENV}/../.env" ]; then
  export $(grep -v '^#' "${SCRIPT_DIR_ENV}/../.env" | xargs)
fi

# Verificar que las variables estén definidas
: "${N8N_URL:?Falta N8N_URL en .env}"
: "${N8N_API_KEY:?Falta N8N_API_KEY en .env}"
: "${TELEGRAM_TOKEN:?Falta TELEGRAM_TOKEN en .env}"
: "${GROQ_API_KEY:?Falta GROQ_API_KEY en .env}"

echo ""
echo "💈 ====================================="
echo "   Barber Shop Bot - Deploy en N8N"
echo "💈 ====================================="
echo ""

# Verificar curl y jq
if ! command -v curl &>/dev/null; then
  echo "❌ curl no está instalado. Instálalo con: sudo apt install curl"
  exit 1
fi

# Función para extraer campo JSON (sin jq)
json_value() {
  echo "$1" | grep -o "\"$2\":\"[^\"]*\"" | head -1 | cut -d'"' -f4
}

echo "🔑 Paso 1: Creando credencial de Telegram..."
TELEGRAM_RESP=$(curl -s -X POST "${N8N_URL}/api/v1/credentials" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Telegram Barber Shop Bot\",
    \"type\": \"telegramApi\",
    \"data\": {
      \"accessToken\": \"${TELEGRAM_TOKEN}\"
    }
  }")

TELEGRAM_CRED_ID=$(json_value "$TELEGRAM_RESP" "id")
if [ -z "$TELEGRAM_CRED_ID" ]; then
  echo "   ⚠️  La credencial de Telegram ya puede existir, buscando..."
  EXISTING=$(curl -s "${N8N_URL}/api/v1/credentials" \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}")
  TELEGRAM_CRED_ID=$(echo "$EXISTING" | grep -o '"id":"[^"]*","name":"Telegram Barber Shop Bot"' | cut -d'"' -f4)
fi
echo "   ✅ Telegram ID: ${TELEGRAM_CRED_ID}"

echo ""
echo "🤖 Paso 2: Creando credencial de Groq (IA)..."
GROQ_RESP=$(curl -s -X POST "${N8N_URL}/api/v1/credentials" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Groq Barber Shop\",
    \"type\": \"groqApi\",
    \"data\": {
      \"apiKey\": \"${GROQ_API_KEY}\"
    }
  }")

GROQ_CRED_ID=$(json_value "$GROQ_RESP" "id")
echo "   ✅ Groq ID: ${GROQ_CRED_ID}"

echo ""
echo "🎙️ Paso 3: Creando credencial de Groq para Whisper (audio)..."
GROQ_HEADER_RESP=$(curl -s -X POST "${N8N_URL}/api/v1/credentials" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Groq Header Auth\",
    \"type\": \"httpHeaderAuth\",
    \"data\": {
      \"name\": \"Authorization\",
      \"value\": \"Bearer ${GROQ_API_KEY}\"
    }
  }")

GROQ_HEADER_ID=$(json_value "$GROQ_HEADER_RESP" "id")
echo "   ✅ Groq Header ID: ${GROQ_HEADER_ID}"

echo ""
echo "📥 Paso 4: Preparando workflow con credenciales reales..."

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="${SCRIPT_DIR}/../workflows/barbershop-chatbot-groq.json"

if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "❌ No se encontró el workflow en: $WORKFLOW_FILE"
  echo "   Asegúrate de ejecutar este script desde el repositorio clonado."
  exit 1
fi

# Reemplazar IDs de credenciales en el workflow
WORKFLOW_CONTENT=$(cat "$WORKFLOW_FILE")
WORKFLOW_CONTENT="${WORKFLOW_CONTENT//TELEGRAM_CREDENTIALS_ID/$TELEGRAM_CRED_ID}"
WORKFLOW_CONTENT="${WORKFLOW_CONTENT//GROQ_CREDENTIALS_ID/$GROQ_CRED_ID}"
WORKFLOW_CONTENT="${WORKFLOW_CONTENT//GROQ_HEADER_CREDENTIALS_ID/$GROQ_HEADER_ID}"

# También actualizar los nombres de credenciales
WORKFLOW_CONTENT="${WORKFLOW_CONTENT//\"name\": \"Telegram Bot API\"/\"name\": \"Telegram Barber Shop Bot\"}"
WORKFLOW_CONTENT="${WORKFLOW_CONTENT//\"name\": \"Groq API\"/\"name\": \"Groq Barber Shop\"}"
WORKFLOW_CONTENT="${WORKFLOW_CONTENT//\"name\": \"Groq API Header\"/\"name\": \"Groq Header Auth\"}"

echo ""
echo "🚀 Paso 5: Importando workflow en N8N..."
IMPORT_RESP=$(curl -s -X POST "${N8N_URL}/api/v1/workflows" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$WORKFLOW_CONTENT")

WORKFLOW_ID=$(json_value "$IMPORT_RESP" "id")

if [ -z "$WORKFLOW_ID" ]; then
  echo "❌ Error al importar el workflow."
  echo "Respuesta: $IMPORT_RESP"
  exit 1
fi

echo "   ✅ Workflow importado con ID: ${WORKFLOW_ID}"

echo ""
echo "▶️  Paso 6: Activando el workflow..."
ACTIVATE_RESP=$(curl -s -X PATCH "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"active": true}')

IS_ACTIVE=$(json_value "$ACTIVATE_RESP" "active")

if echo "$ACTIVATE_RESP" | grep -q '"active":true'; then
  echo "   ✅ Workflow ACTIVADO"
else
  echo "   ⚠️  No se pudo activar automáticamente."
  echo "   Actívalo manualmente en: ${N8N_URL}/workflow/${WORKFLOW_ID}"
fi

echo ""
echo "✅ ====================================="
echo "   ¡INSTALACIÓN COMPLETADA!"
echo "✅ ====================================="
echo ""
echo "📱 Tu bot de Telegram está listo en:"
echo "   https://t.me/barbershopCR_bot"
echo ""
echo "🔗 Workflow en N8N:"
echo "   ${N8N_URL}/workflow/${WORKFLOW_ID}"
echo ""
echo "📝 Prueba escribiéndole a tu bot en Telegram:"
echo "   'Hola, quiero una cita'"
echo "   O envía una nota de voz!"
echo ""
echo "💈 ¡Pura vida! 🇨🇷"
