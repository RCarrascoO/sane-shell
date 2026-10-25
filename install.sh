#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
echo "==> Instalando sane-shell (Material 3 Expressive + Catppuccin Mocha)..."

# 1. Crear directorios base
mkdir -p "$HOME/.local/bin" "$HOME/.cache/sane-shell" "$HOME/.mozilla/native-messaging-hosts" "$HOME/.config/fuzzel"

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

# 5. Sincronizar configuración de Fuzzel
cp "$SCRIPT_DIR/niri-configs/fuzzel/fuzzel.ini" "$HOME/.config/fuzzel/fuzzel.ini"

# 6. Sincronizar tema inicial
"$SCRIPT_DIR/scripts/toggle-theme.sh" dark

echo "==> ¡sane-shell instalado y funcionando correctamente!"
