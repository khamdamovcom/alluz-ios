// «Yana» tab: barcha bo'limlar guruhlab (Sayohat, Madaniyat, Transport, Xizmatlar, Ilova) — Sozlamalar uslubidagi rangli ikonkali qatorlar.
// Qatorlar yonida bo'limdagi yozuvlar soni (model.config.counts). Bo'limlar: Route orqali; Xarita va Tablo — o'z tabiga o'tadi.
import SwiftUI

struct MoreView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                MoreHeader()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            ForEach(groups) { g in
                Section {
                    ForEach(g.rows) { row in MoreRowView(row: row) }
                } header: {
                    Text(g.title).font(Theme.Font.kicker).foregroundStyle(Theme.muted)
                }
                .listRowBackground(Theme.card)
                .listRowSeparatorTint(Theme.line)
            }

            Section {
                Text(tr("Mustaqil maʼlumot loyihasi · kuzatuv va reklamasiz", "Независимый справочный проект · без слежки и рекламы",
                        "An independent guide · no tracking, no ads"))
                    .font(Theme.Font.caption).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle(tr("Yana", "Ещё", "More"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.open(.search) } label: { Image(systemName: "magnifyingglass") }
                    .accessibilityLabel(tr("Qidiruv", "Поиск", "Search"))
            }
        }
    }

    private var groups: [MoreGroup] {
        let c = model.config?.counts ?? [:]
        func n(_ k: String...) -> Int? { let s = k.compactMap { c[$0] }.reduce(0, +); return s > 0 ? s : nil }
        return [
            MoreGroup(id: "travel", title: tr("Sayohat", "Путешествие", "Travel"), rows: [
                .init(id: "places", title: tr("Joylar", "Места", "Places"), symbol: "building.columns.fill", color: Theme.accent, count: n("place"),
                      action: .route(.list(ListSpec(type: "place")))),
                .init(id: "regions", title: tr("Hududlar", "Регионы", "Regions"), symbol: "map.fill", color: Theme.teal, count: n("region"),
                      action: .route(.regions)),
                .init(id: "routes", title: tr("Marshrutlar", "Маршруты", "Itineraries"), symbol: "point.topleft.down.to.point.bottomright.curvepath",
                      color: Theme.gold, count: n("route"), action: .route(.list(ListSpec(type: "route")))),
                .init(id: "stay", title: tr("Mehmonxonalar", "Отели", "Hotels"), symbol: "bed.double.fill", color: Theme.warn, count: nil,
                      action: .route(.list(ListSpec(type: "venue", kind: "stay", title: tr("Mehmonxonalar", "Отели", "Hotels"))))),
                .init(id: "eat", title: tr("Restoranlar", "Рестораны", "Restaurants"), symbol: "fork.knife", color: Theme.bad, count: nil,
                      action: .route(.list(ListSpec(type: "venue", kind: "eat", title: tr("Restoranlar", "Рестораны", "Restaurants"))))),
                .init(id: "map", title: tr("Xarita", "Карта", "Map"), symbol: "mappin.and.ellipse", color: Theme.ok, count: nil, action: .tab(.map)),
            ]),
            MoreGroup(id: "culture", title: tr("Madaniyat", "Культура", "Culture"), rows: [
                .init(id: "history", title: tr("Tarix", "История", "History"), symbol: "scroll.fill", color: Theme.gold, count: n("era"),
                      action: .route(.history)),
                .init(id: "persons", title: tr("Allomalar", "Великие личности", "Great minds"), symbol: "person.fill", color: Theme.teal,
                      count: n("person"), action: .route(.list(ListSpec(type: "person")))),
                .init(id: "culture", title: tr("Madaniyat", "Культура", "Culture"), symbol: "paintpalette.fill", color: Theme.accent,
                      count: n("cuisine", "craft", "tradition", "holiday"), action: .route(.culture)),
                .init(id: "fests", title: tr("Tadbirlar", "События", "Events"), symbol: "calendar", color: Theme.bad, count: n("fest"),
                      action: .route(.list(ListSpec(type: "fest")))),
                .init(id: "guides", title: tr("Sayohatchilarga", "Путешественникам", "Travel tips"), symbol: "info.circle.fill", color: Theme.ok,
                      count: n("guide"), action: .route(.list(ListSpec(type: "guide")))),
            ]),
            MoreGroup(id: "transport", title: tr("Transport", "Транспорт", "Transport"), rows: [
                .init(id: "board", title: tr("Tablo", "Табло", "Flight board"), symbol: "airplane.departure", color: Theme.accent, count: nil,
                      action: .tab(.board)),
                .init(id: "transport", title: tr("Transport", "Транспорт", "Transport"), symbol: "tram.fill", color: Theme.teal, count: nil,
                      action: .route(.transport)),
                .init(id: "distances", title: tr("Masofalar", "Расстояния", "Distances"), symbol: "ruler.fill", color: Theme.gold, count: nil,
                      action: .route(.distances(nil))),
            ]),
            MoreGroup(id: "services", title: tr("Xizmatlar", "Сервисы", "Services"), rows: [
                .init(id: "weather", title: tr("Ob-havo", "Погода", "Weather"), symbol: "cloud.sun.fill", color: Theme.warn, count: nil,
                      action: .route(.weather(nil))),
                .init(id: "currency", title: tr("Valyuta va banklar", "Валюта и банки", "Currency and banks"), symbol: "dollarsign.circle.fill",
                      color: Theme.ok, count: nil, action: .route(.currency)),
                .init(id: "visa", title: tr("Viza", "Виза", "Visa"), symbol: "person.text.rectangle.fill", color: Theme.bad, count: nil,
                      action: .route(.visa(nil))),
                .init(id: "post", title: tr("Pochta indekslari", "Почтовые индексы", "Postal codes"), symbol: "envelope.fill", color: Theme.gold,
                      count: n("post"), action: .route(.post(nil))),
                .init(id: "gov", title: tr("Davlat idoralari", "Госучреждения", "Government offices"), symbol: "building.2.fill", color: Theme.teal,
                      count: n("org"), action: .route(.gov)),
            ]),
            MoreGroup(id: "app", title: tr("Ilova", "Приложение", "App"), rows: [
                .init(id: "saved", title: tr("Saqlanganlar", "Избранное", "Saved"), symbol: "bookmark.fill", color: Theme.accent,
                      count: model.saved.isEmpty ? nil : model.saved.count, action: .route(.saved)),
                .init(id: "settings", title: tr("Sozlamalar", "Настройки", "Settings"), symbol: "gearshape.fill", color: Theme.muted, count: nil,
                      action: .route(.settings)),
                .init(id: "about", title: tr("Ilova haqida", "О приложении", "About"), symbol: "info.circle.fill", color: Theme.teal, count: nil,
                      action: .route(.about)),
                .init(id: "site", title: tr("Saytni ochish", "Открыть сайт", "Open the website"), symbol: "safari.fill", color: Theme.ink2,
                      count: nil, action: .web(MoreLinks.site)),
            ]),
        ]
    }
}

