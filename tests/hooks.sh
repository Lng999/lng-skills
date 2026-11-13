#!/bin/bash
# patronaj kancalarinin davranis testleri.
#
#   bash tests/hooks.sh
#
# Her senaryo gecici bir git deposunda kosar; hicbir sey repoya ya da ~/.claude'a
# yazilmaz. macOS bash 3.2, Linux ve Windows Git Bash'te calisacak bicimde yazildi.

set -u

# Betikler, testi kosan bash ile kosar (macOS CI: /bin/bash 3.2).
SH=${BASH:-bash}
HOOKS=$(CDPATH='' cd "$(dirname "$0")/../skills/patronaj/hooks" && pwd) || exit 2
KK="$HOOKS/kapsam-kontrol.sh"
BT="$HOOKS/baglam-topla.sh"
PB="$HOOKS/patronaj-brief.sh"

WORK=$(mktemp -d) || exit 2
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
OUT=""
RC=0

ok()   { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; printf '%s\n' "$OUT" | sed 's/^/      | /'; }

# run <komut...>: ciktiyi OUT'a, cikis kodunu RC'ye yazar.
run() { OUT=$("$@" 2>&1); RC=$?; }

expect_rc() {  # <aciklama> <beklenen rc>
  if [ "$RC" -eq "$2" ]; then ok "$1"; else fail "$1 (rc=$RC, beklenen $2)"; fi
}
expect_has() {  # <aciklama> <alt dizgi>
  case "$OUT" in *"$2"*) ok "$1" ;; *) fail "$1 (cikti '$2' icermiyor)" ;; esac
}
expect_lacks() {  # <aciklama> <alt dizgi>
  case "$OUT" in *"$2"*) fail "$1 (cikti '$2' iceriyor)" ;; *) ok "$1" ;; esac
}

# Taze depo: a.txt, Turkce adli ve bosluklu dosyalar, tek commit.
new_repo() {
  REPO="$WORK/repo$1"
  mkdir -p "$REPO" && cd "$REPO" || exit 2
  git init -q
  git config user.email test@example.invalid
  git config user.name test
  git config core.autocrlf false
  printf 'a\n' > a.txt
  printf 'x\n' > "$(printf 'g\303\274ncel.ts')"
  printf 'y\n' > 'with space.md'
  git add -A && git commit -qm init
}

TR_FILE=$(printf 'g\303\274ncel.ts')

# --- kapsam-kontrol: kesisim --------------------------------------------------
cd "$WORK" || exit 2
run "$SH" "$KK" kesisim "a.ts b.ts" "c.ts"
expect_rc "kesisim: ayrik kumeler temiz" 0

run "$SH" "$KK" kesisim "a.ts b.ts" "b.ts c.ts"
expect_rc "kesisim: ortak dosya exit 1" 1
expect_has "kesisim: ortak dosya adi basilir" "b.ts"

touch "$WORK/glob-tuzagi.ts"
run "$SH" "$KK" kesisim "*.ts" "glob-tuzagi.ts"
expect_rc "kesisim: '*' kabukta genislemez" 0

run "$SH" "$KK" kesisim "./src/a.ts" "src\\a.ts"
expect_rc "kesisim: ./ ve ters bolu normalize edilir" 1

run "$SH" "$KK" kesisim a b c d e f g h i j "x" "x"
expect_has "kesisim: 10+ kumede numaralar dogru" "kume 11 <-> kume 12"

run "$SH" "$KK"
expect_rc "kullanim: argumansiz exit 2" 2
expect_lacks "kullanim: betik kodu basilmaz" "set -u"

# --- kapsam-kontrol: dogrula --------------------------------------------------
new_repo 1
printf 'z\n' >> "$TR_FILE"
printf 'q\n' >> 'with space.md'
run "$SH" "$KK" dogrula "$TR_FILE" 'with space.md'
expect_rc "dogrula: Turkce ve bosluklu ad eslesir" 0
expect_lacks "dogrula: git'in tirnakli bicimi sizmaz" '\303'

run "$SH" "$KK" dogrula 'with space.md'
expect_rc "dogrula: listede olmayan degisiklik exit 1" 1
expect_has "dogrula: kacak dosya adi basilir" "$TR_FILE"

git checkout -q -- .
printf 'yeni\n' > yeni.txt
run "$SH" "$KK" dogrula yeni.txt a.txt
expect_rc "dogrula: izlenmeyen yeni dosya sayilir" 0
expect_has "dogrula: degismeyen izinli dosya DOKUNULMAMIS" "DOKUNULMAMIS"
rm -f yeni.txt

git mv a.txt b.txt
run "$SH" "$KK" dogrula b.txt
expect_rc "dogrula: yeniden adlandirmada eski ad da degismis sayilir" 1
run "$SH" "$KK" dogrula a.txt b.txt
expect_rc "dogrula: yeniden adlandirma iki adla temiz" 0
git reset -q --hard

# --- kapsam-kontrol: anlik + dogrula (taban) ----------------------------------
new_repo 2
printf 'onceden\n' >> a.txt
run "$SH" "$KK" anlik
expect_has "anlik: kirli dosya sayisi" "1 dosya zaten kirli"
printf 'yeni\n' > yeni.txt
run "$SH" "$KK" dogrula yeni.txt
expect_rc "taban: onceden kirli ve dokunulmamis dosya kacak sayilmaz" 0
expect_lacks "taban: durum klasoru kendini raporlamaz" ".patronaj"

