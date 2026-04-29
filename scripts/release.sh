#!/bin/bash
# release.sh — Compilar y desplegar ProsodIA al servidor OTA
# Ejecutar desde la raíz del proyecto en la máquina de desarrollo:
#   bash scripts/release.sh
#   bash scripts/release.sh --bump   # incrementa build number automáticamente

set -euo pipefail

OTA_HOST="root@laravas.com"
OTA_REMOTE_PATH="/root/apps/prosodia/ota/releases"
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
echo "▶ Compilando APK release..."
flutter build apk --release
echo "✅ APK generado: $APK_LOCAL"

# ── Subir APK al servidor OTA ─────────────────────────────────────────────────
echo "▶ Subiendo APK al servidor OTA..."
scp "$APK_LOCAL" "$OTA_HOST:$OTA_REMOTE_PATH/$APK_NAME"

# ── Actualizar version.json en el servidor ────────────────────────────────────
echo "▶ Actualizando version.json..."
CHANGELOG="${2:-Versión $VERSION}"
ssh "$OTA_HOST" "cat > $OTA_REMOTE_PATH/version.json" <<EOF
{
  "version": "$VERSION",
  "build": $BUILD,
  "url": "https://ota.laravas.com/$APK_NAME",
  "changelog": "$CHANGELOG"
}
EOF

echo ""
echo "🚀 Deploy completo:"
echo "   Versión: $VERSION (build $BUILD)"
echo "   APK:     https://ota.laravas.com/$APK_NAME"
echo "   Info:    https://ota.laravas.com/version.json"
