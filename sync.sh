#!/bin/bash
# ~/.claude/skills/ altindaki calisan kopyayi bu repoya aynala.
# Repo kokunden calistir: ./sync.sh
set -eu

REPO_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
SRC="$HOME/.claude/skills"

[ -d "$SRC" ] || { echo "hata: $SRC yok"; exit 1; }

for skill_path in "$REPO_DIR"/skills/*/; do
  [ -d "$skill_path" ] || continue
  name=$(basename "$skill_path")
  if [ ! -d "$SRC/$name" ]; then
    echo "atlandi: $name (yerelde kurulu degil)"
    continue
  fi
  rm -rf "$skill_path"
  cp -r "$SRC/$name" "$REPO_DIR/skills/$name"
  echo "aynalandi: $name"
done

# Yerel calisma artiklarini repoya tasima.
find "$REPO_DIR/skills" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || :
find "$REPO_DIR/skills" -name '.DS_Store' -type f -delete 2>/dev/null || :

echo
git -C "$REPO_DIR" status --short
