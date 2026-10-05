#!/bin/sh
# Sestaví Julie.app a Pelíšek.app (stačí Command Line Tools, Xcode není potřeba)
# a nainstaluje je do ~/Applications (Plocha se synchronizuje přes iCloud a ten by mohl
# aplikaci odsunout do cloudu – pak by se po přihlášení nespustila).
#
# Sestavuje se bokem do build/; funkční aplikace se nahradí až po úspěšném překladu
# a předchozí verze zůstane jako build/Julie-predchozi.app.
set -e
cd "$(dirname "$0")"
BUILD="build"
NEW="$BUILD/Julie.app"
rm -rf "$NEW"
mkdir -p "$NEW/Contents/MacOS" "$NEW/Contents/Resources/sprity"
swiftc -O -swift-version 5 -framework Cocoa -framework QuartzCore -framework Carbon Sources/*.swift -o "$NEW/Contents/MacOS/Julie"
cp art/sprity/*.png "$NEW/Contents/Resources/sprity/"
cat > "$NEW/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Julie</string>
<key>CFBundleDisplayName</key><string>Julie</string>
<key>CFBundleIdentifier</key><string>cz.karelhlas.julie</string>
<key>CFBundleExecutable</key><string>Julie</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF
codesign -s - --force "$NEW" >/dev/null 2>&1 || true

# Pelíšek: malá pomocná aplikace (ikona do Docku, teď nepoužitá, ale funkční)
BED="$BUILD/Pelíšek.app"
mkdir -p "$BED/Contents/MacOS" "$BED/Contents/Resources"
swiftc -O -swift-version 5 -framework Cocoa Pelisek/main.swift -o "$BED/Contents/MacOS/Pelisek"
if python3 -c "import PIL" 2>/dev/null; then
  python3 art/pelisek/ikona.py art/pelisek/seda1.png "$BED/Contents/Resources/Pelisek.icns"
else
  echo "Upozornění: chybí Pillow (pip3 install pillow) – Pelíšek je bez ikony, řezání obrázků (art/*.py) nepůjde."
fi
cat > "$BED/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Pelíšek</string>
<key>CFBundleDisplayName</key><string>Pelíšek</string>
<key>CFBundleIdentifier</key><string>cz.karelhlas.julie.pelisek</string>
<key>CFBundleExecutable</key><string>Pelisek</string>
<key>CFBundleIconFile</key><string>Pelisek</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
EOF
codesign -s - --force "$BED" >/dev/null 2>&1 || true

# překlad prošel: záloha předchozí verze, pak výměna (i ve složce projektu kvůli --sim)
DEST="$HOME/Applications"
mkdir -p "$DEST"
if [ -d "$DEST/Julie.app" ]; then rm -rf "$BUILD/Julie-predchozi.app"; ditto "$DEST/Julie.app" "$BUILD/Julie-predchozi.app"; fi
rm -rf "$DEST/Julie.app.nova"; ditto "$NEW" "$DEST/Julie.app.nova"
rm -rf "$DEST/Julie.app"; mv "$DEST/Julie.app.nova" "$DEST/Julie.app"
rm -rf "$DEST/Pelíšek.app"; ditto "$BED" "$DEST/Pelíšek.app"
rm -rf Julie.app Pelíšek.app; ditto "$NEW" Julie.app; ditto "$BED" Pelíšek.app
echo "Hotovo: $DEST/Julie.app (a Pelíšek.app); záloha předchozí: $BUILD/Julie-predchozi.app"
