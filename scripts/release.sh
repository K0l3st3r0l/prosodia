#!/bin/bash
# release.sh — Compilar y desplegar ProsodIA al servidor OTA
# Ejecutar en el servidor desde la raíz del proyecto:
#   bash scripts/release.sh
#   bash scripts/release.sh --bump              # incrementa build number
#   bash scripts/release.sh --bump "Changelog"  # con mensaje de cambio

set -euo pipefail

export ANDROID_HOME=/opt/android-sdk
export PATH="$PATH:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/flutter/bin"

OTA_RELEASES="/root/apps/prosodia/ota/releases"
APK_LOCAL="build/app/outputs/flutter-apk/app-release.apk"
APK_NAME="prosodia-latest.apk"
PUBSPEC="pubspec.yaml"

# ── Bump build number ──────────────────────────────────────────────────────────
if [[ "${1:-}" == "--bump" ]]; then
  CURRENT_BUILD=$(grep "^version:" "$PUBSPEC" | grep -oP '\+\K[0-9]+')
  NEW_BUILD=$((CURRENT_BUILD + 1))
  VERSION=$(grep "^version:" "$PUBSPEC" | grep -oP '[\d.]+(?=\+)')
  sed -i "s/^version: .*/version: ${VERSION}+${NEW_BUILD}/" "$PUBSPEC"
  echo "▶ Build bump: $CURRENT_BUILD → $NEW_BUILD"
fi

# ── Leer versión actual ────────────────────────────────────────────────────────
VERSION=$(grep "^version:" "$PUBSPEC" | grep -oP '[\d.]+(?=\+)')
BUILD=$(grep "^version:" "$PUBSPEC" | grep -oP '\+\K[0-9]+')
echo "▶ Versión: $VERSION+$BUILD"

# ── Build APK release ──────────────────────────────────────────────────────────
echo "▶ Compilando APK release (puede tardar 3-5 min)..."
flutter --suppress-analytics build apk --release --target-platform android-arm64 2>&1 | grep -v "Woah\|root\|superuser"
echo "✅ APK generado"

# ── Copiar APK al servidor OTA ────────────────────────────────────────────────
echo "▶ Publicando en OTA..."
cp "$APK_LOCAL" "$OTA_RELEASES/$APK_NAME"

# ── Actualizar version.json ───────────────────────────────────────────────────
CHANGELOG="${2:-Versión $VERSION}"
cat > "$OTA_RELEASES/version.json" <<EOF
{
  "version": "$VERSION",
  "build": $BUILD,
  "url": "https://ota.laravas.com/$APK_NAME",
  "changelog": "$CHANGELOG"
}
EOF

echo ""
echo "🚀 Deploy completo:"
echo "   Versión:  $VERSION (build $BUILD)"
echo "   APK:      https://ota.laravas.com/$APK_NAME"
echo "   Tamaño:   $(du -sh "$OTA_RELEASES/$APK_NAME" | cut -f1)"
echo "   Info:     https://ota.laravas.com/version.json"
