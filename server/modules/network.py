"""
network.py — Modulo de escaneo de red con Nmap.

Responsabilidad unica (Single Responsibility): descubrir hosts y
detectar servicios en una red. Es la parte defensiva / administrativa
del proyecto: el mismo tipo de escaneo que hace un admin de red sobre
su propia infraestructura para saber que hay conectado.

Uso previsto: SOLO sobre redes propias o con autorizacion explicita.

Diseno:
- No sabe nada de Flask ni de la cola SSE. En vez de eso recibe un
  'callback' (on_line): una funcion que le pasamos y que decide que
  hacer con cada linea de output. Asi el modulo es reutilizable y
  testeable por separado.
"""

from __future__ import annotations

import ipaddress
import re
import subprocess
import threading
from typing import Callable, List

from logger import get_logger

log = get_logger(__name__)

# Un LineCallback es "cualquier funcion que recibe un str y no devuelve nada".
# En C++ seria algo como  std::function<void(const std::string&)>.
LineCallback = Callable[[str], None]

# Regex conservador para hostnames validos (letras, numeros, punto, guion).
_HOSTNAME_RE = re.compile(r"^[a-zA-Z0-9.\-]{1,253}$")

# Regex para puertos: "80", "1-1000", "22,80,443", "1-100,443", etc.
_PORTS_RE = re.compile(r"^\d{1,5}(-\d{1,5})?(,\d{1,5}(-\d{1,5})?)*$")


class ValidationError(ValueError):
    """El target o los puertos no pasaron la validacion."""


def validate_target(target: str) -> str:
    """
    Valida que 'target' sea una IP, una red CIDR o un hostname con forma
    valida. Devuelve el target limpio o lanza ValidationError.

    Por que importa: hoy el input del usuario va directo al comando. Aunque
    usamos lista de argumentos (no shell), validar evita comportamientos
    raros y deja documentado que solo aceptamos entradas con forma esperada.
    """
    target = (target or "").strip()
    if not target:
        raise ValidationError("El target esta vacio")

    # 1) Es una IP o una red CIDR valida?  (ej. 192.168.1.1  o  192.168.1.0/24)
    try:
        ipaddress.ip_network(target, strict=False)
        return target
    except ValueError:
        pass  # no es IP/CIDR, probamos hostname

    # 2) Es un hostname con forma valida?  (ej. router.local)
    if _HOSTNAME_RE.match(target):
        return target

    raise ValidationError(f"Target invalido: {target!r}")


def validate_ports(ports: str) -> str:
    """
    Valida una especificacion de puertos tipo Nmap y chequea que cada
    numero este en el rango 1-65535. Devuelve la spec limpia o lanza error.
    """
    ports = (ports or "").strip()
    if not _PORTS_RE.match(ports):
        raise ValidationError(f"Especificacion de puertos invalida: {ports!r}")

    for chunk in ports.split(","):        # separa por comas: "1-100,443" -> ["1-100","443"]
        for n in chunk.split("-"):        # separa rangos:     "1-100"     -> ["1","100"]
            if not (1 <= int(n) <= 65535):
                raise ValidationError(f"Puerto fuera de rango (1-65535): {n}")
    return ports


class NetworkScanner:
    """
    Encapsula los escaneos de red. Se construye una vez pasandole el
    callback y despues se llaman sus metodos (ping_scan, port_scan).
    """

    def __init__(self, on_line: LineCallback, nmap_path: str = "nmap") -> None:
        # Guardamos el callback y la ruta al binario nmap como atributos.
        self._on_line = on_line
        self._nmap = nmap_path

    # ── Metodo interno: ejecuta un comando y transmite su output ──────────
    def _run(self, cmd: List[str]) -> None:
        log.info("Ejecutando: %s", " ".join(cmd))
        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,   # junta stderr con stdout
                text=True,                  # devuelve str en vez de bytes
                bufsize=1,                  # buffer linea por linea
            )
            # Lee stdout linea por linea hasta que se cierra (cadena vacia).
            for line in iter(proc.stdout.readline, ""):
                line = line.rstrip("\n")
                if line:
                    self._on_line(line)     # entrega la linea a quien nos llamo
            proc.wait()
            log.info("Comando finalizado (codigo %s)", proc.returncode)

        except FileNotFoundError:
            msg = f"[ERROR] Herramienta no encontrada: {cmd[0]}"
            log.error(msg)
            self._on_line(msg)
        except Exception as exc:            # cualquier otro fallo inesperado
            log.exception("Fallo ejecutando el comando")
            self._on_line(f"[ERROR] {exc}")
        finally:
            # Pase lo que pase, avisamos que terminamos (la UI espera esto).
            self._on_line("__DONE__")

    # ── API publica ──────────────────────────────────────────────────────
    def ping_scan(self, target: str) -> threading.Thread:
        """
        Descubrimiento de hosts activos (nmap -sn = solo ping, sin puertos).
        Recibe una IP, un rango CIDR o un hostname.
        """
        target = validate_target(target)
        log.info("Ping scan sobre %s", target)
        cmd = [self._nmap, "-sn", "-v", "--stats-every", "2s", target]
        return self._spawn(cmd)

    def port_scan(self, target: str, ports: str = "1-1000") -> threading.Thread:
        """
        Escaneo de puertos + deteccion de versiones de servicios (nmap -sV).
        """
        target = validate_target(target)
        ports = validate_ports(ports)
        log.info("Port scan sobre %s puertos %s", target, ports)
        cmd = [self._nmap, "-sV", "-p", ports, target]
        return self._spawn(cmd)

    # ── Helper: lanza _run en un thread para no bloquear el servidor ──────
    def _spawn(self, cmd: List[str]) -> threading.Thread:
        t = threading.Thread(target=self._run, args=(cmd,), daemon=True)
        t.start()
        return t
