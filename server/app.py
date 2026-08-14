"""
app.py — Orquestador del servidor (version 1).

Rol: recibir pedidos HTTP del navegador, validarlos minimamente,
DELEGAR el trabajo pesado a los modulos (network.py, etc.) y devolver
la respuesta. La logica real NO vive aca; aca solo se coordina.

Arrancar parado en la carpeta server/:
    cd server
    python3 app.py
"""

from flask import Flask, render_template, jsonify, request, Response
import os
import re
import queue
import signal
import subprocess
import threading

from logger import get_logger
from modules.network import NetworkScanner, ValidationError
from modules.wifi_scan import WifiScanner

log = get_logger(__name__)

# ── 1. Inicializacion ────────────────────────────────────────────────
app = Flask(
    __name__,
    template_folder=os.path.join(os.path.dirname(__file__), "..", "templates"),
    static_folder=os.path.join(os.path.dirname(__file__), "..", "static"),
)

# Cola compartida (patron productor/consumidor). El scanner escribe aca,
# el SSE lee de aca. queue.Queue ya es thread-safe (no necesitas mutex).
output_queue: "queue.Queue[str]" = queue.Queue()

# El scanner recibe como callback la funcion 'put' de la cola: cada linea
# que produce Nmap termina en la cola automaticamente. Aca se conectan
# los dos modulos.
scanner = NetworkScanner(on_line=output_queue.put)

# Scanner WiFi pasivo (reconocimiento). iface = interfaz en modo monitor.
# Ajustar a 'wlan2mon' si ese es el nombre que muestra `iw dev`.
wifi = WifiScanner(on_line=output_queue.put, iface="wlan2")


# ── 2. Generador del stream SSE ──────────────────────────────────────
def event_stream():
    """
    Lee la cola linea por linea y las emite en formato SSE.
    'yield' entrega un valor y pausa la funcion hasta la proxima linea
    (parecido a una corrutina de C++20).
    """
    while True:
        try:
            line = output_queue.get(timeout=1)   # espera hasta 1 seg por una linea
            if line == "__DONE__":
                yield "data: __DONE__\n\n"
                break
            yield f"data: {line}\n\n"
        except queue.Empty:
            # Sin datos por 1 seg: mandamos un comentario SSE para que la
            # conexion no se cierre por inactividad.
            yield ": keepalive\n\n"


def _clear_queue() -> None:
    """Vacia restos de un scan anterior antes de arrancar uno nuevo."""
    while not output_queue.empty():
        output_queue.get()


# ── 3. Rutas ─────────────────────────────────────────────────────────
@app.route("/")
def index():
    """Sirve la pagina principal."""
    return render_template("index.html")


@app.route("/stream")
def stream():
    """El navegador se conecta aca para recibir el output en tiempo real."""
    return Response(
        event_stream(),
        mimetype="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


# ── 4. Endpoints de red (descubrimiento / administracion) ────────────
@app.route("/api/scan/network", methods=["POST"])
def scan_network():
    """Descubre hosts activos en una red. Body: { "target": "192.168.1.0/24" }"""
    target = (request.get_json(silent=True) or {}).get("target", "192.168.1.0/24")
    _clear_queue()
    try:
        scanner.ping_scan(target)          # delega TODO al modulo
    except ValidationError as exc:
        log.warning("Target rechazado: %s", exc)
        return jsonify({"error": str(exc)}), 400
    return jsonify({"status": "started", "target": target})


@app.route("/api/scan/ports", methods=["POST"])
def scan_ports():
    """Escanea puertos/servicios de un host. Body: { "target": "...", "ports": "1-1000" }"""
    data = request.get_json(silent=True) or {}
    target = data.get("target")
    ports = data.get("ports", "1-1000")
    if not target:
        return jsonify({"error": "Se requiere un target"}), 400
    _clear_queue()
    try:
        scanner.port_scan(target, ports)
    except ValidationError as exc:
        log.warning("Input rechazado: %s", exc)
        return jsonify({"error": str(exc)}), 400
    return jsonify({"status": "started", "target": target, "ports": ports})


# ── 5. Endpoint WiFi: reconocimiento pasivo ──────────────────────────
@app.route("/api/wifi/scan", methods=["POST"])
def wifi_scan():
    """Reconocimiento WiFi pasivo (escucha). Body opcional: { "seconds": 30 }"""
    seconds = int((request.get_json(silent=True) or {}).get("seconds", 30))
    seconds = max(10, min(seconds, 120))   # limite: entre 10 y 120 segundos
    _clear_queue()
    try:
        wifi.run_scan(seconds=seconds)
    except Exception as exc:  # noqa: BLE001
        log.warning("Fallo al iniciar escaneo wifi: %s", exc)
        return jsonify({"error": str(exc)}), 500
    return jsonify({"status": "started", "seconds": seconds})


@app.route("/api/wifi/targets", methods=["GET"])
def wifi_targets():
    """
    Devuelve los objetivos del ULTIMO reconocimiento WiFi (redes + clientes)
    ya parseados. La UI los usa para que el usuario elija un AP en vez de
    tipear el BSSID/SSID a mano. Si todavia no se corrio un scan, devuelve
    listas vacias.
    """
    return jsonify(wifi.last_result)


# ── 6. Endpoints WiFi ofensivos ──────────────────────────────────────
#
# ADVERTENCIA DE ALCANCE: estas operaciones (deauth, evil twin, wifite)
# solo deben usarse sobre redes PROPIAS o con autorizacion explicita.
# Ejecutan scripts de Kali que viven en scripts/kali-scripts/.
#
# Los scripts se ejecutan en su PROPIA sesion (start_new_session=True) para
# poder matar todo el arbol de procesos desde /api/stop. Cada linea de salida
# se limpia de codigos de color ANSI y se empuja a la cola SSE, igual que hace
# NetworkScanner._run con Nmap.

# Regex que saca las secuencias de color ANSI (\033[...m) de la salida bash.
_ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")

# Carpeta absoluta de los scripts de Kali (../scripts/kali-scripts).
_SCRIPTS_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "scripts", "kali-scripts")
)

