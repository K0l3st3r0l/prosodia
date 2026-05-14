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
# Esquema: 1.0.N+N — el último dígito de la versión y el build code son iguales
if [[ "${1:-}" == "--bump" ]]; then
  CURRENT_BUILD=$(grep "^version:" "$PUBSPEC" | grep -oP '\+\K[0-9]+')
  NEW_BUILD=$((CURRENT_BUILD + 1))
  MAJOR_MINOR=$(grep "^version:" "$PUBSPEC" | grep -oP '[\d]+\.[\d]+(?=\.)')
  sed -i "s/^version: .*/version: ${MAJOR_MINOR}.${NEW_BUILD}+${NEW_BUILD}/" "$PUBSPEC"
  echo "▶ Build bump: $CURRENT_BUILD → $NEW_BUILD"
fi

# ── Leer versión actual ────────────────────────────────────────────────────────
VERSION=$(grep "^version:" "$PUBSPEC" | grep -oP '[\d.]+(?=\+)')
BUILD=$(grep "^version:" "$PUBSPEC" | grep -oP '\+\K[0-9]+')
echo "▶ Versión: $VERSION+$BUILD"

# ── Build APK release ──────────────────────────────────────────────────────────
echo "▶ Compilando APK release (puede tardar 3-5 min)..."
flutter --suppress-analytics build apk --release 2>&1 | grep -v "Woah\|root\|superuser"
echo "✅ APK generado"

# ── Copiar APK al servidor OTA ────────────────────────────────────────────────
echo "▶ Publicando en OTA..."
# Guardar versión anterior para posible rollback
if [[ -f "$OTA_RELEASES/$APK_NAME" ]]; then
  cp "$OTA_RELEASES/$APK_NAME" "$OTA_RELEASES/prosodia-prev.apk"
  cp "$OTA_RELEASES/version.json" "$OTA_RELEASES/version-prev.json"
fi
cp "$APK_LOCAL" "$OTA_RELEASES/$APK_NAME"

# ── Actualizar version.json ───────────────────────────────────────────────────
CHANGELOG="${2:-Versión $VERSION}"
cat > "$OTA_RELEASES/version.json" <<EOF
{
  "version": "$VERSION",
  "build": $BUILD,
  "url": "https://ota.laravas.com/$APK_NAME?v=$BUILD",
  "changelog": "$CHANGELOG"
}
EOF

echo ""
echo "🚀 Deploy completo:"
echo "   Versión:  $VERSION (build $BUILD)"
echo "   APK:      https://ota.laravas.com/$APK_NAME"
echo "   Tamaño:   $(du -sh "$OTA_RELEASES/$APK_NAME" | cut -f1)"
echo "   Info:     https://ota.laravas.com/version.json"

# ── Git commit y push ─────────────────────────────────────────────────────────
echo ""
echo "▶ Commiteando cambios..."
git add pubspec.yaml ota/releases/version.json
git commit -m "release: v${VERSION} (build ${BUILD}) — ${CHANGELOG}"
git push origin main
echo "✅ Git actualizado → v${VERSION} (build ${BUILD})"
