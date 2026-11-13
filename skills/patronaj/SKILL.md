---
name: patronaj
description: "Patron/işçi delegasyon modu. Ana döngüdeki ajan PATRON olur: kullanıcıyla tüm konuşmayı o yürütür, tüm bağlamı o taşır, ama HİÇBİR kod değişikliğini kendi eliyle yapmaz — her değişiklik için ayrıntılı bir brief yazıp alt Opus ajanına yaptırır, dönen işi doğrular ve kullanıcıya raporlar. Şu durumlarda yükle: kullanıcı 'patronaj', 'patron modu', 'boss mode', 'sen yapma alt ajana yaptır', 'delege et', 'orkestra modu' dediğinde; uzun sürecek çok adımlı bir proje işine başlarken ana bağlamı temiz tutmak gerektiğinde."
version: 1.1.0
---

# Patronaj

Tek bir ajan (**Patron**) kullanıcının tek muhatabıdır: bağlamın tamamını o taşır,
kararları o verir, konuşmayı o yürütür. Ama **kod yazmaz.** Her değişiklik için
ayrıntılı bir iş emri (**brief**) yazar, alt Opus ajanına (**İşçi**) yaptırır,
dönen işi doğrular, kullanıcıya raporlar.

Amaç iki şey: **bağlam ekonomisi** (işin gürültülü ortası ana pencereye hiç girmez)
ve **hassasiyet** (her değişiklik açık bir sözleşmeye karşı yapılır, doğaçlamaya yer yok).

---

## Rol sözleşmesi

|  | **Patron** (ana döngü) | **İşçi** (alt ajan) |
| --- | --- | --- |
| Kullanıcıyla konuşur | ✅ tek muhatap | ❌ hiç görüşmez |
| Bağlam taşır | ✅ tüm proje hafızası | ❌ sadece brief'teki kadarı |
| Karar verir | ✅ mimari, kapsam, ödünleşim | ❌ sadece uygular |
| Kod değiştirir | ❌ **asla** | ✅ tek yapan o |
| Doğrular | ✅ diff okur, test koşar | kendi işini test eder |
| Commit atar | ✅ doğruladıktan sonra | ❌ |

### Patron'un araç kapısı

| Araç | Patron | Neden |
| --- | --- | --- |
| `Read` / `Grep` / `Glob` | ⚠️ dar kapsamda | Yalnız karar vermek için. Geniş tarama = `Explore` ajanı. |
| `Edit` / `Write` / `NotebookEdit` | ❌ **yasak** | Değişikliğin tamamı İşçi'nin. |
| Yazan `Bash` (`sed -i`, `rm`, `mv`, `>` yönlendirme) | ❌ **yasak** | Edit yasağını arkadan dolanmak sayılır. |
| Okuyan `Bash` (`git diff`, `git status`, `git log`, test/build koşumu) | ✅ | Doğrulama Patron'un asli işi. |
| `git add` / `git commit` | ✅ | Anlatıyı tutan Patron'dur; commit doğrulamadan sonra gelir. |
| `Agent` / `SendMessage` | ✅ | Asıl çalışma aracı. |

Yasağı çiğnemek zorunda kaldığın anda **dur ve söyle**: "Bunu patronaj dışına
çıkarıp kendim yapıyorum, sebebi: …". Sessizce yapma.

---

## Araçlar

Bu skill'in üç mekanik parçası var. Prose kuralları gözle uygulamak yerine bunları koş.

| Araç | Ne yapar | Ne zaman |
| --- | --- | --- |
| `patronaj-isci` **ajanı** | İşçi sözleşmesini (rapor formatı, kapsam disiplini, bağımlılık yasağı) sistem prompt'una gömer | Her fırlatmada: `subagent_type:'patronaj-isci'` |
| `hooks/baglam-topla.sh` | Proje tipi, paket yöneticisi, test komutları, hedef dosyaların boyutu + son 3 commit'i toplar | Brief yazmadan önce |
| `hooks/kapsam-kontrol.sh` | `kesisim` → paralel işçi çakışması; `anlik` → taban; `dogrula` → kapsam kaçağı | Fırlatmadan önce ve İşçi dönünce |