printf 'isci\n' >> a.txt
run "$SH" "$KK" dogrula yeni.txt
expect_rc "taban: isci onceden kirli dosyaya dokunduysa yakalanir" 1
expect_has "taban: dokunulan kirli dosya basilir" "a.txt"

git checkout -q -- a.txt
run "$SH" "$KK" dogrula yeni.txt
expect_rc "taban: isci onceden kirli dosyayi geri aldiysa yakalanir" 1

printf 'a.txt\n' > .patronaj/taban.txt   # eski bicim: sadece yol
printf 'tekrar\n' >> a.txt
run "$SH" "$KK" dogrula yeni.txt
expect_rc "taban: eski (ozetsiz) bicim hala okunur" 0

# --- kapsam-kontrol: henuz commit yok -----------------------------------------
mkdir -p "$WORK/bos" && cd "$WORK/bos" && git init -q
printf 'a\n' > a && git add a
printf 'b\n' > b
run "$SH" "$KK" dogrula a
expect_rc "commitsiz depo: indeksteki ve yeni dosyalar gorulur" 1
expect_has "commitsiz depo: kacak basilir" "b"

cd "$WORK" || exit 2
run "$SH" "$KK" anlik
expect_rc "git disinda exit 2" 2

# --- baglam-topla -------------------------------------------------------------
new_repo 3
printf '{"scripts":{"test":"vitest","build":"tsc"},"dependencies":{"zod":"1"}}\n' > package.json
: > pnpm-lock.yaml
run "$SH" "$BT" 'with space.md' "$TR_FILE" --sembol x
expect_rc "baglam-topla: exit 0" 0
# shellcheck disable=SC2016  # ters tirnaklar ciktinin kendisi
expect_has "baglam-topla: bosluklu yol tek dosya" '`with space.md` — 1 satir'
expect_has "baglam-topla: Turkce adli dosya bulunur" "\`$TR_FILE\` — 1 satir"
expect_has "baglam-topla: paket yoneticisi" "pnpm"
expect_has "baglam-topla: --sembol hedefte bulunur" "$TR_FILE:1:x"

run "$SH" "$BT" yok.ts
expect_has "baglam-topla: olmayan dosya YOK" "YOK, yeni olusturulacak"

mkdir -p sub && cd sub || exit 2
run "$SH" "$BT" ../a.txt
expect_has "baglam-topla: alt dizine gore yol uyarisi" "repo kokunde yok"
cd .. || exit 2

if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
  run "$SH" "$BT" a.txt
  expect_has "baglam-topla: package.json komutlari" "pnpm run test"
  expect_has "baglam-topla: bagimliliklar" "zod"
else
  printf 'skip  baglam-topla: python yok, package.json testi atlandi\n'
fi

new_repo 4
: > proje.csproj
printf 'all: build\n.PHONY: all\nCC:=gcc\nbuild:\n\ttrue\n' > Makefile
run "$SH" "$BT" a.txt
expect_has "baglam-topla: yalniz .csproj ile .NET" ".NET"
expect_has "baglam-topla: Makefile hedefleri" "all build"
expect_lacks "baglam-topla: .PHONY hedef sayilmaz" ".PHONY"
expect_lacks "baglam-topla: atama hedef sayilmaz" "CC"

run "$SH" "$BT"
expect_rc "baglam-topla: argumansiz exit 2" 2

# --- patronaj-brief -----------------------------------------------------------
PYBIN=""
for cand in python3 python; do
  if "$cand" -c 'import sys' >/dev/null 2>&1; then PYBIN=$cand; break; fi
done
if [ -n "$PYBIN" ]; then
  OUT=$(echo '{}' | HOME="$WORK/bos-home" "$SH" "$PB" 2>&1); RC=$?
  expect_rc "patronaj-brief: exit 0" 0
  if printf '%s' "$OUT" | "$PYBIN" -c '
import json, sys
d = json.load(sys.stdin)["hookSpecificOutput"]
assert d["hookEventName"] == "SessionStart"
assert d["additionalContext"].startswith("[Patronaj]")
assert "\r" not in d["additionalContext"]
' 2>/dev/null; then
    ok "patronaj-brief: gecerli SessionStart JSON, kart betigin yanindan"
  else
    fail "patronaj-brief: gecerli SessionStart JSON, kart betigin yanindan"
  fi
else
  printf 'skip  patronaj-brief: python yok\n'
fi

mkdir -p "$WORK/yalniz"
cp "$PB" "$WORK/yalniz/patronaj-brief.sh"
OUT=$(echo '{}' | HOME="$WORK/bos-home" "$SH" "$WORK/yalniz/patronaj-brief.sh" 2>&1); RC=$?
expect_rc "patronaj-brief: kart yoksa sessiz exit 0" 0
if [ -z "$OUT" ]; then ok "patronaj-brief: kart yoksa cikti yok"; else fail "patronaj-brief: kart yoksa cikti yok"; fi

echo
echo "$PASS gecti, $FAIL kaldi"
[ "$FAIL" -eq 0 ]
