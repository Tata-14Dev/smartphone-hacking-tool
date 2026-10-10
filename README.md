# WATCHDOG — Watch Dogs Phone

Framework de auditoría/pentesting de redes inspirado en el teléfono de *Watch Dogs*,
sobre un **Samsung Galaxy S10 con Kali NetHunter**. Un servidor Flask corre dentro
del chroot de Kali y expone una **interfaz web (PWA)** con estética Watch Dogs, que
funciona **sin internet** (modo avión) y se instala como app a pantalla completa.

> ⚠️ **Uso autorizado únicamente.** Esta herramienta es para auditar **redes y
> dispositivos propios o con autorización explícita**. El uso no autorizado es
> delito en la mayoría de las jurisdicciones. Los autores no se responsabilizan
> por el mal uso.

## Qué hace (hoy)
- **Reconocimiento WiFi** (2.4 y 5 GHz): redes, señal, canal, seguridad y clientes.
- **Escaneo de red/puertos** con Nmap (hosts, puertos, versiones de servicios).
- **Operaciones ofensivas** (sobre redes propias/lab): deauth, evil twin, wifite.
- **Salud de antena**: prepara monitor solo; botón de **RESET** que recupera la
  antena sin reiniciar el teléfono.
- **Chequeo de dependencias** al abrir + instalador (`setup.sh`).
- **100% offline**: todo local en `localhost`, sin requests a internet.

## Arquitectura (resumen)
El "motor" (aircrack, nmap, hostapd, wifite) corre **como root dentro del chroot de
Kali** sobre una **antena externa RTL8812AU** (`wlan2`, modo monitor). La UI es una
PWA servida por Flask en `localhost:5001` — un control remoto local del backend.
El WiFi interno del teléfono no se toca. Detalle completo en
[`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md).

## Requisitos
- Galaxy S10 (u otro device NetHunter) con Kali NetHunter.
- Antena WiFi externa con chipset **RTL8812AU** (monitor + inyección).
- Ver dependencias y setup en [`docs/setup.md`](docs/setup.md).

## Inicio rápido
```bash
# dentro del chroot de Kali, como root:
cd /root/watchdog-git
bash scripts/setup.sh                 # instala/actualiza dependencias (necesita internet)
cd server && python3 app.py           # arranca el server en localhost:5001
```
Después, abrí `http://localhost:5001` en el navegador del teléfono. Para instalarlo
como app a pantalla completa (incluso en teléfonos de-Googled), ver `docs/setup.md`.

## Estado del proyecto
En desarrollo activo, organizado por milestones (ver roadmap en `docs/REQUIREMENTS.md`):
**M1 (PWA/offline) ✅ · M2 (core ofensivo confiable) 🚧 · M3 defensivo · M4 módulos
+ motor de decisión · M5 portabilidad.**

## Estructura
```
server/        # Flask (app.py) + módulos (network.py, wifi_scan.py, …)
  static/      # PWA: fuentes, iconos, manifest, service worker
  templates/   # index.html (UI Watch Dogs)
scripts/
  setup.sh             # instalador de dependencias
  kali-scripts/        # corren dentro de Kali (antenna.sh, check_deps.sh, wifi_*.sh, …)
  termux-shortcuts/    # widgets WD-* para Termux
docs/          # REQUIREMENTS.md (SRS), setup.md
```

## Flujo de trabajo (Git)
`develop` (se prueba en el teléfono) → confirmado → `main` (estable, el que se clona).
