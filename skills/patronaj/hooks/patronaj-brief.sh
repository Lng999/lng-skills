#!/bin/bash
# Patronaj: her oturum basinda protokol kartini baglama enjekte et.
# Patron modunu AKTIF ETMEZ - sadece protokolun varligini ve tetikleyicilerini hatirlatir.
# Kart metni skill'in yaninda durur; skill guncellenirse kart da guncellenir.
# Her hata durumunda sessizce exit 0: kanca oturumu asla bozmamali.

# Kart, betigin kendi konumuna gore aranir (skill baska bir yere kurulduysa da
# calissin); bulunamazsa varsayilan kurulum yoluna bakilir.
HOOK_DIR=$(CDPATH='' cd "$(dirname "$0")" 2>/dev/null && pwd)
CARD_FILE="$HOOK_DIR/../references/oturum-karti.md"
[ -f "$CARD_FILE" ] || CARD_FILE="$HOME/.claude/skills/patronaj/references/oturum-karti.md"
[ -f "$CARD_FILE" ] || exit 0

# Windows'ta python3 cogu zaman Store'un sahte kisayoludur; gercekten calisani sec.
PYBIN=""
for cand in python3 python; do
  if "$cand" -c 'import sys' >/dev/null 2>&1; then PYBIN=$cand; break; fi
done
[ -n "$PYBIN" ] || exit 0

"$PYBIN" - "$CARD_FILE" <<'PY' 2>/dev/null || exit 0
import json, sys

with open(sys.argv[1], "rb") as handle:
    text = handle.read().decode("utf-8-sig", "replace")

# Windows'ta CRLF ile checkout edilmis kart, baglama \r tasimasin.
text = text.replace("\r\n", "\n").strip()

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
