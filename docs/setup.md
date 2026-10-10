# Setup / Instalación — WATCHDOG

Guía para dejar el proyecto corriendo en un teléfono con Kali NetHunter.

## 1. Requisitos previos
- Teléfono con **Kali NetHunter** (probado en Galaxy S10 / LineageOS 23.2 / Android 16).
- **Antena WiFi externa RTL8812AU** (monitor + inyección), conectada por USB-OTG.
  Aparece como `wlan2`. Para inyectar en 5 GHz, evitar canales DFS (52–144).
- Alimentación estable: si usás un hub USB + powerbank, asegurate de que el hub
  reparta corriente al puerto de la antena (la inyección consume picos; un brownout
  resetea la antena).

## 2. Clonar el repo (en el teléfono, dentro de Kali)
```bash
su
chroot /data/local/nhsystem/kali-arm64 /bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
cd /root
git clone https://github.com/Tata-14Dev/smartphone-hacking-tool watchdog-git
cd watchdog-git
```

## 3. Instalar dependencias
```bash
bash scripts/setup.sh
```
Instala: `aircrack-ng, nmap, hostapd, dnsmasq, wireless-tools, iw, wifite,
python3, python3-pip` y `flask`. Necesita internet **solo en este paso**.
La app además chequea las dependencias al abrir (y hay botón CHEQUEAR en SISTEMA).

## 4. Arrancar el servidor
```bash
cd /root/watchdog-git/server
python3 app.py            # queda sirviendo en localhost:5001
```
En el teléfono se suele manejar con los widgets de Termux (**WD-START / WD-STOP /
WD-WEB / WD-UPDATE**). No hace falta **WD-MONITOR**: el escaneo y los ataques dejan
la antena en monitor automáticamente. Si algo se traba: SISTEMA → ANTENA → **RESET**.

## 5. Instalar la UI como app (pantalla completa)
La UI es una PWA. Cómo "instalarla" depende del teléfono:

- **Teléfono con Google Play Services:** navegador basado en Chromium (Cromite /
  Chromium) → abrir `http://localhost:5001` → menú → "Instalar app".
- **Teléfono de-Googled (sin Play Services — el caso típico de NetHunter):** la
  instalación nativa de PWA (WebAPK) no está disponible. Usar un contenedor WebView:
  **Native Alpha** (FOSS, F-Droid, repo `APraxx/NativeAlphaForAndroid`):
  1. Instalar Native Alpha.
  2. Nueva web app → `http://localhost:5001` → pantalla completa, nombre WATCHDOG.
  3. Ícono: guardar `http://localhost:5001/static/icons/icon-512.png` y elegirlo
     como ícono de la app (o re-crear la web app para que lo tome).
  4. Si el launcher no deja agregar el acceso directo: en los ajustes del launcher
     (LineageOS/Trebuchet) activar "permitir accesos directos / agregar iconos".

El System WebView soporta service workers, así que el modo offline funciona dentro
de Native Alpha también.

## 6. Flujo de uso típico
1. Enchufar la antena.
2. **WD-UPDATE** (git pull) → **WD-STOP** → **WD-START** (reinicia el server).
3. Abrir la app (ícono o `localhost:5001`).
4. RECON → RECONOCIMIENTO WIFI (prepara la antena solo y escanea).
5. Elegir objetivos en OFENSIVAS y operar. Cortar con ABORTAR / WD-STOP-ATK.
6. Tras un EVIL TWIN, siempre cortar (hostapd deja la antena en modo AP). Si quedó
   trabada: SISTEMA → ANTENA → RESET.

## 7. Desarrollo (en la Mac)
- Trabajar en `develop`. Probar en el teléfono desde `develop`; promover a `main`
  solo lo confirmado.
- El HTML se puede abrir suelto para ver la UI (muestra "SIMULACIÓN" sin backend).
- Server en puerto **5001** (en Mac, 5000 lo ocupa AirPlay).
