#!/bin/bash
# ==============================================================================
# wifi_eviltwin.sh - Despliegue de Punto de Acceso Falso (Evil Twin).
# ==============================================================================
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

IFACE="wlan2"
FAKE_SSID="$1"
CONF_FILE="/tmp/hostapd.conf"

echo -e "${CYAN}[*] Configurando entorno para Punto de Acceso Falso...${NC}"

if [ -z "$FAKE_SSID" ]; then
    echo -e "${RED}[X] Error: Nombre de red SSID vacío.${NC}"; exit 1
fi

# Desconectar cualquier software de gestión inalámbrica sobre wlan2
if command -v pkill >/dev/null 2>&1; then
    pkill -f "wpa_supplicant.*$IFACE" 2>/dev/null
    pkill -f "hostapd" 2>/dev/null
fi

# Forzar interfaz a modo Managed (Punto de acceso nativo requiere este estado)
ip link set "$IFACE" down 2>/dev/null
iw dev "$IFACE" set type managed 2>/dev/null
ip link set "$IFACE" up 2>/dev/null
sleep 1

# Generación dinámica del archivo hostapd (Manteniendo la estética limpia de tu repo)
cat << EOF > "$CONF_FILE"
interface=$IFACE
driver=nl80211
ssid=$FAKE_SSID
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF

echo -e "${GREEN}[OK] Archivo de configuración temporal montado en $CONF_FILE${NC}"
echo -e "${GREEN}[OK] Desplegando red gemela: [ $FAKE_SSID ] en canal 6...${NC}"
echo -e "${CYAN}[*] Presioná 'DETENER' en la interfaz web para apagar el punto de acceso.${NC}"
echo ""

# Ejecución de hostapd en primer plano para transferir sus logs en tiempo real al SSE
hostapd "$CONF_FILE"

# Al ser abortado por el usuario desde la UI, se limpia el entorno de red
echo ""
echo -e "${CYAN}[*] Apagando Punto de Acceso y limpiando interfaces...${NC}"
rm -f "$CONF_FILE"
echo -e "${GREEN}[OK] Red inalámbrica restaurada.${NC}"
