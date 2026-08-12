#!/bin/bash
# ==============================================================================
# wifite_auto.sh - Auditoría de Wifite para interfaz fija wlan2.
# Guarda archivos .cap y genera un registro de contraseñas obtenidas.
# ==============================================================================

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; DIM='\033[2;37m'; NC='\033[0m'

IFACE="wlan2"
PROJECT_DIR="/root/watchdog-git"
HS_DIR="$PROJECT_DIR/handshakes"
REPORT_FILE="$HS_DIR/accesos_exitosos.txt"

# Asegurar que existan los directorios
mkdir -p "$HS_DIR"
touch "$REPORT_FILE"

start_audit() {
    echo -e "${CYAN}[*] Iniciando auditoría automatizada en la interfaz $IFACE...${NC}"
    
    # 1. Validar existencia de la interfaz
    if ! ip link show "$IFACE" > /dev/null 2>&1; then
        echo -e "${RED}[ERROR] No se encontró la interfaz inalámbrica $IFACE.${NC}"
        exit 1
    fi

    # 2. Detener servicios conflictivos únicamente para wlan2 (Estilo monitor.sh)
    if command -v pkill >/dev/null 2>&1; then
        pkill -f "wpa_supplicant.*$IFACE" 2>/dev/null
    fi

    # 3. Configuración limpia del modo monitor
    ip link set "$IFACE" down 2>/dev/null
    if ! iw dev "$IFACE" set type monitor 2>/dev/null; then
        echo -e "${RED}[ERROR] iw no pudo cambiar $IFACE a modo monitor.${NC}"
        ip link set "$IFACE" up 2>/dev/null
        exit 1
    fi
    ip link set "$IFACE" up 2>/dev/null
    sleep 1

    # Validar éxito del modo monitor
    if ! iw dev "$IFACE" info 2>/dev/null | grep -q "type monitor"; then
        echo -e "${RED}[ERROR] La interfaz se configuró pero no quedó en modo monitor.${NC}"
        exit 1
    fi
    echo -e "${GREEN}[OK] Interfaz $IFACE establecida en modo monitor.${NC}"

    echo -e "${CYAN}[*] Lanzando Wifite en segundo plano...${NC}"
    echo -e "${DIM}[+] Capturas y reportes se almacenarán en: $HS_DIR${NC}"
    echo ""

    # 4. Ejecución del ataque Wifite
    # Wifite guarda un archivo de texto llamado 'cracked.txt' en su directorio de trabajo
    # cuando logra descifrar una contraseña de forma exitosa.
    wifite -i "$IFACE" --kill --skip-hcxdumptool --all --hs-dir "$HS_DIR"

    # 5. Post-Procesamiento: Generar reporte pertinente (Estilo quickscan.sh)
    # Si Wifite crackeó contraseñas en esta sesión, las volcamos a nuestro reporte centralizado
    if [ -f "cracked.txt" ]; then
        echo -e "${GREEN}[OK] ¡Se encontraron contraseñas descifradas! Generando reporte...${NC}"
        STAMP=$(date "+%Y-%m-%d %H:%M:%S")
        
        echo "==================================================" >> "$REPORT_FILE"
        echo " AUDITORÍA RECIENTE - FECHA: $STAMP" >> "$REPORT_FILE"
        echo "==================================================" >> "$REPORT_FILE"
        
        # Leemos el archivo cracked.txt de Wifite (Formato típico: BSSID, SSID, Encriptación, Password)
        while IFS=, read -r bssid encryption ssid password _; do
            # Limpiamos espacios en blanco de las variables
            bssid=$(echo "$bssid" | xargs)
            ssid=$(echo "$ssid" | xargs)
            encryption=$(echo "$encryption" | xargs)
            password=$(echo "$password" | xargs)
            
            if [ -n "$ssid" ] && [ -n "$password" ]; then
                echo "• RED Wi-Fi     : $ssid" >> "$REPORT_FILE"
                echo "  Dirección MAC : $bssid" >> "$REPORT_FILE"
                echo "  Seguridad     : $encryption" >> "$REPORT_FILE"
                echo "  CONTRASEÑA    : $password" >> "$REPORT_FILE"
                echo "--------------------------------------------------" >> "$REPORT_FILE"
            fi
        done < cracked.txt
        
        # Limpieza del archivo temporal de Wifite
        rm -f cracked.txt
    else
        echo -e "${YELLOW}[!] La sesión finalizó sin claves descifradas (Handshakes almacenados).${NC}"
    fi

    # 6. Restauración limpia del hardware
    echo -e "${CYAN}[*] Devolviendo la antena $IFACE a modo managed...${NC}"
    ip link set "$IFACE" down 2>/dev/null
    iw dev "$IFACE" set type managed 2>/dev/null
    ip link set "$IFACE" up 2>/dev/null
    echo -e "${GREEN}[OK] Proceso finalizado. Hardware restaurado.${NC}"
}

# Validación de privilegios
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Este script requiere privilegios de root.${NC}"
    exit 1
fi

start_audit