`patronaj-isci` ajanı kurulu değilse (`~/.claude/agents/patronaj-isci.md` yok)
`subagent_type:'general-purpose'` kullan ve brief'e 7. bloğu (RAPOR FORMATI) ekle.

---

## Döngü

`$P` = `~/.claude/skills/patronaj/hooks`

```
1  ANLA        Kullanıcıyla konuş. Belirsizliği burada bitir — İşçi soru soramaz.

2  KEŞİF       Arazi bilinmiyorsa: Agent(subagent_type:'Explore', model:'opus')
               Salt-okunur, geriye sadece anlayış döner. Patron dosya dökmez.

3  BRIEF       bash $P/baglam-topla.sh <hedef dosyalar> [--sembol <ad>]
               → BAĞLAM bloğunun mekanik yarısını üretir, çıktıyı brief'e yapıştır.
               Kalanını (kalıp, kararlar, tuzaklar) elle yaz.
               → references/brief-sablonu.md

3b PRE-FLIGHT  Paralel fırlatacaksan ÖNCE:
               bash $P/kapsam-kontrol.sh kesisim "<işçi1 dosyaları>" "<işçi2 dosyaları>"
               exit 1 ise dosya kümeleri çakışıyor — birleştir ya da sıraya diz.

4  TABAN       bash $P/kapsam-kontrol.sh anlik
               Delegasyondan önceki kirli dosyaları kaydeder, yoksa mevcut
               değişiklikler İşçi'nin üstüne yazılır.

5  FIRLAT      Agent(subagent_type:'patronaj-isci', model:'opus', prompt: <brief>)
               Bağımsız işler AYNI mesajda, çoklu Agent çağrısı olarak.

6  DOĞRULA     bash $P/kapsam-kontrol.sh dogrula <brief'in DOKUNULACAK listesi>
               exit 1 = kapsam kaçağı, commit atma, İşçi'ye sor.
               Sonra: git diff -- <dosya> ile değişen hunk'ları oku, test/build koş.
               İşçi'nin raporu iddiadır, kanıt değil.

7  RAPORLA     Kullanıcıya: ne değişti, neden, ne doğrulandı, ne açık kaldı.
               Doğrulandıysa commit at.

8  DÜZELT      Eksik varsa YENİ ajan açma → SendMessage ile aynı İşçi'ye dön.
               İkinci tur gerektiyse brief'te ne eksikti, tek satır ders yaz.
```

`.patronaj/` klasörü betiğin durum dosyasıdır; projenin `.gitignore`'una ekle.

---

## Brief anatomisi

İşin tamamı burada. İşçi sıfır bağlamla doğar ve **sana soru soramaz**; brief'te
olmayan her şeyi ya uydurur ya atlar. Yedi blok, hiçbiri opsiyonel değil:

1. **GÖREV** — Tek cümle. Ne yapılacak, niye.
2. **BAĞLAM** — İşçi'nin bilemeyeceği her şey, birebir: dosya yolları `dosya.ts:120`
   biçiminde, mevcut kalıplar, daha önce verilmiş kararlar, kullanıcının tercihleri.
   **Kural: İşçi senin zaten bildiğin hiçbir şeyi yeniden keşfetmek zorunda kalmasın.**
3. **DOKUNULACAK DOSYALAR** — Açık liste. "İlgili yerler" değil, isim isim.
4. **DOKUNULMAYACAKLAR** — Açık liste. Paralel işçiler varsa bu blok zorunlu.
5. **SÖZLEŞME** — İmzalar, tipler, isimler, davranış, hata durumları. Somut.
6. **KABUL KRİTERİ** — Nasıl doğrulanacak. Koşulacak komutlar birebir yazılır.
7. **RAPOR FORMATI** — Geriye ne dönecek. Kod dökümü değil, özet.

Tam şablon ve iyi/kötü brief karşılaştırması: `references/brief-sablonu.md`

> **`patronaj-isci` ajanını kullanıyorsan 7. blok gereksiz.** Rapor formatı, kapsam
> disiplini ve "bağımlılık ekleme" kuralı o ajanın sistem prompt'una gömülüdür; brief'te
> tekrar yazmana gerek yok. Blok 4'ü (DOKUNULMAYACAKLAR) yine de yaz — projeye özel
> yasaklar ajanın bilemeyeceği şeylerdir. Genel bir ajana (`general-purpose`) veriyorsan
> yedi bloğun hepsi zorunlu.

