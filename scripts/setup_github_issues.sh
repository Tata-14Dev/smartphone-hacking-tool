#!/bin/bash

# ============================================================
# setup_github_issues.sh
# Crea labels, milestones e issues en GitHub para el proyecto
# Watch Dogs Phone, basado en el documento de requerimientos.
#
# USO: ejecutar desde la raíz del proyecto (watchdogs-phone/)
#   bash scripts/setup_github_issues.sh
# ============================================================

set -e  # detener el script si cualquier comando falla

# ── Colores para output ──────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # sin color

echo -e "${YELLOW}=== Watch Dogs Phone — Setup de GitHub Issues ===${NC}\n"

# ── PASO 1: Verificar e instalar GitHub CLI ──────────────────
echo -e "${YELLOW}[1/4] Verificando GitHub CLI...${NC}"

if ! command -v gh &> /dev/null; then
    echo "GitHub CLI no encontrado. Instalando con Homebrew..."
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}Error: Homebrew no está instalado.${NC}"
        echo "Instalá Homebrew primero: https://brew.sh"
        exit 1
    fi
    brew install gh
    echo -e "${GREEN}GitHub CLI instalado correctamente.${NC}"
else
    echo -e "${GREEN}GitHub CLI ya está instalado: $(gh --version | head -1)${NC}"
fi

# ── PASO 2: Autenticación ────────────────────────────────────
echo -e "\n${YELLOW}[2/4] Verificando autenticación con GitHub...${NC}"

if ! gh auth status &> /dev/null; then
    echo "No estás autenticado. Iniciando login..."
    gh auth login
else
    echo -e "${GREEN}Ya estás autenticado con GitHub.${NC}"
fi

# ── Verificar que estamos en un repo de GitHub ───────────────
if ! gh repo view &> /dev/null; then
    echo -e "${RED}Error: No se detectó un repositorio de GitHub en esta carpeta.${NC}"
    echo "Asegurate de estar en la raíz del proyecto (watchdogs-phone/) y que el repo esté creado en GitHub."
    exit 1
fi

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo -e "Repositorio detectado: ${GREEN}$REPO${NC}"

# ── PASO 3: Crear Labels ─────────────────────────────────────
echo -e "\n${YELLOW}[3/4] Creando labels...${NC}"

create_label() {
    local name=$1
    local color=$2
    local description=$3
    if gh label list | grep -q "^$name"; then
        echo "  Label '$name' ya existe, saltando..."
    else
        gh label create "$name" --color "$color" --description "$description" 2>/dev/null && \
            echo -e "  ${GREEN}✓${NC} Label '$name' creado" || \
            echo -e "  ${YELLOW}⚠${NC} No se pudo crear label '$name'"
    fi
}

# Labels de módulo
create_label "modulo: wifi"      "0075ca" "Issues del módulo WiFi"
create_label "modulo: network"   "2ea44f" "Issues del módulo de red"
create_label "modulo: bluetooth" "00b4d8" "Issues del módulo Bluetooth"
create_label "modulo: nfc"       "ffd60a" "Issues del módulo NFC/RFID"
create_label "modulo: hid"       "fb8500" "Issues del módulo HID"
create_label "modulo: ui"        "8338ec" "Issues de la interfaz Android"
create_label "modulo: decision"  "e63946" "Issues del motor de decisión"

# Labels de prioridad
create_label "prioridad: alta"   "d73a4a" "Requerimiento crítico para el MVP"
create_label "prioridad: media"  "e4a11b" "Requerimiento importante"
create_label "prioridad: baja"   "6c757d" "Nice to have"

# Labels de fase
create_label "fase: 1"           "cdb4db" "Backend base + Nmap"
create_label "fase: 2"           "bde0fe" "Módulo WiFi"
create_label "fase: 3"           "caffbf" "APK básica"
create_label "fase: 4"           "ffdfba" "Módulos BT, NFC, HID"
create_label "fase: 5"           "ffc6ff" "Motor de decisión"
create_label "fase: 6"           "fdffb6" "UI final Watch Dogs"

echo -e "${GREEN}Labels creados.${NC}"

# ── PASO 4: Crear Milestones ─────────────────────────────────
echo -e "\n${YELLOW}[4/4] Creando milestones y issues...${NC}"

