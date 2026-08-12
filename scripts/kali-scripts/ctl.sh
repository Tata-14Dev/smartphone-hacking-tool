#!/bin/bash
# ============================================================
# ctl.sh v2 — Controlador Watch Dogs (con TUI animado)
#
#   ./ctl.sh start | stop | restart | status | update | logs | web
#   ./ctl.sh            -> menu interactivo animado
# ============================================================

PROJECT_DIR="/root/watchdog-git"
SERVER_DIR="$PROJECT_DIR/server"
PID_FILE="/tmp/watchdog.pid"
LOG_FILE="/tmp/watchdog_logs/watchdog.log"
SERVER_LOG="/tmp/watchdog_server.out"
PORT=5001

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; DIM='\033[2;37m'; NC='\033[0m'

# ── Efecto "desencriptando": muestra chars random y resuelve al texto ──
decrypt_line() {
    local text="$1" color="$2" i c rnd
    local charset='#%&$@01<>{}[]/\|=+*'
    for ((i=0; i<${#text}; i++)); do
        c="${text:$i:1}"
        if [ "$c" == " " ]; then printf " "; continue; fi
        for ((r=0; r<2; r++)); do
            rnd="${charset:RANDOM%${#charset}:1}"
            printf "${DIM}%s${NC}\b" "$rnd"; sleep 0.004
        done
        printf "${color}%s${NC}" "$c"
    done
    printf "\n"
}

banner() {
    clear
    echo -e "${CYAN}"
    local B=(
' ██╗    ██╗ █████╗ ████████╗ ██████╗██╗  ██╗'
' ██║    ██║██╔══██╗╚══██╔══╝██╔════╝██║  ██║'
' ██║ █╗ ██║███████║   ██║   ██║     ███████║'
' ██║███╗██║██╔══██║   ██║   ██║     ██╔══██║'
' ╚███╔███╔╝██║  ██║   ██║   ╚██████╗██║  ██║'
'  ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝'
    )
    for l in "${B[@]}"; do echo "$l"; sleep 0.03; done
    echo -e "${NC}"
    decrypt_line "     [ WATCHDOG // ACCESS TERMINAL ]" "$CYAN"
    echo ""
}

is_running() {
    [ -f "$PID_FILE" ] || return 1
    kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

start() {
    if is_running; then
        echo -e "${YELLOW}[!] Server ya activo (PID $(cat "$PID_FILE"))${NC}"; return; fi
    echo -e "${CYAN}[*] Iniciando server...${NC}"
    cd "$SERVER_DIR" || { echo -e "${RED}[X] No existe $SERVER_DIR${NC}"; return 1; }
    nohup python3 app.py > "$SERVER_LOG" 2>&1 &
    echo $! > "$PID_FILE"; sleep 1
    if is_running; then
        echo -e "${GREEN}[OK] Server ARRIBA — PID $(cat "$PID_FILE") — http://localhost:$PORT${NC}"
    else
        echo -e "${RED}[X] No arranco. Ver: ./ctl.sh logs${NC}"; fi
}
stop() {
    if ! is_running; then echo -e "${YELLOW}[!] No estaba corriendo${NC}"; rm -f "$PID_FILE"; return; fi
    local pid; pid=$(cat "$PID_FILE")
    echo -e "${CYAN}[*] Cerrando (PID $pid)...${NC}"
    kill "$pid" 2>/dev/null; sleep 1
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
    rm -f "$PID_FILE"; echo -e "${GREEN}[OK] Server DETENIDO${NC}"
}
restart(){ stop; sleep 1; start; }
status(){
    if is_running; then
        echo -e "${GREEN}[OK] ARRIBA — PID $(cat "$PID_FILE") — puerto $PORT${NC}"
    else echo -e "${RED}[--] ABAJO${NC}"; fi
}
update(){
    echo -e "${CYAN}[*] git pull...${NC}"
    cd "$PROJECT_DIR" || { echo -e "${RED}[X] No existe $PROJECT_DIR${NC}"; return 1; }
    if git pull; then echo -e "${GREEN}[OK] Actualizado. Si estaba arriba: ./ctl.sh restart${NC}"
    else echo -e "${RED}[X] git pull fallo${NC}"; fi
}
logs(){
    echo -e "${CYAN}[*] Log de la app:${NC}"
    [ -f "$LOG_FILE" ] && tail -n 25 "$LOG_FILE" || echo -e "${YELLOW}[!] Sin log aun${NC}"
    echo -e "${CYAN}[*] Salida server:${NC}"
    [ -f "$SERVER_LOG" ] && tail -n 12 "$SERVER_LOG"
}
open_web(){
    # abre el navegador (funciona si se llama desde Termux con acceso a am)
    am start -a android.intent.action.VIEW -d "http://localhost:$PORT" >/dev/null 2>&1 \
      && echo -e "${GREEN}[OK] Abriendo navegador...${NC}" \
      || echo -e "${YELLOW}[!] Abrí manualmente http://localhost:$PORT${NC}"
}

menu(){
    while true; do
        banner
        if is_running; then st="${GREEN}● ONLINE${NC}"; else st="${RED}● OFFLINE${NC}"; fi
        echo -e "   estado: $st"
        echo ""
        echo -e "   ${GREEN}[1]${NC} START      iniciar server"
        echo -e "   ${GREEN}[2]${NC} STOP       detener server"
        echo -e "   ${GREEN}[3]${NC} RESTART    reiniciar"
        echo -e "   ${GREEN}[4]${NC} UPDATE     git pull"
        echo -e "   ${GREEN}[5]${NC} STATUS     ver estado"
        echo -e "   ${GREEN}[6]${NC} LOGS       ver logs"
        echo -e "   ${GREEN}[7]${NC} WEB        abrir interfaz"
        echo -e "   ${GREEN}[0]${NC} EXIT"
        echo ""
        echo -ne "${CYAN}   watchdog> ${NC}"; read -r ch
        echo ""
        case "$ch" in
            1) start ;; 2) stop ;; 3) restart ;; 4) update ;;
            5) status ;; 6) logs ;; 7) open_web ;; 0) clear; exit 0 ;;
            *) echo -e "${RED}[X] Opcion invalida${NC}" ;;
        esac
        echo ""; echo -ne "${DIM}   [enter para continuar]${NC}"; read -r
    done
}

case "$1" in
    start) start ;; stop) stop ;; restart) restart ;;
    status) status ;; update) update ;; logs) logs ;; web) open_web ;;
    "") menu ;;
    *) echo -e "${RED}Uso: $0 {start|stop|restart|status|update|logs|web}${NC}" ;;
esac
