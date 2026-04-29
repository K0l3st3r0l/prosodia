#!/bin/bash
# update-version.sh — Actualizar version.json en el servidor OTA sin recompilar
# Uso (en el servidor): bash scripts/update-version.sh 1.0.1 2 "Mejoras en la pantalla de evaluación"

set -euo pipefail

RELEASES_DIR="/root/apps/prosodia/ota/releases"
VERSION="${1:?Uso: $0 <version> <build> [changelog]}"
BUILD="${2:?Uso: $0 <version> <build> [changelog]}"
CHANGELOG="${3:-Versión $VERSION}"

cat > "$RELEASES_DIR/version.json" <<EOF
{
  "version": "$VERSION",
  "build": $BUILD,
  "url": "https://ota.laravas.com/prosodia-latest.apk",
  "changelog": "$CHANGELOG"
}
EOF

echo "✅ version.json actualizado: $VERSION+$BUILD"
cat "$RELEASES_DIR/version.json"
