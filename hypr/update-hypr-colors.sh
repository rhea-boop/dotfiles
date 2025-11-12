#!/bin/bash
# This script converts noctalia's colors.json to a format hyprland, wofi, and alacritty can use

# --- Configuration ---
COLORS_JSON="/home/rhea/.config/noctalia/colors.json"
HYPR_COLORS_CONF="/home/rhea/.config/hypr/noctalia_colors.conf"
HYPR_COLORS_CONF_TMP="$HYPR_COLORS_CONF.tmp"
WOFI_STYLE_CSS="/home/rhea/.config/wofi/style.css"
KITTY_COLORS_CONF="/home/rhea/.config/kitty/noctalia_colors.conf"
MAKO_CONFIG="/home/rhea/.config/mako/config"
# Attempt to get the current wallpaper path from noctalia's settings
WALLPAPER_PATH=$(jq -r '.wallpaper.monitors[0].wallpaper' /home/rhea/.config/noctalia/settings.json 2>/dev/null)


# --- Helper Functions ---
hex_to_rgba() {
    local hex=$1
    local alpha=$2
    local r=$(printf "%d" "0x${hex:1:2}")
    local g=$(printf "%d" "0x${hex:3:2}")
    local b=$(printf "%d" "0x${hex:5:2}")
    echo "rgba($r, $g, $b, $alpha)"
}

brighten_hex_color() {
    local hex_color="$1"
    local increment="${2:-30}" # Default increment is 30
    hex_color="${hex_color#\#}"
    if [[ ! "$hex_color" =~ ^[0-9a-fA-F]{6}$ ]]; then
        echo "Error: Invalid hex color format." >&2
        return 1
    fi
    local r_hex="${hex_color:0:2}"
    local g_hex="${hex_color:2:2}"
    local b_hex="${hex_color:4:2}"
    local r_dec=$((16#$r_hex))
    local g_dec=$((16#$g_hex))
    local b_dec=$((16#$b_hex))
    r_dec=$((r_dec + increment))
    g_dec=$((g_dec + increment))
    b_dec=$((b_dec + increment))
    r_dec=$((r_dec > 255 ? 255 : r_dec))
    g_dec=$((g_dec > 255 ? 255 : g_dec))
    b_dec=$((b_dec > 255 ? 255 : b_dec))
    local new_r_hex=$(printf "%02X" "$r_dec")
    local new_g_hex=$(printf "%02X" "$g_dec")
    local new_b_hex=$(printf "%02X" "$b_dec")
    echo "#${new_r_hex}${new_g_hex}${new_b_hex}"
}


# --- Color Processing ---
mPrimary=$(jq -r '.mPrimary' "$COLORS_JSON")
mOnPrimary=$(jq -r '.mOnPrimary' "$COLORS_JSON")
mSecondary=$(jq -r '.mSecondary' "$COLORS_JSON")
mOnSecondary=$(jq -r '.mOnSecondary' "$COLORS_JSON")
mTertiary=$(jq -r '.mTertiary' "$COLORS_JSON")
mOnTertiary=$(jq -r '.mOnTertiary' "$COLORS_JSON")
mError=$(jq -r '.mError' "$COLORS_JSON")
mOnError=$(jq -r '.mOnError' "$COLORS_JSON")
mSurface=$(jq -r '.mSurface' "$COLORS_JSON")
mOnSurface=$(jq -r '.mOnSurface' "$COLORS_JSON")
mSurfaceVariant=$(jq -r '.mSurfaceVariant' "$COLORS_JSON")
mOnSurfaceVariant=$(jq -r '.mOnSurfaceVariant' "$COLORS_JSON")
mOutline=$(jq -r '.mOutline' "$COLORS_JSON")
mShadow=$(jq -r '.mShadow' "$COLORS_JSON")

# --- Theme Application ---

# Create Hyprland color file
{
  echo "\$noctalia_wallpaper = $WALLPAPER_PATH"
  echo "\$noctalia_primary = rgba($(echo $mPrimary | sed 's/#//')ff)"
  echo "\$noctalia_on_primary = rgba($(echo $mOnPrimary | sed 's/#//')ff)"
  echo "\$noctalia_secondary = rgba($(echo $mSecondary | sed 's/#//')ff)"
  echo "\$noctalia_on_secondary = rgba($(echo $mOnSecondary | sed 's/#//')ff)"
  echo "\$noctalia_tertiary = rgba($(echo $mTertiary | sed 's/#//')ff)"
  echo "\$noctalia_on_tertiary = rgba($(echo $mOnTertiary | sed 's/#//')ff)"
  echo "\$noctalia_error = rgba($(echo $mError | sed 's/#//')ff)"
  echo "\$noctalia_on_error = rgba($(echo $mOnError | sed 's/#//')ff)"
  echo "\$noctalia_surface = rgba($(echo $mSurface | sed 's/#//')ff)"
  echo "\$noctalia_on_surface = rgba($(echo $mOnSurface | sed 's/#//')ff)"
  echo "\$noctalia_surface_variant = rgba($(echo $mSurfaceVariant | sed 's/#//')ff)"
  echo "\$noctalia_on_surface_variant = rgba($(echo $mOnSurfaceVariant | sed 's/#//')ff)"
  echo "\$noctalia_outline = rgba($(echo $mOutline | sed 's/#//')ff)"
  echo "\$noctalia_shadow = rgba($(echo $mShadow | sed 's/#//')ff)"
} > "$HYPR_COLORS_CONF_TMP"

# Atomically move the new config into place to trigger Hyprland's file watcher
mv "$HYPR_COLORS_CONF_TMP" "$HYPR_COLORS_CONF"

# Create wofi stylesheet
cat <<EOF > "$WOFI_STYLE_CSS"
window {
    margin: 0px;
    border: 1px solid $(hex_to_rgba $mPrimary 0.8);
    background-color: $(hex_to_rgba $mSurface 0.8);
}
#input {
    margin: 5px;
    border: none;
    color: $mOnSurface;
    background-color: $(hex_to_rgba $mSurfaceVariant 0.8);
}
#inner-box, #outer-box {
    margin: 5px;
    border: none;
    background-color: $(hex_to_rgba $mSurface 0.8);
}
#scroll {
    margin: 0px;
    border: none;
}
#text {
    margin: 5px;
    border: none;
    color: $mOnSurface;
}
#entry.activatable #text {
    color: $mOnSecondary;
}
#entry > * {
    color: $mOnSurface;
}
#entry:selected {
    background-color: $(hex_to_rgba $mSecondary 0.8);
}
#entry:selected #text {
    font-weight: bold;
}
EOF

