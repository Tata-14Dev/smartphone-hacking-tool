#!/bin/bash
# ============================================================
# monitor.sh — Deja la antena externa en modo monitor.
# Metodo directo (ip + iw), sin airmon-ng check kill (que colgaba).
# Corre DENTRO del chroot de Kali.
#
#   ./monitor.sh          -> autodetecta la antena y la pone en monitor
#   ./monitor.sh stop     -> la devuelve a modo managed
# ============================================================

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

# Autodetecta la antena externa: interfaz wlan* cuyo phy soporta monitor
# y que NO este asociada a un SSID (esa es tu conexion interna).
detect_iface() {
    local ifaces i phy
    ifaces=$(iw dev 2>/dev/null | awk '/Interface/{print $2}')
    for i in $ifaces; do
        phy=$(iw dev "$i" info 2>/dev/null | awk '/wiphy/{print "phy"$2}')
        if iw phy "$phy" info 2>/dev/null | grep -q "\* monitor"; then
            if ! iw dev "$i" info 2>/dev/null | grep -q "ssid "; then
                echo "$i"; return 0
            fi
        fi
    done
    return 1
}

start_monitor() {
    echo -e "${CYAN}[*] Buscando antena externa...${NC}"
    IFACE=$(detect_iface)
    if [ -z "$IFACE" ]; then
        echo -e "${RED}[X] No se detecto antena capaz de monitor.${NC}"
        echo -e "${YELLOW}    ¿Esta enchufada por OTG? Proba: iw dev${NC}"
        return 1
    fi
    echo -e "${GREEN}[OK] Antena detectada: $IFACE${NC}"

    if iw dev "$IFACE" info 2>/dev/null | grep -q "type monitor"; then
        echo -e "${GREEN}[OK] $IFACE ya esta en modo monitor.${NC}"
        return 0
    fi

    # Solo frenamos wpa_supplicant SI existe, y sin matar toda la sesion.
    # (no usamos airmon-ng check kill porque colgaba el entorno)
    if command -v pkill >/dev/null 2>&1; then
        pkill -f "wpa_supplicant.*$IFACE" 2>/dev/null
    fi

    echo -e "${CYAN}[*] Configurando modo monitor via ip/iw...${NC}"
    # Metodo directo: bajar -> monitor -> subir
    ip link set "$IFACE" down 2>/dev/null
    if iw dev "$IFACE" set type monitor 2>/dev/null; then
        ip link set "$IFACE" up 2>/dev/null
        sleep 1
        if iw dev "$IFACE" info 2>/dev/null | grep -q "type monitor"; then
            echo -e "${GREEN}[OK] Modo monitor ACTIVO en: $IFACE${NC}"
            echo -e "${CYAN}    (usa este nombre en app.py -> iface)${NC}"
        else
            echo -e "${RED}[X] Se configuro pero no quedo en monitor. Proba: iw dev${NC}"
            return 1
        fi
    else
        echo -e "${RED}[X] iw no pudo cambiar a monitor.${NC}"
        ip link set "$IFACE" up 2>/dev/null
        return 1
    fi
}

stop_monitor() {
    echo -e "${CYAN}[*] Devolviendo la antena a modo managed...${NC}"
    local i
    for i in $(iw dev 2>/dev/null | awk '/Interface/{print $2}'); do
        if iw dev "$i" info 2>/dev/null | grep -q "type monitor"; then
            ip link set "$i" down 2>/dev/null
            iw dev "$i" set type managed 2>/dev/null
            ip link set "$i" up 2>/dev/null
            echo -e "${GREEN}[OK] $i devuelta a managed${NC}"
        fi
    done
}

case "$1" in
    stop) stop_monitor ;;
    *)    start_monitor ;;
esac