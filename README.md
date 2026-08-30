# lng-skills

Agent skills for Claude Code and any other `SKILL.md` harness.
Written in Turkish — the protocols themselves are language-agnostic.

---

## Skill'ler

### `patronaj` — patron/işçi delegasyon modu

Ana döngüdeki ajan **Patron** olur: kullanıcıyla tüm konuşmayı o yürütür, bağlamın
tamamını o taşır, ama **hiçbir kod değişikliğini kendi eliyle yapmaz.** Her değişiklik
için 7 bloklu bir iş emri (brief) yazar, alt Opus ajanına (**İşçi**) yaptırır, dönen
diff'i kendi doğrular, commit'i kendi atar.

İki şey kazandırır:

- **Bağlam ekonomisi** — işin gürültülü ortası (dosya taramaları, build logları, kod
  dökümleri) ana pencereye hiç girmez. Ana pencerede biriken şey konuşma, kararlar,
  brief'ler ve özet raporlar.
- **Hassasiyet** — her değişiklik açık bir sözleşmeye karşı yapılır. İşçi sıfır bağlamla
  doğar ve soru soramaz, bu yüzden brief belirsizlik bırakamaz. Belirsizlik bırakmayan
  brief, doğaçlamayan işçi demektir.

| Dosya | Ne var |
| --- | --- |
| `SKILL.md` | Rol sözleşmesi, Patron'un araç kapısı, 7 adımlı döngü, paralellik kuralları, doğrulama disiplini, istisnalar |
| `references/brief-sablonu.md` | Doldurulabilir brief şablonu, kötü→iyi brief karşılaştırması (tam metin), keşif brief'i, sık yapılan 7 hata |
| `references/oturum-karti.md` | SessionStart kancasının enjekte ettiği ~1000 karakterlik protokol kartı |
| `references/sert-mod-hook.md` | Opsiyonel PreToolUse kancası: Patron'un `Edit`/`Write` çağrılarını dürten veya bloklayan iki varyant |
| `hooks/patronaj-brief.sh` | SessionStart kancası — protokolü her oturumda hazır eder, modu **açmaz** |

#### Neden başka bir orkestrasyon eklentisi değil

Bu kalıbın adı literatürde *context firewall*. Mevcut çözümler ajan koleksiyonu ve
yönlendirme altyapısı sunuyor; hiçbiri işin kalite belirleyici kısmına — **patronun
yazdığı brief'in anatomisine ve dönen işin doğrulanmasına** — odaklanmıyor. `patronaj`
tek bir şeyi ciddiye alıyor: brief'i kalınlaştır, sonra dönen diff'e körlemesine güvenme.

---

## Kurulum

```bash
git clone https://github.com/Lng999/lng-skills.git
cp -r lng-skills/skills/patronaj ~/.claude/skills/patronaj
```

Claude Code `~/.claude/skills/` altını kendiliğinden tarar. Yeni oturumda `/patronaj`
ile çağırabilir ya da "patron modu" diyebilirsin.

### Her oturumda otomatik hatırlatma (opsiyonel)

`~/.claude/settings.json` içindeki `SessionStart` dizisine **ekle** (varsa mevcut
girdileri silme):

```json
{
  "type": "command",
  "command": "$HOME/.claude/skills/patronaj/hooks/patronaj-brief.sh",
  "timeout": 10,
  "statusMessage": "Patronaj protokolu yukleniyor"
}
```

Windows'ta `.sh` doğrudan çalışmaz, Git Bash üzerinden mutlak yolla ver:

```
"C:/Program Files/Git/bin/bash.exe" "C:/Users/<kullanici>/.claude/skills/patronaj/hooks/patronaj-brief.sh"
```

Kanca protokolü her oturumda hazır eder ama **modu açmaz** — patron modu ancak sen
istediğinde devreye girer. Doğrulamak için:

```bash
echo '{}' | bash ~/.claude/skills/patronaj/hooks/patronaj-brief.sh
```

Geçerli JSON dönmeli. Dönmüyorsa `python3` PATH'te değildir; kanca o durumda sessizce
çıkar, oturumu bozmaz.

---

## Geliştirme

Skill'lerin çalışan kopyası `~/.claude/skills/` altında durur, repo bunun aynasıdır.
Değişiklikten sonra:

```bash
./sync.sh          # ~/.claude/skills/ -> repo
```

---

## Lisans

MIT — bkz. [LICENSE](LICENSE).
