#!/bin/bash
# ============================================================
# monitor.sh — Deja la antena externa en modo monitor.
# Corre DENTRO del chroot de Kali (necesita airmon-ng / iw).
#
#   ./monitor.sh          -> autodetecta la antena y la pone en monitor
#   ./monitor.sh stop     -> la devuelve a modo managed
# ============================================================

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

# El chip WiFi interno del telefono es phy0 y NO soporta monitor.
# Autodetectamos la antena externa: la interfaz wlan* que NO sea la interna.
# La interna suele ser la que tiene una IP / esta asociada a un SSID.
detect_iface() {
    # lista interfaces wlan gestionadas por nl80211
    local ifaces
    ifaces=$(iw dev 2>/dev/null | awk '/Interface/{print $2}')
    for i in $ifaces; do
        # la antena externa: soporta monitor en su phy
        local phy
        phy=$(iw dev "$i" info 2>/dev/null | awk '/wiphy/{print "phy"$2}')
        if iw phy "$phy" info 2>/dev/null | grep -q "\* monitor"; then
            # y ademas no debe ser la que tiene el SSID de tu conexion normal
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
        echo -e "${RED}[X] No se detecto ninguna antena capaz de monitor.${NC}"
        echo -e "${YELLOW}    ¿Esta enchufada por OTG? Proba: iw dev${NC}"
        return 1
    fi
    echo -e "${GREEN}[OK] Antena detectada: $IFACE${NC}"

    # ¿ya esta en monitor?
    if iw dev "$IFACE" info 2>/dev/null | grep -q "type monitor"; then
        echo -e "${GREEN}[OK] $IFACE ya esta en modo monitor. Nada que hacer.${NC}"
        return 0
    fi

    echo -e "${CYAN}[*] Matando procesos que interfieren...${NC}"
    airmon-ng check kill >/dev/null 2>&1

    echo -e "${CYAN}[*] Poniendo $IFACE en modo monitor...${NC}"
    airmon-ng start "$IFACE" >/dev/null 2>&1

    # airmon-ng puede renombrar a <iface>mon; re-detectamos
    sleep 1
    RES=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | while read -r i; do
        iw dev "$i" info 2>/dev/null | grep -q "type monitor" && echo "$i"
    done | head -n1)

    if [ -n "$RES" ]; then
        echo -e "${GREEN}[OK] Modo monitor ACTIVO en: $RES${NC}"
        echo -e "${CYAN}    (usa este nombre en app.py -> iface)${NC}"
    else
        echo -e "${RED}[X] No se pudo confirmar el modo monitor. Proba manual: iw dev${NC}"
        return 1
    fi
}

stop_monitor() {
    echo -e "${CYAN}[*] Devolviendo interfaces a modo managed...${NC}"
    iw dev 2>/dev/null | awk '/Interface/{print $2}' | while read -r i; do
        if iw dev "$i" info 2>/dev/null | grep -q "type monitor"; then
            airmon-ng stop "$i" >/dev/null 2>&1
            echo -e "${GREEN}[OK] $i devuelta a managed${NC}"
        fi
    done
}

case "$1" in
    stop) stop_monitor ;;
    *)    start_monitor ;;
esac
