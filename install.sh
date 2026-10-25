#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
echo "==> Instalando sane-shell (Material 3 Expressive + Catppuccin Mocha)..."

# 1. Crear directorios base
mkdir -p "$HOME/.local/bin" "$HOME/.cache/sane-shell" "$HOME/.mozilla/native-messaging-hosts" "$HOME/.config/fuzzel"

# 2. Compilar herramientas en Go (agy-tool y niri-deck)
echo "==> Compilando agy-tool (Go)..."
cd "$SCRIPT_DIR/go-agy-tool"
go build -ldflags="-s -w" -o "$HOME/.local/bin/agy-tool" main.go
chmod +x "$HOME/.local/bin/agy-tool"

echo "==> Compilando niri-deck (Go - Material 3 Companion)..."
cd "$SCRIPT_DIR/go-niri-deck"
go build -ldflags="-s -w" -o "$HOME/.local/bin/niri-deck" main.go
chmod +x "$HOME/.local/bin/niri-deck"

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

# 5. Sincronizar configuración de Fuzzel
cp "$SCRIPT_DIR/niri-configs/fuzzel/fuzzel.ini" "$HOME/.config/fuzzel/fuzzel.ini"

# 6. Sincronizar tema inicial
"$SCRIPT_DIR/scripts/toggle-theme.sh" dark

# 7. Configurar e iniciar servicio niri-deck
mkdir -p "$HOME/.config/systemd/user"
cp "$SCRIPT_DIR/go-niri-deck/niri-deck.service" "$HOME/.config/systemd/user/niri-deck.service"
systemctl --user daemon-reload
systemctl --user enable --now niri-deck.service 2>/dev/null || true

echo "==> ¡sane-shell instalado y funcionando correctamente!"
