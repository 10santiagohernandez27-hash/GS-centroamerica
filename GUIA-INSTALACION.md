# 💈 Barber Shop - Chatbot de Telegram con IA

## Chatbot inteligente para tu barbería con reconocimiento de voz y agendado de citas

---

## 🎯 ¿Qué hace este chatbot?

- ✅ Atiende clientes 24/7 por Telegram
- ✅ Entiende texto Y audios/notas de voz
- ✅ Agenda, consulta y cancela citas automáticamente
- ✅ Muestra precios, horarios y ubicación
- ✅ Asigna barberos (Santiago, Steven, Jarell)
- ✅ Recuerda la conversación (tiene memoria)
- ✅ Habla en español tico 🇨🇷
- ✅ 100% GRATIS - sin APIs de pago

---

## 📦 Requisitos

- Una computadora con **4GB+ de RAM** (para Ollama)
- **Docker** y **Docker Compose** instalados
- **Conexión a internet**
- **Cuenta de Telegram** (la que ya tienes)

---

## 🚀 Instalación Rápida (5 minutos)

### Paso 1: Clonar el repositorio
```bash
git clone <URL_DEL_REPO>
cd GS-centroamerica
```

### Paso 2: Ejecutar el instalador
```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

Esto descargará e instalará automáticamente:
- **N8N** (plataforma de automatización)
- **Ollama** (inteligencia artificial local)
- **Whisper** (transcripción de audio)

### Paso 3: Crear tu Bot de Telegram

1. Abre **Telegram** en tu celular
2. Busca **@BotFather**
3. Envía `/newbot`
4. Elige un nombre: `Barber Shop Bot`
5. Elige un username: `barbershop_cr_bot` (debe terminar en `bot`)
6. **BotFather te dará un TOKEN** - ¡GUÁRDALO!

El token se ve así: `7123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw`

### Paso 4: Configurar N8N

1. Abre tu navegador y ve a: **http://localhost:5678**
2. Credenciales de acceso:
   - Usuario: `admin`
   - Contraseña: `barbershop2024`
3. Ve a **Settings → Credentials → Add Credential**
4. Busca **Telegram API**
5. Pega tu **Bot Token** del paso anterior
6. Guarda

### Paso 5: Importar el Workflow

1. En N8N, haz clic en **"+"** para crear nuevo workflow
2. Clic en los **3 puntos (⋮)** → **Import from File**
3. Selecciona: `workflows/barbershop-chatbot.json`
4. Actualiza las credenciales de Telegram en cada nodo que lo necesite
5. **Activa el workflow** (toggle arriba a la derecha)

### Paso 6: Exponer al Internet (para webhooks de Telegram)

Para que Telegram pueda enviar mensajes a tu N8N, necesitas exponer tu servidor:

**Opción A: ngrok (más fácil, gratis)**
```bash
chmod +x scripts/ngrok-tunnel.sh
./scripts/ngrok-tunnel.sh
```

**Opción B: Si tienes un servidor con IP pública**
- Actualiza `WEBHOOK_URL` en `docker-compose.yml` con tu URL
- Reinicia: `docker compose restart n8n`

### Paso 7: ¡Probarlo!

1. Abre Telegram
2. Busca tu bot por el username que le pusiste
3. Envía `/start` o un mensaje como "Hola, quiero una cita"
4. ¡Envía un audio y mira cómo lo entiende! 🎙️

---

## 📱 Acceder desde el Celular

Para ver N8N desde tu celular (en la misma red WiFi):

1. En tu computadora, ejecuta:
   ```bash
   hostname -I
   ```
2. Usa esa IP en tu celular: `http://192.168.X.X:5678`

Con **ngrok**, puedes acceder desde cualquier lugar con la URL que te genera.

---

## 💰 Precios Configurados (en Colones ₡)

| Servicio | Precio |
|----------|--------|
| Corte de cabello | ₡4,000 |
| Barba | ₡3,000 |
| Cejas | ₡2,000 |
| Combo Completo | ₡7,500 |
| Tinte | ₡8,000 |
| Alisado | ₡6,000 |
| Diseño artístico | ₡5,000 |
| Tratamiento capilar | ₡4,500 |
| Lavado y secado | ₡2,500 |

Para cambiar precios, edita el **System Message** del nodo "Agente IA Barbería" en N8N.

---

## 🏗️ Arquitectura del Sistema

```
Cliente (Telegram)
    ↓
[Telegram Trigger] → recibe mensaje
    ↓
[Switch] → ¿Es texto, audio o botón?
    ↓                    ↓
  Texto              Audio
    ↓                    ↓
    │            [Descargar audio]
    │                    ↓
    │            [Whisper: Transcribir]
    │                    ↓
    └────────→ [Agente IA con Ollama] ←── Memoria de conversación
                    ↓          ↑
              [Herramientas]   │
              - Guardar cita   │
              - Consultar citas│
              - Cancelar cita  │
                    ↓
            [Enviar respuesta por Telegram]
```

---

## 🔧 Solución de Problemas

### "El bot no responde"
- Verifica que el workflow esté **activado** en N8N
- Verifica que la URL de webhook sea accesible desde internet
- Revisa los logs: `docker compose logs n8n`

### "Los audios no se transcriben"
- Verifica que Whisper esté corriendo: `docker compose logs whisper`
- Prueba: `curl http://localhost:9000/`

### "La IA responde lento"
- Es normal la primera vez (carga el modelo)
- Después es más rápido
- Si tienes GPU, configura Ollama para usarla

### "Quiero cambiar la información de la barbería"
- Abre el workflow en N8N
- Doble clic en el nodo "Agente IA Barbería"
- Edita el System Message con tu nueva información

---

## 📂 Estructura del Proyecto

```
GS-centroamerica/
├── docker-compose.yml          # Servicios: N8N + Ollama + Whisper
├── GUIA-INSTALACION.md         # Esta guía
├── workflows/
│   └── barbershop-chatbot.json # Workflow principal de N8N
├── scripts/
│   ├── setup.sh                # Script de instalación automática
│   └── ngrok-tunnel.sh         # Script para exponer al internet
└── data/
    └── citas.json              # Base de datos de citas (auto-generado)
```

---

## 🇨🇷 Hecho con ❤️ para Barber Shop - Pura Vida!

**Dirección:** Casa 27, Condominio Privado Puerta Madera, Purral, Guadalupe, San José, Costa Rica
**Horario:** Lunes a Domingo, 8:00 AM - 6:00 PM
**Barberos:** Santiago | Steven | Jarell
