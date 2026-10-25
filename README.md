# sane-shell 🚀

> **Ultralight Wayland Desktop Shell for Niri**
> Android 16 (*Material 3 Expressive* / Google Pixel UI) + Catppuccin Palette (Mocha & Latte).
> Construido sobre **Quickshell (Qt6 QML)** y **Go (`agy-tool`)**.

---

## 📑 Bitácora y Registro del Trabajo Realizado

Este proyecto sustituye por completo la suite anterior (`iNiR`), reduciendo drásticamente la sobrecarga del sistema, eliminando llamadas repetitivas al intérprete de Python y proporcionando una interfaz moderna, limpia y reactiva.

### 📊 Comparativa de Rendimiento (Antes vs. Después)

| Métrica | Anterior (`iNiR`) | Nuevo (`sane-shell`) | Diferencia |
| :--- | :--- | :--- | :--- |
| **Consumo de Memoria RAM** | ~1.1 GB (1,100 MB) | **49.3 MB** | **-95.5%** de RAM |
| **Uso de CPU en Reposo** | ~17.7% (15 min acumulados) | **0.0%** (116 ms) | **Prácticamente nulo** |
| **Tiempo de Consulta de Cuota** | ~350 - 600 ms (Python 3) | **~5 ms** (`agy-tool` Go) | **x70 más rápido** |
| **Procesos en Segundo Plano** | Cava, Python watchers, udev, nmcli | **1 proceso nativo** (`quickshell`) | Entorno limpio y determinista |

---

### 🛠️ Resumen de las Fases Ejecutadas

#### Fase 1: Rescate, Port a Go (`agy-tool`) y Script de Rollback
1. **Respaldo de Seguridad:**
   - Se creó un respaldo comprimido de la configuración previa en `~/.local/share/inir-backup/quickshell-inir-backup.tar.gz`.
   - Se crearon copias `.bak` de `50-startup.kdl`, `70-binds.kdl`, `inir_gemini_bridge.json` e `inir.service`.
