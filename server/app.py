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
import queue

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


# Los endpoints ofensivos quedan deshabilitados a proposito.
@app.route("/api/wifi/deauth", methods=["POST"])
@app.route("/api/wifi/handshake", methods=["POST"])
@app.route("/api/wifi/eviltwin", methods=["POST"])
def wifi_offensive_blocked():
    return jsonify({"error": "Operacion no disponible"}), 501


# ── 6. Arranque ──────────────────────────────────────────────────────
if __name__ == "__main__":
    log.info("Iniciando servidor en http://0.0.0.0:5001")
    # debug=False para una v1; threaded=True para atender el SSE + requests.
    app.run(host="0.0.0.0", port=5001, debug=False, threaded=True)