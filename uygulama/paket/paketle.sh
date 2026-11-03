#!/bin/bash
# Fotora.app'i oluşturur (imzasız, yalnız yerel imza): uygulama/paket/Fotora.app
set -e
K="$(cd "$(dirname "$0")" && pwd)"; U="$K/.."; E="$U/../eklenti/Fotora.lrplugin"
cd "$U" && swift build -c release --product Fotora
A="$K/Fotora.app"; rm -rf "$A"; mkdir -p "$A/Contents/MacOS" "$A/Contents/Resources"
cp .build/release/Fotora "$A/Contents/MacOS/"
cp -R "$E" "$A/Contents/Resources/"
cp "$U/../LICENSE" "$U/../NOTICE" "$A/Contents/Resources/"   # Apache 2.0: lisans ve atıflar uygulamayla gider
I="$K/simge.iconset"; rm -rf "$I"; mkdir "$I"
for b in 16 32 128 256 512; do
  swift "$K/simge.swift" "$I/icon_${b}x${b}.png" $b
  swift "$K/simge.swift" "$I/icon_${b}x${b}@2x.png" $((b*2))
done
iconutil -c icns "$I" -o "$A/Contents/Resources/Fotora.icns"; rm -rf "$I"
cat > "$A/Contents/Info.plist" <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Fotora</string>
<key>CFBundleDisplayName</key><string>Fotora</string>
<key>CFBundleIdentifier</key><string>com.fotora.app</string>
<key>CFBundleExecutable</key><string>Fotora</string>
<key>CFBundleIconFile</key><string>Fotora</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>CFBundleDevelopmentRegion</key><string>tr</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
P
codesign --force --deep -s - "$A"
# Finder simgeyi önbellekten göstermesin: paket her seferinde yeniden kurulduğu için kaydı yenile
touch "$A"; /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$A"
echo "hazır: $A"

# İndirilecek disk görüntüsü: Fotora.app ve Uygulamalar kısayolu (sürükle-bırak kurulum).
# İmzasız: Apple imzası alınmayacak (Okan, 3 Kasım 2026); kullanıcı ilk açılışta Open Anyway der.
if [ "${1:-}" = "--dmg" ]; then
  S="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$A/Contents/Info.plist")"
  G="$K/dmg-hazirlik"; rm -rf "$G"; mkdir "$G"
  cp -R "$A" "$G/"; ln -s /Applications "$G/Applications"
  # Modeller pakette değil: kurulumda indirilir (paket/modelleri_hazirla.sh, Uygulama.modelAdresi).
  cp "$K/Once_Oku-Read_Me.txt" "$G/Önce Oku - Read Me.txt"
  cp "$U/../LICENSE" "$U/../NOTICE" "$G/"
  rm -f "$K/Fotora-$S.dmg"
  hdiutil create -volname "Fotora $S" -srcfolder "$G" -ov -format UDZO "$K/Fotora-$S.dmg" >/dev/null
  rm -rf "$G"
  echo "disk görüntüsü: $K/Fotora-$S.dmg"
fi
