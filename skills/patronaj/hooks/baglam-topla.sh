#!/bin/bash
# Patronaj brief'inin BAGLAM blogunun mekanik yarisini toplar.
#
#   baglam-topla.sh <dosya> [dosya...] [--sembol <isim>]
#
# Uretir: proje tipi, paket yoneticisi, test/build komutlari, repo durumu ve her hedef
# dosya icin boyut + son 3 commit. --sembol verilirse o sembolun tanim yerlerini de bulur.
# Cikti dogrudan brief'in "## BAGLAM" blogu altina yapistirilmak icin bicimlendirilmistir.
#
# Amac: Patron'un iyi bir brief yazmak icin dosya okumak zorunda kalmamasi -
# okuma ana baglami yakar, bu betik yakmaz.

set -u

FILES=""
SYMBOL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --sembol) SYMBOL=${2:-}; shift 2 || shift ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
    *) FILES="$FILES $1"; shift ;;
  esac
done

[ -n "${FILES# }" ] || { echo "kullanim: baglam-topla.sh <dosya...> [--sembol <isim>]"; exit 2; }

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "hata: git deposu icinde degilsin"; exit 2; }
cd "$ROOT" || exit 2

say() { printf '%s\n' "$*"; }

# --- proje tipi ve komutlar ---------------------------------------------------
PROJE="bilinmiyor"
PM=""
KOMUTLAR=""

if [ -f package.json ]; then
  PROJE="Node/JS"
  if   [ -f pnpm-lock.yaml ];    then PM="pnpm"
  elif [ -f yarn.lock ];         then PM="yarn"
  elif [ -f bun.lockb ];         then PM="bun"
  elif [ -f package-lock.json ]; then PM="npm"
  else PM="npm (lockfile yok)"; fi
  if command -v python3 >/dev/null 2>&1; then
    KOMUTLAR=$(python3 - <<'PY' 2>/dev/null || :
import json
try:
    d = json.load(open("package.json", encoding="utf-8"))
except Exception:
    raise SystemExit(0)
scripts = d.get("scripts") or {}
ilgi = ("test", "build", "lint", "typecheck", "tsc", "check", "dev")
for name in scripts:
    if any(k in name.lower() for k in ilgi):
        print(f"{name}: {scripts[name]}")
deps = list((d.get("dependencies") or {}).keys())
if deps:
    print("__DEPS__" + ", ".join(sorted(deps)[:15]))
PY
)
  fi
elif [ -f Cargo.toml ];    then PROJE="Rust";       PM="cargo"; KOMUTLAR="test: cargo test
build: cargo build"
elif [ -f go.mod ];        then PROJE="Go";         PM="go";    KOMUTLAR="test: go test ./...
build: go build ./..."
elif [ -f pyproject.toml ];then PROJE="Python";     PM="pip/uv/poetry (pyproject.toml)"
elif [ -f requirements.txt ]; then PROJE="Python";  PM="pip"
elif ls ./*.sln ./*.csproj >/dev/null 2>&1; then PROJE=".NET"; PM="dotnet"; KOMUTLAR="build: dotnet build"
fi

MAKE_HEDEF=""
if [ -f Makefile ]; then
  MAKE_HEDEF=$(grep -E '^[a-zA-Z0-9_.-]+:' Makefile 2>/dev/null | cut -d: -f1 | head -12 | tr '\n' ' ')
fi

# --- cikti --------------------------------------------------------------------
say "<!-- baglam-topla.sh ciktisi, $(date '+%Y-%m-%d %H:%M') -->"
say ""
say "- **Proje:** $PROJE${PM:+ / paket yoneticisi: $PM}"

if [ -n "$KOMUTLAR" ]; then
  DEPS=$(printf '%s\n' "$KOMUTLAR" | sed -n 's/^__DEPS__//p')
  SCRIPTS=$(printf '%s\n' "$KOMUTLAR" | grep -v '^__DEPS__' || :)
  if [ -n "$SCRIPTS" ]; then
    say "- **Kullanilabilir komutlar:**"
    printf '%s\n' "$SCRIPTS" | sed "s/^/    - \`${PM%% *} run /; s/: /\` -> /"
  fi
  [ -n "$DEPS" ] && say "- **Mevcut bagimliliklar (ilk 15):** $DEPS"
fi
[ -n "$MAKE_HEDEF" ] && say "- **Makefile hedefleri:** $MAKE_HEDEF"

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
LAST=$(git log -1 --format='%h %s' 2>/dev/null || echo "commit yok")
DIRTY=$(git status --porcelain 2>/dev/null | sed -n '$=' || echo 0)
say "- **Repo:** dal \`$BRANCH\`, son commit \`$LAST\`, kaydedilmemis ${DIRTY:-0} dosya"
say ""
say "- **Hedef dosyalar:**"

for f in $FILES; do
  if [ -f "$f" ]; then
    N=$(sed -n '$=' "$f" 2>/dev/null || echo 0)
    say "    - \`$f\` — ${N:-0} satir"
    git log -3 --format='        - %h %ad %s' --date=short -- "$f" 2>/dev/null | sed 's/$//' || :
  else
    say "    - \`$f\` — **YOK, yeni olusturulacak**"
  fi
done

if [ -n "$SYMBOL" ]; then
  say ""
  say "- **\`$SYMBOL\` gecen yerler:**"
  # shellcheck disable=SC2086
  HITS=$(git grep -n --fixed-strings -- "$SYMBOL" $FILES 2>/dev/null | head -20)
  if [ -n "$HITS" ]; then
    printf '%s\n' "$HITS" | sed 's/^/    - /'
  else
    say "    - (hedef dosyalarda bulunamadi)"
  fi
fi

say ""
say "> Bunlar mekanik veri. Brief'in BAGLAM blogu buna EK olarak sunlari da istiyor:"
say "> uyulacak mevcut kalip (kisa alintiyla), daha once verilmis kararlar, kullanicinin"
say "> tercihleri, bilinen tuzaklar. Onlari Patron elle yazar."
