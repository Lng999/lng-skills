# Brief şablonu

İşçi sıfır bağlamla doğar, sana soru soramaz, ve senin konuşma geçmişini görmez.
Brief'te olmayan her şey ya uydurulur ya atlanır. Bu yüzden brief **iş emridir**,
niyet beyanı değil.

Aşağıdakini `Agent(prompt: ...)` içine olduğu gibi doldur.

> **BAĞLAM bloğunun mekanik yarısını elle yazma:**
> `bash ~/.claude/skills/patronaj/hooks/baglam-topla.sh <hedef dosyalar> [--sembol <ad>]`
> proje tipini, paket yöneticisini, test/build komutlarını ve her hedef dosyanın
> boyutu + son 3 commit'ini paste-ready üretir. Sen sadece kalıbı, kararları ve
> tuzakları eklersin.
>
> **`patronaj-isci` ajanına veriyorsan 7. blok (RAPOR FORMATI) gereksiz** — o ajanın
> sistem prompt'unda zaten sabit. Genel bir ajana veriyorsan yaz.

---

## Şablon

```
## GÖREV
<Tek cümle: ne yapılacak ve niye. "Neden" olmadan işçi ödünleşimleri yanlış çözer.>

## BAĞLAM
<İşçi'nin bilemeyeceği her şey. Buraya cömert ol, asıl değer burada.>
- Proje / dil / framework / paket yöneticisi:
- İlgili mevcut yapı ve nerede olduğu — `dosya:satır` biçiminde:
- Uyulacak mevcut kalıp (kısa alıntıyla göster, tarif etme):
- Daha önce verilmiş kararlar ve gerekçeleri:
- Kullanıcının bilinen tercihleri / proje kuralları:
- Bilinen tuzaklar (platform, encoding, build quirk'leri):

## DOKUNULACAK DOSYALAR
<İsim isim. "İlgili yerler" yazma.>
- `yol/a.ts` — ne yapılacak
- `yol/b.ts` — ne yapılacak

## DOKUNULMAYACAKLAR
<Paralel işçi varsa ZORUNLU. Ayrıca kapsam kaçağını burada kapatırsın.>
- Bu listenin dışındaki hiçbir dosyaya yazma.
- `yol/c.ts` şu an başka bir işçide, açma bile.
- Bağımlılık ekleme/yükseltme yok.
- Mevcut public API imzalarını değiştirme.
- Formatlama/lint amaçlı kitlesel dokunuş yok, sadece istenen değişiklik.

## SÖZLEŞME
<Somut ol. Belirsiz bırakılan her şey doğaçlanır.>
- İmza / tip:
- Davranış (mutlu yol):
- Hata durumları ve ne dönecek:
- İsimlendirme:
- Kenar durumlar:

## KABUL KRİTERİ
<Koşulacak komutları birebir yaz. "Testler geçmeli" yetersiz.>
- [ ] `<komut>` hatasız
- [ ] `<test komutu>` yeşil
- [ ] <elle doğrulanacak davranış>

## RAPOR FORMATI
Bittiğinde SADECE şunu döndür (kod dökme, dosya içeriği yapıştırma):
1. Değiştirilen dosyalar ve her birinde tek satır ne yaptığın
2. Sözleşmeden saptığın yer var mı, varsa neden
3. Koştuğun doğrulama komutları ve birebir sonuçları
4. Bu iş sırasında fark ettiğin ama DOKUNMADIĞIN sorunlar
5. Kararsız kaldığın ve varsayımla geçtiğin noktalar
```

---

## Kötü brief → iyi brief

### ❌ Kötü

```
Login sayfasına rate limiting ekle.
```

Ne olur: İşçi projeyi baştan tarar (token yakar), kendi rate-limit kütüphanesini
seçer, `package.json`'a bağımlılık ekler, mevcut middleware kalıbını görmez,
kendi hata formatını uydurur. İkinci tur kaçınılmaz.

### ✅ İyi

