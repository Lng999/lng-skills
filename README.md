# lng-skills

[![test](https://github.com/Lng999/lng-skills/actions/workflows/test.yml/badge.svg)](https://github.com/Lng999/lng-skills/actions/workflows/test.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Günlük işte kullandığım ajan skill'leri. Claude Code ve Codex için, `SKILL.md`
okuyan her harness'ta çalışır. Ortak fikir: **pahalı model düşünür, ucuz/hızlı model
yazar** ve dönen iş her zaman doğrulanır.

| Skill | Harness | Ne yapar |
| --- | --- | --- |
| [`patronaj`](#patronaj--patronişçi-delegasyon-modu) | Claude Code | Ana ajan Patron olur: konuşma ve bağlam onda, kodu 7 bloklu brief ile alt Opus ajanına yazdırır, diff'i kendisi doğrular |
| [`sol-patronaj`](#sol-patronaj--codex-planlar-opus-yazar) | Codex | Aynı kalıbın Codex sürümü: GPT-6.1 Sol planlar ve inceler, kodu `claude` CLI üzerinden Opus 4.6/4.5 yazar |

- [Kurulum](#kurulum)
- [Kullandığım diğer skill'ler](#kullandığım-diğer-skilller)
- [Geliştirme](#geliştirme)

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
| `SKILL.md` | Rol sözleşmesi, Patron'un araç kapısı, 8 adımlı döngü, paralellik kuralları, doğrulama disiplini, istisnalar |
| `agents/patronaj-isci.md` | **İşçi ajanı.** Rapor formatı, kapsam disiplini ve bağımlılık yasağı sistem prompt'una gömülü; `Agent` aracı yok, alt-alt delegasyon yapamaz |
| `hooks/baglam-topla.sh` | Brief'in BAĞLAM bloğunun mekanik yarısını üretir: proje tipi, paket yöneticisi, test/build komutları, hedef dosyaların boyutu + son 3 commit'i |
| `hooks/kapsam-kontrol.sh` | `kesisim` → paralel işçilerin dosya çakışması; `anlik` → taban al; `dogrula` → kapsam kaçağı denetimi (exit 1 = kaçak) |
| `references/brief-sablonu.md` | Doldurulabilir brief şablonu, kötü→iyi brief karşılaştırması (tam metin), keşif brief'i, sık yapılan 7 hata |
| `references/oturum-karti.md` | SessionStart kancasının enjekte ettiği ~1000 karakterlik protokol kartı |
| `references/sert-mod-hook.md` | Opsiyonel PreToolUse kancası: Patron'un `Edit`/`Write` çağrılarını dürten veya bloklayan iki varyant |
| `hooks/patronaj-brief.sh` | SessionStart kancası — protokolü her oturumda hazır eder, modu **açmaz** |

Tasarım fikri: prose olan ama mekanik olabilecek her şeyi mekanikleştirmek. İşçi
sözleşmesi her brief'te tekrar yazılan metin değil, ajanın sistem prompt'u. Kapsam
kaçağı gözle aranan bir şey değil, `exit 1` dönen bir betik. Brief'in BAĞLAM bloğunun
yarısı elle yazılan bilgi değil, `git log`'dan derlenen çıktı.

#### Neden başka bir orkestrasyon eklentisi değil

Bu kalıbın adı literatürde *context firewall*. Mevcut çözümler ajan koleksiyonu ve
yönlendirme altyapısı sunuyor; hiçbiri işin kalite belirleyici kısmına — **patronun
yazdığı brief'in anatomisine ve dönen işin doğrulanmasına** — odaklanmıyor. `patronaj`
tek bir şeyi ciddiye alıyor: brief'i kalınlaştır, sonra dönen diff'e körlemesine güvenme.

### `sol-patronaj` — Codex planlar, Opus yazar

Codex'in ana döngüsü **GPT-6.1 Sol** üzerinde çalışırken kullanılır. Sol bütün
düşünme işini yapar: kodu okur, kök nedeni bulur, mimariyi seçer, brief'i yazar,
dönen diff'i inceler ve son kararı verir. **Dosyaları kendisi değiştirmez.** Her
kod değişikliği `scripts/opus.sh` ile `claude` CLI'ye, Claude Opus 4.6'ya gider
(meşgulse otomatik olarak Opus 4.5'e düşer).

| Dosya | Ne var |
| --- | --- |
| `SKILL.md` | Kesin kurallar, iş akışı (anla → planla → brief → devret → incele → yinele → raporla), brief şablonu, paralel hatlar, istisnalar |
| `scripts/opus.sh` | Brief'i Opus'a verir; son raporu, `OPUS_MODEL` ve takip için `OPUS_SESSION` satırlarını basar. `-r <session>` ile aynı oturuma düzeltme gönderilir |

```bash
S=~/.agents/skills/sol-patronaj/scripts/opus.sh
$S -C /path/to/repo -b brief.md            # Opus 4.6, effort high
$S -C /path/to/repo -b fix.md -r <OPUS_SESSION>   # aynı oturumda düzeltme
```

Gereksinimler: `claude` CLI kurulu ve giriş yapılmış olmalı, `python3` gerekir.
Opus `bypassPermissions` ile çalıştığı için Codex'in `sandbox_mode = "danger-full-access"`
olması gerekir ve `-C` her zaman doğru proje klasörünü göstermelidir.

---

## Kurulum

```bash
git clone https://github.com/Lng999/lng-skills.git
mkdir -p ~/.claude/skills ~/.claude/agents
cp -R lng-skills/skills/patronaj ~/.claude/skills/

# İşçi ajanı: Claude Code ajan tanımlarını ~/.claude/agents/ altında arar,
# skill klasöründe değil. Bu adım atlanırsa delegasyon çalışmaz.
cp ~/.claude/skills/patronaj/agents/patronaj-isci.md ~/.claude/agents/
```

Hedef `~/.claude/skills/` olarak verildiği için aynı iki `cp` komutu **güncelleme** için de
çalışır (`git -C lng-skills pull` sonrası). Hedefi `~/.claude/skills/patronaj` diye
verme: klasör zaten varsa `cp` kopyayı içine, `patronaj/patronaj/` olarak koyar.

**Codex (`sol-patronaj`):** Codex kullanıcı skill'lerini `~/.agents/skills/` altında arar.

```bash
mkdir -p ~/.agents/skills
cp -R lng-skills/skills/sol-patronaj ~/.agents/skills/
```

Claude Code `~/.claude/skills/` altını kendiliğinden tarar. Yeni oturumda `/patronaj`
ile çağırabilir ya da "patron modu" diyebilirsin.

Betikler `bash` + `git` ister; `baglam-topla.sh`'nin `package.json` okuması için
`python3` (ya da `python`) gerekir (yoksa o bölüm atlanır, betik yine çalışır).
`jq` gerekmez. macOS'un hazır bash 3.2'si ve Windows'ta Git Bash yeterli.

Projelerin `.gitignore`'una `.patronaj/` ekle — `kapsam-kontrol.sh` taban dosyasını
oraya yazar.

### Her oturumda otomatik hatırlatma (opsiyonel)

`~/.claude/settings.json` içinde `hooks.SessionStart` dizisine aşağıdaki girdiyi **ekle**
(dizide başka girdiler varsa onları silme; `hooks` anahtarı hiç yoksa bu bloğun tamamını
koy):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/skills/patronaj/hooks/patronaj-brief.sh",
            "timeout": 10,
            "statusMessage": "Patronaj protokolu yukleniyor"
          }
        ]
      }
    ]
  }
}
```

Windows'ta `.sh` doğrudan çalışmaz, Git Bash üzerinden mutlak yolla ver. JSON içinde
tırnaklar kaçışlı yazılır:

```json
"command": "\"C:/Program Files/Git/bin/bash.exe\" \"C:/Users/<kullanici>/.claude/skills/patronaj/hooks/patronaj-brief.sh\""
```

Kanca protokolü her oturumda hazır eder ama **modu açmaz** — patron modu ancak sen
istediğinde devreye girer. Doğrulamak için:

```bash
echo '{}' | bash ~/.claude/skills/patronaj/hooks/patronaj-brief.sh
```

Geçerli JSON dönmeli. Dönmüyorsa ne `python3` ne `python` PATH'te çalışıyordur; kanca
o durumda sessizce çıkar, oturumu bozmaz.

---

## Kullandığım diğer skill'ler

Bu repoda olmayan, başkalarının yazdığı ama sık kullandığım skill'ler. Kendi
repolarından kur:

| Skill | Kaynak | Ne için |
| --- | --- | --- |
| `fable-orchestration` | [avenoxai/avenoxskills](https://github.com/avenoxai/avenoxskills) | Üst model ana döngüde, iş Opus alt ajanlarına; `patronaj`'ın ilham kaynağı |
| `codex-fleet` | [avenoxai/avenoxskills](https://github.com/avenoxai/avenoxskills) | `codex exec` ile kod işleri, `gpt-image-2` ile görsel üretimi, paralel Codex hatları |
| `omp-fleet` | [avenoxai/avenoxskills](https://github.com/avenoxai/avenoxskills) | Oh My Pi ile ucuz bağlam toplama ve paralel işler |
| `gptpro`, `gptpro-handoff` | [avenoxai/avenoxskills](https://github.com/avenoxai/avenoxskills) | Repoyu zip paketlere bölüp ajan olmayan bir modele inceletme |
| `avenox-video`, `avenox-thumbnail` | [avenoxai/avenoxskills](https://github.com/avenoxai/avenoxskills) | Video kurgu hattı ve YouTube kapak üretimi |

---

## Geliştirme

Skill'lerin çalışan kopyası `~/.claude/skills/` (Claude Code) ve `~/.agents/skills/`
(Codex) altında durur, repo bunların aynasıdır.
Değişiklikten sonra:

```bash
./sync.sh          # ~/.claude/skills/ -> repo
bash tests/hooks.sh   # kancalarin davranis testleri (gecici git depolarinda kosar)
```

CI aynı testleri Linux, macOS (`/bin/bash` 3.2) ve Windows Git Bash'te koşar.

---

## Lisans

MIT — bkz. [LICENSE](LICENSE).
