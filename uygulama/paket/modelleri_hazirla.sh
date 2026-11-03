#!/bin/bash
# İndirilecek model dosyalarını hazırlar: paket/modeller/fotora-<model>-<sürüm>.zip ve SHA-256 değerleri.
# Dosyalar sunucuya (şimdilik bu Mac'teki deneme sunucusuna) konur; SHA-256 ve boyut Uygulama.swift'teki tabloya yazılır.
set -e
K="$(cd "$(dirname "$0")" && pwd)"; KESIF="$K/../../kesif"; C="$K/modeller"; S=1
mkdir -p "$C"
for m in so400m:coreml base:coreml_base; do
  ad=${m%%:*}; kaynak=${m##*:}
  G="${TMPDIR:-/tmp}/fotora-model-$ad"; rm -rf "$G"; mkdir "$G"
  rsync -a --exclude derlenmis --exclude "._*" "$KESIF/$kaynak/" "$G/"
  cp "$K/MODEL_LISANSI.txt" "$G/"   # Apache 2.0: lisans ağırlıklarla birlikte gider
  rm -f "$C/fotora-$ad-$S.zip"
  ditto -c -k --norsrc --noextattr "$G" "$C/fotora-$ad-$S.zip"; rm -rf "$G"
  echo "$ad  fotora-$ad-$S.zip  $(stat -f %z "$C/fotora-$ad-$S.zip")  $(shasum -a 256 "$C/fotora-$ad-$S.zip" | cut -d' ' -f1)"
done
