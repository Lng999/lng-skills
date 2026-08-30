#!/bin/bash
# Patronaj: her oturum basinda protokol kartini baglama enjekte et.
# Patron modunu AKTIF ETMEZ - sadece protokolun varligini ve tetikleyicilerini hatirlatir.
# Kart metni skill'in yaninda durur; skill guncellenirse kart da guncellenir.

CARD_FILE="$HOME/.claude/skills/patronaj/references/oturum-karti.md"
[ -f "$CARD_FILE" ] || exit 0

command -v python3 >/dev/null 2>&1 || exit 0

python3 - "$CARD_FILE" <<'PY' 2>/dev/null || exit 0
import json, sys

with open(sys.argv[1], "rb") as handle:
    text = handle.read().decode("utf-8", "replace").strip()

if not text:
    raise SystemExit(0)

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": text,
    }
}))
PY
exit 0