# Create Kitty color scheme
# Brighten dark colors for better visibility
color0_bright=$(brighten_hex_color "$mSurface" 120)
color5_bright=$(brighten_hex_color "$mOnPrimary" 120)
color6_bright=$(brighten_hex_color "$mOnSecondary" 120)
color8_bright=$(brighten_hex_color "$mSurfaceVariant" 120)

cat <<EOF > "$KITTY_COLORS_CONF"
# Colors (Noctalia)
foreground $mOnSurface
background $mSurface
cursor $mOnSurface
selection_foreground $mSurface
selection_background $mOnSurface

# Normal colors
color0 $color0_bright
color1 $mError
color2 $mTertiary
color3 $mSecondary
color4 $mPrimary
color5 $color5_bright
color6 $color6_bright
color7 $mOnSurface

# Bright colors
color8 $color8_bright
color9 $mError
color10 $mTertiary
color11 $mSecondary
color12 $mPrimary
color13 $color5_bright
color14 $color6_bright
color15 $mOnSurface

background_opacity 0.8
EOF

# Create Mako config
cat <<EOF > "$MAKO_CONFIG"
# Mako configuration file
# For more options, see \`man mako\`

# Appearance
font=monospace 10
border-radius=10
border-size=2

# Colors
background-color=$mSurface
text-color=$mOnSurface
border-color=$mPrimary

# Behavior
default-timeout=5000
EOF

makoctl reload

