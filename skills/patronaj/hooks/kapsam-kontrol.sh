#!/bin/bash
# Patronaj kapsam kontrolu.
#
#   kapsam-kontrol.sh anlik
#       Delegasyondan ONCE calistir. O andaki kirli dosya listesini .patronaj/taban.txt'e
#       yazar; boylece isci donusunde "zaten kirliydi" olanlar kacak sayilmaz.
#
#   kapsam-kontrol.sh dogrula <izinli-dosya> [izinli-dosya...]
#       Isci donusunde calistir. Brief'in DOKUNULACAK listesini argüman olarak ver.
#       EKSTRA (listede yok ama degismis) ve DOKUNULMAMIS (listede var ama degismemis)
#       dosyalari raporlar. EKSTRA varsa exit 1.
#
#   kapsam-kontrol.sh kesisim "a.ts b.ts" "b.ts c.ts" [...]
#       Paralel isci FIRLATMADAN ONCE calistir. Dosya kumeleri kesisiyorsa exit 1.
#
# Yollar repo kokune gore verilir (git diff --name-only ne veriyorsa o bicimde).

set -u

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

[ $# -ge 1 ] || usage
CMD=$1
shift

# --- kesisim: git gerektirmez, once bunu ele al -------------------------------
if [ "$CMD" = "kesisim" ]; then
  [ $# -ge 2 ] || { echo "kesisim: en az iki kume gerekir"; exit 2; }
  TMP_DIR=$(mktemp -d) || exit 2
  trap 'rm -rf "$TMP_DIR"' EXIT
  i=0
  for set_arg in "$@"; do
    i=$((i + 1))
    printf '%s\n' $set_arg | sed '/^$/d' | sort -u > "$TMP_DIR/$i"
  done
  FOUND=0
  a=0
  for fa in "$TMP_DIR"/*; do
    a=$((a + 1))
    b=0
    for fb in "$TMP_DIR"/*; do
      b=$((b + 1))
      [ "$b" -le "$a" ] && continue
      OVERLAP=$(comm -12 "$fa" "$fb")
      if [ -n "$OVERLAP" ]; then
        FOUND=1
        echo "CAKISMA  kume $a <-> kume $b:"
        printf '%s\n' "$OVERLAP" | sed 's/^/    /'
      fi
    done
  done
  if [ "$FOUND" -eq 1 ]; then
    echo
    echo "Iki isciyi ayni dosyaya salma. Ya birlestir ya sıraya diz."
    exit 1
  fi
  echo "TEMIZ  kume dosyalari kesismiyor, paralel firlatilabilir."
  exit 0
fi

# --- buradan sonrasi git gerektirir -------------------------------------------
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "hata: git deposu icinde degilsin"; exit 2; }
cd "$ROOT" || exit 2

STATE_DIR="$ROOT/.patronaj"
BASE_FILE="$STATE_DIR/taban.txt"

# Betigin kendi durum klasoru asla degisiklik sayilmaz; yoksa taban.txt kendini
# kapsam kacagi olarak raporlar.
degisenler() {
  {
    git diff --name-only HEAD 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | sed '/^$/d' | grep -v '^\.patronaj/' | sort -u
}

case "$CMD" in
  anlik)
    mkdir -p "$STATE_DIR" 2>/dev/null || :
    degisenler > "$BASE_FILE"
    N=$(sed -n '$=' "$BASE_FILE" 2>/dev/null || echo 0)
    echo "taban alindi: ${N:-0} dosya zaten kirli (.patronaj/taban.txt)"
    exit 0
    ;;

  dogrula)
    [ $# -ge 1 ] || { echo "dogrula: en az bir izinli dosya ver"; exit 2; }
    TMP_DIR=$(mktemp -d) || exit 2
    trap 'rm -rf "$TMP_DIR"' EXIT

    printf '%s\n' "$@" | sed '/^$/d' | sort -u > "$TMP_DIR/izinli"
    degisenler > "$TMP_DIR/simdi"

    if [ -f "$BASE_FILE" ]; then
      comm -23 "$TMP_DIR/simdi" <(sort -u "$BASE_FILE") > "$TMP_DIR/degisen"
    else
      cp "$TMP_DIR/simdi" "$TMP_DIR/degisen"
      echo "not: taban yok (once 'anlik' calistirilmamis), tum kirli dosyalar bu ise sayiliyor"
    fi

    comm -13 "$TMP_DIR/izinli" "$TMP_DIR/degisen" > "$TMP_DIR/ekstra"
    comm -23 "$TMP_DIR/izinli" "$TMP_DIR/degisen" > "$TMP_DIR/eksik"

    echo "izinli: $(sed -n '$=' "$TMP_DIR/izinli" 2>/dev/null || echo 0) dosya | degisen: $(sed -n '$=' "$TMP_DIR/degisen" 2>/dev/null || echo 0) dosya"
    echo

    if [ -s "$TMP_DIR/eksik" ]; then
      echo "DOKUNULMAMIS  (brief'te vardi, degismemis - is yarim olabilir):"
      sed 's/^/    /' "$TMP_DIR/eksik"
      echo
    fi

    if [ -s "$TMP_DIR/ekstra" ]; then
      echo "KAPSAM KACAGI  (brief'te yoktu, degismis):"
      sed 's/^/    /' "$TMP_DIR/ekstra"
      echo
      echo "Isciye sor: bunlar niye degisti? Kabul etmeden commit atma."
      exit 1
    fi

    echo "TEMIZ  diff brief'in disina tasmadi."
    exit 0
    ;;

  *)
    usage
    ;;
esac
