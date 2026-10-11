# Watch Dogs Phone — Documento de Requerimientos (SRS)

**Versión:** 1.1
**Fecha:** Octubre 2026
**Estado:** En desarrollo activo (ver roadmap en §8)

> Documento vivo. Se actualiza a medida que el proyecto evoluciona; cada cambio
> se versiona en Git. El estado de cada requerimiento refleja lo realmente
> implementado y validado en hardware.

---

## 1. Introducción

### 1.1 Propósito
Este documento describe los requerimientos del sistema **Watch Dogs Phone**
(repo: *smartphone-hacking-tool*, alias **WATCHDOG**), un framework de auditoría
y pentesting móvil inspirado en el teléfono de Watch Dogs. Permite ejecutar
herramientas de seguridad ofensiva y defensiva desde un Samsung Galaxy S10 con
Kali NetHunter, a través de una interfaz unificada.

### 1.2 Alcance
El sistema comprende:
- Un **servidor backend (Flask/Python)** que corre dentro del chroot de Kali NetHunter.
- Una **interfaz web (PWA)** servida por ese backend en `localhost:5001`, instalable
  como app a pantalla completa y **operable sin conexión a internet** (modo avión).
- **Módulos** por protocolo/vector (WiFi, Red, y a futuro Bluetooth/NFC/HID).
- Scripts de Kali (escaneo, ataques, salud de antena) y un **motor de decisión**
  (a futuro) que sugiere el mejor camino de ataque según el contexto.

> Nota de arquitectura: la UI NO es una APK nativa. Es una PWA (web) servida en
> localhost. En teléfonos de-Googled (sin Play Services) se "instala" a pantalla
> completa con un contenedor WebView (ej. Native Alpha). Ver §2.1.

### 1.3 Definiciones y acrónimos
| Término | Definición |
|---|---|
| NetHunter | Overlay de Kali Linux para Android |
| Chroot | Entorno Linux aislado corriendo dentro de Android |
| PWA | Progressive Web App — web instalable, con service worker y modo offline |
| SSE | Server-Sent Events — stream de salida en tiempo real del backend a la UI |
| BSSID / SSID | MAC / nombre de un punto de acceso WiFi |
| PMF / 802.11w | Protected Management Frames — protege contra deauth; si está "required", el deauth clásico no funciona |
| DFS | Canales 5 GHz de radar (52–64, 100–144) donde el adaptador en monitor normalmente NO puede inyectar |
| WIDS | Wireless Intrusion Detection System (lado defensivo) |
| HID | Human Interface Device — emulación de teclado/mouse por USB |
| SDR | Software Defined Radio |

### 1.4 Referencias
- Kali NetHunter Docs: https://www.kali.org/docs/nethunter/
- Samsung Galaxy S10 NetHunter (beyond1lte, LineageOS 23.2 / Android 16)
- OWASP Mobile Security Testing Guide

---

## 2. Descripción general del sistema

### 2.1 Perspectiva del sistema
El sistema es una capa de abstracción sobre las herramientas de Kali. En vez de
tipear comandos en una terminal, el usuario usa una interfaz que arma y ejecuta
esos comandos. **El motor vive en Kali** (solo ahí hay root + acceso a la antena
en modo monitor); la UI es siempre un "control remoto" local de ese backend.

```
┌────────────────────────────────────────────────────────────┐
│                    SAMSUNG GALAXY S10                       │
│                                                            │
│  ┌──────────────────────┐      ┌────────────────────────┐  │
│  │  PWA (web, WebView)  │◄────►│  Servidor Flask        │  │
│  │  localhost:5001      │ HTTP │  (dentro del chroot)   │  │
│  │  offline / instalable│ /SSE │  app.py + módulos      │  │
│  └──────────────────────┘      └───────────┬────────────┘  │
│                                            │               │
│                           ┌────────────────▼────────────┐  │
│                           │   Kali NetHunter Chroot     │  │
│                           │  nmap / aircrack / hostapd  │  │
│                           │  dnsmasq / wifite / iw      │  │
│                           └───────────┬─────────────────┘  │
│                                       │ USB-OTG            │
│                           ┌───────────▼─────────────────┐  │
│                           │ Antena externa RTL8812AU     │  │
│                           │ (wlan2, monitor + inyección) │  │
│                           └──────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```
El WiFi interno (wlan0/wlan1, BCM) NO soporta monitor y NO se toca: la interna
queda para la conexión del teléfono; toda auditoría WiFi va por la antena externa.

