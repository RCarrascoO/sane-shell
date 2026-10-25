# niri-deck 🎛️📱

> **Sub-app de sane-shell: Consola táctil y companion de escritorio para Niri**
> Implementado en **Go puro** con frontend embebido en **Material Design 3 (M3 Expressive)** y paleta Catppuccin Mocha.

---

## 🎯 ¿Qué es `niri-deck`?

`niri-deck` convierte cualquier teléfono o tablet (como un **Huawei Mate 20 Lite**) conectado por USB-C en una mesa de control táctil de hardware para tu PC con CachyOS / Arch Linux:

* **Ultra-eficiente:** Consume únicamente **~9 MB de RAM** y 0.0% de CPU en reposo.
* **Cero dependencias externas:** Ni Node.js, ni Electron, ni Python. Un solo binario estático de ~7 MB.
* **Auto ADB Reverse:** Al conectar el teléfono por USB-C, configura de forma automática el túnel `adb reverse tcp:8080 tcp:8080` sin tocar la terminal.
* **100% Material Design 3 (M3):** Sigue estrictamente la especificación [m3.material.io](https://m3.material.io/), compartiendo los mismos tokens de color y esquinas redondeadas de `sane-shell`.

---

## ⚡ Capacidades

1. **Audio Mixer Reactivo (PipeWire / `wpctl`):**
   * Control de volumen Master con sliders gruesos tipo píldora (*M3 Expressive Sliders*).
   * Sliders de volumen independientes para aplicaciones activas (Zen Browser, Vesktop, etc.).
   * Botón táctil para silenciar el micrófono con feedback de color instantáneo (Píldora Azul/Verde cuando está activo, Roja cuando está muteado).
2. **Workspaces y Niri IPC:**
   * Matriz táctil de workspaces organizados por monitor (`DVI-D-1` y `HDMI-A-1`).
   * Visualización del workspace activo y la ventana enfocada.
3. **Atajos de Sistema:**
   * Apagar/Encender monitores (`power-off-monitors`).
   * Alternar modo ventana flotante / mosaico.
   * Pantalla completa y captura de pantalla interactiva.
   * Cerrar ventana activa.
4. **Telemetría en Vivo:**
   * Lectura directa de `/proc/meminfo` (RAM usada en MB), `/proc/stat` (CPU %) y temperatura de la GPU AMD Radeon.
5. **Controlador Multimedia (MPRIS):**
   * Reproducir, pausar, anterior y siguiente con títulos de canciones actualizados en tiempo real.

---

## 🚀 Inicio y Uso

### 1. Compilación
El binario se compila automáticamente al ejecutar `./install.sh` desde la raíz de `sane-shell`, o de forma individual con:

```bash
cd ~/.config/quickshell/sane-shell/go-niri-deck
go build -ldflags="-s -w" -o ~/.local/bin/niri-deck main.go
```

### 2. Ejecución
Para iniciar el servicio:

```bash
niri-deck
```

*(Opcional: puedes agregar `spawn-at-startup "niri-deck"` en tu `~/.config/niri/config.d/50-startup.kdl` para que inicie automáticamente con Niri).*

### 3. Conexión del Teléfono
1. Conecta el Huawei Mate 20 Lite a tu PC mediante el cable **USB-C** (con Depuración USB activada).
2. Abre el navegador en el teléfono e ingresa a:
   ```text
   http://localhost:8080
   ```
3. *(Recomendado)* En el menú del navegador del teléfono, selecciona **"Agregar a la pantalla de inicio"** para abrirlo en modo pantalla completa sin barra de navegación.