create_milestone() {
    local title=$1
    local description=$2
    if ! gh api repos/$REPO/milestones | grep -q "\"title\":\"$title\""; then
        gh api repos/$REPO/milestones \
            --method POST \
            --field title="$title" \
            --field description="$description" \
            --silent && echo -e "  ${GREEN}✓${NC} Milestone '$title' creado"
    else
        echo "  Milestone '$title' ya existe, saltando..."
    fi
}

create_milestone "Fase 1 — Backend base"     "Servidor Flask + módulo de red (Nmap) + logging"
create_milestone "Fase 2 — WiFi"             "Módulo WiFi completo (escaneo, deauth, handshake)"
create_milestone "Fase 3 — APK básica"       "Interfaz Android con módulos de red y WiFi"
create_milestone "Fase 4 — Módulos extra"    "Bluetooth, NFC/RFID, HID"
create_milestone "Fase 5 — Motor decisión"   "Lógica de sugerencia automática de ataques"
create_milestone "Fase 6 — UI final"         "Diseño Watch Dogs, pulido general"

# ── Función para crear issues ────────────────────────────────
create_issue() {
    local title=$1
    local body=$2
    local labels=$3
    local milestone=$4

    if gh issue list --search "$title" --json title -q '.[].title' | grep -qF "$title"; then
        echo -e "  ${YELLOW}⚠${NC} Issue '$title' ya existe, saltando..."
    else
        gh issue create \
            --title "$title" \
            --body "$body" \
            --label "$labels" \
            --milestone "$milestone" \
            --silent && echo -e "  ${GREEN}✓${NC} $title"
    fi
}

echo -e "\n  Creando issues de WiFi..."

create_issue \
    "[RF-WIFI-01] Escanear redes WiFi cercanas" \
    "El sistema debe poder escanear redes WiFi cercanas y mostrar SSID, BSSID, canal, potencia de señal y tipo de encriptación.\n\n**Herramienta:** airodump-ng\n**Módulo:** server/modules/wifi.py" \
    "modulo: wifi,prioridad: alta,fase: 2" \
    "Fase 2 — WiFi"

create_issue \
    "[RF-WIFI-02] Poner interfaz WiFi en modo monitor" \
    "El sistema debe poder poner la interfaz WiFi en modo monitor para captura pasiva de paquetes.\n\n**Herramienta:** airmon-ng\n**Módulo:** server/modules/wifi.py" \
    "modulo: wifi,prioridad: alta,fase: 2" \
    "Fase 2 — WiFi"

create_issue \
    "[RF-WIFI-03] Capturar handshakes WPA/WPA2" \
    "El sistema debe poder capturar handshakes WPA/WPA2 de redes objetivo.\n\n**Herramienta:** airodump-ng\n**Módulo:** server/modules/wifi.py" \
    "modulo: wifi,prioridad: alta,fase: 2" \
    "Fase 2 — WiFi"

create_issue \
    "[RF-WIFI-04] Ejecutar ataque de desautenticación (deauth)" \
    "El sistema debe poder ejecutar ataques de desautenticación contra clientes de una red.\n\n**Herramienta:** aireplay-ng --deauth\n**Módulo:** server/modules/wifi.py" \
    "modulo: wifi,prioridad: alta,fase: 2" \
    "Fase 2 — WiFi"

create_issue \
    "[RF-WIFI-05] Crear Access Point falso (Evil Twin)" \
    "El sistema debe poder crear un Access Point falso con el SSID de una red objetivo.\n\n**Herramienta:** hostapd + dnsmasq\n**Módulo:** server/modules/wifi.py" \
    "modulo: wifi,prioridad: media,fase: 2" \
    "Fase 2 — WiFi"

create_issue \
    "[RF-WIFI-06] Ataque MITM sobre clientes del Evil Twin" \
    "El sistema debe poder realizar ataques MITM sobre clientes conectados al Evil Twin.\n\n**Herramienta:** iptables + mitmproxy\n**Módulo:** server/modules/wifi.py" \
    "modulo: wifi,prioridad: media,fase: 2" \
    "Fase 2 — WiFi"

create_issue \
    "[RF-WIFI-07] Crackear handshakes con diccionarios" \
    "El sistema debe poder intentar crackear handshakes capturados usando diccionarios.\n\n**Herramienta:** aircrack-ng\n**Módulo:** server/modules/wifi.py" \
    "modulo: wifi,prioridad: media,fase: 2" \
    "Fase 2 — WiFi"

