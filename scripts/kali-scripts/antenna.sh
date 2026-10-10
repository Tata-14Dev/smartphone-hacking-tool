#!/bin/bash
# ==============================================================================
# antenna.sh - Salud / preparacion / recuperacion de la antena externa (wlan2).
# Uso: antenna.sh [status|prepare|reset]
#   status  -> informa estado de la antena y procesos que puedan molestar
#   prepare -> deja la antena en modo monitor (idempotente)
#   reset   -> mata procesos colgados (hostapd/airodump/aireplay/wifite) y
#              recupera la antena a monitor SIN necesidad de reiniciar el telefono
#
# FOOLPROOF: solo opera sobre la antena EXTERNA (la unica interfaz cuyo phy
# soporta modo monitor). NUNCA toca wlan0/wlan1 (WiFi interno del telefono),
# asi que no te corta tu propia conexion. Corre DENTRO del chroot de Kali.
# ==============================================================================
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

EXPECTED="wlan2"   # nombre que espera app.py (ver notas / config M5)

# --- Detecta la antena externa: la interfaz cuyo phy soporta "monitor".
#     El WiFi interno (BCM) NO soporta monitor, asi que queda excluido solo. ---
detect_iface() {
    local i phy
    for i in $(iw dev 2>/dev/null | awk '/Interface/{print $2}'); do
        phy=$(iw dev "$i" info 2>/dev/null | awk '/wiphy/{print "phy"$2}')
        if iw phy "$phy" info 2>/dev/null | grep -qE '^[[:space:]]*\* monitor'; then
            echo "$i"; return 0
        fi
    done
    return 1
}

driver_of() {
    local i="$1" d
    d=$(readlink -f "/sys/class/net/$i/device/driver" 2>/dev/null)
    [ -n "$d" ] && basename "$d" || echo "desconocido"
}

# Lista procesos que suelen dejar la antena ocupada ("resource busy") o en modo AP.
list_conflicts() {
    local found=0 p
    for p in hostapd dnsmasq airodump-ng aireplay-ng wifite; do
        if pgrep -x "$p" >/dev/null 2>&1 || pgrep -f "$p" >/dev/null 2>&1; then
            echo -e "${YELLOW}    - $p esta corriendo${NC}"; found=1
        fi
    done
    [ "$found" -eq 0 ] && echo -e "${GREEN}    (sin procesos en conflicto)${NC}"
}

show_status() {
    echo -e "${CYAN}[*] Estado de la antena${NC}"
    IFACE=$(detect_iface)
    if [ -z "$IFACE" ]; then
        echo -e "${RED}[X] No se detecto antena capaz de monitor.${NC}"
        echo -e "${YELLOW}    ¿Esta enchufada por OTG? Proba: iw dev / lsusb${NC}"
        echo -e "${CYAN}[*] Procesos:${NC}"; list_conflicts
        return 1
    fi
    local type ch tp drv
    type=$(iw dev "$IFACE" info 2>/dev/null | awk '/type/{print $2}')
    ch=$(iw dev "$IFACE" info 2>/dev/null | awk '/channel/{$1="";print $0}' | sed 's/^ //')
    tp=$(iw dev "$IFACE" info 2>/dev/null | awk '/txpower/{print $2, $3}')
    drv=$(driver_of "$IFACE")
    echo -e "${GREEN}[OK] Antena: $IFACE${NC}  (driver: $drv)"
    echo -e "    modo ........ ${type:-?}"
    echo -e "    canal ....... ${ch:-(sin fijar)}"
    echo -e "    txpower ..... ${tp:-?}"
    if [ "$type" = "monitor" ]; then
        echo -e "${GREEN}    => lista para escaneo/ataques${NC}"
    else
        echo -e "${YELLOW}    => NO esta en monitor. Corre 'prepare' o 'reset'.${NC}"
    fi
    if [ "$IFACE" != "$EXPECTED" ]; then
        echo -e "${YELLOW}[!] app.py espera '$EXPECTED' pero la antena es '$IFACE'.${NC}"
        echo -e "${YELLOW}    Ajusta iface en app.py (o la config de M5).${NC}"
    fi
    echo -e "${CYAN}[*] Procesos que podrian molestar:${NC}"; list_conflicts
}

set_monitor() {
    local IFACE="$1"
    if iw dev "$IFACE" info 2>/dev/null | grep -q "type monitor"; then
        echo -e "${GREEN}[OK] $IFACE ya esta en modo monitor.${NC}"; return 0
    fi
    # Solo frenamos wpa_supplicant de ESTA antena (no el del WiFi interno).
    pkill -f "wpa_supplicant.*$IFACE" 2>/dev/null
    echo -e "${CYAN}[*] Poniendo $IFACE en monitor (ip/iw)...${NC}"
    ip link set "$IFACE" down 2>/dev/null
    iw dev "$IFACE" set type monitor 2>/dev/null
    ip link set "$IFACE" up 2>/dev/null
    sleep 1
    if iw dev "$IFACE" info 2>/dev/null | grep -q "type monitor"; then
        echo -e "${GREEN}[OK] Monitor ACTIVO en $IFACE.${NC}"; return 0
    fi
    echo -e "${RED}[X] No quedo en monitor. Proba desenchufar/reenchufar la antena.${NC}"; return 1
}

do_prepare() {
    echo -e "${CYAN}[*] Preparando antena...${NC}"
    IFACE=$(detect_iface)
    if [ -z "$IFACE" ]; then
        echo -e "${RED}[X] No se detecto antena. ¿Enchufada por OTG?${NC}"; return 1
    fi
    echo -e "${GREEN}[OK] Antena detectada: $IFACE${NC}"
    set_monitor "$IFACE"
}

do_reset() {
    echo -e "${CYAN}[*] RESET de antena (recuperacion sin reboot)...${NC}"
    # 1. Matar lo que suele dejar la antena ocupada o en modo AP.
    echo -e "${CYAN}[*] Matando procesos colgados...${NC}"
    for p in aireplay-ng airodump-ng wifite hostapd dnsmasq; do
        pkill -9 -x "$p" 2>/dev/null; pkill -9 -f "$p" 2>/dev/null
    done
    sleep 1
    # 2. Detectar (ahora que no hay hostapd, la antena ya no figura como AP).
    IFACE=$(detect_iface)
    if [ -z "$IFACE" ]; then
        echo -e "${RED}[X] No se detecto antena tras limpiar. Reenchufa por OTG y reintenta.${NC}"
        return 1
    fi
    echo -e "${GREEN}[OK] Antena: $IFACE${NC}"
    # 3. Devolverla a monitor limpio.
    set_monitor "$IFACE"
    # 4. Reporte final.
    echo ""
    show_status
}

case "$1" in
    prepare) do_prepare ;;
    reset)   do_reset ;;
    status|"") show_status ;;
    *) echo -e "${RED}Uso: antenna.sh [status|prepare|reset]${NC}"; exit 1 ;;
esac
