#!/bin/sh
# Vypne sledování: odebere háčky Julie z ~/.claude/settings.json.
python3 - <<'PY'
import json, os
p = os.path.expanduser("~/.claude/settings.json")
if not os.path.exists(p):
    raise SystemExit("settings.json nenalezen")
data = json.load(open(p))
hooks = data.get("hooks", {})
for ev in list(hooks):
    hooks[ev] = [g for g in hooks[ev] if not any("jezevcik/hook.sh" in h.get("command", "") for h in g.get("hooks", []))]
    if not hooks[ev]:
        del hooks[ev]
if not hooks:
    data.pop("hooks", None)
json.dump(data, open(p, "w"), indent=2, ensure_ascii=False)
print("Háčky Julie odebrány.")
PY
