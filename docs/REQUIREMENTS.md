# Watch Dogs Phone — Documento de Requerimientos

**Versión:** 1.0  
**Fecha:** Julio 2026  
**Estado:** Borrador inicial

---

## 1. Introducción

### 1.1 Propósito
Este documento describe los requerimientos del sistema **Watch Dogs Phone**, un framework de auditoría y pentesting móvil inspirado en el teléfono del videojuego Watch Dogs. El sistema permite ejecutar herramientas de seguridad ofensiva y defensiva desde un Samsung Galaxy S10 con Kali NetHunter, a través de una interfaz unificada.

### 1.2 Alcance
El sistema comprende:
- Un servidor backend (Flask/Python) que corre dentro del chroot de Kali NetHunter
- Una interfaz de usuario (APK Android) que permite seleccionar y configurar ataques/auditorías
- Módulos independientes para cada protocolo o vector de ataque
- Un motor de decisión que sugiere el mejor camino de ataque según el contexto

### 1.3 Definiciones y acrónimos
| Término | Definición |
|---|---|
| NetHunter | Overlay de Kali Linux para Android |
| Chroot | Entorno Linux aislado corriendo dentro de Android |
| APK | Android Package — aplicación instalable en Android |
| BSSID | Dirección MAC de un punto de acceso WiFi |
| SSID | Nombre de una red WiFi |
| HID | Human Interface Device — emulación de teclado/mouse por USB |
| SDR | Software Defined Radio — radio definida por software |
| MITM | Man In The Middle — ataque de interceptación de tráfico |

### 1.4 Referencias
- Kali NetHunter Documentation: https://www.kali.org/docs/nethunter/
- Samsung Galaxy S10 NetHunter Kernel (v0lk3n): beyond1lte-los
- OWASP Mobile Security Testing Guide

---

## 2. Descripción general del sistema

### 2.1 Perspectiva del sistema
El sistema actúa como una capa de abstracción sobre las herramientas de Kali Linux. En lugar de ejecutar comandos manualmente en una terminal, el usuario interactúa con una interfaz gráfica que construye y ejecuta esos comandos automáticamente.

