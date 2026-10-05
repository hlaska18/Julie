#!/bin/sh
# Zapne sledování Claude Code: přidá háčky do ~/.claude/settings.json (záloha: settings.json.julie-zaloha).
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HOME/.jezevcik"
cp "$DIR/hook.sh" "$HOME/.jezevcik/hook.sh"
chmod +x "$HOME/.jezevcik/hook.sh"
python3 - <<'PY'
import json, os, shutil
p = os.path.expanduser("~/.claude/settings.json")
data = {}
if os.path.exists(p):
    shutil.copy(p, p + ".julie-zaloha")
    data = json.load(open(p))
hooks = data.setdefault("hooks", {})
def add(event, arg):
    cmd = os.path.expanduser("~/.jezevcik/hook.sh") + " " + arg
    lst = hooks.setdefault(event, [])
    for g in lst:
        for h in g.get("hooks", []):
            if "jezevcik/hook.sh" in h.get("command", ""):
                h["command"] = cmd
                return
    lst.append({"matcher": "", "hooks": [{"type": "command", "command": cmd}]})
add("UserPromptSubmit", "prompt")
add("PreToolUse", "pre")
add("Notification", "notify")
add("Stop", "stop")
json.dump(data, open(p, "w"), indent=2, ensure_ascii=False)
print("Hotovo. Spusť Claude Code znovu, ať si háčky načte.")
PY
