// Ilova haqida: loyiha (mustaqil ma'lumot platformasi), ma'lumot manbalari (rasmiy), rasmlar mualliflari va litsenziyalari
// (config.links.photos), maxfiylik («Kuzatuv, reklama, hisob yo'q»), aloqa (sayt), versiya. Logotip — BrandMark.
import SwiftUI

struct AboutScreen: View {
    @Environment(AppModel.self) private var model
    @State private var appeared = false

    private let sources: [(String, String)] = [
        ("stat.uz", "https://stat.uz"), ("lex.uz", "https://lex.uz"), ("gov.uz", "https://gov.uz"), ("uzbekistan.travel", "https://uzbekistan.travel"),
        ("UNESCO", "https://whc.unesco.org"), ("OpenStreetMap", "https://www.openstreetmap.org"), ("Wikimedia Commons", "https://commons.wikimedia.org"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero

                AboutBlock(symbol: "sparkles", color: Theme.accent, title: tr("Nima bu?", "Что это?", "What is this?")) {
                    AboutText(tr("All Uzbekistan — alluzbekistan.com saytining ilovasi: Oʻzbekistonning barcha 14 hududi haqidagi mustaqil sayohat va maʼlumot loyihasi. Obidalar va tabiat, mehmonxona va restoranlar, aeroportlar tablosi, poyezdlar, davlat idoralari, tarix va madaniyat — oʻzbek, rus va ingliz tillarida.",
                                 "All Uzbekistan — приложение сайта alluzbekistan.com: независимый справочник и путеводитель по всем 14 регионам Узбекистана. Памятники и природа, отели и рестораны, табло аэропортов, поезда, госучреждения, история и культура — на узбекском, русском и английском.",
                                 "All Uzbekistan is the app for alluzbekistan.com — an independent travel guide and directory covering all 14 regions of Uzbekistan: monuments and nature, hotels and restaurants, live airport boards, trains, government offices, history and culture — in Uzbek, Russian and English."))
                }
                .appear(delay: 0.05)

                AboutBlock(symbol: "checkmark.seal.fill", color: Theme.teal, title: tr("Maʼlumotlar qayerdan?", "Откуда данные?", "Where does the data come from?")) {
                    AboutText(tr("Matnlar rasmiy va ochiq manbalar asosida tayyorlanadi, manbalari har sahifa oxirida koʻrsatiladi. Koordinatalar — OpenStreetMap (© hissadorlar, ODbL).",
                                 "Тексты готовятся по официальным и открытым источникам; источники указаны внизу каждой страницы. Координаты — OpenStreetMap (© участники, ODbL).",
                                 "Texts are based on official and open sources, listed at the bottom of every page. Coordinates come from OpenStreetMap (© contributors, ODbL)."))
                    SearchFlow(spacing: 8) {
                        ForEach(sources, id: \.0) { s in
                            Button { model.openWeb(s.1) } label: {
                                Text(s.0).font(Theme.Font.sub.weight(.medium)).foregroundStyle(Theme.teal)
                                    .padding(.horizontal, 12).frame(minHeight: 36)
                                    .background(Theme.teal.opacity(0.1), in: Capsule())
                            }
                            .buttonStyle(.press)
                            .accessibilityHint(tr("Saytni ochish", "Открыть сайт", "Open website"))
                        }
                    }
                    .padding(.top, 4)
                    AboutText(tr("Ish vaqti, narxlar va jadvallar oʻzgarib turadi — muhim safar oldidan rasmiy manbadan tekshiring.",
                                 "Часы работы, цены и расписания меняются — перед важной поездкой проверяйте их в официальных источниках.",
                                 "Opening hours, prices and timetables change — check official sources before an important trip."), muted: true)
                }
                .appear(delay: 0.1)

                AboutBlock(symbol: "camera.fill", color: Theme.gold, title: tr("Suratlar", "Фотографии", "Photos")) {
                    AboutText(tr("Suratlar Wikimedia Commons, Flickr (CC BY, CC BY-SA, CC0) va foydalanishga ruxsat bergan rasmiy saytlardan olingan. Har bir surat ostida muallifi va litsenziyasi koʻrsatiladi.",
                                 "Фотографии взяты из Wikimedia Commons, Flickr (CC BY, CC BY-SA, CC0) и официальных сайтов, разрешающих использование. Под каждым снимком указаны автор и лицензия.",
                                 "Photos come from Wikimedia Commons, Flickr (CC BY, CC BY-SA, CC0) and official websites that permit reuse. Each photo is credited with its author and licence."))
                    AboutLink(title: tr("Suratlar mualliflari va litsenziyalari", "Авторы фотографий и лицензии", "Photo credits and licences"),
                              symbol: "photo.on.rectangle.angled") { model.openWeb(MoreLinks.photos(model.config)) }
                }
                .appear(delay: 0.15)

                AboutBlock(symbol: "lock.shield.fill", color: Theme.ok, title: tr("Maxfiylik", "Конфиденциальность", "Privacy")) {
                    Text(tr("Kuzatuv, reklama, hisob yoʻq. Saqlanganlar faqat telefoningizda.",
                            "Без слежки, рекламы и учётных записей. Избранное хранится только на вашем телефоне.",
                            "No tracking, no ads, no account. Saved items stay on your phone."))
                        .font(Theme.Font.headline).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    AboutText(tr("Ilova faqat alluzbekistan.com bilan himoyalangan ulanish orqali bogʻlanadi. Joylashuv (xaritada) faqat telefonda ishlatiladi va serverga yuborilmaydi.",
                                 "Приложение связывается только с alluzbekistan.com по защищённому соединению. Геопозиция (на карте) используется только на телефоне и не отправляется на сервер.",
                                 "The app talks only to alluzbekistan.com over a secure, pinned connection. Your location (on the map) is used on the phone only and never sent to the server."))
                    AboutLink(title: tr("Maxfiylik siyosati", "Политика конфиденциальности", "Privacy policy"), symbol: "hand.raised") {
                        model.openWeb(MoreLinks.privacy(model.config))
                    }
                }
                .appear(delay: 0.2)

                AboutBlock(symbol: "bubble.left.and.bubble.right.fill", color: Theme.accent, title: tr("Aloqa", "Связь", "Contact")) {
                    AboutText(tr("Xato yoki eskirgan maʼlumot topdingizmi? Sayt orqali bizga xabar bering — tuzatamiz.",
                                 "Нашли ошибку или устаревшие данные? Сообщите нам через сайт — исправим.",
                                 "Spotted a mistake or outdated information? Let us know through the website and we’ll fix it."))
                    AboutLink(title: "alluzbekistan.com", symbol: "safari") { model.openWeb(MoreLinks.site) }
                }
                .appear(delay: 0.25)

                Text("© \(Calendar.current.component(.year, from: Date())) All Uzbekistan · \(tr("Versiya", "Версия", "Version")) \(MoreLinks.appVersion)")
                    .font(Theme.Font.caption).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 30)
        }
        .background(Theme.paper)
        .navigationTitle(tr("Ilova haqida", "О приложении", "About"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { appeared = true }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image("BrandMark").resizable().frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Theme.accent.opacity(0.3), radius: 18, y: 8)
                .scaleEffect(appeared ? 1 : 0.8)
                .rotationEffect(.degrees(appeared ? 0 : -12))
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: appeared)
                .accessibilityHidden(true)
            Text("All Uzbekistan").font(Theme.Font.display(32)).foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(tr("Butun Oʻzbekiston — bir ilovada", "Весь Узбекистан — в одном приложении", "All of Uzbekistan in one app"))
                .font(Theme.Font.sub).foregroundStyle(Theme.ink2)
            Text(tr("Versiya", "Версия", "Version") + " " + MoreLinks.appVersion)
                .font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.muted)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Theme.paper2, in: Capsule())
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

private struct AboutBlock<Content: View>: View {
    let symbol: String
    let color: Color
    let title: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        Panel(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    MoreIcon(symbol: symbol, color: color)
                    Text(title).font(Theme.Font.title3).foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                content()
            }
        }
    }
}

private struct AboutText: View {
    let text: String
    var muted = false
    init(_ text: String, muted: Bool = false) { self.text = text; self.muted = muted }
    var body: some View {
        Text(text).font(muted ? Theme.Font.sub : Theme.Font.body).foregroundStyle(muted ? Theme.muted : Theme.ink2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct AboutLink: View {
    let title: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.body.weight(.semibold))
                Text(title).font(Theme.Font.body.weight(.semibold)).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.footnote.weight(.bold))
            }
            .foregroundStyle(Theme.accent)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
    }
}