create_issue \
    "[RF-WIFI-08] Seleccionar interfaz WiFi a usar" \
    "El sistema debe permitir al usuario seleccionar la interfaz WiFi a usar (interna o adaptador externo).\n\n**Módulo:** server/modules/wifi.py" \
    "modulo: wifi,prioridad: alta,fase: 2" \
    "Fase 2 — WiFi"

echo -e "\n  Creando issues de Red..."

create_issue \
    "[RF-NET-01] Escanear hosts activos en rango de IPs" \
    "El sistema debe poder escanear hosts activos en un rango de IPs dado.\n\n**Herramienta:** nmap\n**Módulo:** server/modules/network.py" \
    "modulo: network,prioridad: alta,fase: 1" \
    "Fase 1 — Backend base"

create_issue \
    "[RF-NET-02] Detectar puertos abiertos y servicios" \
    "El sistema debe poder detectar puertos abiertos y servicios corriendo en un host objetivo.\n\n**Herramienta:** nmap -sV\n**Módulo:** server/modules/network.py" \
    "modulo: network,prioridad: alta,fase: 1" \
    "Fase 1 — Backend base"

create_issue \
    "[RF-NET-03] Detectar versión de servicios" \
    "El sistema debe poder detectar la versión de los servicios detectados en un host.\n\n**Herramienta:** nmap -sV\n**Módulo:** server/modules/network.py" \
    "modulo: network,prioridad: alta,fase: 1" \
    "Fase 1 — Backend base"

create_issue \
    "[RF-NET-04] Capturar tráfico de red en formato .pcap" \
    "El sistema debe poder capturar tráfico de red en una interfaz dada y guardarlo en formato .pcap.\n\n**Herramienta:** tcpdump / tshark\n**Módulo:** server/modules/network.py" \
    "modulo: network,prioridad: media,fase: 1" \
    "Fase 1 — Backend base"

create_issue \
    "[RF-NET-05] ARP spoofing para MITM en red local" \
    "El sistema debe poder realizar ARP spoofing para posicionarse como MITM en una red local.\n\n**Herramienta:** arpspoof / ettercap\n**Módulo:** server/modules/network.py" \
    "modulo: network,prioridad: media,fase: 1" \
    "Fase 1 — Backend base"

create_issue \
    "[RF-NET-06] DNS spoofing" \
    "El sistema debe poder realizar DNS spoofing para redirigir dominios a IPs controladas.\n\n**Herramienta:** dnsmasq\n**Módulo:** server/modules/network.py" \
    "modulo: network,prioridad: media,fase: 1" \
    "Fase 1 — Backend base"

create_issue \
    "[RF-NET-07] Integración con Metasploit" \
    "El sistema debe integrar Metasploit para explotación de vulnerabilidades detectadas.\n\n**Herramienta:** msfconsole / msfrpc\n**Módulo:** server/modules/exploits.py" \
    "modulo: network,prioridad: alta,fase: 1" \
    "Fase 1 — Backend base"

create_issue \
    "[RF-NET-08] Fuerza bruta sobre servicios SSH, FTP, HTTP" \
    "El sistema debe poder realizar ataques de fuerza bruta sobre servicios SSH, FTP y HTTP.\n\n**Herramienta:** hydra\n**Módulo:** server/modules/network.py" \
    "modulo: network,prioridad: media,fase: 1" \
    "Fase 1 — Backend base"

echo -e "\n  Creando issues de Bluetooth..."

create_issue \
    "[RF-BT-01] Escanear dispositivos Bluetooth y BLE" \
    "El sistema debe poder escanear dispositivos Bluetooth y BLE cercanos.\n\n**Herramienta:** hcitool / bluetoothctl\n**Módulo:** server/modules/bluetooth.py" \
    "modulo: bluetooth,prioridad: alta,fase: 4" \
    "Fase 4 — Módulos extra"

create_issue \
    "[RF-BT-02] Mostrar información de dispositivos BT encontrados" \
    "El sistema debe mostrar información de cada dispositivo encontrado: MAC, nombre, RSSI y servicios.\n\n**Herramienta:** hcitool / bettercap\n**Módulo:** server/modules/bluetooth.py" \
    "modulo: bluetooth,prioridad: alta,fase: 4" \
    "Fase 4 — Módulos extra"

