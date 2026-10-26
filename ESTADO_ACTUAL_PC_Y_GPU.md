# Estado Maestro del Sistema, Diagnóstico de la GPU (RX 570) y Arquitectura de `sane-shell`

> [!IMPORTANT]
> **Para agentes futuros:** Este documento resume el estado completo del hardware, kernel, optimizaciones gráficas y el entorno de escritorio (`niri` + `sane-shell`) de `sane` al **26 de octubre de 2026**. Una copia permanente de este archivo reside en [`/home/sane/.config/quickshell/sane-shell/ESTADO_ACTUAL_PC_Y_GPU.md`](file:///home/sane/.config/quickshell/sane-shell/ESTADO_ACTUAL_PC_Y_GPU.md). Léelo antes de explorar el sistema para ahorrar tokens.

---

## 1. Diagnóstico de la Tarjeta Gráfica: ¿Qué le pasó a tu RX 570 y por qué ciertas cosas hacen que crashee?

Tu GPU es una **AMD Radeon RX 570 de 8 GB GDDR5** con arquitectura **Polaris 10 (`GCN 4.0`, ID PCI `1002:67df`, driver `amdgpu` + `RADV` Vulkan)**.
**Tu tarjeta gráfica NO está dañada físicamente** (sus 8 GB de VRAM y motores UVD/VCE inicializan sin errores de hardware en el kernel y mantiene temperaturas frescas de `34°C–43°C` en escritorio).

Los crasheos que sufrías al abrir juegos de Steam, usar pantallas completas o transmitir se debían a **4 choques de software/driver específicos de la arquitectura Polaris 10 en Linux moderno**:

### Causa 1: Inyección automática de FSR4 (`amdxcffx64.dll`) por `Proton-CachyOS` (Solucionado)
- **Qué pasaba:** `Proton-CachyOS` traía activada por defecto la inyección automática de la librería de reescalado **AMD FidelityFX / FSR4 (`amdxcffx64.dll`)** dentro de todos los prefijos de Wine/Proton (`drive_c/windows/system32/amdxcffx64.dll`).
- **Por qué crasheaba tu RX 570:** FSR4 y las extensiones modernas de `amdxcffx64.dll` utilizan instrucciones de cómputo asíncrono y matrices (`WMMA` / `Wave32` / `FP16` empaquetado) diseñadas para **RDNA3 / RDNA4 (RX 7000/9000)**. La RX 570 (**GCN 4.0 / Polaris 10**) solo ejecuta `Wave64` clásico y carece de esas instrucciones. En cuanto un juego DX11/DX12 cargaba esa DLL, el motor de shaders de la RX 570 recibía una instrucción inválida o caía en un bucle infinito en la cola de cómputo (`ring gfx_0.0.0` / `ring sdma0`).
- **Cómo empeoraba (`winedbg` fork-bomb):** Al fallar la DLL, Wine lanzaba `winedbg.exe` en bucle infinito intentando volcar la memoria, congelando los 16 GB de RAM y toda la sesión gráfica.
- **Solución aplicada:**
  1. Se bloqueó globalmente en [`/home/sane/.config/niri/config.d/40-environment.kdl`](file:///home/sane/.config/niri/config.d/40-environment.kdl) con `PROTON_FSR4_UPGRADE "0"` y `WINEDEBUG "-all"`.
  2. Se eliminaron las DLLs `amdxcffx64.dll` contaminadas de tus prefijos de Steam y se configuró **`Proton 10.0`** como versión limpia en Steam.

### Causa 2: Sobrecarga de Shaders de Recorte (Rounded Corners + Alpha Blending) en Wayland sobre Juegos (Solucionado)
- **Qué pasaba:** En compositores Wayland como `niri`, si se aplica un `geometry-corner-radius` (bordes redondeados con `clip-to-geometry true`) a una ventana de juego Vulkan/OpenGL a pantalla completa, el compositor desactiva el **Direct Scanout** (envío directo del frame del juego al monitor) y fuerza a la GPU a copiar cada fotograma a una textura intermedia y pasarle un shader de recorte con canal alfa.
- **Por qué afecta a la RX 570:** En Polaris 10, combinar un juego pesado en Vulkan (`RADV`) con composición forzada del compositor y compilación de shaders en segundo plano (`fossilize_replay`) satura el bus GDDR5 de 256 bits y provoca que un paquete del anillo gráfico tarde más de 2 segundos, disparando el watchdog del kernel (`amdgpu: ring gfx timeout`).
- **Solución aplicada:**
  1. Se creó la regla de gaming directo en [`/home/sane/.config/niri/config.d/90-user-extra.kdl`](file:///home/sane/.config/niri/config.d/90-user-extra.kdl) (`match app-id=r#"^steam_app_"#`, `Minecraft`, `gamescope`) con `opacity 1.0`, `geometry-corner-radius 0` y `clip-to-geometry false` para permitir **Direct Scanout** puro.
  2. Se desactivó el pre-cacheo en segundo plano de Vulkan (`DisableShaderCache "1"` en `config.vdf` de Steam) para que `fossilize_replay` no robe CPU/GPU mientras juegas.

### Causa 3: `Disabling VM faults because of PRT request!` y Texturas Virtuales (Comportamiento de `RADV` en Polaris)
- En los logs del kernel verás siempre al abrir juegos o navegadores basados en Chromium/Electron:
  `amdgpu 0000:01:00.0: Disabling VM faults because of PRT request!`
- **Qué significa:** Los juegos modernos (DX12 / Vulkan via DXVK/VKD3D) usan **Partially Resident Textures (PRT / Sparse Textures)**. Como el hardware Polaris 10 no distingue entre un acceso válido a una página PRT sin mapear y un fallo real de memoria virtual (`VM page fault`), el driver `amdgpu` apaga los reportes de `VM fault` cuando una app pide PRT.
- **Por qué ciertas cosas aún pueden hacerla crashear si te excedes:**
  1. **Ray Tracing por software o juegos DX12 que exigen Shader Model 6.6+ / Mesh Shaders:** Polaris 10 no tiene hardware de Ray Tracing ni Mesh Shaders nativos. Si un juego intenta emularlos en RADV con PRT activo y desborda los 8 GB de VRAM, como los `VM faults` están desactivados por PRT, en lugar de cerrar solo el juego, puede colgar el anillo `gfx` y reiniciar la pantalla.
  2. **Picos bruscos de voltaje/frecuencia en Polaris (`polaris10_smu`) con decodificación de video + juego simultáneo:** Cuando tienes **YouTube/Crunchyroll (decodificación por hardware UVD/VA-API)** en un monitor y un **juego pesado en Vulkan** en el otro, la tabla de estados de energía (`DPM`) de la RX 570 salta continuamente entre el estado de video y el estado 3D máximo. Si notas un cuelgue haciendo ambas cosas a la vez, en **CoreCtrl** (que ya tienes en tu bandeja del sistema) puedes fijar el perfil de rendimiento en **Alto (High)** o aplicar un ligero *undervolt* (-30 mV en el último estado P7) para estabilizar la tarjeta al 100%.

---

## 2. Estado Actual de la PC (Hardware, Almacenamiento y RAM)

| Componente | Estado Actual | Detalles Clave |
| :--- | :--- | :--- |
| **CPU** | AMD Ryzen 5 5500 (6C/12T) | Escala hasta **4.27 GHz** con scheduler **BORE** (`6.18.23-2-cachyos`). |
| **GPU** | AMD Radeon RX 570 8GB (`Polaris10`) | `amdgpu` + `RADV` Vulkan + `radeonsi` VA-API (`Resizable BAR` de **8192 MB** activo). |
| **RAM** | 16 GB DDR4-2666 + 15 GB `zram` | **~700 MB en reposo base** (frente a los ~3.8 GB que consumía antes con `iNiR` y daemons basura). Con navegador, Vesktop y Antigravity abiertos ronda `3.8–4.5 GB`. |
| **Monitores** | Dual Monitor en `niri` | **Principal (`DVI-D-1`):** `1360x768 @ 60.015Hz` (`Normal`, `x=0, y=0`).<br>**Secundario (`HDMI-A-1`):** `1366x768 @ 59.990Hz` (`Vertical 90°`, `x=1360, y=0` a la derecha). |
| **Disco Raíz (`/`)** | `/dev/sda5` (300 GB Btrfs) | **234 GB libres** (solo 20% usado; se liberaron **~257 GB** de snapshots viejos y cachés). |
| **Disco Datos (`/mnt/Files`)** | `/dev/sdb1` (458 GB) | **409 GB libres** (solo 6% usado). |

---

## 3. Arquitectura Actual del Escritorio: `niri` + `sane-shell` v2

Reemplazamos por completo `iNiR` (que consumía ~800 MB de RAM y 17.7% de CPU constante) por **`sane-shell`**, nuestra shell propia diseñada bajo **Material Design 3 Expressive (`m3.material.io`) / Android 16 Pixel UI** con paleta **Catppuccin Mocha (Oscuro) / Latte (Claro)**.

### Repositorio y Ubicación
- **Ruta local:** [`/home/sane/.config/quickshell/sane-shell/`](file:///home/sane/.config/quickshell/sane-shell/)
- **Repositorio GitHub:** `git@github.com:RCarrascoO/sane-shell.git` (rama `main`, sincronizada hasta el commit `4d50fa4`).
- **Rollback de emergencia (por si algún día lo necesitaras):** `/home/sane/.local/bin/rollback-to-inir.sh` (backup guardado en `/home/sane/.local/share/inir-backup/`).

### Componentes Clave de `sane-shell`
1. **Motor Backend en Go ([`go-agy-tool/main.go`](file:///home/sane/.config/quickshell/sane-shell/go-agy-tool/main.go) → `/home/sane/.local/bin/agy-tool`):**
   - Cero procesos de Python en tu sesión. Todo corre sobre un único binario estático en Go (<5 ms de respuesta):
     - `agy-tool quota`: Lee en paralelo las cuotas de **Antigravity IDE** y **Zen Browser (Gemini Web)**.
     - `agy-tool focus [zen]`: Enfoca o lanza Antigravity / Zen Browser.
     - `agy-tool apps`: Escanea y genera el JSON de aplicaciones `.desktop` para el cajón de apps.
     - `agy-tool toggle-drawer` / `agy-tool toggle-popup <id>`: Detecta el monitor enfocado (`DVI-D-1` o `HDMI-A-1`) y abre el popup en esa pantalla.
     - `agy-tool volume <up|down|mute>`, `brightness <up|down>`, `media <play-pause|next|previous>`: Controla PipeWire / `brightnessctl` / MPRIS y dispara los OSDs.
     - `agy-tool displays` / `set-display`: Lee y aplica resoluciones, hercios, rotación y posición de monitores en `niri` y los persiste en [`/home/sane/.config/niri/config.kdl`](file:///home/sane/.config/niri/config.kdl).
2. **Módulos Visuales QML (`modules/`):**
   - **Tokens M3 sin colisión de señales ([`Theme.qml`](file:///home/sane/.config/quickshell/sane-shell/modules/common/Theme.qml)):** Usa el prefijo `colOn*` (`colOnSurface`, `colOnPrimary`, `colOnSecondaryContainer`, etc.) para evitar la colisión de nombres `on<PropertyName>` de Qt6 QML.
   - **Barra Superior Segmentada ([`TopBar.qml`](file:///home/sane/.config/quickshell/sane-shell/modules/bar/TopBar.qml)):** Botón de Apps + Workspaces a la izquierda; Reloj/Calendario al centro; CPU/RAM/GPU Temp ([`HardwarePill.qml`](file:///home/sane/.config/quickshell/sane-shell/modules/bar/HardwarePill.qml)), Cuota IA ([`AgyUsage.qml`](file:///home/sane/.config/quickshell/sane-shell/modules/bar/AgyUsage.qml)), Bandeja con menús M3 ([`TrayPill.qml`](file:///home/sane/.config/quickshell/sane-shell/modules/bar/TrayPill.qml) + [`TrayMenuPopup.qml`](file:///home/sane/.config/quickshell/sane-shell/modules/bar/TrayMenuPopup.qml)) y Ajustes Rápidos ([`SystemPill.qml`](file:///home/sane/.config/quickshell/sane-shell/modules/bar/SystemPill.qml)) a la derecha.
   - **Panel de Ajustes Rápidos ([`QuickSettingsPopup.qml`](file:///home/sane/.config/quickshell/sane-shell/modules/bar/QuickSettingsPopup.qml)):** Cuadrícula 2x4 de 8 tiles (Ethernet/Wi-Fi, Bluetooth USB `hci0`, Sonido PipeWire, Luz Nocturna `wlsunset`, Tema Oscuro/Claro, Fondos de Pantalla, Captura de Región y Portapapeles `cliphist`) + Reproductor MPRIS con carátula.
   - **Gestor de Pantallas y Luz Nocturna ([`DisplayPopup.qml`](file:///home/sane/.config/quickshell/sane-shell/modules/bar/DisplayPopup.qml)):** Slider de temperatura Kelvin (`2500K–6000K`) para `wlsunset` + selector en vivo de resolución, rotación y posición de `DVI-D-1` y `HDMI-A-1`.
   - **Selector Visual de Fondos ([`WallpaperPopup.qml`](file:///home/sane/.config/quickshell/sane-shell/modules/bar/WallpaperPopup.qml)):** Cuadrícula con tus 171 fondos de `/home/sane/Imágenes/Wallpapers/` aplicada con `swaybg` y persistida en [`50-startup.kdl`](file:///home/sane/.config/niri/config.d/50-startup.kdl).
   - **App Drawer Nativo Multimonitor ([`AppDrawerPopup.qml`](file:///home/sane/.config/quickshell/sane-shell/modules/bar/AppDrawerPopup.qml)):** Se abre con `Mod + Space` en el monitor donde tengas el foco con captura inmediata del teclado (`WlrKeyboardFocus.Exclusive`).
   - **3 Overlays OSD ([`OsdOverlay.qml`](file:///home/sane/.config/quickshell/sane-shell/modules/bar/OsdOverlay.qml)):**
     - **Música:** Arriba al centro (con portada, título y artista).
     - **Volumen:** Barra vertical a la derecha.
     - **Brillo:** Barra vertical a la izquierda.
3. **Gestor de Archivos y Portales (`COSMIC Files` en Rust):**
   - `Win + E` (`Super+E`) abre `/home/sane/.local/bin/cosmic-files`.
   - El selector de archivos al guardar/subir desde navegadores usa **`xdg-desktop-portal-cosmic`** ([`/home/sane/.config/xdg-desktop-portal/niri-portals.conf`](file:///home/sane/.config/xdg-desktop-portal/niri-portals.conf)), habiendo erradicado por completo el selector antiguo de GTK/Nautilus.
4. **Script de Purga de Paquetes Duplicados (Opcional con `sudo`):**
   - Quedó preparado en [`/home/sane/.gemini/antigravity/brain/d3935ecf-b3bb-4e3f-9773-0162878178e9/scratch/purge_kde_hypr_duplicates.sh`](file:///home/sane/.gemini/antigravity/brain/d3935ecf-b3bb-4e3f-9773-0162878178e9/scratch/purge_kde_hypr_duplicates.sh) por si deseas desinstalar del disco los paquetes huérfanos de KDE Plasma, Hyprpicker, Rofi, Wofi, Waybar, Dunst y Nautilus cuando quieras.
