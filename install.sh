#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
echo "==> Instalando sane-shell..."

# 1. Crear directorios base
mkdir -p "$HOME/.local/bin" "$HOME/.cache/sane-shell" "$HOME/.config/systemd/user" "$HOME/.mozilla/native-messaging-hosts"

# 2. Compilar agy-tool en Go
echo "==> Compilando agy-tool (Go)..."
cd "$SCRIPT_DIR/go-agy-tool"
go build -ldflags="-s -w" -o "$HOME/.local/bin/agy-tool" main.go
chmod +x "$HOME/.local/bin/agy-tool"

# 3. Crear wrapper de native messaging
cat << 'EOF' > "$HOME/.local/bin/agy-gemini-bridge"
#!/usr/bin/env bash
exec /home/sane/.local/bin/agy-tool bridge
EOF
chmod +x "$HOME/.local/bin/agy-gemini-bridge"

# 4. Configurar bridge para Zen Browser
cat << 'EOF' > "$HOME/.mozilla/native-messaging-hosts/inir_gemini_bridge.json"
{
  "name": "inir_gemini_bridge",
  "description": "Bridge between Gemini Web extension and Inir desktop bar",
  "path": "/home/sane/.local/bin/agy-gemini-bridge",
  "type": "stdio",
  "allowed_extensions": [
    "inir-gemini-bridge@sane.local"
  ]
}
EOF

# 5. Configurar systemd unit
cat << 'EOF' > "$HOME/.config/systemd/user/sane-shell.service"
[Unit]
Description=sane-shell (Android 16 Pixel UI + Catppuccin)
PartOf=niri.service
After=niri.service
Before=xdg-desktop-autostart.target

[Service]
Type=simple
Environment=QT_SCALE_FACTOR=1
Environment=QT_SCALE_FACTOR_ROUNDING_POLICY=RoundPreferFloor
Environment=QT_LOGGING_RULES=quickshell.dbus.properties=false;qt.qpa.wayland.textinput.warning=false
ExecStart=/usr/bin/quickshell -c sane-shell
Restart=always
RestartSec=2
KillMode=process

[Install]
WantedBy=niri.service
EOF

# 6. Habilitar e iniciar servicio
systemctl --user daemon-reload
systemctl --user enable --now sane-shell.service || true

# 7. Sincronizar tema inicial
"$SCRIPT_DIR/scripts/toggle-theme.sh" dark

echo "==> ¡sane-shell instalado y funcionando correctamente!"
