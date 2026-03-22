#!/bin/bash
# ============================================
# 🌐 Script para exponer N8N con ngrok (gratis)
# Necesario para que Telegram pueda enviar webhooks
# ============================================

echo "🌐 Exponiendo N8N al internet con ngrok..."
echo ""

# Verificar ngrok
if ! command -v ngrok &> /dev/null; then
    echo "📥 Instalando ngrok..."
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok-v3-stable-linux-amd64.tgz | sudo tar xvz -C /usr/local/bin
    echo "✅ ngrok instalado."
    echo ""
    echo "⚠️  IMPORTANTE: Necesitas una cuenta gratuita de ngrok."
    echo "   1. Ve a https://ngrok.com y crea una cuenta gratis"
    echo "   2. Copia tu authtoken desde el dashboard"
    echo "   3. Ejecuta: ngrok config add-authtoken TU_TOKEN"
    echo "   4. Luego ejecuta este script de nuevo"
    exit 1
fi

echo "🚀 Iniciando túnel ngrok..."
echo "   La URL pública aparecerá abajo."
echo "   Copia esa URL y actualiza WEBHOOK_URL en docker-compose.yml"
echo ""
echo "   Luego reinicia N8N: docker compose restart n8n"
echo ""

ngrok http 5678
