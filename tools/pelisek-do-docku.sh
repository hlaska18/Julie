#!/bin/sh
# Přidá ikonu Pelíšek na konec aplikací v Docku (Dock se krátce restartuje).
APP="$(cd "$(dirname "$0")/.." && pwd)/Pelíšek.app"
[ -d "$APP" ] || { echo "Nejdřív ./build.sh"; exit 1; }
if defaults export com.apple.dock - | grep -q "cz.karelhlas.julie.pelisek\|Pel%C3%AD%C5%A1ek.app"; then
  echo "Pelíšek už v Docku je."
  exit 0
fi
URL=$(python3 -c 'import sys, pathlib; print(pathlib.Path(sys.argv[1]).as_uri() + "/")' "$APP")
defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$URL</string><key>_CFURLStringType</key><integer>15</integer></dict></dict><key>tile-type</key><string>file-tile</string></dict>"
killall Dock
echo "Pelíšek přidán do Docku."
