# All Uzbekistan iOS — agentlar uchun umumiy yo'riqnoma

**Maqsad (egasining so'zi):** «zamonaviy dizayn, tez ishlaydigan, animatsiyalar bilan, iloji boricha tushunarli, ishlatish oson,
xavfsizlik choralari kuchli, hamma bo'limlar yaxshi ishlasin». Ilova — alluzbekistan.com (butun O'zbekiston sayohat va ma'lumot
sayti, uz/ru/en) ning native iOS ilovasi. Foydalanuvchilar: chet ellik turistlar (en/ru) va mahalliy aholi (uz).

## Texnologiya
SwiftUI, iOS 17+ (iOS 26 da Liquid Glass — `UI/Glass.swift`), faqat iPhone, portret. Observation (`@Observable`), async/await.
Tashqi kutubxona YO'Q. XcodeGen (`project.yml`) — fayl qo'shsangiz, o'zi kiradi (AllUz/ ichida istalgan joy).
Mac yo'q: kodni serverda tekshirish — `flock /tmp/alluz-ios-heavy.lock bash scripts/typecheck.sh` (Swift 6.2 + iOS 26 SDK, to'liq
type-check, ~10–60 s). Xato bo'lmasa — «OK — xato yo'q». Har katta qadamdan keyin ishga tushiring. Simulyatorni koordinator CI'da
yuritadi va skrinshotlarni ko'radi.

## Yadro (koordinatorniki — O'ZGARTIRMANG; kerak bo'lsa hisobotda «SO'ROV» deb yozing)
- `App/AppModel.swift` — `@Environment(AppModel.self) var model`: `model.open(.item(ref))`, `model.open(card)`, `model.openURL(url)`,
  `model.openWeb(string)`, `model.toggleSaved(card)`, `model.isSaved(ref)`, `model.visited(card)`, `model.saved`, `model.recent`,
  `model.show("xabar")` (toast), `model.lang`, `model.theme`, `model.tab`, `model.config`.
- `App/Router.swift` — `Route` (barcha ekranlar), `ListSpec`, `Tab`, `Route(webPath:)` (sayt havolasi → ekran), `Route(spec:)`.
- `App/RouteViews.swift` — Route → View; `App/AllUzApp.swift` — tablar; `App/ShotMode.swift` — `-shot` rejimi.
- `Data/API.swift` — `try await API.shared.get("item/place/registon") as Item`, `getRaw("/api/board", query:)`. Faqat shu orqali
  tarmoq (TLS pin, oflayn kesh). `Data/Models.swift` — Img, Card, ItemRef, Item, ListPage, HomeData, MapData…; `Data/JSONValue.swift`.
- `Data/L10n.swift` — `tr("O'zbekcha", "Русский", "English")`, `Lang`, `Fmt` (num, date, time, day, month, duration, km).
- `UI/Theme.swift` — ranglar `Theme.paper/paper2/card/ink/ink2/muted/line/accent/accentInk/teal/gold/ok/warn/bad`,
  `Theme.hue(region)`, `Theme.Font.display/largeTitle/title/title3/headline/body/sub/caption/kicker/mono`, `Theme.Radius`, `Theme.gutter`,
  `Kicker(text:)`. `UI/Motion.swift` — `.buttonStyle(.press)`, `.appear(delay:)`, `.scrollFade()`, `.carouselEffect()`, `Haptics`,
  `Motion.spring/snappy/gentle`, `.zoomSource(id, in: ns)` (+ `@Environment(\.zoomNS)`).
- `UI/Components.swift` — `Loadable(load:) { value in … }` (yuklash/skeleton/xato/qayta urinish/pull-to-refresh/til almashsa qayta),
  `CardLarge`, `CardTile`, `CardRow`, `CardMenu`, `Rail`, `SectionHeader`, `ChipBar`, `InfoRow`, `Panel`, `SaveButton`, `RatingView`,
  `UnescoBadge`, `CreditLine(img:)`, `EmptyState`, `ErrorState`, `SkeletonList`, `ToastView`.
- `UI/RemoteImage.swift` — `RemoteImage(img:, region:, icon:, mode:, width:)` (kesh, kichraytirish, yaltirash), `Placeholder`, `Shimmer`.
- `UI/SymbolMap.swift` — sayt ikonka nomi → SF Symbol, `SymbolMap.forType(type)`. `UI/Glass.swift` — `.glassBackground(shape)`,
  `.primaryButton()`, `.secondaryButton()`, `.glassGroup()`.

