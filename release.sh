#!/bin/sh
# Vydání pro ostatní: univerzální aplikace (Apple Silicon + Intel), macOS 12+, zabalená jako ZIP a DMG.
# Výsledek: dist/Julie-<verze>.zip a dist/Julie-<verze>.dmg
# Sestavuje se v dočasné složce mimo Plochu: iCloud přidává k souborům metadata
# („Finder information“) a s nimi codesign aplikaci nepodepíše.
set -e
cd "$(dirname "$0")"
VERZE="${1:-1.0}"
DIST="dist"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
APP="$OUT/Julie.app"
rm -rf "$DIST"
mkdir -p "$DIST" "$APP/Contents/MacOS" "$APP/Contents/Resources/sprity" "$OUT/tmp"
for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$ARCH-apple-macos12.0" -framework Cocoa -framework QuartzCore -framework Carbon \
    Sources/*.swift -o "$OUT/tmp/Julie-$ARCH"
done
lipo -create "$OUT/tmp/Julie-arm64" "$OUT/tmp/Julie-x86_64" -output "$APP/Contents/MacOS/Julie"
rm -rf "$OUT/tmp"
cp art/sprity/*.png "$APP/Contents/Resources/sprity/"
# ikona aplikace: Julie (stojící snímek zvětšený nejbližším sousedem)
if python3 -c "import PIL" 2>/dev/null; then
  python3 - "$APP/Contents/Resources/Julie.icns" <<'PY'
import os, sys, shutil, subprocess, tempfile
from PIL import Image
src = Image.open("art/sprity/stoji.png").convert("RGBA")
d = tempfile.mkdtemp(); iconset = os.path.join(d, "Julie.iconset"); os.makedirs(iconset)
for base in (16, 32, 128, 256, 512):
    for sc in (1, 2):
        n = base * sc
        k = max(1, int(n * 0.9 / src.width))
        big = src.resize((src.width * k, src.height * k), Image.NEAREST)
        if big.width > n:
            big = src.resize((n, max(1, round(src.height * n / src.width))), Image.NEAREST)
        c = Image.new("RGBA", (n, n), (0, 0, 0, 0)); c.alpha_composite(big, ((n - big.width) // 2, (n - big.height) // 2))
        c.save(os.path.join(iconset, f"icon_{base}x{base}" + ("@2x" if sc == 2 else "") + ".png"))
subprocess.run(["iconutil", "-c", "icns", iconset, "-o", sys.argv[1]], check=True)
shutil.rmtree(d)
PY
fi
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Julie</string>
<key>CFBundleDisplayName</key><string>Julie</string>
<key>CFBundleIdentifier</key><string>cz.karelhlas.julie</string>
<key>CFBundleExecutable</key><string>Julie</string>
<key>CFBundleIconFile</key><string>Julie</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>$VERZE</string>
<key>CFBundleShortVersionString</key><string>$VERZE</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>cs</string><string>en</string><string>de</string><string>sk</string><string>pl</string></array>
</dict></plist>
PLIST
# podpis bez vývojářského účtu (ad hoc): bez něj macOS staženou aplikaci hlásí jako poškozenou
xattr -cr "$APP"
codesign -s - --force "$APP" || { echo "Podpis selhal – nevydávám."; exit 1; }
codesign --verify --strict "$APP" || { echo "Podpis nesedí – nevydávám."; exit 1; }
"$APP/Contents/MacOS/Julie" --test >/dev/null || { echo "Samotest neprošel – nevydávám."; exit 1; }
( cd "$OUT" && ditto -c -k --keepParent Julie.app "Julie-$VERZE.zip" )
DMGDIR="$OUT/dmg"; mkdir -p "$DMGDIR"; ditto "$APP" "$DMGDIR/Julie.app"; ln -s /Applications "$DMGDIR/Applications"
hdiutil create -volname "Julie" -srcfolder "$DMGDIR" -ov -format UDZO "$OUT/Julie-$VERZE.dmg" >/dev/null 2>&1
# kontrola hotového DMG: aplikace v něm musí být podepsaná
MNT="$OUT/mnt"; mkdir -p "$MNT"
hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$OUT/Julie-$VERZE.dmg" >/dev/null 2>&1
codesign --verify --strict "$MNT/Julie.app" || { hdiutil detach "$MNT" >/dev/null 2>&1; echo "Aplikace v DMG není podepsaná – nevydávám."; exit 1; }
hdiutil detach "$MNT" >/dev/null 2>&1
cp "$OUT/Julie-$VERZE.zip" "$OUT/Julie-$VERZE.dmg" "$DIST/"
lipo -info "$APP/Contents/MacOS/Julie"
echo "Podpis: ad hoc, ověřený (i v DMG)."
ls -lh "$DIST"
