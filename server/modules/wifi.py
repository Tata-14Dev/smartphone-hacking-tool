"""
wifi_scan.py — Reconocimiento WiFi pasivo (parser de airodump-ng).

Responsabilidad unica: leer el CSV que genera airodump-ng y convertirlo
en datos limpios + un analisis defensivo de seguridad de cada red.

Es 100% RECONOCIMIENTO Y ANALISIS: lee lo que las redes ya emiten y lo
clasifica. No transmite nada. Es el equivalente a un "site survey" que
hace cualquier tecnico de redes.

Uso previsto: analisis del propio entorno / redes autorizadas.
"""

from __future__ import annotations

import csv
import io
import subprocess
import threading
from typing import Callable, Dict, List

from logger import get_logger

log = get_logger(__name__)

LineCallback = Callable[[str], None]

# airodump-ng escribe DOS tablas en el mismo CSV, separadas por una linea
# en blanco: primero los AP (redes), despues las estaciones (clientes).
# Estos son los encabezados que marcan el inicio de cada seccion.
_AP_HEADER = "BSSID, First time seen"
_ST_HEADER = "Station MAC, First time seen"


def _split_sections(text: str) -> tuple[str, str]:
    """Separa el CSV en (bloque_APs, bloque_estaciones)."""
    ap_block, st_block = text, ""
    idx = text.find(_ST_HEADER)
    if idx != -1:
        ap_block = text[:idx]
        st_block = text[idx:]
    return ap_block, st_block


def classify_security(privacy: str, cipher: str) -> Dict[str, str]:
    """
    Clasifica el nivel de seguridad de una red segun su cifrado.
    Analisis puramente defensivo: etiqueta el riesgo para un reporte.

    Devuelve {'nivel': ..., 'nota': ...}
    """
    p = (privacy or "").upper()
    c = (cipher or "").upper()

    if "OPN" in p or p.strip() == "":
        return {"nivel": "CRITICO", "nota": "Red abierta, sin cifrado"}
    if "WPA3" in p:
        return {"nivel": "OPTIMO", "nota": "WPA3 (SAE), cifrado moderno"}
    if "WPA2" in p and "WPA" in p and "WPA2" != p.strip():
        # aparece "WPA2 WPA" -> modo mixto con WPA viejo
        return {"nivel": "DEBIL", "nota": "Modo mixto WPA/WPA2 (compatibilidad vieja)"}
    if "TKIP" in c:
        return {"nivel": "DEBIL", "nota": "Usa TKIP, cifrado obsoleto"}
    if "WPA2" in p:
        return {"nivel": "OK", "nota": "WPA2-CCMP, estandar aceptable"}
    if "WEP" in p:
        return {"nivel": "CRITICO", "nota": "WEP, roto hace decadas"}
    return {"nivel": "DESCONOCIDO", "nota": "No se pudo determinar"}


def parse_airodump_csv(path: str) -> Dict[str, List[dict]]:
    """
    Lee el CSV de airodump-ng y devuelve {'redes': [...], 'clientes': [...]}.
    Cada red incluye su clasificacion de seguridad.
    """
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        text = f.read()

    ap_block, st_block = _split_sections(text)
    redes: List[dict] = []
    clientes: List[dict] = []

    # ── Parsear APs ────────────────────────────────────────────────
    for row in csv.reader(io.StringIO(ap_block)):
        if not row or row[0].strip() == "" or row[0].strip() == "BSSID":
            continue
        if len(row) < 14:
            continue
        privacy = row[5].strip()
        cipher = row[6].strip()
        sec = classify_security(privacy, cipher)
        redes.append({
            "bssid": row[0].strip(),
            "canal": row[3].strip(),
            "privacy": privacy,
            "cipher": cipher,
            "auth": row[7].strip(),
            "power": _to_int(row[8]),
            "beacons": _to_int(row[9]),
            "essid": row[13].strip() or "<oculta>",
            "nivel": sec["nivel"],
            "nota": sec["nota"],
        })

    # ── Parsear estaciones (clientes) ──────────────────────────────
    for row in csv.reader(io.StringIO(st_block)):
        if not row or row[0].strip() in ("", "Station MAC"):
            continue
        if len(row) < 6:
            continue
        clientes.append({
            "station": row[0].strip(),
            "power": _to_int(row[3]),
            "packets": _to_int(row[4]),
            "bssid": row[5].strip(),
        })

    # ordenar redes por señal (mas fuerte primero)
    redes.sort(key=lambda r: r["power"], reverse=True)
    log.info("Parseadas %d redes y %d clientes", len(redes), len(clientes))
    return {"redes": redes, "clientes": clientes}


def _to_int(s: str) -> int:
    try:
        return int(s.strip())
    except (ValueError, AttributeError):
        return 0


class WifiScanner:
    """
    Lanza airodump-ng por unos segundos sobre la interfaz en modo monitor,
    y al terminar parsea el CSV resultante.
    """

    def __init__(self, on_line: LineCallback, iface: str = "wlan2") -> None:
        self._on_line = on_line
        self._iface = iface

    def run_scan(self, seconds: int = 30, prefix: str = "/tmp/wd_recon") -> threading.Thread:
        t = threading.Thread(target=self._scan, args=(seconds, prefix), daemon=True)
        t.start()
        return t

    def _scan(self, seconds: int, prefix: str) -> None:
        # --write-interval 1 y timeout controlado; airodump corre hasta que lo matamos
        cmd = ["airodump-ng", "-w", prefix, "--output-format", "csv",
               "--write-interval", "1", self._iface]
        log.info("Escaneo pasivo %ds sobre %s", seconds, self._iface)
        self._on_line(f"[*] Escuchando el aire {seconds}s sobre {self._iface}...")
        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            import time
            time.sleep(seconds)
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
        except FileNotFoundError:
            self._on_line("[ERROR] airodump-ng no encontrado")
            self._on_line("__DONE__")
            return
        except Exception as exc:  # noqa: BLE001
            log.exception("Fallo en el escaneo")
            self._on_line(f"[ERROR] {exc}")
            self._on_line("__DONE__")
            return

        # airodump agrega -01 al prefijo
        csv_path = f"{prefix}-01.csv"
        try:
            data = parse_airodump_csv(csv_path)
        except FileNotFoundError:
            self._on_line("[ERROR] No se genero el CSV (¿interfaz en monitor?)")
            self._on_line("__DONE__")
            return

        self._report(data)
        self._on_line("__DONE__")

    def _report(self, data: Dict[str, List[dict]]) -> None:
        redes = data["redes"]
        self._on_line(f"[OK] {len(redes)} redes detectadas:")
        self._on_line("")
        for r in redes:
            linea = (f"  {r['power']:>4}dBm  CH{r['canal']:>3}  "
                     f"{r['nivel']:<10} {r['essid'][:22]:<22}  {r['nota']}")
            self._on_line(linea)
        # resumen por nivel
        from collections import Counter
        c = Counter(r["nivel"] for r in redes)
        self._on_line("")
        self._on_line(f"[*] Resumen: {dict(c)}")
        self._on_line(f"[*] Clientes detectados: {len(data['clientes'])}")