#!/bin/bash
# ============================================================
# quickscan.sh — Menu de escaneo que se adapta a la red actual.
# Las opciones se generan segun el entorno (red / gateway detectados).
# Corre DENTRO del chroot de Kali. Uso: solo sobre TU red / redes autorizadas.
# ============================================================

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
mkdir -p /root/scans

# ── Detección de entorno ───────────────────────────────────
# $(...) captura la salida del comando en una variable.

# Interfaz por la que sale el trafico (la de la ruta default)
IFACE=$(ip route 2>/dev/null | awk '/default/{print $5; exit}')

# Gateway (router)
GATEWAY=$(ip route 2>/dev/null | awk '/default/{print $3; exit}')

# Rango de red al que pertenece esa interfaz (ej. 192.168.1.0/24)
NETWORK=$(ip route 2>/dev/null | awk -v i="$IFACE" '$0 ~ i && /\//{print $1; exit}')

# Mi propia IP en esa interfaz
MYIP=$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet /{print $2; exit}' | cut -d/ -f1)

# ── Mostrar el entorno detectado ───────────────────────────
clear
echo -e "${CYAN}== QUICKSCAN — entorno detectado ==${NC}"
if [ -z "$NETWORK" ]; then
    echo -e "${RED}[X] No se detecto una red activa.${NC}"
    echo -e "${YELLOW}    ¿Estas conectado a alguna red? Proba: ip route${NC}"
    echo; echo "[enter para salir]"; read; exit 1
fi
echo -e "  Interfaz : ${GREEN}${IFACE:-?}${NC}"
echo -e "  Mi IP    : ${GREEN}${MYIP:-?}${NC}"
echo -e "  Red      : ${GREEN}${NETWORK:-?}${NC}"
echo -e "  Router   : ${GREEN}${GATEWAY:-?}${NC}"
echo ""

# ── Menu con opciones armadas a partir del entorno ─────────
echo -e "${CYAN}== Que escaneo? ==${NC}"
echo -e "  ${GREEN}1)${NC} Descubrir hosts en mi red  (${NETWORK})"
echo -e "  ${GREEN}2)${NC} Escanear el router          (${GATEWAY})"
echo -e "  ${GREEN}3)${NC} Objetivo custom (lo escribo)"
echo -e "  ${GREEN}0)${NC} Salir"
echo ""
read -p "Opcion: " OP

case "$OP" in
    1) TARGET="$NETWORK"; MODE="ping" ;;
    2) TARGET="$GATEWAY"; MODE="ports" ;;
    3) read -p "IP o rango: " TARGET
       read -p "Modo [1=ping 2=puertos]: " M
       [ "$M" = "2" ] && MODE="ports" || MODE="ping" ;;
    0) exit 0 ;;
    *) echo -e "${RED}Opcion invalida${NC}"; exit 1 ;;
esac

if [ -z "$TARGET" ]; then
    echo -e "${RED}[X] Sin objetivo. Cancelado.${NC}"; exit 1
fi

# ── Ejecutar ───────────────────────────────────────────────
STAMP=$(date +%F_%H%M%S)
OUT="/root/scans/${MODE}_${STAMP}.txt"
echo ""
echo -e "${CYAN}[*] Escaneando ${TARGET} (${MODE})...${NC}"

if [ "$MODE" = "ports" ]; then
    nmap -sV "$TARGET" -oN "$OUT"
else
    nmap -sn "$TARGET" -oN "$OUT"
fi

echo -e "${GREEN}[OK] Resultado en $OUT${NC}"
echo; echo "[enter para cerrar]"; read