```
## GÖREV
Login endpoint'ine IP başına rate limiting ekle; brute-force denemeleri
uygulamaya hiç ulaşmadan elensin.

## BAĞLAM
- Next.js 16 App Router, TypeScript, pnpm.
- Middleware zinciri `src/middleware.ts:1-48`. Kalıp şu:
    export const config = { matcher: [...] }
    export async function middleware(req: NextRequest) { ... }
- Redis zaten var ve bağlı: `src/lib/redis.ts:12` → `redis` adıyla export ediliyor,
  ioredis instance'ı. Yeni bağlantı AÇMA, bunu kullan.
- Hata gövdesi projede her yerde şu şekilde: `{ error: { code: string, message: string } }`
  (örnek `src/app/api/auth/login/route.ts:31`).
- Kullanıcı yeni bağımlılık istemiyor; sayaç elle Redis üstünde tutulacak.

## DOKUNULACAK DOSYALAR
- `src/middleware.ts` — rate-limit kontrolünü zincire ekle
- `src/lib/rate-limit.ts` — YENİ dosya, sayaç mantığı

## DOKUNULMAYACAKLAR
- `package.json` — bağımlılık ekleme yok
- `src/app/api/auth/login/route.ts` — endpoint'in kendisine dokunma
- Bu iki dosya dışında hiçbir şeye yazma

## SÖZLEŞME
- `src/lib/rate-limit.ts` export'u:
    export async function checkRateLimit(ip: string): Promise<{ ok: boolean; retryAfter: number }>
- Pencere 60 sn, limit 5 istek, Redis anahtarı `rl:login:<ip>`, TTL 60 sn.
- Sayaç `INCR` + ilk istekte `EXPIRE`. Atomiklik için pipeline kullan.
- Limit aşılırsa middleware 429 döner:
    gövde: { error: { code: "RATE_LIMITED", message: "Çok fazla deneme" } }
    header: Retry-After: <retryAfter saniye>
- Redis erişilemezse fail-open: isteği geçir, `console.warn` at. Kullanıcıyı kilitleme.
- IP kaynağı: `req.headers.get("x-forwarded-for")?.split(",")[0] ?? "unknown"`

## KABUL KRİTERİ
- [ ] `pnpm tsc --noEmit` hatasız
- [ ] `pnpm build` başarılı
- [ ] `src/middleware.ts` içindeki mevcut matcher davranışı değişmemiş
      (`git diff src/middleware.ts` ile göster)

## RAPOR FORMATI
Bittiğinde SADECE şunu döndür (kod dökme):
1. Değiştirilen dosyalar + her birinde tek satır ne yaptığın
2. Sözleşmeden sapma var mı, neden
3. Koştuğun komutlar ve birebir çıktı sonuçları
4. Fark ettiğin ama dokunmadığın sorunlar
5. Varsayımla geçtiğin noktalar
```

---

## Keşif brief'i (Explore ajanı için)

Arazi bilinmiyorsa önce salt-okunur keşif. Bu brief kısa olur; amaç **anlayış**,
diff değil.

```
Agent(subagent_type: 'Explore', model: 'opus', prompt: """
Bu repoda kimlik doğrulama akışını haritala. Arama genişliği: medium.

Şunları bul ve KONUM olarak rapor et (dosya:satır), kod dökme:
- Login isteği hangi endpoint'e gidiyor, handler nerede
- Session/token nerede üretiliyor, nerede doğrulanıyor
- Middleware zinciri var mı, sırası ne
- Redis / cache katmanı zaten kullanılıyor mu, nereden import ediliyor
- Hata gövdesi formatı ne (bir örnek satır ver)

Rapor: en fazla 20 satır, madde madde, her maddede dosya:satır.
""")
```

---

## Sık yapılan brief hataları

| Hata | Sonuç | Çözüm |
| --- | --- | --- |
| "İlgili dosyaları güncelle" | İşçi kapsamı kendi belirler, alakasız dosyalara girer | Dosyaları isim isim listele |
| Mevcut kalıbı tarif etmek | İşçi kendi kalıbını uydurur | Kalıptan 3-5 satır **alıntıla** |
| "Neden" yazmamak | Ödünleşimler yanlış çözülür | GÖREV satırında sebebi söyle |
| Kabul kriterine komut yazmamak | İşçi doğrulamayı atlar | Koşulacak komutu birebir yaz |
| Rapor formatı dayatmamak | İşçi 400 satır kod döker, Patron'un bağlamı şişer | 5 maddelik formatı zorunlu kıl |
| "Gerekirse bağımlılık ekle" | Sürpriz `package.json` değişikliği | DOKUNULMAYACAKLAR'a yaz |
| Belirsizliği brief'e taşımak | İşçi soru soramaz, varsayım yapar | Belirsizliği kullanıcıyla önce çöz |
