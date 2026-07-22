"""
logger.py — Configuracion central de logging para todo el proyecto.

Un solo lugar donde se define COMO y DONDE se registran los eventos.
Cualquier modulo hace:

    from logger import get_logger
    log = get_logger(__name__)

y ya tiene logging consistente (consola + archivo rotativo).

Esto cubre el requisito NO FUNCIONAL de AUDITABILIDAD / TRAZABILIDAD:
todo lo que ejecuta la herramienta queda registrado con fecha, hora,
nivel y modulo de origen.
"""

import logging
import os
from logging.handlers import RotatingFileHandler

# Carpeta donde se guardan los logs. Se puede sobreescribir con la
# variable de entorno WATCHDOG_LOG_DIR; si no, usa /tmp.
LOG_DIR = os.environ.get("WATCHDOG_LOG_DIR", "/tmp/watchdog_logs")
LOG_FILE = os.path.join(LOG_DIR, "watchdog.log")

# Formato de cada linea. Ejemplo de salida:
# 2026-07-20 14:03:11 | INFO    | network | Ping scan sobre 192.168.1.0/24
_FORMAT = "%(asctime)s | %(levelname)-7s | %(name)s | %(message)s"
_DATEFMT = "%Y-%m-%d %H:%M:%S"

# Flag para no configurar los handlers dos veces (ver _configure_root).
_configured = False


def _configure_root() -> None:
    """Configura el logger raiz del proyecto una sola vez."""
    global _configured
    if _configured:
        return

    # Crea la carpeta de logs si no existe (exist_ok evita error si ya esta).
    os.makedirs(LOG_DIR, exist_ok=True)

    formatter = logging.Formatter(_FORMAT, datefmt=_DATEFMT)

    # Handler 1: muestra los logs en la consola (stderr).
    console = logging.StreamHandler()
    console.setFormatter(formatter)

    # Handler 2: escribe a archivo. Rota al llegar a 1 MB y guarda 3 backups
    # para que el log no crezca infinito.
    file_handler = RotatingFileHandler(
        LOG_FILE, maxBytes=1_000_000, backupCount=3, encoding="utf-8"
    )
    file_handler.setFormatter(formatter)

    # Todos los loggers del proyecto cuelgan de "watchdog".
    root = logging.getLogger("watchdog")
    root.setLevel(logging.DEBUG)
    root.addHandler(console)
    root.addHandler(file_handler)
    # propagate=False evita que los mensajes suban al logger global de Python
    # y se dupliquen.
    root.propagate = False

    _configured = True


def get_logger(name: str) -> logging.Logger:
    """
    Devuelve un logger listo para usar.

    'name' normalmente es __name__ del modulo que llama. Nos quedamos
    solo con la ultima parte (ej. "network") para que la linea de log
    sea corta y legible.
    """
    _configure_root()
    short = name.split(".")[-1]
    return logging.getLogger(f"watchdog.{short}")
