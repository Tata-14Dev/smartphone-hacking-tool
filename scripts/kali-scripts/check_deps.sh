#!/bin/bash
# ==============================================================================
# check_deps.sh - Verifica que esten las herramientas que necesita WATCHDOG.
# Imprime estado por herramienta. Exit 0 si estan todas, 1 si falta alguna.
# Lo usa /api/health (la app avisa al abrir) y lo puede correr el usuario.
# ==============================================================================
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}[*] Chequeo de dependencias WATCHDOG${NC}"
MISS=0

check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} $1"
    else
        echo -e "${RED}[X]${NC} $1  (FALTA)"
        MISS=$((MISS+1))
    fi
}

# Comandos del sistema (vienen de: aircrack-ng, nmap, hostapd, dnsmasq, iw, wifite)
for c in iw ip nmap airodump-ng aireplay-ng aircrack-ng hostapd dnsmasq wifite python3; do
    check_cmd "$c"
done

# Modulo de Python (Flask)
if python3 -c "import flask" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} python:flask"
else
    echo -e "${RED}[X]${NC} python:flask  (FALTA)"
    MISS=$((MISS+1))
fi

echo ""
if [ "$MISS" -eq 0 ]; then
    echo -e "${GREEN}[OK] Todas las dependencias estan instaladas.${NC}"
    exit 0
else
    echo -e "${RED}[!] Faltan $MISS dependencia(s).${NC}"
    echo -e "${CYAN}    Instalalas con:  bash scripts/setup.sh   (dentro del chroot de Kali)${NC}"
    exit 1
fi