create_issue \
    "[RF-BT-03] Capturar paquetes BLE" \
    "El sistema debe poder capturar paquetes BLE en el rango de alcance.\n\n**Herramienta:** btmon / hcidump\n**Módulo:** server/modules/bluetooth.py" \
    "modulo: bluetooth,prioridad: media,fase: 4" \
    "Fase 4 — Módulos extra"

create_issue \
    "[RF-BT-04] Intentar emparejamiento con dispositivos sin confirmación" \
    "El sistema debe poder intentar emparejar con dispositivos que no requieren confirmación manual.\n\n**Herramienta:** bluetoothctl\n**Módulo:** server/modules/bluetooth.py" \
    "modulo: bluetooth,prioridad: baja,fase: 4" \
    "Fase 4 — Módulos extra"

echo -e "\n  Creando issues de NFC/RFID..."

create_issue \
    "[RF-NFC-01] Leer tags NFC de 13.56MHz" \
    "El sistema debe poder leer tags NFC de 13.56MHz usando el chip interno del teléfono.\n\n**Herramienta:** libnfc / nfc-list\n**Módulo:** server/modules/nfc.py" \
    "modulo: nfc,prioridad: alta,fase: 4" \
    "Fase 4 — Módulos extra"

create_issue \
    "[RF-NFC-02] Escribir datos en tags NFC vírgenes" \
    "El sistema debe poder escribir datos personalizados en tags NFC vírgenes.\n\n**Herramienta:** nfc-write-tag\n**Módulo:** server/modules/nfc.py" \
    "modulo: nfc,prioridad: media,fase: 4" \
    "Fase 4 — Módulos extra"

create_issue \
    "[RF-NFC-03] Soporte RFID 125kHz via Proxmark3" \
    "El sistema debe soportar lectura/escritura de tags RFID de 125kHz mediante adaptador externo Proxmark3 conectado por USB.\n\n**Herramienta:** proxmark3 client\n**Módulo:** server/modules/nfc.py" \
    "modulo: nfc,prioridad: media,fase: 4" \
    "Fase 4 — Módulos extra"

create_issue \
    "[RF-NFC-04] Clonar tags NFC/RFID" \
    "El sistema debe poder clonar tags NFC/RFID compatibles a tags vírgenes.\n\n**Herramienta:** nfc-mfclassic / proxmark3\n**Módulo:** server/modules/nfc.py" \
    "modulo: nfc,prioridad: media,fase: 4" \
    "Fase 4 — Módulos extra"

create_issue \
    "[RF-NFC-05] Mostrar contenido decodificado del tag leído" \
    "El sistema debe mostrar el contenido decodificado del tag leído: UID, tipo, datos en formato legible.\n\n**Módulo:** server/modules/nfc.py" \
    "modulo: nfc,prioridad: alta,fase: 4" \
    "Fase 4 — Módulos extra"

echo -e "\n  Creando issues de HID..."

create_issue \
    "[RF-HID-01] Emular teclado USB via HID" \
    "El sistema debe poder emular un teclado USB cuando el teléfono se conecta a una PC por USB.\n\n**Herramienta:** hid-gadget-test / kernel HID gadget\n**Módulo:** server/modules/hid.py" \
    "modulo: hid,prioridad: alta,fase: 4" \
    "Fase 4 — Módulos extra"

create_issue \
    "[RF-HID-02] Cargar y ejecutar scripts de keystrokes" \
    "El sistema debe permitir al usuario cargar o escribir scripts de teclas a inyectar (estilo Rubber Ducky).\n\n**Módulo:** server/modules/hid.py" \
    "modulo: hid,prioridad: alta,fase: 4" \
    "Fase 4 — Módulos extra"

create_issue \
    "[RF-HID-03] Templates de payloads predefinidos" \
    "El sistema debe incluir templates de payloads predefinidos: reverse shell, exfiltración de datos, etc.\n\n**Módulo:** server/modules/hid.py" \
    "modulo: hid,prioridad: media,fase: 4" \
    "Fase 4 — Módulos extra"

create_issue \
    "[RF-HID-04] Configurar delay entre keystrokes" \
    "El sistema debe permitir configurar el delay en ms entre cada keystroke del payload.\n\n**Módulo:** server/modules/hid.py" \
    "modulo: hid,prioridad: media,fase: 4" \
    "Fase 4 — Módulos extra"

