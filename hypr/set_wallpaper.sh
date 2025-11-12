#!/bin/bash
set -euxo pipefail

# This script sets a wallpaper using awww, generates a color scheme with matugen,
# and applies the theme to Hyprland, Wofi, and Mako.

# --- Helper Functions ---
darken_hex_color() {
    local hex_color="$1"
    local decrement="${2:-30}" # Default decrement is 30

    hex_color="${hex_color#\#}"
    echo "DEBUG: darken_hex_color input hex_color: $hex_color" >&2

    if [[ ! "$hex_color" =~ ^[0-9a-fA-F]{6}$ ]]; then
        echo "Error: Invalid hex color format." >&2
        return 1
    fi

    local r_hex="${hex_color:0:2}"
    local g_hex="${hex_color:2:2}"
    local b_hex="${hex_color:4:2}"
    echo "DEBUG: darken_hex_color r_hex: $r_hex, g_hex: $g_hex, b_hex: $b_hex" >&2

    local r_dec=$((16#$r_hex))
    local g_dec=$((16#$g_hex))
    local b_dec=$((16#$b_hex))

    r_dec=$((r_dec - decrement))
    g_dec=$((g_dec - decrement))
    b_dec=$((b_dec - decrement))

    r_dec=$((r_dec < 0 ? 0 : r_dec))
    g_dec=$((g_dec < 0 ? 0 : g_dec))
    b_dec=$((b_dec < 0 ? 0 : b_dec))

    local new_r_hex=$(printf "%02X" "$r_dec")
    local new_g_hex=$(printf "%02X" "$g_dec")
    local new_b_hex=$(printf "%02X" "$b_dec")

    echo "#${new_r_hex}${new_g_hex}${new_b_hex}"
}

brighten_hex_color() {
    local hex_color="$1"
    local increment="${2:-30}" # Default increment is 30
    hex_color="${hex_color#\#}"
    echo "DEBUG: brighten_hex_color input hex_color: $hex_color" >&2
    if [[ ! "$hex_color" =~ ^[0-9a-fA-F]{6}$ ]]; then
        echo "Error: Invalid hex color format." >&2
        return 1
    fi
    local r_hex="${hex_color:0:2}"
    local g_hex="${hex_color:2:2}"
    local b_hex="${hex_color:4:2}"
    echo "DEBUG: brighten_hex_color r_hex: $r_hex, g_hex: $g_hex, b_hex: $b_hex" >&2
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

# --- Configuration ---
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
HYPR_COLORS_CONF="/home/rhea/.config/hypr/noctalia_colors.conf"
HYPR_COLORS_CONF_TMP="$HYPR_COLORS_CONF.tmp"
WOFI_STYLE_CSS="/home/rhea/.config/wofi/style.css"
MAKO_CONFIG="/home/rhea/.config/mako/config"
KITTY_COLORS_CONF="/home/rhea/.config/kitty/themes/noctalia_colors.conf"
MATUGEN_COLORS_JSON="/tmp/matugen_colors.json"
NOCTALIA_SETTINGS_JSON="/home/rhea/.config/noctalia/settings.json"

# Read Noctalia's matugen settings
MATUGEN_MODE=$(jq -r '.colorSchemes.darkMode | if . == true then "dark" else "light" end' "$NOCTALIA_SETTINGS_JSON")
MATUGEN_SCHEME_TYPE=$(jq -r '.colorSchemes.matugenSchemeType' "$NOCTALIA_SETTINGS_JSON")

# --- Wallpaper Selection ---
if [ -z "${1:-}" ]; then
    echo "Choosing random wallpaper from $WALLPAPER_DIR..."
    if [ ! -d "$WALLPAPER_DIR" ]; then echo "Error: Wallpaper directory does not exist." >&2; exit 1; fi

    CURRENT_WALLPAPER_PATH=""
    if [ -f "$HYPR_COLORS_CONF" ]; then
        CURRENT_WALLPAPER_PATH=$(grep '^\$noctalia_wallpaper' "$HYPR_COLORS_CONF" | sed 's/^\$noctalia_wallpaper = //')
    fi

    WALLPAPER_LIST=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \))

    if [ -n "$CURRENT_WALLPAPER_PATH" ]; then
        # Exclude the current wallpaper from the list
        NEW_WALLPAPER=$(echo "$WALLPAPER_LIST" | grep -vF "$CURRENT_WALLPAPER_PATH" | shuf -n 1)
    else
        NEW_WALLPAPER=$(echo "$WALLPAPER_LIST" | shuf -n 1)
    fi

    # If filtering left the list empty (e.g., only one wallpaper), just pick from the full list
    if [ -z "$NEW_WALLPAPER" ]; then
        NEW_WALLPAPER=$(echo "$WALLPAPER_LIST" | shuf -n 1)
    fi

    if [ -z "$NEW_WALLPAPER" ]; then echo "Error: No image files found in $WALLPAPER_DIR." >&2; exit 1; fi
else
    NEW_WALLPAPER="$1"
    if [ ! -f "$NEW_WALLPAPER" ]; then echo "Error: Not a valid file: $NEW_WALLPAPER" >&2; exit 1; fi
fi
echo "Selected wallpaper: $NEW_WALLPAPER"

# --- Wallpaper and Color Generation ---

# 1. Start awww-daemon if not running
if ! pgrep -x "awww-daemon" > /dev/null; then
    echo "Starting awww-daemon..."
    awww-daemon &
    sleep 0.5
fi

# 2. Set wallpaper with awww on all monitors
# The user specified DP-3 and HDMI-A-1. Applying to all is the most robust.
awww img "$NEW_WALLPAPER" --transition-type random --transition-step 90 --transition-duration 1.5 --transition-fps 144

# 3. Generate colors with matugen
echo "Generating color scheme with matugen..."
# We assume '--json hex' provides a simple key-value JSON of the Material You palette.
matugen image "$NEW_WALLPAPER" --mode "$MATUGEN_MODE" --type "$MATUGEN_SCHEME_TYPE" --json hex > "$MATUGEN_COLORS_JSON"
if [ $? -ne 0 ] || [ ! -s "$MATUGEN_COLORS_JSON" ]; then
    echo "Error: matugen command failed or produced an empty file." >&2
    exit 1
fi

# --- Theme Application ---

echo "Applying themes to Hyprland, Wofi, and Mako..."

# 4. Read colors from the generated JSON
#    The JSON is nested, so we access the dark theme colors via .colors.<role>.dark
mPrimary=$(jq -r '.colors.primary.dark' "$MATUGEN_COLORS_JSON")
mOnPrimary=$(jq -r '.colors.on_primary.dark' "$MATUGEN_COLORS_JSON")
mSecondary=$(jq -r '.colors.secondary.dark' "$MATUGEN_COLORS_JSON")
mOnSecondary=$(jq -r '.colors.on_secondary.dark' "$MATUGEN_COLORS_JSON")
mTertiary=$(jq -r '.colors.tertiary.dark' "$MATUGEN_COLORS_JSON")
mOnTertiary=$(jq -r '.colors.on_tertiary.dark' "$MATUGEN_COLORS_JSON")
mError=$(jq -r '.colors.error.dark' "$MATUGEN_COLORS_JSON")
mOnError=$(jq -r '.colors.on_error.dark' "$MATUGEN_COLORS_JSON")
mSurface=$(jq -r '.colors.surface.dark' "$MATUGEN_COLORS_JSON")
mOnSurface=$(jq -r '.colors.on_surface.dark' "$MATUGEN_COLORS_JSON")
mSurfaceVariant=$(jq -r '.colors.surface_variant.dark' "$MATUGEN_COLORS_JSON")
mOnSurfaceVariant=$(jq -r '.colors.on_surface_variant.dark' "$MATUGEN_COLORS_JSON")
mOutline=$(jq -r '.colors.outline.dark' "$MATUGEN_COLORS_JSON")
mShadow=$(jq -r '.colors.shadow.dark' "$MATUGEN_COLORS_JSON")

# Darken the surface variant color for the bar background
mSurfaceVariant=$(darken_hex_color "$mSurfaceVariant" 50)

# Check if colors were extracted successfully
if [ -z "$mPrimary" ]; then
    echo "Error: Could not extract colors from matugen's JSON output." >&2
    echo "Please check the format of $MATUGEN_COLORS_JSON" >&2
    exit 1
fi

# --- Noctalia Integration ---
echo "Updating Noctalia configuration..."

# 5a. Create Noctalia colors.json
#     We use mTertiary and mOnTertiary for mHover and mOnHover as a default.
NOCTALIA_COLORS_JSON="/home/rhea/.config/noctalia/colors.json"
cat <<EOF > "$NOCTALIA_COLORS_JSON"
{
  "mPrimary": "$mPrimary",
  "mOnPrimary": "$mOnPrimary",
  "mSecondary": "$mSecondary",
  "mOnSecondary": "$mOnSecondary",
  "mTertiary": "$mTertiary",
  "mOnTertiary": "$mOnTertiary",
  "mError": "$mError",
  "mOnError": "$mOnError",
  "mSurface": "$mSurface",
  "mOnSurface": "$mOnSurface",
  "mSurfaceVariant": "$mSurfaceVariant",
  "mOnSurfaceVariant": "$mOnSurfaceVariant",
  "mOutline": "$mOutline",
  "mShadow": "$mShadow",
  "mHover": "$mTertiary",
  "mOnHover": "$mOnTertiary"
}
EOF

# 5b. Update Noctalia settings.json
NOCTALIA_SETTINGS_JSON="/home/rhea/.config/noctalia/settings.json"
NOCTALIA_SETTINGS_JSON_TMP="$NOCTALIA_SETTINGS_JSON.tmp"

# Use jq to update the wallpaper path for all monitors and clear the hook
jq ".wallpaper.monitors |= map(.wallpaper = \"$NEW_WALLPAPER\") | .hooks.wallpaperChange = \"\"" \
   "$NOCTALIA_SETTINGS_JSON" > "$NOCTALIA_SETTINGS_JSON_TMP" && \
   mv "$NOCTALIA_SETTINGS_JSON_TMP" "$NOCTALIA_SETTINGS_JSON"

if [ $? -ne 0 ]; then
    echo "Error: Failed to update Noctalia settings." >&2
    # Clean up temp file
    rm -f "$NOCTALIA_SETTINGS_JSON_TMP"
    exit 1
fi

# --- Theme Application ---

echo "Applying themes to Hyprland, Wofi, and Mako..."

# 5. Create the hyprland color file
{
  echo "\$noctalia_wallpaper = $NEW_WALLPAPER"
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

# Atomically move the new config to trigger Hyprland's file watcher
mv "$HYPR_COLORS_CONF_TMP" "$HYPR_COLORS_CONF"

# 6. Helper function to convert hex to rgba for Wofi
hex_to_rgba() {
    local hex=$1
    local alpha=$2
    local r=$(printf "%d" "0x${hex:1:2}")
    local g=$(printf "%d" "0x${hex:3:2}")
    local b=$(printf "%d" "0x${hex:5:2}")
    echo "rgba($r, $g, $b, $alpha)"
}

# 7. Create Wofi stylesheet with the exact original CSS
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

# 8. Create Mako config
cat <<EOF > "$MAKO_CONFIG"
# Mako configuration file
font=monospace 10
border-radius=10
border-size=2
background-color=$mSurface
text-color=$mOnSurface
border-color=$mPrimary
default-timeout=5000
EOF

makoctl reload

# Create Kitty color scheme
cat <<EOF > "$KITTY_COLORS_CONF"
# Colors (Noctalia)
foreground $mOnSurface
background $mSurface
cursor $mOnSurface
selection_foreground $mOnSurfaceVariant
selection_background $mSurfaceVariant

# Normal colors
color0 $mSurface
color1 $mError
color2 $mTertiary
color3 $mSecondary
color4 $mPrimary
color5 $(darken_hex_color "$mTertiary" 30)
color6 $(darken_hex_color "$mSecondary" 30)
color7 $mOnSurface

# Bright colors
color8 $mOutline
color9 $mError
color10 $mTertiary
color11 $mSecondary
color12 $mPrimary
color13 $(darken_hex_color "$mTertiary" 30)
color14 $(darken_hex_color "$mSecondary" 30)
color15 $mOnSurface

background_opacity 0.8
cursor_text_color $mSurface
url_color $mPrimary
EOF

echo "DEBUG: Listing generated Kitty config file:"
ls -l "$KITTY_COLORS_CONF"
echo "DEBUG: Content of generated Kitty config file:"
cat "$KITTY_COLORS_CONF"

cp "$KITTY_COLORS_CONF" "/home/rhea/.config/kitty/current-theme.conf"
pkill -USR1 kitty
echo "Wallpaper and themes updated successfully!"
