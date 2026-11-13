#!/bin/bash
# Patronaj kapsam kontrolu.
#
#   kapsam-kontrol.sh anlik
#       Delegasyondan ONCE calistir. O andaki kirli dosyalari icerik ozetleriyle
#       .patronaj/taban.txt'e yazar; boylece isci donusunde "zaten kirliydi" olanlar
#       kacak sayilmaz - ama isci o dosyalara da dokunduysa yakalanir.
#
#   kapsam-kontrol.sh dogrula <izinli-dosya> [izinli-dosya...]
#       Isci donusunde calistir. Brief'in DOKUNULACAK listesini argüman olarak ver.
#       EKSTRA (listede yok ama degismis) ve DOKUNULMAMIS (listede var ama degismemis)
#       dosyalari raporlar. EKSTRA varsa exit 1.
#
#   kapsam-kontrol.sh kesisim "a.ts b.ts" "b.ts c.ts" [...]
#       Paralel isci FIRLATMADAN ONCE calistir. Dosya kumeleri kesisiyorsa exit 1.
#       Kume icindeki yollar bosluk ile ayrilir.
#
# Yollar repo kokune gore verilir (git diff --name-only ne veriyorsa o bicimde).

set -u
# sort/comm ayni siralamayi kullansin; yerel ayara gore degisen siralama comm'u bozar.
export LC_ALL=C

usage() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
  exit 2
}

# "./a.ts" ve Windows'tan gelen "src\a.ts" bicimlerini git'in bicimine cevir.
normalize() {
  # shellcheck disable=SC1003  # tr'ye giden tek bir ters bolu, tirnak kacisi degil
  tr '\\' '/' | sed -e 's#^\(\./\)*##' -e '/^$/d'
}

satir_say() {
  N=$(sed -n '$=' "$1" 2>/dev/null)
  echo "${N:-0}"
}

[ $# -ge 1 ] || usage
CMD=$1
shift

# --- kesisim: git gerektirmez, once bunu ele al -------------------------------
if [ "$CMD" = "kesisim" ]; then
  [ $# -ge 2 ] || { echo "kesisim: en az iki kume gerekir"; exit 2; }
  TMP_DIR=$(mktemp -d) || exit 2
  trap 'rm -rf "$TMP_DIR"' EXIT
  n=0
  set -f  # "src/*.ts" gibi bir kume kabukta genislemesin
  for set_arg in "$@"; do
    n=$((n + 1))
    # shellcheck disable=SC2086  # bosluga gore bolme kasitli
    printf '%s\n' $set_arg | normalize | sort -u > "$TMP_DIR/$n"
  done
  set +f
  FOUND=0
  a=1
  while [ "$a" -le "$n" ]; do
    b=$((a + 1))
    while [ "$b" -le "$n" ]; do
      OVERLAP=$(comm -12 "$TMP_DIR/$a" "$TMP_DIR/$b")
      if [ -n "$OVERLAP" ]; then
        FOUND=1
        echo "CAKISMA  kume $a <-> kume $b:"
        printf '%s\n' "$OVERLAP" | sed 's/^/    /'
      fi
      b=$((b + 1))
    done
    a=$((a + 1))
  done
  if [ "$FOUND" -eq 1 ]; then
    echo
    echo "Iki isciyi ayni dosyaya salma. Ya birlestir ya sıraya diz."
    exit 1
  fi
  echo "TEMIZ  kume dosyalari kesismiyor, paralel firlatilabilir."
  exit 0
fi

case "$CMD" in
  anlik|dogrula) ;;
  *) usage ;;
esac

# --- buradan sonrasi git gerektirir -------------------------------------------
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "hata: git deposu icinde degilsin"; exit 2; }
cd "$ROOT" || exit 2

STATE_DIR="$ROOT/.patronaj"
BASE_FILE="$STATE_DIR/taban.txt"

# core.quotePath=false + -z: Turkce/bosluklu dosya adlari git'in "g\303\274..."
# tirnakli bicimine donmesin, yoksa izinli listeyle hic eslesmez.
# --no-renames: yeniden adlandirmada eski ad da "degisti" sayilsin.
# Betigin kendi durum klasoru asla degisiklik sayilmaz; yoksa taban.txt kendini
# kapsam kacagi olarak raporlar.
degisenler() {
  {
    if git rev-parse -q --verify HEAD >/dev/null 2>&1; then
      git -c core.quotePath=false diff --name-only --no-renames -z HEAD 2>/dev/null
    else
      # Henuz commit yok: indekse alinmislar + calisma agacindakiler.
      git -c core.quotePath=false diff --name-only --no-renames -z --cached 2>/dev/null
      git -c core.quotePath=false diff --name-only --no-renames -z 2>/dev/null
    fi
    git -c core.quotePath=false ls-files -z --others --exclude-standard 2>/dev/null
  } | tr '\0' '\n' | sed '/^$/d' | grep -v '^\.patronaj/' | sort -u
}

# stdin'deki her yol icin "<ozet>\t<yol>". Silinmis dosyanin ozeti "-".
imzala() {
  while IFS= read -r p; do
    if [ -f "$p" ]; then
      h=$(git hash-object -- "$p" 2>/dev/null) || h="?"
    else
      h="-"
    fi
    printf '%s\t%s\n' "$h" "$p"
  done
}

case "$CMD" in
  anlik)
    mkdir -p "$STATE_DIR" 2>/dev/null || :
    degisenler | imzala > "$BASE_FILE" || {
      echo "hata: $BASE_FILE yazilamadi"; exit 2; }
    echo "taban alindi: $(satir_say "$BASE_FILE") dosya zaten kirli (.patronaj/taban.txt)"
    exit 0
    ;;

  dogrula)
    [ $# -ge 1 ] || { echo "dogrula: en az bir izinli dosya ver"; exit 2; }
    TMP_DIR=$(mktemp -d) || exit 2
    trap 'rm -rf "$TMP_DIR"' EXIT

    printf '%s\n' "$@" | normalize | sort -u > "$TMP_DIR/izinli"
    degisenler > "$TMP_DIR/simdi"

    if [ -f "$BASE_FILE" ]; then
      # Tabandaki dosya: ozeti degistiyse (ya da isci onu geri aldiysa) isci dokunmus.
      # Eski bicimli taban (ozetsiz, sadece yol) yalnizca adla karsilastirilir.
      awk -F '\t' 'NF >= 2 { print $2; next } { print }' "$BASE_FILE" > "$TMP_DIR/taban_yol"
      sort -u "$TMP_DIR/simdi" "$TMP_DIR/taban_yol" | imzala > "$TMP_DIR/simdi_imza"
      awk -F '\t' '
        FNR == NR { if (NF >= 2) h[$2] = $1; else h[$0] = "*"; next }
        {
          if (!($2 in h)) { print $2; next }
          if (h[$2] == "*") next
          if (h[$2] != $1) print $2
        }' "$BASE_FILE" "$TMP_DIR/simdi_imza" | sort -u > "$TMP_DIR/degisen"
    else
      cp "$TMP_DIR/simdi" "$TMP_DIR/degisen"
      echo "not: taban yok (once 'anlik' calistirilmamis), tum kirli dosyalar bu ise sayiliyor"
    fi

    comm -13 "$TMP_DIR/izinli" "$TMP_DIR/degisen" > "$TMP_DIR/ekstra"
    comm -23 "$TMP_DIR/izinli" "$TMP_DIR/degisen" > "$TMP_DIR/eksik"

    echo "izinli: $(satir_say "$TMP_DIR/izinli") dosya | degisen: $(satir_say "$TMP_DIR/degisen") dosya"
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
esac
