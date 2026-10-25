#!/usr/bin/env bash
set -e

THEME_FILE="$HOME/.cache/sane-shell-theme.json"
FUZZEL_CONFIG="$HOME/.config/fuzzel/fuzzel.ini"

TARGET_THEME="$1"
if [ -z "$TARGET_THEME" ]; then
    if [ -f "$THEME_FILE" ] && grep -q '"isDark":false' "$THEME_FILE"; then
        TARGET_THEME="dark"
    else
        TARGET_THEME="light"
    fi
fi

if [ "$TARGET_THEME" = "dark" ]; then
    IS_DARK=true
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    cat << 'EOF' > "$FUZZEL_CONFIG"
[main]
font=Inter:size=11
prompt="❯ "
terminal=kitty
lines=10
width=40
horizontal-pad=24
vertical-pad=16
inner-pad=8
image-size-ratio=0.5
line-height=24

[border]
width=2
radius=20

[colors]
background=1e1e2ef2
text=cdd6f4ff
match=b4befeff
selection=b4befeff
selection-text=11111bff
selection-match=11111bff
border=b4befeff
EOF
else
    IS_DARK=false
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
    cat << 'EOF' > "$FUZZEL_CONFIG"
[main]
font=Inter:size=11
prompt="❯ "
terminal=kitty
lines=10
width=40
horizontal-pad=24
vertical-pad=16
inner-pad=8
image-size-ratio=0.5
line-height=24

[border]
width=2
radius=20

[colors]
background=eff1f5dd
text=4c4f69ff
match=7287fdff
selection=bcc0ccff
selection-text=4c4f69ff
selection-match=7287fdff
border=7287fdff
EOF
fi

printf '{"isDark":%s}\n' "$IS_DARK" > "$THEME_FILE"
