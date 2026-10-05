#!/bin/sh
# Odebere ikonu Pelíšek z Docku (Dock se krátce restartuje). Pelíšek vedle Docku zůstává.
python3 - <<'PY'
import plistlib, subprocess, urllib.parse
raw = subprocess.run(["defaults", "export", "com.apple.dock", "-"], capture_output=True, check=True).stdout
d = plistlib.loads(raw)
def je_pelisek(a):
    td = a.get("tile-data", {})
    if td.get("bundle-identifier") == "cz.karelhlas.julie.pelisek":
        return True
    url = urllib.parse.unquote(td.get("file-data", {}).get("_CFURLString", ""))
    return "Pelíšek.app" in url
pred = len(d.get("persistent-apps", []))
d["persistent-apps"] = [a for a in d.get("persistent-apps", []) if not je_pelisek(a)]
if len(d["persistent-apps"]) == pred:
    print("Pelíšek v Docku není.")
    raise SystemExit(1)
subprocess.run(["defaults", "import", "com.apple.dock", "-"], input=plistlib.dumps(d), check=True)
print("Pelíšek odebrán z Docku.")
PY
[ $? -eq 0 ] && killall Dock
exit 0
