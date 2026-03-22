#!/bin/bash
# ============================================
# 🏪 Barber Shop - Script de Instalación
# Chatbot de Telegram con IA para Barbería
# ============================================

set -e

echo "💈 =================================="
echo "   BARBER SHOP - Instalación del Chatbot"
echo "💈 =================================="
echo ""

# Verificar Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker no está instalado."
    echo "📥 Instalando Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "✅ Docker instalado. Por favor cierra sesión y vuelve a entrar."
    echo "   Luego ejecuta este script de nuevo."
    exit 1
fi

# Verificar Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose no está instalado."
    echo "📥 Instalando Docker Compose..."
    sudo apt-get update && sudo apt-get install -y docker-compose-plugin
    echo "✅ Docker Compose instalado."
fi

echo ""
echo "📦 Paso 1: Levantando servicios (N8N + Ollama + Whisper)..."
echo "   Esto puede tomar unos minutos la primera vez..."
echo ""

cd "$(dirname "$0")/.."
docker compose up -d

echo ""
echo "⏳ Paso 2: Esperando a que los servicios estén listos..."
sleep 10

echo ""
echo "🤖 Paso 3: Descargando modelo de IA (llama3.1)..."
echo "   Esto puede tomar varios minutos dependiendo de tu internet..."
echo ""
docker exec barbershop-ollama ollama pull llama3.1:8b

echo ""
echo "📁 Paso 4: Creando archivo de citas..."
mkdir -p data
echo "[]" > data/citas.json

echo ""
echo "✅ =================================="
echo "   ¡INSTALACIÓN COMPLETADA!"
echo "✅ =================================="
echo ""
echo "📋 PRÓXIMOS PASOS:"
echo ""
echo "1. 🌐 Abre N8N en tu navegador:"
echo "   http://localhost:5678"
echo "   Usuario: admin"
echo "   Contraseña: barbershop2024"
echo ""
echo "2. 🤖 Crea tu Bot de Telegram:"
echo "   - Abre Telegram y busca @BotFather"
echo "   - Envía /newbot"
echo "   - Sigue las instrucciones y guarda el TOKEN"
echo ""
echo "3. 📥 Importa el workflow:"
echo "   - En N8N, haz clic en '+ Add Workflow' o importar"
echo "   - Selecciona 'Import from File'"
echo "   - Elige: workflows/barbershop-chatbot.json"
echo ""
echo "4. 🔑 Configura las credenciales:"
echo "   - Ve a Credentials en N8N"
echo "   - Crea una credencial 'Telegram API'"
echo "   - Pega tu Bot Token de Telegram"
echo ""
echo "5. ▶️  Activa el workflow y ¡listo!"
echo ""
echo "📱 Para acceder desde tu celular:"
echo "   Usa la IP de tu computadora en vez de localhost"
echo "   Ejemplo: http://192.168.1.X:5678"
echo ""
echo "💈 ¡Pura vida! Tu barbería ahora tiene IA 🇨🇷"