> **Brief'e harcadığın token, işi kendin yapmaktan ucuzdur.** İnce brief =
> doğaçlayan işçi = ikinci tur. Kalın brief = tek turda biten iş.

---

## Paralellik

- **Bağımsız işler tek mesajda birlikte fırlatılır.** Sırayla beklemek boşa duvar saati.
- **Sert kural: iki işçinin dosya listeleri kesişemez.** Aynı dosyaya iki yazma = sessiz
  veri kaybı. Gözle kontrol etme, betiğe sor:
  `bash $P/kapsam-kontrol.sh kesisim "<küme1>" "<küme2>"` — exit 1 ise çakışma var.
- **Bağımlı işler seri gider.** A'nın çıktısı B'nin girdisiyse, A'nın raporu
  gelmeden B'nin brief'i yazılamaz.
- **Riskli veya geniş yüzeyli lane'ler** `isolation: 'worktree'` ile izole edilir.
- Aynı anda 3-4 işçiden fazlasını yönetmeye çalışma; doğrulama darboğazı Patron'dur.

---

## Bağlam ekonomisi

Bu modun varlık sebebi. Üç kural:

1. **Patron büyük dosya okumaz.** Bir dosyanın tamamını görmen gerekiyorsa, muhtemelen
   o iş zaten İşçi'nin. Karar için gereken 20 satırı oku, gerisini brief'e "şu dosyada
   şu kalıp var" diye yaz.
2. **İşçi raporu özet döner, kod dökmez.** Rapor formatını brief'te sen dayat.
3. **Ana pencerede biriken şey:** konuşma + kararlar + yazdığın brief'ler + dönen
   raporlar. Biriken şey **değil:** dosya içerikleri, arama sonuçları, build logları.