## Qoidalar
1. **Faqat o'z fayllaringiz** (vazifada ro'yxat). Qolipdagi (stub) struct nomi va init imzosi O'ZGARMASIN (RouteViews shularni chaqiradi).
   Yordamchi view/modellar — o'z papkangizda, nomi bo'lim prefiksi bilan yoki `private`/`fileprivate` (boshqa agent nomi bilan to'qnashmasin!).
2. **Matnlar** — faqat `tr(uz, ru, en)`, uchala til tabiiy va to'g'ri. O'zbekcha lotin, ʻ belgisi bilan: «Oʻzbekiston», «gʻ» (sayt kabi).
   Kontent matni serverdan keladi (tilga mos) — uni tarjima qilmang.
3. **Dizayn**: «sayohat jurnali» — qog'oz fon (`Theme.paper`), serif sarlavhalar (`Theme.Font.display/title`), katta sifatli rasmlar,
   terrakota urg'u. Har ekran: `.background(Theme.paper)` (ScrollView uchun `.scrollContentBackground(.hidden)` + fon), `navigationTitle`,
   chetlar `Theme.gutter`. Kunduzgi va tungi rejimda chiroyli. Rang/shrift qattiq yozilmasin — faqat Theme.
4. **Animatsiya**: mazmunli va yengil — paydo bo'lish (`.appear`), bosilish (`.press`), karusel (`.carouselEffect`), holat almashishi
   `withAnimation(Motion.spring)`, `contentTransition(.numericText())` raqamlar uchun, `.symbolEffect` ikonkalarga. Reduce Motion hurmat qilinsin.
5. **Tezlik**: `LazyVStack/LazyVGrid`, `body` ichida og'ir hisob yo'q (oldindan hisoblang), rasmlar faqat `RemoteImage` (to'g'ri `width` bilan),
   bitta ekranda keraksiz so'rov yo'q, qidiruvda debounce (300 ms).
6. **Tushunarli**: har ekranda aniq sarlavha, bo'sh holat (`EmptyState`) va xato (`Loadable` beradi), katta bosiladigan joylar (≥44 pt),
   VoiceOver yorliqlari, Dynamic Type (matn sig'masa — qatorlar ko'payadi, kesilib qolmasin). 375 pt kenglikda (iPhone SE) ham sig'sin.
7. **Xavfsizlik**: tarmoq faqat `API.shared` orqali (boshqa URLSession, WKWebView YO'Q). Tashqi havola — faqat `model.openURL/openWeb`
   (Safari oynasi) yoki `tel:`/`mailto:` (`model.openURL`). Serverdan kelgan URL'ni `URL(string:)` bilan tekshiring, `javascript:` va h.k.
   ochilmasin (openURL faqat https/tel/mailto/tg/maps ga ruxsat beradi). Hech qanday shaxsiy ma'lumot yig'ilmaydi va yuborilmaydi.
   Joylashuv (faqat Xarita agenti) — so'ralganda, faqat telefonda ishlatiladi.
8. **Sinov**: kod yozib bo'lgach typecheck; o'z ekranlaringiz uchun `-shot` spec ro'yxatini hisobotga yozing (masalan `item:place:registon`,
   `tab:map`, `weather:samarqand`) — koordinator CI'da skrinshot qilib tekshiradi. Server endpoint qo'shsangiz — `docs/API.md` ga yozing
   (o'z bo'limi) va curl bilan o'z nusxangizda sinang.
9. **Git**: ishchi papkangiz — o'z worktree'ingiz (branch `ag/<nom>`). Tez-tez commit qiling (`git add -A && git commit -m "…"`), PUSH
   QILMANG. Boshqa papkalarga yozmang. Tugaganda oxirgi commit + hisobot.
10. **Hisobot** (yakuniy javob): nima qilindi (ekranlar, fayllar), server o'zgarishlari, `-shot` speclar, yadroga SO'ROVlar, ma'lum
   kamchiliklar. Qisqa va aniq.

## Ma'lumot
API: `docs/API.md`, namunalar `docs/samples/*.json` (ingliz tilida). Jonli: `curl -s https://alluzbekistan.com/en/api/app/v1/...`.
Sayt kodi (faqat o'qish, mantiq va matnlarni o'rganish uchun): `/opt/alluz/src/pages/*.js`, `/opt/alluz/src/i18n/*.js`,
`/opt/alluz/ARCHITECTURE.md`. Sayt sahifalari: https://alluzbekistan.com (/ru, /en).
