#!/bin/bash
# ~/.claude/skills/ altindaki calisan kopyayi bu repoya aynala.
# Repo kokunden calistir: ./sync.sh
set -eu

REPO_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
SRC="$HOME/.claude/skills"
AGENTS="$HOME/.claude/agents"

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
find "$REPO_DIR/skills" -name '.patronaj' -type d -prune -exec rm -rf {} + 2>/dev/null || :

# Ajan tanimlari iki yerde yasiyor: skill icinde (kaynak, repoya giden) ve
# ~/.claude/agents/ icinde (Claude Code'un okudugu kurulu kopya). Ayrisirlarsa uyar.
DRIFT=0
for src_agent in "$REPO_DIR"/skills/*/agents/*.md; do
  [ -f "$src_agent" ] || continue
  installed="$AGENTS/$(basename "$src_agent")"
  if [ ! -f "$installed" ]; then
    echo "UYARI: $(basename "$src_agent") ~/.claude/agents/ altinda kurulu degil"
    DRIFT=1
  elif ! cmp -s "$src_agent" "$installed"; then
    echo "UYARI: $(basename "$src_agent") kurulu kopyadan FARKLI"
    echo "       kaynak:  $src_agent"
    echo "       kurulu:  $installed"
    DRIFT=1
  fi
done
[ "$DRIFT" -eq 1 ] && echo "       -> duzeltmek icin: cp <kaynak> ~/.claude/agents/"

echo
git -C "$REPO_DIR" status --short
