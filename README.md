# sane-shell 🚀

> **Ultralight Wayland Desktop Shell for Niri**
> Android 16 (*Material 3 Expressive* / Google Pixel UI) + Catppuccin Palette (Mocha & Latte).
> Construido sobre **Quickshell (Qt6 QML)** y **Go (`agy-tool`)**.

---

## ✨ Características Principales

- **Consumo Ultraliviano:** ~49 MB de RAM (reducción del **95%** frente a los ~1.1 GB del shell anterior) y **0.0% de CPU en reposo**.
- **Identidad Visual Android 16 (Pixel UI):**
  - Barra superior de **30px** borde a borde con píldoras de estado redondeadas (`height: 22`, `radius: 11`).
  - Workspaces estilo Pixel con animación elástica suave al cambiar de escritorio.
  - Quick Settings desplegable estilo Android 16 con tiles de 2 columnas, control deslizante de volumen PipeWire y selector de tema.
- **Paleta Oficial Catppuccin:**
  - **Mocha** (modo oscuro por defecto) y **Latte** (modo claro) con acentos **Lavender (`#b4befe` / `#7287fd`)** y **Blue (`#89b4fa` / `#1e66f5`)**.
  - Alternancia en vivo sincronizada entre shell, lanzador **Fuzzel** y temas de escritorio GNOME (`gsettings`).
- **Soporte Multi-Monitor Inteligente:**
  - **Monitor Principal (`DVI-D-1` / Horizontal):** Barra completa con Workspaces dinámicos + título de ventana activa, reloj central y calendario emergente, estadísticas de hardware (CPU, RAM, temperatura GPU AMD RX 570), widget de cuota de Antigravity / Gemini Web y bandeja del sistema / Quick Settings.
  - **Monitor Secundario (`HDMI-A-1` / Vertical):** Barra reducida enfocada en productividad (solo Workspaces de ese monitor y hora compacta).
- **Backend 100% en Go (`agy-tool`):**
  - Cero dependencias de Python en segundo plano.
  - Consultas de cuota y estado de Antigravity IDE con tiempo de respuesta `< 5 ms`.
  - Native Messaging Bridge compatible con extensiones WebExtensions de Zen Browser.
  - Control de foco instantáneo de ventanas vía IPC de Niri.

---

## 🛠️ Arquitectura del Proyecto

```text
~/.config/quickshell/sane-shell/
├── shell.qml                         # Punto de entrada: instancia TopBar por cada monitor
├── assets/
│   └── icons/                        # Iconos SVG de Antigravity y Gemini
├── scripts/
│   └── toggle-theme.sh               # Alterna Mocha/Latte y sincroniza Fuzzel y gsettings
├── go-agy-tool/
│   └── main.go                       # Binario Go: subcomandos quota, bridge, focus
├── modules/
│   ├── common/
│   │   ├── qmldir                    # Singletons Theme, Appearance, Translation
│   │   ├── Theme.qml                 # Tokens de color Catppuccin Mocha/Latte
│   │   ├── Appearance.qml            # Compatibilidad con widgets de cuota
│   │   ├── Translation.qml           # Motor de traducción ligero
│   │   └── widgets/                  # StyledPopup, StyledText, CustomIcon, RippleButton
│   ├── services/
│   │   ├── qmldir                    # Singletons NiriState y SystemStats
│   │   ├── NiriState.qml             # Workspaces y ventana activa vía IPC de Niri
│   │   └── SystemStats.qml           # Sensores de CPU, RAM, GPU RX 570 y PipeWire
│   └── bar/
│       ├── qmldir
│       ├── TopBar.qml                # Barra superior responsiva por monitor
│       ├── WorkspacesPill.qml        # Píldoras dinámicas estilo Pixel + título
│       ├── ClockPill.qml             # Reloj + Popup de calendario mensual
│       ├── HardwarePill.qml          # CPU% • RAM GB • GPU °C
│       ├── AgyUsage.qml              # Widget de cuotas de Antigravity
│       ├── AgyUsagePopup.qml         # Popup de cuotas detalladas (IDE + Zen Browser)
│       ├── SystemPill.qml            # SystemTray + Red + Audio% + Icono Tema
│       └── QuickSettingsPopup.qml    # Panel de control rápido Android 16
├── niri-configs/                     # Copia sincronizada de binds y autostart
├── install.sh                        # Script de instalación y despliegue automático
└── README.md
```

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

Para instalar o sincronizar en una máquina limpia con CachyOS o Arch Linux:

```bash
cd ~/.config/quickshell/sane-shell
./install.sh
```

El script compilará el binario en Go, configurará el servicio `systemd` del usuario (`sane-shell.service`) y activará la barra automáticamente.
