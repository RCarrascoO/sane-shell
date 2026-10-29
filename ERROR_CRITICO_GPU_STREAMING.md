# Subdocumento Técnico: Error Crítico de la GPU (RX 570 Polaris 10) al Grabar, Compartir Pantalla o Transmitir

> [!CAUTION]
> **REGLA ESTRICTA DEL SISTEMA (`sane`):**
> **NUNCA** activar la codificación de video por hardware de la GPU (`VA-API`, `AMF`, `VCE`) para **grabar (OBS Studio / FFmpeg)**, **transmitir (Streaming)** ni **compartir pantalla (Vesktop / Discord / WebRTC)**. Toda codificación de salida de video debe realizarse exclusivamente por **CPU (`x264` / software)** usando los 12 hilos del **AMD Ryzen 5 5500**.

---

## 1. Resumen del Problema
Aunque la **AMD Radeon RX 570 8GB GDDR5 (`Polaris 10` / `GCN 4.0`)** funciona perfectamente para renderizado 3D (Vulkan `RADV` / OpenGL `radeonsi`), presenta **dos fallos críticos irreversibles de firmware/driver en Linux + Wayland** cuando se intenta usar su bloque de codificación de video física (**`VCE 3.4`**) o importar texturas de captura de pantalla (`DMA-BUF`) con aceleración por hardware:

1. **En OBS Studio / FFmpeg / Sunshine (Grabación y Streaming):** Cuelgue total de la GPU (`ring vce0 timeout`) que congela ambos monitores y fuerza un reinicio del driver `amdgpu`.
2. **En Vesktop / Discord / Navegadores Chromium (Compartir Pantalla por PipeWire):** Cierre abrupto (`SIGABRT` en el hilo `cs0` de `libgallium`) o congelamiento del escritorio en el instante en que alguien entra a ver la pantalla compartida.

---

## 2. Explicación Técnica de las 2 Fallas Críticas

### Falla A: Deadlock del Motor `VCE 3.4` (`ring vce0 timeout`) al Grabar o Transmitir
- **Arquitectura afectada:** `Polaris 10` utiliza el motor antiguo **VCE 3.4 (Video Coding Engine 3.4)** con el firmware propietario `amdgpu/polaris10_vce.bin` (anterior a la arquitectura unificada *VCN* introducida en Vega y RDNA).
- **Qué ocurre a nivel de Kernel (`amdgpu`):**
  1. Cuando OBS Studio o FFmpeg inician una sesión de codificación H.264/HEVC por hardware (`vaapi_h264`), el compositor Wayland (`niri`) entrega las texturas de la pantalla vía `DMA-BUF` al anillo de codificación `vce0`.
  2. En kernels modernos de Linux, el gestor de energía de Polaris (`polaris10_smu`) intenta alternar dinámicamente los relojes `SCLK` (núcleo) y `MCLK` (VRAM GDDR5) mientras el bloque `VCE 3.4` tiene buffers pendientes en memoria GTT/VRAM.
  3. Bajo bitrate constante (CBR) o al combinar un juego 3D en `ring gfx` con codificación en `ring vce0`, el firmware de `VCE 3.4` sufre un **deadlock de sincronización de memoria** y deja de responder.
  4. Tras 2 a 10 segundos sin respuesta, el watchdog del kernel dispara el error fatal:
     ```text
     [drm:amdgpu_job_timedout [amdgpu]] *ERROR* ring vce0 timeout, signaled seq=..., emitted seq=...
     [drm:amdgpu_device_ip_suspend_phase2 [amdgpu]] *ERROR* suspend of IP block <vce_v3_0> failed -22
     amdgpu 0000:01:00.0: GPU reset begin!
     ```
  5. Como el bloque `vce_v3_0` de Polaris 10 no soporta *soft-reset* limpio en caliente (`suspend failed -22`), el intento de recuperación del kernel tumba todo el servidor gráfico Wayland.

### Falla B: Crash de `DMA-BUF` + `libgallium` (`vesktop:cs0`) al Compartir Pantalla en Discord/Vesktop
- **Qué ocurre al compartir pantalla en Wayland (`xdg-desktop-portal-gnome` + PipeWire):**
  1. El portal de captura de Niri exporta cada fotograma de tu monitor o ventana como un buffer de memoria gráfica directa (`DMA-BUF`) usando modificadores de compresión de superficies de AMD.
  2. Si **Vesktop / Electron** tiene activada la aceleración por hardware (`hardwareAcceleration: true` o `hardwareVideoAcceleration: true`), Chromium intenta importar ese `DMA-BUF` directamente en su contexto OpenGL/Vulkan (`libgallium` / `radeonsi`) y pasarlo al codificador WebRTC de hardware (`VCE 3.4`).
  3. En `Polaris 10`, la combinación de importación `DMA-BUF` de PipeWire + conversión de formato `NV12` en `radeonsi` provoca una corrupción de comando en el hilo `vesktop:cs0` (disparando `SIGABRT` inmediato y cerrando Discord) o bloquea el anillo `vce0` igual que en OBS.

---

## 3. Configuración Aplicada y Reglas de Uso

Para evitar el 100% de estos crasheos sin perder rendimiento en juegos, el sistema quedó blindado con la siguiente configuración:

| Aplicación / Flujo | Configuración Obligatoria | Archivo de Configuración |
| :--- | :--- | :--- |
| **OBS Studio (Nativo y Flatpak)** | Codificador: **`obs_x264` (Software CPU)**<br>Preset: `veryfast` \| Formato: `hybrid_mp4` | [`~/.config/obs-studio/basic/profiles/Sin_Título/basic.ini`](file:///home/sane/.config/obs-studio/basic/profiles/Sin_T%C3%ADtulo/basic.ini)<br>[`~/.var/app/com.obsproject.Studio/config/obs-studio/basic/profiles/Sin_Título/basic.ini`](file:///home/sane/.var/app/com.obsproject.Studio/config/obs-studio/basic/profiles/Sin_T%C3%ADtulo/basic.ini) |
| **Vesktop (Discord)** | `"hardwareAcceleration": false`<br>`"hardwareVideoAcceleration": false` | [`~/.config/vesktop/settings.json`](file:///home/sane/.config/vesktop/settings.json) |
| **Zen Browser (Ver videos)** | Decodificación (`UVD 6.3`) activa solo para H.264, pero **`media.av1.enabled = false`** (Polaris no tiene decodificador físico AV1) | [`~/.config/zen/02vo3z9l.Default (release)/user.js`](file:///home/sane/.config/zen/02vo3z9l.Default%20(release)/user.js) |
| **Sunshine / Remote Play** | Desactivado del autostart; si se usa alguna vez, forzar `encoder = software` (`libx264`) | `~/.config/sunshine/sunshine.conf` |

### ¿Por qué grabar y transmitir con el CPU (Ryzen 5 5500) es superior en tu PC?
1. **Calidad de imagen muy superior:** El motor `VCE 3.4` de la RX 570 (año 2016/2017) no soporta *B-frames* en H.264 y produce imagen pixelada a bitrates de streaming (`6000 kbps`). El codificador `x264` (`veryfast`) en tu **Ryzen 5 5500 (6 núcleos / 12 hilos Zen 3)** produce una calidad visual drásticamente más limpia.
2. **GPU 100% libre para tus juegos:** Al no tocar `VCE 3.4`, toda la energía, ancho de banda GDDR5 y estabilidad de la RX 570 se dedican exclusivamente a mover el juego en Vulkan/OpenGL con **0 cuelgues**.