2. **Script de Rollback:**
   - Ubicación: [`~/.local/bin/rollback-to-inir.sh`](file:///home/sane/.local/bin/rollback-to-inir.sh).
   - Permite restaurar de forma instantánea el entorno anterior en caso de cualquier eventualidad.
3. **Port a Go (`agy-tool`):**
   - Código fuente en `go-agy-tool/main.go`, compilado en [`~/.local/bin/agy-tool`](file:///home/sane/.local/bin/agy-tool).
   - Implementa 3 subcomandos sin dependencias externas:
     - `quota`: Lee `~/.gemini/antigravity/conversation_summaries.db`, descubre el puerto/token del Language Server y lee `gemini_web_quota.json`.
     - `bridge`: Servidor de Native Messaging Stdio para extensiones WebExtensions de Zen Browser.
     - `focus`: Enfoque rápido de ventanas vía IPC de Niri (`antigravity` o `zen`).
   - Configurado en [`~/.mozilla/native-messaging-hosts/inir_gemini_bridge.json`](file:///home/sane/.mozilla/native-messaging-hosts/inir_gemini_bridge.json) a través del wrapper [`~/.local/bin/agy-gemini-bridge`](file:///home/sane/.local/bin/agy-gemini-bridge).

#### Fase 2: Identidad Visual — Android 16 (Pixel UI) + Catppuccin
1. **Paleta Catppuccin Reactiva:**
   - Implementado en `modules/common/Theme.qml` con soporte para **Mocha** (modo oscuro) y **Latte** (modo claro), con acentos **Lavender (`#b4befe` / `#7287fd`)** y **Blue (`#89b4fa` / `#1e66f5`)**.
2. **Shims de Compatibilidad:**
   - `modules/common/Appearance.qml` y `modules/common/Translation.qml` proveen compatibilidad retroactiva directa para los widgets de cuota sin requerir librerías pesadas de iNiR.
3. **Geometría Material 3 Expressive:**
   - Barra superior de **30px** de altura, píldoras internas de **22px** (`radius: 11`), espacios compactos y popups con esquinas redondeadas (`radius: 20`).
4. **Sincronización de Temas:**
   - Script [`scripts/toggle-theme.sh`](file:///home/sane/.config/quickshell/sane-shell/scripts/toggle-theme.sh) sincroniza en vivo el shell, la configuración de **Fuzzel** (`~/.config/fuzzel/fuzzel.ini`) y el esquema de color de escritorio vía `gsettings`.

#### Fase 3: Arquitectura y Módulos de la Barra
1. **Punto de Entrada:** `shell.qml` instancia una barra `TopBar` por cada pantalla detectada en `Quickshell.screens`.
2. **Monitor Principal (`DVI-D-1` / 1360x768 Horizontal):**
   - **Izquierda:** `WorkspacesPill.qml` (píldoras dinámicas estilo Pixel con animación elástica) + Título de la ventana activa con elipsis.
   - **Centro:** `ClockPill.qml` (`HH:mm  •  ddd d MMM`) con popup interactivo de calendario mensual.
   - **Derecha:**
     - `HardwarePill.qml`: Monitoreo en tiempo real de CPU%, RAM usada y temperatura de la GPU AMD Radeon RX 570 vía `hwmon1`.
     - `AgyUsage.qml` + `AgyUsagePopup.qml`: Widget rescatado y migrado al binario en Go `agy-tool`.
     - `SystemPill.qml`: Iconos de estado de red, volumen actual con mute, icono de tema y soporte para items de SystemTray.
     - `QuickSettingsPopup.qml`: Panel desplegable Android 16 con tiles de red, alternador Mocha/Latte, slider PipeWire de volumen y botones de bloqueo/apagado.
3. **Monitor Secundario (`HDMI-A-1` / 768x1366 Vertical):**
   - **Izquierda:** Workspaces de ese monitor.
   - **Derecha:** Reloj compacto `HH:mm`.

#### Fase 4: Migración de Atajos, Autostart y Purga de iNiR
1. **Atajos Nativos en Niri ([`~/.config/niri/config.d/70-binds.kdl`](file:///home/sane/.config/niri/config.d/70-binds.kdl)):**
   - Se eliminaron todas las dependencias del lanzador `inir` para usar comandos nativos:
     - Terminal: `Mod+Return` / `Mod+T` $\rightarrow$ `kitty`
     - Lanzador: `Mod+Space` / `Mod+D` $\rightarrow$ `fuzzel`
     - Cerrar ventana: `Mod+Q` $\rightarrow$ `close-window` (acción interna de Niri)
     - Navegador: `Super+W` $\rightarrow$ `zen-browser`
     - Portapapeles: `Mod+V` $\rightarrow$ `cliphist` + `fuzzel`
     - Bloqueo de pantalla: `Mod+Alt+L` $\rightarrow$ `swaylock`
     - Captura de pantalla: `Mod+Shift+S` / `Ctrl+Shift+S` $\rightarrow$ `screenshot`
     - Audio / Volumen: `wpctl`
     - Controles multimedia: `playerctl`
2. **Autostart ([`~/.config/niri/config.d/50-startup.kdl`](file:///home/sane/.config/niri/config.d/50-startup.kdl)):**
   - Configurados watchers de `cliphist` (`text` e `image`).
   - Configurado inicio de `quickshell -c sane-shell`.
3. **Servicio Systemd:**
   - Creado y habilitado [`~/.config/systemd/user/sane-shell.service`](file:///home/sane/.config/systemd/user/sane-shell.service) ligado a `niri.service`.
4. **Purga Segura de iNiR:**
   - Servicios desactivados y carpeta `~/.config/quickshell/inir` eliminada (respaldada previamente en backup tarball).

#### Fase 5: Versionado Git y Repositorio en GitHub
- Repositorio inicializado en `~/.config/quickshell/sane-shell`.
- Respaldadas configuraciones clave de Niri en `niri-configs/`.
- Creado script de instalación autónomo `install.sh`.
- Repositorio subido a GitHub: **[https://github.com/RCarrascoO/sane-shell](https://github.com/RCarrascoO/sane-shell)**

---

## 🗂️ Rutas Clave de Archivos Generados

| Archivo / Componente | Ruta Absoluta |
| :--- | :--- |
| **Configuración sane-shell (Raíz)** | `/home/sane/.config/quickshell/sane-shell/` |
| **Punto de Entrada QML** | `/home/sane/.config/quickshell/sane-shell/shell.qml` |
| **Código Fuente Go `agy-tool`** | `/home/sane/.config/quickshell/sane-shell/go-agy-tool/main.go` |
| **Binario Compilado Go** | `/home/sane/.local/bin/agy-tool` |
| **Script de Rollback de Emergencia** | `/home/sane/.local/bin/rollback-to-inir.sh` |
| **Script Toggle de Tema (Mocha/Latte)** | `/home/sane/.config/quickshell/sane-shell/scripts/toggle-theme.sh` |
| **Script de Instalación Limpia** | `/home/sane/.config/quickshell/sane-shell/install.sh` |
| **Servicio Systemd de Usuario** | `/home/sane/.config/systemd/user/sane-shell.service` |
| **Atajos de Niri Actualizados** | `/home/sane/.config/niri/config.d/70-binds.kdl` |
| **Autostart de Niri Actualizado** | `/home/sane/.config/niri/config.d/50-startup.kdl` |
| **Copia de Seguridad de iNiR** | `/home/sane/.local/share/inir-backup/quickshell-inir-backup.tar.gz` |

---

## ⌨️ Atajos de Teclado Clave (Niri)

| Atajo | Acción |
| :--- | :--- |
| `Mod+Return` / `Mod+T` | Abrir terminal (`kitty`) |
| `Mod+Space` / `Mod+D` | Lanzador de aplicaciones (`fuzzel`) |
| `Mod+Q` | Cerrar ventana activa (acción nativa de Niri) |
| `Super+W` | Navegador web (`zen-browser`) |
| `Mod+V` | Historial de portapapeles (`cliphist` + `fuzzel`) |
| `Mod+Alt+L` | Bloquear pantalla (`swaylock`) |
| `Mod+Shift+S` / `Ctrl+Shift+S` | Captura interactiva de pantalla (`screenshot`) |
| `XF86AudioRaiseVolume` / `Lower` | Subir / Bajar volumen (`wpctl`) |
| `XF86AudioMute` | Silenciar audio (`wpctl`) |

---

## 🚀 Despliegue e Instalación

Para sincronizar o reinstalar en cualquier sistema nuevo con CachyOS o Arch Linux:

```bash
cd ~/.config/quickshell/sane-shell
./install.sh
```