### 2.2 Funciones principales del sistema
- Auditoría de redes WiFi (escaneo 2.4/5 GHz, deauth, evil twin, handshakes).
- Escaneo de red y puertos/servicios (Nmap).
- Salud y recuperación de la antena (preparar/reset sin reboot).
- Chequeo de dependencias e instalador.
- Operación 100% offline (sin internet).
- (A futuro) Bluetooth, NFC/RFID, HID, motor de decisión, WIDS defensivo.

### 2.3 Características de los usuarios
- **Primarios:** pentesters/auditores con conocimiento técnico medio-avanzado.
- **Secundarios:** estudiantes de ciberseguridad en labs controlados.

### 2.4 Restricciones generales
- Uso **solo en redes/dispositivos propios o con autorización explícita**.
- El uso no autorizado es delito en la mayoría de jurisdicciones.
- El sistema no implementa evasión de protecciones legales.

---

## 3. Requerimientos funcionales

Prioridad: Alta / Media / Baja · Estado: Pendiente / En desarrollo / Completado.

### 3.1 Módulo de WiFi
| ID | Descripción | Prioridad | Estado |
|---|---|---|---|
| RF-WIFI-01 | Escanear redes WiFi (SSID, BSSID, canal, señal, encriptación) en 2.4 y 5 GHz | Alta | **Completado** |
| RF-WIFI-02 | Poner la antena externa en modo monitor (automático al operar) | Alta | **Completado** |
| RF-WIFI-03 | Capturar handshakes WPA/WPA2 de redes objetivo | Alta | En desarrollo (wifite; sin validar en HW) |
| RF-WIFI-04 | Ejecutar deauth contra clientes/AP (fijando el canal del objetivo) | Alta | En desarrollo (falta confirmar en HW) |
| RF-WIFI-05 | Crear Evil Twin (hostapd) con el SSID de una red objetivo | Media | En desarrollo |
| RF-WIFI-06 | MITM sobre clientes conectados al Evil Twin | Media | Pendiente |
| RF-WIFI-07 | Crackear handshakes capturados con diccionarios | Media | En desarrollo (wifite) |
| RF-WIFI-08 | Seleccionar la interfaz (autodetección de la antena externa; interna excluida) | Alta | **Completado** (autodetección) |

### 3.2 Módulo de Red
| ID | Descripción | Prioridad | Estado |
|---|---|---|---|
| RF-NET-01 | Escanear hosts activos en un rango de IPs | Alta | **Completado** |
| RF-NET-02 | Detectar puertos abiertos y servicios en un host | Alta | **Completado** |
| RF-NET-03 | Detectar versión de los servicios (-sV) | Alta | **Completado** |
| RF-NET-04 | Capturar tráfico a .pcap | Media | Pendiente |
| RF-NET-05 | ARP spoofing (MITM en LAN) | Media | Pendiente |
| RF-NET-06 | DNS spoofing | Media | Pendiente |
| RF-NET-07 | Integrar Metasploit para explotación | Alta | Pendiente |
| RF-NET-08 | Fuerza bruta sobre SSH/FTP/HTTP | Media | Pendiente |

### 3.3 Módulo de Bluetooth
| ID | Descripción | Prioridad | Estado |
|---|---|---|---|
| RF-BT-01 | Escanear dispositivos Bluetooth/BLE | Alta | Pendiente (M4) |
| RF-BT-02 | Mostrar info por dispositivo (MAC, nombre, RSSI, servicios) | Alta | Pendiente (M4) |
| RF-BT-03 | Capturar paquetes BLE | Media | Pendiente |
| RF-BT-04 | Emparejar con dispositivos sin confirmación | Baja | Pendiente |

### 3.4 Módulo NFC/RFID
| ID | Descripción | Prioridad | Estado |
|---|---|---|---|
| RF-NFC-01 | Leer tags NFC 13.56 MHz (chip interno) | Alta | Pendiente (M4) |
| RF-NFC-02 | Escribir tags NFC vírgenes | Media | Pendiente |
| RF-NFC-03 | RFID 125 kHz vía Proxmark3 | Media | Pendiente |
| RF-NFC-04 | Clonar tags compatibles | Media | Pendiente |
| RF-NFC-05 | Mostrar contenido decodificado (UID, tipo, datos) | Alta | Pendiente |

### 3.5 Módulo HID
| ID | Descripción | Prioridad | Estado |
|---|---|---|---|
| RF-HID-01 | Emular teclado USB al conectar a una PC | Alta | Pendiente |
| RF-HID-02 | Cargar/escribir scripts de teclas (estilo Rubber Ducky) | Alta | Pendiente |
| RF-HID-03 | Templates de payloads predefinidos | Media | Pendiente |
| RF-HID-04 | Configurar delay entre keystrokes | Media | Pendiente |

