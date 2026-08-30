# Sert mod — PreToolUse kancasıyla zorlama

Bu dosya **opsiyoneldir ve kurulu değildir.** Patronaj varsayılan olarak disiplinle
çalışır: skill talimatı Patron'a `Edit`/`Write` yasağını koyar, Patron uyar. Bu yeterli
gelmiyorsa (patron zamanla "şunu ben hallederim" demeye başlıyorsa) aşağıdaki kanca
yasağı mekanik hâle getirir.

> **Uyarı — bu makinede test edilmedi.** Aşağıdaki iki varyantı yazdım ama kurmadım
> ve çalıştırmadım. Kurmadan önce "Doğrulama" bölümündeki testi koş.

---

## Kritik risk: kanca alt ajanı da vurabilir

Claude Code'da PreToolUse kancaları oturum genelinde çalışır. **Kanca alt ajanların
araç çağrılarında da tetikleniyorsa, İşçi'nin `Edit` çağrısını da bloklar** ve
patronaj tamamen kilitlenir — Patron da yazamaz, İşçi de yazamaz.

Bu davranış Claude Code sürümüne göre değişir, körlemesine kurma. Önce test et.

---

## Varyant A — Yumuşak dürtme (önerilen, risksiz)

Bloklamaz, sadece Patron'a hatırlatma enjekte eder. Alt ajana sızsa bile zarar vermez,
en fazla gereksiz bir uyarı satırı olur.

`~/.claude/skills/patronaj/hooks/patronaj-nudge.sh`:

```bash
#!/bin/bash
# Patronaj: Edit/Write kullanimini bloklamadan hatirlat.
# Yalnizca ~/.claude/.patronaj-active isaret dosyasi varken konusur.

MARKER="$HOME/.claude/.patronaj-active"
[ -f "$MARKER" ] || exit 0

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | python3 -c \
  'import json,sys; print(json.load(sys.stdin).get("tool_name",""))' 2>/dev/null)

case "$TOOL" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

printf '%s\n' \
  '[Patronaj] Patron modu acik. Bu degisikligi kendin yapiyorsun. Kasitli bir istisna ise kullaniciya sebebini soyle; degilse dur, brief yaz ve Agent(model:"opus") ile Isciye yaptir.' >&2
exit 0
```

Çıkış kodu `0` + stderr → Claude uyarıyı görür, araç yine de çalışır.

---

## Varyant B — Sert blok

Gerçekten reddeder. Sadece Varyant A'yı test edip alt ajana sızmadığını gördükten
sonra kur.

`~/.claude/skills/patronaj/hooks/patronaj-guard.sh`:

```bash
#!/bin/bash
# Patronaj: Patron'un Edit/Write cagrilarini reddet.
# Isaret dosyasi ~/.claude/.patronaj-active icinde ana oturumun session_id'si tutulur;
# sadece o oturumdan gelen cagri reddedilir, alt ajanlar serbest kalir.

MARKER="$HOME/.claude/.patronaj-active"
[ -f "$MARKER" ] || exit 0

INPUT=$(cat)
read -r TOOL SID <<EOF
$(printf '%s' "$INPUT" | python3 -c \
  'import json,sys; d=json.load(sys.stdin); print(d.get("tool_name",""), d.get("session_id",""))' 2>/dev/null)
EOF

case "$TOOL" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

# Isaret dosyasindaki oturumdan gelmiyorsa dokunma (alt ajan olabilir).
MAIN_SID=$(head -1 "$MARKER" 2>/dev/null)
[ -n "$MAIN_SID" ] && [ "$SID" != "$MAIN_SID" ] && exit 0

python3 -c '
import json
print(json.dumps({"hookSpecificOutput":{
  "hookEventName":"PreToolUse",
  "permissionDecision":"deny",
  "permissionDecisionReason":"Patronaj sert modu: Patron kod degistirmez. Brief yaz ve Agent(subagent_type=\"general-purpose\", model=\"opus\") ile Isciye yaptir. Bilerek istisna yapiyorsan once patron modunu kapat."
}}))'
exit 0
```

`~/.claude/settings.json` içine:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/skills/patronaj/hooks/patronaj-guard.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

> **Windows notu:** Claude Code kanca komutlarını `cmd.exe` ile çalıştırır, `.sh` doğrudan
> çalışmaz ve `$HOME` genişlemez. Windows'ta komutu Git Bash üzerinden **mutlak yolla** ver:
>
> ```
> "C:/Program Files/Git/bin/bash.exe" "C:/Users/<kullanici>/.claude/skills/patronaj/hooks/patronaj-guard.sh"
> ```
>
> Aynı kalıp bu skill'in kendi SessionStart kancasında da kullanılıyor.

> **settings.json'ı ezmeyin.** `PreToolUse` dizisinde zaten girdi varsa **yanına ekleyin**;
> diziyi değiştirmek mevcut kancalarınızı sessizce siler.

---

## Aç / kapat

```bash
# ac  (Patron modu acilirken; sert modda session_id de yazilir)
printf '%s\n' "$CLAUDE_SESSION_ID" > ~/.claude/.patronaj-active

# kapat
rm -f ~/.claude/.patronaj-active
```

İşaret dosyası yoksa kanca hiçbir şey yapmaz, yani normal oturumlar etkilenmez.

---

## Doğrulama (kurmadan önce koş)

1. Varyant A'yı kur, işaret dosyasını oluştur.
2. Ana oturumda bir dosyaya `Edit` yap → stderr'de uyarı görünmeli, düzenleme geçmeli.
3. `Agent(subagent_type:'general-purpose', model:'opus', prompt:'X dosyasina bir yorum satiri ekle')`
   çalıştır.
4. **Kritik soru:** alt ajanın düzenlemesi de uyarı üretti mi?
   - **Hayır** → kanca alt ajanlara sızmıyor, Varyant B güvenle kurulabilir.
   - **Evet** → Varyant B alt ajanı da bloklar. Ya `session_id` filtresinin işe
     yaradığını ayrıca doğrula, ya Varyant A'da kal.
5. İşaret dosyasını sil, uyarının kesildiğini gör.