// MARK: - Umumiy (More papkasi ichida)

/// Sayt havolalari joriy til prefiksi bilan
enum MoreLinks {
    static var langPrefix: String { Lang.current == .uz ? "" : "/" + Lang.current.rawValue }
    static var site: String { AppConfig.site + langPrefix }
    static func privacy(_ config: ServerConfig?) -> String { config?.links?.privacy ?? AppConfig.site + langPrefix + "/maxfiylik" }
    static func photos(_ config: ServerConfig?) -> String { config?.links?.photos ?? AppConfig.site + langPrefix + "/rasmlar" }
    static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

/// Sozlamalar uslubidagi rangli ikonka
struct MoreIcon: View {
    let symbol: String
    let color: Color
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.card)
            .frame(width: 30, height: 30)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct MoreGroup: Identifiable {
    let id: String
    let title: String
    let rows: [MoreRow]
}

private struct MoreRow: Identifiable {
    enum Action { case route(Route), tab(Tab), web(String) }
    let id: String
    let title: String
    let symbol: String
    let color: Color
    let count: Int?
    let action: Action
}

private struct MoreRowView: View {
    let row: MoreRow
    @Environment(AppModel.self) private var model

    var body: some View {
        switch row.action {
        case .route(let r):
            NavigationLink(value: r) { label }
        case .tab(let t):
            Button { Haptics.select(); model.tab = t } label: { label.overlay(alignment: .trailing) { trailingIcon("arrow.turn.up.right") } }
                .accessibilityHint(tr("Boshqa tabga oʻtadi", "Переход на другую вкладку", "Switches tab"))
        case .web(let s):
            Button { model.openWeb(s) } label: { label.overlay(alignment: .trailing) { trailingIcon("arrow.up.right") } }
        }
    }

    private var label: some View {
        HStack(spacing: 14) {
            MoreIcon(symbol: row.symbol, color: row.color)
            Text(row.title).font(Theme.Font.body).foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            if let c = row.count {
                Text(Fmt.num(c)).font(Theme.Font.sub.monospacedDigit()).foregroundStyle(Theme.muted)
                    .contentTransition(.numericText())
                    .padding(.trailing, isLink ? 0 : 20)
            }
        }
        .frame(minHeight: 36)
        .contentShape(Rectangle())
    }

    private var isLink: Bool { if case .route = row.action { return true }; return false }

    private func trailingIcon(_ s: String) -> some View {
        Image(systemName: s).font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted).accessibilityHidden(true)
    }
}

/// Tepada: logotip, nom, qidiruv tugmasi
private struct MoreHeader: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image("BrandMark").resizable().frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("All Uzbekistan").font(Theme.Font.title).foregroundStyle(Theme.ink)
                    Text(tr("Barcha boʻlimlar", "Все разделы", "All sections")).font(Theme.Font.sub).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            Button { Haptics.tap(); model.open(.search) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.accent)
                    Text(tr("Qidiruv", "Поиск", "Search")).foregroundStyle(Theme.muted)
                    Spacer(minLength: 0)
                }
                .font(Theme.Font.body)
                .padding(.horizontal, 16)
                .frame(minHeight: 46)
                .contentShape(Capsule())
                .glassBackground(Capsule(), interactive: true, fallback: .regularMaterial)
                .overlay(Capsule().strokeBorder(Theme.line.opacity(0.7)))
            }
            .buttonStyle(.press)
            .accessibilityLabel(tr("Qidiruv", "Поиск", "Search"))
        }
        .padding(.vertical, 6)
        .appear()
    }
}
