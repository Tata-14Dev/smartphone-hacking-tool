# Scripts de automatización — WATCHDOG

Todos los scripts que automatizan procesos del proyecto, en un solo lugar.
Se dividen en dos grupos según **dónde corren**.

---

## `kali-scripts/` — corren DENTRO del chroot de Kali

Estos son parte del proyecto y van en la **raíz del repo** (junto a `server/`).
En el teléfono viven en `/root/watchdog-git/` y llegan por `git pull`.

| Script | Qué hace | Uso |
|---|---|---|
| `ctl.sh` | Controla el servidor Flask (start/stop/restart/status/update/logs/web) + menú TUI animado | `./ctl.sh` (menú) o `./ctl.sh start` |
| `monitor.sh` | Autodetecta la antena externa y la pone en modo monitor (método `ip`+`iw`) | `./monitor.sh` / `./monitor.sh stop` |
| `quickscan.sh` | Menú de escaneo nmap cuyas opciones se adaptan a la red detectada | `./quickscan.sh` |

**Instalación:** ya vienen por el repo. Solo asegurate del bit de ejecución:
```bash
cd /root/watchdog-git
chmod +x ctl.sh monitor.sh quickscan.sh
```
(Si el `chmod +x` se commitea desde Linux/Mac, viaja en el repo y no hace falta repetirlo.)

---

## `termux-shortcuts/` — corren en TERMUX (no en Kali)

Son los botones del home. Hacen el puente Termux → `su` → chroot → comando en Kali.
**NO van en el repo del proyecto** (son accesos directos personales del teléfono),
pero se guardan acá como respaldo para no perderlos.

| Widget | Qué hace |
|---|---|
| `WD-START` | Inicia el servidor (ctl.sh start) |
| `WD-STOP` | Detiene el servidor |
| `WD-UPDATE` | git pull en el teléfono |
| `WD-STATUS` | Muestra estado del servidor |
| `WD-PANEL` | Abre el menú TUI completo (ctl.sh) |
| `WD-WEB` | Abre la interfaz web en el navegador |
| `WD-MONITOR` | Pone la antena en modo monitor (monitor.sh) |
| `WD-SHELL` | Abre un prompt `root@kali` interactivo listo para usar |

**Instalación en Termux:**
```bash
# 1) pasar los archivos al teléfono (desde la PC)
adb push termux-shortcuts/ /sdcard/Download/wd-shortcuts/

# 2) en Termux
mkdir -p ~/.shortcuts
cp ~/storage/shared/Download/wd-shortcuts/* ~/.shortcuts/
chmod +x ~/.shortcuts/*
```
Después: home → mantener presionado → Widgets → Termux:Widget → arrastrar al home.

**Requisitos previos (una sola vez):**
- Termux + Termux:Widget instalados desde GitHub (misma fuente/firma), NO de Google Play.
- `termux-setup-storage` ejecutado.
- Root de Termux concedido en Magisk (`su` debe funcionar).
- Permiso "Display over other apps" concedido a Termux:Widget.

---

## Flujo típico desde el home
Enchufar antena → **WD-MONITOR** → **WD-START** → **WD-WEB** → operar.

## Ajustes que quizás necesites
- Si la antena queda como `wlan2mon` en vez de `wlan2`, actualizá el `iface` en `server/app.py`.
- Las rutas de los scripts asumen el repo en `/root/watchdog-git`. Si cambia, editá
  la variable `PROJECT_DIR`/`KALI` al inicio de cada script.