echo -e "\n  Creando issues del Motor de Decisión..."

create_issue \
    "[RF-DEC-01] Sugerir vector de ataque automáticamente" \
    "El sistema debe analizar los resultados de un escaneo y sugerir automáticamente el siguiente vector de ataque más probable.\n\n**Módulo:** server/modules/decision.py" \
    "modulo: decision,prioridad: alta,fase: 5" \
    "Fase 5 — Motor decisión"

create_issue \
    "[RF-DEC-02] Priorizar vectores por probabilidad de éxito" \
    "El sistema debe priorizar vectores de ataque según probabilidad de éxito basada en puertos abiertos, servicios detectados y vulnerabilidades conocidas.\n\n**Módulo:** server/modules/decision.py" \
    "modulo: decision,prioridad: media,fase: 5" \
    "Fase 5 — Motor decisión"

create_issue \
    "[RF-DEC-03] Integración con API de LLM para análisis contextual" \
    "El sistema debe poder integrarse con una API de LLM (Claude/OpenAI) para análisis contextual avanzado de resultados y sugerencia de ataques.\n\n**Módulo:** server/modules/decision.py" \
    "modulo: decision,prioridad: baja,fase: 5" \
    "Fase 5 — Motor decisión"

create_issue \
    "[RF-DEC-04] Logging de todas las acciones ejecutadas" \
    "El sistema debe registrar un log de todas las acciones ejecutadas con timestamp, parámetros usados y resultado.\n\n**Módulo:** server/logger.py" \
    "modulo: decision,prioridad: alta,fase: 1" \
    "Fase 1 — Backend base"

echo -e "\n  Creando issues de UI..."

create_issue \
    "[RF-UI-01] Menú principal con módulos disponibles" \
    "La APK debe presentar un menú principal con acceso a todos los módulos disponibles.\n\n**Stack:** Android Studio / Kotlin" \
    "modulo: ui,prioridad: alta,fase: 3" \
    "Fase 3 — APK básica"

create_issue \
    "[RF-UI-02] Pantalla de configuración de parámetros por módulo" \
    "Cada módulo debe tener una pantalla de configuración donde el usuario ingresa los parámetros necesarios (IP, puerto, interfaz, etc.).\n\n**Stack:** Android Studio / Kotlin" \
    "modulo: ui,prioridad: alta,fase: 3" \
    "Fase 3 — APK básica"

create_issue \
    "[RF-UI-03] Mostrar output de herramientas en tiempo real" \
    "La APK debe mostrar el output de cada herramienta en tiempo real mediante streaming desde el servidor Flask.\n\n**Stack:** WebSocket / SSE" \
    "modulo: ui,prioridad: alta,fase: 3" \
    "Fase 3 — APK básica"

create_issue \
    "[RF-UI-04] Diseño visual estilo Watch Dogs" \
    "La APK debe tener un diseño visual inspirado en el teléfono de Watch Dogs: tema oscuro, tipografía monoespaciada, colores neón.\n\n**Stack:** Android Studio / Material Design" \
    "modulo: ui,prioridad: baja,fase: 6" \
    "Fase 6 — UI final"

create_issue \
    "[RF-UI-05] Mostrar estado del chroot de Kali" \
    "La APK debe mostrar el estado actual del chroot de Kali (activo/inactivo) y permitir iniciarlo/detenerlo.\n\n**Stack:** Android Studio / Kotlin" \
    "modulo: ui,prioridad: media,fase: 3" \
    "Fase 3 — APK básica"

create_issue \
    "[RF-UI-06] Guardar y cargar configuraciones de ataques" \
    "La APK debe permitir guardar configuraciones de ataques previos y cargarlas para reutilizarlas.\n\n**Stack:** Android Room Database" \
    "modulo: ui,prioridad: baja,fase: 6" \
    "Fase 6 — UI final"

# ── Resumen final ────────────────────────────────────────────
echo -e "\n${GREEN}=== Setup completado ===${NC}"
echo -e "Repositorio: ${GREEN}https://github.com/$REPO${NC}"
echo -e "Issues creados: ${GREEN}$(gh issue list --limit 100 --json number -q 'length')${NC}"
echo -e "\nPodés ver todo en: ${GREEN}https://github.com/$REPO/issues${NC}"
