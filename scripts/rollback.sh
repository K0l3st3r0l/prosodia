#!/bin/bash
# rollback.sh — Revertir al APK anterior en caso de error grave
# Ejecutar desde la raíz del proyecto: bash scripts/rollback.sh

set -euo pipefail

OTA_RELEASES="/root/apps/prosodia/ota/releases"

if [[ ! -f "$OTA_RELEASES/prosodia-prev.apk" ]]; then
  echo "❌ No hay versión anterior disponible para rollback"
  exit 1
fi

PREV_VERSION=$(grep '"version"' "$OTA_RELEASES/version-prev.json" | grep -oP '"\K[^"]+(?=",[^"]*$)' || grep -oP '"version":\s*"\K[^"]+' "$OTA_RELEASES/version-prev.json")
PREV_BUILD=$(grep -oP '"build":\s*\K[0-9]+' "$OTA_RELEASES/version-prev.json")

echo "▶ Versión actual:   $(grep -oP '"version":\s*"\K[^"]+' "$OTA_RELEASES/version.json") (build $(grep -oP '"build":\s*\K[0-9]+' "$OTA_RELEASES/version.json"))"
echo "▶ Versión anterior: $PREV_VERSION (build $PREV_BUILD)"
echo ""
read -p "¿Confirmar rollback a $PREV_VERSION? [s/N] " confirm
[[ "$confirm" != "s" && "$confirm" != "S" ]] && echo "Cancelado." && exit 0

cp "$OTA_RELEASES/prosodia-prev.apk" "$OTA_RELEASES/prosodia-latest.apk"
cp "$OTA_RELEASES/version-prev.json" "$OTA_RELEASES/version.json"

echo ""
echo "✅ Rollback completado → versión $PREV_VERSION (build $PREV_BUILD)"
echo "   Los tablets recibirán esta versión en la próxima actualización"