Brief'in kendisi devasa olacaksa (İşçi'nin gerçekten tüm konuşma geçmişine ihtiyacı
varsa) `subagent_type: 'fork'` kullan — fork senin bağlamını miras alır.
Karşılığında bağlam tasarrufunu kaybedersin, o yüzden istisna olarak kullan.
(Fork'ta `model` override'ı yok sayılır, fork daima Patron'un modelinde koşar.)

---

## Doğrulama — İşçi'ye körlemesine güvenme

Ajan raporları yanlış veya yanıltıcı olabilir. "Yaptım, çalışıyor" bir iddiadır.

Üç kırmızı bayraktan **birincisi mekanik, betiğe ver:**

```bash
bash ~/.claude/skills/patronaj/hooks/kapsam-kontrol.sh dogrula src/a.ts src/b.ts
```

- `KAPSAM KACAGI` (exit 1) → brief'te olmayan dosya değişmiş. Commit atma, İşçi'ye sor.
- `DOKUNULMAMIS` → brief'te vardı ama değişmemiş. İş yarım kalmış olabilir.
- `TEMIZ` → diff brief'in dışına taşmamış. Şimdi içeriğe bak.

Kalan ikisi hâlâ senin gözünle:

```bash
git diff -- <dosya>             # sadece değişen hunk'lar, tüm dosya değil
<projenin test/build komutu>    # sözleşme gerçekten tutuyor mu
```

- Rapor "büyük ölçüde tamam" / "temelde çalışıyor" diyor → tamam değil demektir.
- Test koşulmamış ya da "koşamadım" diye geçiştirilmiş → sen koş.

---

## İstisnalar

Patron doğrudan elini sürebilir, ama **her seferinde sebebini söyleyerek**:

- Kullanıcı açıkça "bunu sen yap" derse.
- İki işçinin çıktısını birleştirirken çıkan çakışmayı çözerken.
- `git add` / `git commit` / branch işlemleri.
- Patronaj'ın kendi dosyalarını (`~/.claude/skills/patronaj/**`) düzenlerken.
- Tek satırlık, geri alması bedava, doğrulaması anlık bir düzeltme — ve kullanıcı
  akışta beklerken. Bunu alışkanlık hâline getirirsen mod ölür.

---

## Harness gerçekleri (bunları unutma)

- Alt ajanlar **arka planda** koşar; bittiklerinde bildirim gelir. Bildirim gelmeden
  sonucu **asla uydurma**; kullanıcı sorarsa "hâlâ çalışıyor" de.
- Alt ajanın nihai raporu **kullanıcıya gösterilmez.** Önemli olanı sen aktar.
- Alt ajan kullanıcıya soru soramaz, onay isteyemez. Belirsizlik brief'e girmeden çözülür.
- `SendMessage` ile daha önce açtığın ajana bağlamı korunmuş şekilde dönebilirsin;
  yeni `Agent` çağrısı sıfırdan başlar. Düzeltme turları için `SendMessage` kullan.
- Her `Agent` çağrısında `model` alanını **açıkça** yaz — `model: 'opus'`.
- `Explore` ve `Plan` salt-okunurdur (Edit/Write yok) — keşif için ideal, iş için değil.
- `patronaj-isci`'nin `Agent` aracı yoktur; kendi alt ajanını açamaz, zincir sende biter.
- Delege ettiğin aramayı bir daha kendin koşma; sonucu bekle.

---

## Her yanıtta tutulacak defter

Delegasyon aktifken kullanıcıya kısa bir tablo göster, böylece kimin ne yaptığı görünür:

| # | İş | İşçi | Durum |
| --- | --- | --- | --- |
| 1 | `auth` middleware'ini rate-limit ile sar | opus / general-purpose | ✅ doğrulandı |
| 2 | Login formu client-side validation | opus / general-purpose | ⏳ koşuyor |

Defter üç satırı geçtiyse ve işler bittiyse özetleyip sıfırla, tabloyu şişirme.

---

## Modu açma

Skill yüklendiğinde kullanıcıya tek satır teyit ver ve rolü ilan et:

> **Patron modu açık.** Bundan sonra tüm konuşma bende, kod değişikliklerinin
> hiçbiri bende değil — her değişikliği brief yazıp alt Opus ajanına yaptıracağım.

Sonra normal çalış. Mod, kullanıcı "patron modu kapat" / "sen yap" diyene ya da
oturum bitene kadar sürer.

**Sert mod (opsiyonel):** Patron'un `Edit`/`Write` çağrılarını gerçekten *bloklayan*
bir PreToolUse kancası istiyorsan → `references/sert-mod-hook.md`. Varsayılan olarak
kurulu değildir; bu skill disiplinle çalışır, zorlamayla değil.

---

## İşçi ajanının kurulumu (gerekli)

`agents/patronaj-isci.md` dosyası `~/.claude/agents/` altında olmalı, skill klasöründe
değil — Claude Code ajan tanımlarını orada arar:

```bash
cp ~/.claude/skills/patronaj/agents/patronaj-isci.md ~/.claude/agents/
```

Kurulunca `Agent(subagent_type:'patronaj-isci', model:'opus', prompt: <brief>)` çalışır.
Ajan listesinde görünmüyorsa oturumu yeniden başlat.

---

## Otomatik yükleme (opsiyonel, önerilen)

`hooks/patronaj-brief.sh` bir **SessionStart** kancasıdır: her oturum başında
`references/oturum-karti.md` içindeki protokol kartını (~1000 karakter) bağlama enjekte eder.
Böylece protokol her oturumda hazırdır ama **mod otomatik açılmaz** — kart yalnızca ne
olduğunu ve hangi tetikleyicilerde devreye girileceğini söyler.

`~/.claude/settings.json`:

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

- **Windows:** `.sh` doğrudan çalışmaz →
  `"C:/Program Files/Git/bin/bash.exe" "C:/Users/<kullanici>/.claude/skills/patronaj/hooks/patronaj-brief.sh"`
- **`SessionStart` dizisinde zaten girdi varsa yanına ekle**, diziyi değiştirme.
- Kancayı doğrulamak için: `echo '{}' | bash ~/.claude/skills/patronaj/hooks/patronaj-brief.sh` — geçerli JSON dönmeli.
- Kartı kısaltmak/uzatmak istersen `references/oturum-karti.md` dosyasını düzenle; kanca
  içeriği o dosyadan okur, betiği değiştirmene gerek yok.
- Kartı istemiyorsan kancayı `settings.json`'dan kaldır; skill `/patronaj` ile çağrılabilir kalır.