```
┌──────────────────────────────────────────────────┐
│              SAMSUNG GALAXY S10                  │
│                                                  │
│  ┌─────────────────┐    ┌────────────────────┐  │
│  │   APK Android   │◄──►│  Servidor Flask    │  │
│  │   (Interfaz)    │    │  (localhost:5000)  │  │
│  └─────────────────┘    └────────┬───────────┘  │
│                                  │               │
│                    ┌─────────────▼────────────┐  │
│                    │   Kali NetHunter Chroot  │  │
│                    │  nmap / aircrack / msf   │  │
│                    │  hydra / sqlmap / etc.   │  │
│                    └──────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

### 2.2 Funciones principales del sistema
- Auditoría de redes WiFi (escaneo, captura de handshakes, ataques)
- Auditoría de redes Bluetooth (escaneo, sniffing)
- Lectura y escritura de tags NFC/RFID
- Escaneo de red y análisis de vulnerabilidades
- Explotación de servicios vulnerables (Metasploit)
- Ataques HID (emulación de teclado USB)
- Motor de decisión para sugerencia automática de vectores de ataque

### 2.3 Características de los usuarios
El sistema está dirigido a:
- **Usuarios primarios:** Pentesters y auditores de seguridad con conocimiento técnico medio-avanzado
- **Usuarios secundarios:** Estudiantes de ciberseguridad en entornos controlados de laboratorio

### 2.4 Restricciones generales
- El sistema **solo debe usarse en redes y dispositivos propios o con autorización explícita por escrito** del propietario
- El uso en redes o dispositivos ajenos sin autorización constituye un delito en la mayoría de jurisdicciones
- El sistema no implementa ningún mecanismo de evasión de protecciones legales

---

## 3. Requerimientos funcionales

Los requerimientos se clasifican por módulo. Cada requerimiento tiene:
- **ID único**
- **Descripción**
- **Prioridad:** Alta / Media / Baja
- **Estado:** Pendiente / En desarrollo / Completado

---

### 3.1 Módulo de WiFi

| ID | Descripción | Prioridad | Estado |
|---|---|---|---|
| RF-WIFI-01 | El sistema debe poder escanear redes WiFi cercanas y mostrar SSID, BSSID, canal, potencia de señal y tipo de encriptación | Alta | Pendiente |
| RF-WIFI-02 | El sistema debe poder poner la interfaz WiFi en modo monitor | Alta | Pendiente |
| RF-WIFI-03 | El sistema debe poder capturar handshakes WPA/WPA2 de redes objetivo | Alta | Pendiente |
| RF-WIFI-04 | El sistema debe poder ejecutar ataques de desautenticación (deauth) contra clientes de una red | Alta | Pendiente |
| RF-WIFI-05 | El sistema debe poder crear un Access Point falso (Evil Twin) con el SSID de una red objetivo | Media | Pendiente |
| RF-WIFI-06 | El sistema debe poder realizar ataques MITM sobre clientes conectados al Evil Twin | Media | Pendiente |
| RF-WIFI-07 | El sistema debe poder intentar crackear handshakes capturados usando diccionarios | Media | Pendiente |
| RF-WIFI-08 | El sistema debe permitir al usuario seleccionar la interfaz WiFi a usar (interna o adaptador externo) | Alta | Pendiente |

---

### 3.2 Módulo de Red

| ID | Descripción | Prioridad | Estado |
|---|---|---|---|
| RF-NET-01 | El sistema debe poder escanear hosts activos en un rango de IPs dado | Alta | Pendiente |
| RF-NET-02 | El sistema debe poder detectar puertos abiertos y servicios corriendo en un host objetivo | Alta | Pendiente |
| RF-NET-03 | El sistema debe poder detectar la versión de los servicios detectados | Alta | Pendiente |
| RF-NET-04 | El sistema debe poder capturar tráfico de red en una interfaz dada y guardarlo en formato .pcap | Media | Pendiente |
| RF-NET-05 | El sistema debe poder realizar ARP spoofing para posicionarse como MITM en una red local | Media | Pendiente |
| RF-NET-06 | El sistema debe poder realizar DNS spoofing para redirigir dominios a IPs controladas | Media | Pendiente |
| RF-NET-07 | El sistema debe integrar Metasploit para explotación de vulnerabilidades detectadas | Alta | Pendiente |
| RF-NET-08 | El sistema debe poder realizar ataques de fuerza bruta sobre servicios SSH, FTP, HTTP | Media | Pendiente |

---

### 3.3 Módulo de Bluetooth

| ID | Descripción | Prioridad | Estado |
|---|---|---|---|
| RF-BT-01 | El sistema debe poder escanear dispositivos Bluetooth y BLE cercanos | Alta | Pendiente |
| RF-BT-02 | El sistema debe mostrar información de cada dispositivo encontrado (MAC, nombre, RSSI, servicios) | Alta | Pendiente |
| RF-BT-03 | El sistema debe poder capturar paquetes BLE en el rango de alcance | Media | Pendiente |
| RF-BT-04 | El sistema debe poder intentar emparejar con dispositivos que no requieren confirmación | Baja | Pendiente |

---

### 3.4 Módulo NFC/RFID

| ID | Descripción | Prioridad | Estado |
|---|---|---|---|
| RF-NFC-01 | El sistema debe poder leer tags NFC de 13.56MHz usando el chip interno del teléfono | Alta | Pendiente |
| RF-NFC-02 | El sistema debe poder escribir datos en tags NFC vírgenes | Media | Pendiente |
| RF-NFC-03 | El sistema debe soportar lectura/escritura de tags RFID de 125kHz mediante adaptador externo (Proxmark3) | Media | Pendiente |
| RF-NFC-04 | El sistema debe poder clonar tags NFC/RFID compatibles | Media | Pendiente |
| RF-NFC-05 | El sistema debe mostrar el contenido decodificado del tag leído (UID, tipo, datos) | Alta | Pendiente |

---

### 3.5 Módulo HID

| ID | Descripción | Prioridad | Estado |
|---|---|---|---|
| RF-HID-01 | El sistema debe poder emular un teclado USB cuando el teléfono se conecta a una PC por USB | Alta | Pendiente |
| RF-HID-02 | El sistema debe permitir al usuario cargar o escribir scripts de teclas a inyectar (estilo Rubber Ducky) | Alta | Pendiente |
| RF-HID-03 | El sistema debe incluir templates de payloads predefinidos (reverse shell, exfiltración, etc.) | Media | Pendiente |
| RF-HID-04 | El sistema debe permitir configurar el delay entre keystrokes | Media | Pendiente |

---

### 3.6 Motor de decisión

| ID | Descripción | Prioridad | Estado |
|---|---|---|---|
| RF-DEC-01 | El sistema debe analizar los resultados de un escaneo y sugerir automáticamente el siguiente vector de ataque | Alta | Pendiente |
| RF-DEC-02 | El sistema debe priorizar vectores según probabilidad de éxito (puertos abiertos, servicios vulnerables, etc.) | Media | Pendiente |
| RF-DEC-03 | El sistema debe poder integrarse con una API de LLM (ej. Claude/OpenAI) para análisis contextual avanzado | Baja | Pendiente |
| RF-DEC-04 | El sistema debe registrar un log de todas las acciones ejecutadas con timestamp | Alta | Pendiente |

---

### 3.7 Interfaz de usuario (APK)

| ID | Descripción | Prioridad | Estado |
|---|---|---|---|
| RF-UI-01 | La APK debe presentar un menú principal con los módulos disponibles | Alta | Pendiente |
| RF-UI-02 | Cada módulo debe tener una pantalla de configuración donde el usuario ingresa los parámetros necesarios | Alta | Pendiente |
| RF-UI-03 | La APK debe mostrar el output de cada herramienta en tiempo real | Alta | Pendiente |
| RF-UI-04 | La APK debe tener un diseño visual inspirado en el teléfono de Watch Dogs (tema oscuro, tipografía monoespaciada, colores neón) | Baja | Pendiente |
| RF-UI-05 | La APK debe mostrar el estado del chroot de Kali (activo/inactivo) | Media | Pendiente |
| RF-UI-06 | La APK debe permitir guardar y cargar configuraciones de ataques previos | Baja | Pendiente |

---

## 4. Requerimientos no funcionales

| ID | Categoría | Descripción | Prioridad |
|---|---|---|---|
| RNF-01 | Rendimiento | El servidor Flask debe responder a cada request en menos de 500ms (excluyendo el tiempo de ejecución de la herramienta) | Media |
| RNF-02 | Seguridad | El servidor Flask solo debe aceptar conexiones desde localhost (127.0.0.1) | Alta |
| RNF-03 | Usabilidad | El usuario debe poder configurar y lanzar un ataque básico en menos de 3 pasos desde la interfaz | Media |
| RNF-04 | Portabilidad | El backend debe poder correr en cualquier dispositivo Android con Kali NetHunter instalado | Media |
| RNF-05 | Mantenibilidad | Cada módulo de ataque debe estar en un archivo Python independiente para facilitar el mantenimiento | Alta |
| RNF-06 | Legalidad | El sistema debe incluir advertencias explícitas sobre uso ético y legal en el primer arranque | Alta |
| RNF-07 | Logging | Todas las acciones ejecutadas deben quedar registradas en un archivo de log con timestamp y parámetros usados | Alta |

---

## 5. Casos de uso principales

### CU-01: Auditoría de red WiFi
**Actor:** Usuario  
**Precondición:** Chroot de Kali activo, interfaz WiFi en modo monitor  
**Flujo principal:**
1. Usuario abre el módulo WiFi en la APK
2. Selecciona "Escanear redes"
3. El sistema muestra la lista de redes detectadas
4. Usuario selecciona una red objetivo
5. Selecciona "Capturar handshake"
6. El sistema desautentica un cliente y captura el handshake
7. El sistema guarda el archivo .cap

**Flujo alternativo:** Si no hay clientes conectados, el sistema notifica al usuario y sugiere esperar.

---

### CU-02: Escaneo y explotación de red
**Actor:** Usuario  
**Precondición:** Conectado a una red WiFi objetivo  
**Flujo principal:**
1. Usuario abre el módulo de Red
2. Ingresa el rango de IPs a escanear
3. El sistema ejecuta Nmap y muestra hosts activos
4. Usuario selecciona un host
5. El sistema escanea puertos y detecta servicios
6. El motor de decisión sugiere el mejor exploit disponible
7. Usuario confirma y el sistema lanza el exploit via Metasploit

---

### CU-03: Ataque HID a PC
**Actor:** Usuario  
**Precondición:** Teléfono conectado a una PC por USB, modo HID habilitado  
**Flujo principal:**
1. Usuario abre el módulo HID
2. Selecciona o escribe un payload
3. Configura el delay entre teclas
4. Ejecuta el payload
5. El teléfono inyecta las teclas en la PC objetivo

---

## 6. Requerimientos de hardware

| Componente | Especificación | Obligatorio |
|---|---|---|
| Teléfono | Samsung Galaxy S10 (SM-G973F) con NetHunter | Sí |
| OS del teléfono | LineageOS 23.2 + Magisk + Kali NetHunter | Sí |
| Adaptador WiFi externo | Chipset RTL8812AU (para inyección avanzada) | No |
| Adaptador NFC/RFID | Proxmark3 (para 125kHz) | No |
| Dongle SDR | RTL-SDR RTL2832U (para análisis de radiofrecuencia) | No |

---

## 7. Restricciones y suposiciones

### Restricciones
- El sistema depende del kernel de NetHunter para funciones de bajo nivel (monitor mode, inyección WiFi, HID)
- Las herramientas de Kali deben estar instaladas en el chroot antes de usar los módulos correspondientes
- La APK requiere Android 12 o superior (LineageOS 23.2)

### Suposiciones
- El usuario tiene conocimientos básicos de redes y seguridad informática
- El usuario cuenta con autorización legal para auditar los sistemas objetivo
- El teléfono tiene conexión a internet para descargar actualizaciones del chroot

---

## 8. Plan de desarrollo (MVP)

| Fase | Contenido | Estimación |
|---|---|---|
| Fase 1 — Backend base | Servidor Flask + módulo de red (Nmap) + logging | 1 semana |
| Fase 2 — WiFi | Módulo WiFi completo (escaneo, deauth, handshake) | 1 semana |
| Fase 3 — APK básica | Interfaz Android con módulos de red y WiFi | 2 semanas |
| Fase 4 — Módulos extra | BT, NFC, HID | 2 semanas |
| Fase 5 — Motor de decisión | Lógica de sugerencia automática de ataques | 1 semana |
| Fase 6 — UI final | Diseño Watch Dogs, pulido general | 1 semana |

---

*Este documento debe actualizarse a medida que el proyecto evoluciona. Cada cambio debe versionarse en Git.*
