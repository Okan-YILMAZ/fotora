#!/bin/bash
# Fotora testleri: uygulama çekirdeği (fotora-test) ve eklenti sözdizimi. Her değişiklikten sonra çalıştırın.
# Kullanım: ./test.sh [model klasörü]  (varsayılan: geliştirme kopyası ../kesif/coreml)
set -e
K="$(cd "$(dirname "$0")" && pwd)"; M="${1:-$K/../kesif/coreml}"
cd "$K" && swift build -c release --product fotora-test 2>&1 | grep -E "error|Build comp"
for f in "$K"/../eklenti/Fotora.lrplugin/*.lua; do luac -p "$f" || { echo "✗ Lua sözdizimi: $f"; exit 1; }; done
echo "✓ eklenti Lua sözdizimi"
"$K/.build/release/fotora-test" "$M"
