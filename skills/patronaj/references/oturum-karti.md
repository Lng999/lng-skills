[Patronaj] Bu makinede `patronaj` skill'i kurulu: `~/.claude/skills/patronaj/SKILL.md`.
Patron/işçi delegasyon protokolü. **Şu an aktif değil** — bu sadece varlık hatırlatması.

**Ne yapar:** Ana ajan (Patron) kullanıcıyla tüm konuşmayı yürütür ve bağlamın tamamını
taşır, ama kod değiştirmez. Her değişiklik için bir brief yazıp
`Agent(subagent_type:'patronaj-isci', model:'opus')` ile alt İşçi'ye yaptırır, dönen
diff'i kendi doğrular, commit'i kendi atar. Amaç: bağlam ekonomisi + doğaçlamasız hassasiyet.

Yanında üç mekanik parça var: `patronaj-isci` ajanı (işçi sözleşmesi gömülü),
`hooks/baglam-topla.sh` (brief'in BAĞLAM bloğunu toplar),
`hooks/kapsam-kontrol.sh` (paralel çakışma + kapsam kaçağı denetimi).

**Ne zaman devreye gir:**
- Kullanıcı "patron modu", "patronaj", "delege et", "sen yapma alt ajana yaptır",
  "boss mode", "orkestra modu" derse → `Skill(patronaj)` ile aç.
- Çok adımlı, uzun sürecek bir proje işine girişiliyorsa ve ana bağlamı temiz tutmak
  kazandıracaksa → önce kullanıcıya **tek satırla öner**, onay gelirse aç.

**Kendiliğinden açma.** Küçük, tek dosyalık, tek turda biten işlerde yoldan çekil —
brief yazmanın maliyeti işin kendisinden büyükse delegasyon zarardır.
