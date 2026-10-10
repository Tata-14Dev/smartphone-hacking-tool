#!/bin/bash
# ==============================================================================
# setup.sh - Instalador/actualizador de dependencias de WATCHDOG.
# Correr COMO ROOT, DENTRO del chroot de Kali, una sola vez al clonar (o para
# actualizar). Necesita internet solo en este paso.
#   su -> chroot ... -> cd /root/watchdog-git -> bash scripts/setup.sh
# ==============================================================================
set -u
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$HERE")"

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[X] Correr como root, dentro del chroot de Kali.${NC}"
    exit 1
fi

echo -e "${CYAN}[*] Actualizando indices de apt...${NC}"
apt-get update -y || { echo -e "${RED}[X] apt-get update fallo (¿hay internet?).${NC}"; exit 1; }

echo -e "${CYAN}[*] Instalando dependencias del sistema...${NC}"
# aircrack-ng trae airodump-ng/aireplay-ng/aircrack-ng
apt-get install -y \
    aircrack-ng nmap hostapd dnsmasq wireless-tools iw wifite \
    python3 python3-pip \
    || { echo -e "${RED}[X] Fallo instalando paquetes de apt.${NC}"; exit 1; }

echo -e "${CYAN}[*] Instalando dependencias de Python...${NC}"
if [ -f "$REPO/server/requirements.txt" ]; then
    pip3 install --break-system-packages -r "$REPO/server/requirements.txt" \
        || pip3 install --break-system-packages flask
else
    pip3 install --break-system-packages flask
fi

echo ""
echo -e "${GREEN}[OK] Setup completo.${NC}"
echo -e "${CYAN}[*] Verificando...${NC}"
bash "$HERE/kali-scripts/check_deps.sh" || true