# Proceso ofensivo en curso (uno por vez). Protegido con un lock porque lo
# tocan dos hilos: el worker que corre el script y el request de /api/stop.
_proc_lock = threading.Lock()
_current_proc: "subprocess.Popen | None" = None


def launch_asynchronous_attack(script_name: str, args_list=None) -> threading.Thread:
    """
    Limpia la cola, arma el comando (bash + script + args) y lo corre en un
    hilo daemon. Streamea la salida al SSE y al terminar emite '__DONE__'.

    Se invoca 'bash <script>' en vez de './<script>' para no depender del bit
    +x (Windows no lo maneja; ver notas del proyecto).
    """
    _clear_queue()
    script_path = os.path.join(_SCRIPTS_DIR, script_name)
    cmd = ["bash", script_path] + list(args_list or [])

    def worker() -> None:
        global _current_proc
        log.info("Ejecutando script ofensivo: %s", " ".join(cmd))
        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,   # junta stderr con stdout
                text=True,
                bufsize=1,                  # linea por linea
                start_new_session=True,     # sesion propia -> matable por grupo
            )
            with _proc_lock:
                _current_proc = proc

            for line in iter(proc.stdout.readline, ""):
                line = _ANSI_RE.sub("", line).rstrip("\n")
                if line:
                    output_queue.put(line)
            proc.wait()
            log.info("Script finalizado (codigo %s)", proc.returncode)

        except FileNotFoundError:
            msg = f"[ERROR] Script no encontrado: {script_path}"
            log.error(msg)
            output_queue.put(msg)
        except Exception as exc:  # noqa: BLE001
            log.exception("Fallo ejecutando el script")
            output_queue.put(f"[ERROR] {exc}")
        finally:
            with _proc_lock:
                _current_proc = None
            output_queue.put("__DONE__")   # la UI espera esto para cerrar

    thread = threading.Thread(target=worker, daemon=True)
    thread.start()
    return thread


@app.route("/api/wifi/deauth", methods=["POST"])
def wifi_deauth():
    """Deauth dirigido/masivo con aireplay-ng. Body: {bssid, client?, count?}"""
    data = request.get_json(silent=True) or {}
    bssid = data.get("bssid")
    client = data.get("client", "FF:FF:FF:FF:FF:FF")
    count = str(data.get("count", "20"))
    if not bssid:
        return jsonify({"error": "Se requiere el BSSID de la red objetivo"}), 400
    # Canal del AP segun el ULTIMO scan. aireplay-ng NO hopea de canal: si la
    # interfaz no esta fijada en el canal del objetivo, las tramas no llegan y
    # nadie se desconecta. Lo buscamos por BSSID y se lo pasamos al script.
    # El front puede mandarlo tambien (data['channel']); si no, lo deducimos.
    channel = str(data.get("channel", "")).strip()
    if not channel:
        for red in wifi.last_result.get("redes", []):
            if str(red.get("bssid", "")).upper() == str(bssid).upper():
                channel = str(red.get("canal", "")).strip()
                break
    # Orden posicional esperado por el script: bssid, client, count, channel
    launch_asynchronous_attack("wifi_deauth.sh", [bssid, client, count, channel])
    return jsonify({"status": "started", "message": f"Deauth lanzado contra AP {bssid}"})


@app.route("/api/wifi/handshake", methods=["POST"])
def wifi_handshake():
    """Auditoria automatizada de Wifite en wlan2 (captura/crackeo)."""
    launch_asynchronous_attack("wifite_auto.sh")
    return jsonify({"status": "started", "message": "Auditoria Wifite iniciada en wlan2"})


@app.route("/api/wifi/eviltwin", methods=["POST"])
def wifi_evil_twin():
    """Punto de acceso falso clonando un SSID con hostapd. Body: {ssid}"""
    data = request.get_json(silent=True) or {}
    ssid = data.get("ssid")
    if not ssid:
        return jsonify({"error": "Se requiere el SSID objetivo para clonar"}), 400
    launch_asynchronous_attack("wifi_eviltwin.sh", [ssid])
    return jsonify({"status": "started", "message": f"Evil twin desplegado: {ssid}"})


# ── 6b. Detener el proceso ofensivo en curso ─────────────────────────
@app.route("/api/stop", methods=["POST"])
def stop_attack():
    """
    Mata el proceso ofensivo activo (y todo su grupo: hostapd, wifite, etc.).
    Necesario para deauth/evil twin/wifite que corren indefinidamente.
    Es idempotente: si no hay nada corriendo responde 'idle'.
    """
    with _proc_lock:
        proc = _current_proc
    if proc is None:
        return jsonify({"status": "idle", "message": "No hay proceso activo"}), 200
    try:
        # Matamos el GRUPO entero (setsid dio un pgid propio), no solo el bash.
        os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
    except ProcessLookupError:
        pass  # ya habia terminado solo
    except Exception as exc:  # noqa: BLE001
        log.warning("Fallo al detener proceso: %s", exc)
        return jsonify({"error": str(exc)}), 500
    output_queue.put("[!] Proceso detenido por el usuario")
    return jsonify({"status": "stopped"})


# ── 7. Arranque ──────────────────────────────────────────────────────
if __name__ == "__main__":
    log.info("Iniciando servidor en http://0.0.0.0:5001")
    # debug=False para una v1; threaded=True para atender el SSE + requests.
    app.run(host="0.0.0.0", port=5001, debug=False, threaded=True)