### 3.6 Motor de decisión (Fase/M4)
| ID | Descripción | Prioridad | Estado |
|---|---|---|---|
| RF-DEC-01 | Analizar resultados de un escaneo y sugerir el siguiente vector | Alta | Pendiente |
| RF-DEC-02 | Priorizar vectores por probabilidad de éxito | Media | Pendiente |
| RF-DEC-03 | Integrar un LLM para análisis contextual | Baja | Pendiente |
| RF-DEC-04 | Log de todas las acciones con timestamp | Alta | En desarrollo (logger central existe) |

### 3.7 Interfaz de usuario (PWA)
| ID | Descripción | Prioridad | Estado |
|---|---|---|---|
| RF-UI-01 | Menú principal con los módulos (tabs RECON / OFENSIVAS / SISTEMA) | Alta | **Completado** |
| RF-UI-02 | Pantalla de configuración por operación (tarjetas/carrusel) | Alta | **Completado** |
| RF-UI-03 | Output de cada herramienta en tiempo real (SSE, consola tipo bandeja) | Alta | **Completado** |
| RF-UI-04 | Diseño inspirado en Watch Dogs (tema oscuro, mono, acentos neón) | Baja | **Completado** |
| RF-UI-05 | Mostrar estado del sistema/antena/dependencias | Media | **Completado** (parcial: SISTEMA) |
| RF-UI-06 | Guardar/cargar configuraciones de ataques previos | Baja | Pendiente |

### 3.8 Sistema, operación y fiabilidad (NUEVO)
| ID | Descripción | Prioridad | Estado |
|---|---|---|---|
| RF-SYS-01 | Funcionar 100% offline (sin internet), servido en localhost; PWA instalable | Alta | **Completado** (M1) |
| RF-SYS-02 | Preparar la antena (monitor) automáticamente al iniciar una operación (sin pasos manuales) | Alta | **Completado** (M2) |
| RF-SYS-03 | Recuperar la antena (reset): matar procesos colgados y restaurar monitor SIN reiniciar el teléfono | Alta | **Completado** (M2) |
| RF-SYS-04 | Verificar las dependencias al abrir y avisar qué falta | Alta | **Completado** (M2) |
| RF-SYS-05 | Script de instalación/actualización de dependencias (setup.sh) | Alta | **Completado** (M2) |
| RF-SYS-06 | No mostrar datos inventados: sin backend, estado honesto (cero redes de ejemplo) | Alta | **Completado** (M2) |
| RF-SYS-07 | Indicar por objetivo si el ataque es viable (PMF/802.11w, canal DFS, test de inyección) | Alta | **Completado** (PMF/DFS en la UI + test de inyección aireplay --test) |
| RF-SYS-08 | Foolproof: nunca operar sobre la interfaz interna ni cortar la conexión del operador sin intención | Alta | **Completado** (parcial; se refina) |
| RF-SYS-09 | Portabilidad: config central (interfaz/rutas/puerto) para correr en varios devices NetHunter | Media | Pendiente (M5) |
| RF-SYS-10 | Al terminar una operación (o al abortar), sacar la antena de monitor y apagar la radio (ahorro de batería/recursos) | Alta | **Completado** (M2) |

---

## 4. Requerimientos no funcionales
| ID | Categoría | Descripción | Prioridad | Estado |
|---|---|---|---|---|
| RNF-01 | Rendimiento | El backend responde a cada request en <500ms (sin contar la ejecución de la herramienta) | Media | Completado |
| RNF-02 | Seguridad | El backend debería aceptar conexiones solo desde localhost (127.0.0.1) | Alta | **Pendiente** (hoy bindea 0.0.0.0:5001 — ver §7) |
| RNF-03 | Usabilidad | Configurar y lanzar un ataque básico en ≤3 pasos | Media | Completado |
| RNF-04 | Portabilidad | El backend corre en cualquier device Android con NetHunter | Media | En desarrollo (M5) |
| RNF-05 | Mantenibilidad | Cada módulo de ataque en un archivo Python/script independiente | Alta | Completado |
| RNF-06 | Legalidad | Advertencias de uso ético/legal visibles en la interfaz | Alta | Completado |
| RNF-07 | Logging | Acciones registradas con timestamp y parámetros | Alta | En desarrollo (logger central) |
| RNF-08 | Offline | Operar sin conexión a internet (modo avión); sin dependencias externas en runtime | Alta | **Completado** (M1) |
| RNF-09 | Fiabilidad | Recuperarse de estados trabados de la antena sin reiniciar el teléfono | Alta | **Completado** (M2, reset) |

---

## 5. Casos de uso principales

### CU-01: Reconocimiento WiFi
**Actor:** Usuario · **Precondición:** antena externa enchufada (el monitor se activa solo).
1. Abre RECON → RECONOCIMIENTO WIFI y ejecuta.
2. El sistema prepara la antena en monitor automáticamente y escucha el aire (2.4+5 GHz).
3. Muestra las redes reales (señal, canal, seguridad) y clientes; alimenta el selector de objetivos ofensivos.

### CU-02: Deauth dirigido
**Actor:** Usuario · **Precondición:** scan previo.
1. En OFENSIVAS → DEAUTH elige un AP de la lista (y opcional un cliente).
2. El sistema fija el canal del AP y lanza el deauth.
3. (En desarrollo) Antes, el sistema indica si el objetivo es viable (PMF/DFS).

### CU-03: Recuperar la antena
**Actor:** Usuario · **Precondición:** algo quedó trabado (ej. evil twin dejó la antena en modo AP).
1. SISTEMA → ANTENA → RESET.
2. El sistema mata hostapd/airodump/aireplay/wifite y devuelve la antena a monitor, sin reiniciar.

### CU-04: Escaneo y (futuro) explotación de red
**Actor:** Usuario · **Precondición:** conectado a la red objetivo.
1. RECON → ESCANEO DE RED / PUERTOS (Nmap).
2. (Futuro) el motor de decisión sugiere el mejor exploit; el usuario confirma.

---

## 6. Requerimientos de hardware
| Componente | Especificación | Obligatorio |
|---|---|---|
| Teléfono | Samsung Galaxy S10 (SM-G973F) con NetHunter | Sí |
| OS | LineageOS 23.2 (Android 16) + Magisk + Kali NetHunter | Sí |
| Adaptador WiFi externo | RTL8812AU (monitor + inyección, 2.4/5 GHz) | Sí (para WiFi) |
| Alimentación | Hub USB + powerbank (la inyección consume picos; evitar brownouts) | Recomendado |
| Adaptador NFC/RFID | Proxmark3 (125 kHz) | No |
| Dongle SDR | RTL-SDR RTL2832U | No |

---

## 7. Restricciones y suposiciones

### Restricciones
- Depende del kernel de NetHunter para monitor mode, inyección y (futuro) HID.
- Las herramientas de Kali deben estar instaladas en el chroot (ver `setup.sh`;
  la app las chequea al abrir).
- La antena externa es obligatoria para WiFi (el WiFi interno no hace monitor).
- Canales **DFS** de 5 GHz (52–144): el RTL8812AU en monitor normalmente no inyecta.
- **PMF/802.11w**: si el AP lo tiene "required" (WPA3/WiFi6), el deauth no funciona.

### Deuda técnica / pendientes conocidos
- **RNF-02:** el server hoy bindea `0.0.0.0:5001` (accesible por LAN). Para cumplir
  "solo localhost" debería bindear `127.0.0.1`. Pendiente de decidir/implementar.
- Interfaz hardcodeada a `wlan2` en varios lugares (pendiente config central, M5).

### Suposiciones
- El usuario tiene conocimientos básicos de redes/seguridad.
- El usuario cuenta con autorización legal sobre los objetivos.
- Se necesita internet SOLO para instalar/actualizar dependencias (`setup.sh`),
  no para operar.

---

## 8. Roadmap por milestones (reemplaza el plan de fases anterior)

| Milestone | Contenido | Estado |
|---|---|---|
| **M1 — PWA + offline total** | Fuentes embebidas, manifest, service worker, ícono; abre sin internet; instalable | **Completado** |
| **M2 — Core ofensivo confiable** | Antena (prepare/reset), auto-preparar, chequeo de deps + setup.sh, sin hardcode; (en curso) viabilidad PMF/DFS, scan de clientes bloqueado, confirmar deauth/evil twin/wifite en HW | En desarrollo |
| **M3 — Core defensivo (WIDS)** | Detección de evil twins, deauth floods, rogue APs; sección DEFENSA | Pendiente |
| **M4 — Módulos restantes** | bluetooth/nfc/hid/exploits + `decision.py` (motor de decisión) + tests/logging/scope | Pendiente |
| **M5 — Portabilidad** | Config central (iface/rutas/puerto), autodetección, deploy documentado en varios devices NetHunter | Pendiente |

### Flujo de trabajo (Git)
experimental → `develop` (se prueba en el teléfono) → confirmado → `main` (repo
principal, el que la gente clona).

---

*Documento vivo — actualizar con cada cambio y versionar en Git.*
