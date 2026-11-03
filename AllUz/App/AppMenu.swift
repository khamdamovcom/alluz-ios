// Server boshqaradigan menyu (admin → Ilova, server: /opt/alluz/src/app-menu.js): pastki tablar, Bosh sahifadagi tezkor to'r, «Yana» guruhlari.
// config.menu = { tabs:[Item], home:[Item], more:[{id, title, items:[Item]}] }, Item = {id, icon, title (tilda), route}.
// route — Route(spec:) satri, «tab:<tab>» yoki «web:site|https://…». Noma'lum route — band ko'rsatilmaydi (eski ilova yangi bandni o'tkazib yuboradi).
// Config kelguncha / oflayn — oxirgi saqlangan config (AppModel), u ham bo'lmasa — `AppMenu.builtIn` (server standarti bilan bir xil).
import SwiftUI

/// Serverdagi band (xom)
struct MenuItem: Codable, Hashable, Sendable {
    let id: String
    let icon: String?
    let title: String
    let route: String
}

struct MenuGroupRaw: Codable, Hashable, Sendable {
    let id: String
    let title: String
    let items: [MenuItem]

    init(id: String, title: String, items: [MenuItem]) { self.id = id; self.title = title; self.items = items }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        items = ((try? c.decode([Lenient<MenuItem>].self, forKey: .items)) ?? []).compactMap(\.value)
    }
}

/// config.menu — har band alohida o'qiladi: bittasi buzuq bo'lsa ham qolganlari ishlaydi
struct MenuConfig: Codable, Hashable, Sendable {
    var tabs: [MenuItem]
    var home: [MenuItem]
    var more: [MenuGroupRaw]

    init(tabs: [MenuItem], home: [MenuItem], more: [MenuGroupRaw]) { self.tabs = tabs; self.home = home; self.more = more }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tabs = ((try? c.decode([Lenient<MenuItem>].self, forKey: .tabs)) ?? []).compactMap(\.value)
        home = ((try? c.decode([Lenient<MenuItem>].self, forKey: .home)) ?? []).compactMap(\.value)
        more = ((try? c.decode([Lenient<MenuGroupRaw>].self, forKey: .more)) ?? []).compactMap(\.value)
    }
}

/// Massiv elementini xatosiz o'qish (buzuq element — nil)
struct Lenient<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

/// Band bosilganda nima bo'ladi
enum MenuAction: Hashable {
    case route(Route)
    case tab(Tab)
    case web(URL)

    /// route satri → amal; tanilmasa nil
    init?(spec raw: String, title: String? = nil) {
        let spec = raw.trimmingCharacters(in: .whitespaces)
        guard !spec.isEmpty, spec.count < 300 else { return nil }
        if spec.hasPrefix("tab:") {
            guard let t = Tab(rawValue: String(spec.dropFirst(4))) else { return nil }
            self = .tab(t); return
        }
        if spec.hasPrefix("web:") {
            let rest = String(spec.dropFirst(4))
            if rest == "site" { guard let u = URL(string: MoreLinks.site) else { return nil }; self = .web(u); return }
            guard let u = URL(string: rest), u.scheme?.lowercased() == "https", u.host?.isEmpty == false else { return nil }
            self = .web(u); return
        }
        guard var r = Route(spec: spec) else { return nil }
        // Ro'yxat sarlavhasi — band nomi (masalan «Mehmonxonalar» — venue:stay)
        if case .list(var l) = r, l.kind != nil, let title, !title.isEmpty { l.title = title; r = .list(l) }
        self = .route(r)
    }
}

/// Tayyor (tekshirilgan) band
struct MenuEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String?
    let spec: String
    let action: MenuAction

    /// Ro'yxat/katak uchun to'liq (fill) SF Symbol
    var symbol: String { SymbolMap.menu(icon) }
    /// Rang — route bo'yicha (bir xil bo'lim hamma joyda bir xil rangda)
    func color(home: Bool = false) -> Color { MenuStyle.color(spec, home: home) }
}

struct MenuTab: Identifiable, Hashable {
    let tab: Tab
    let title: String
    let symbol: String
    var id: Tab { tab }
}

struct MenuSection: Identifiable, Hashable {
    let id: String
    let title: String
    let items: [MenuEntry]
}

/// Ilova ko'rsatadigan menyu (config'dan hisoblangan; body ichida hisob yo'q)
struct AppMenu: Equatable {
    let tabs: [MenuTab]
    let home: [MenuEntry]
    let more: [MenuSection]

    var visibleTabs: Set<Tab> { Set(tabs.map(\.tab)) }

    init(_ cfg: MenuConfig) {
        // Tablar: tanilganlari, takrorsiz, 5 tagacha; Asosiy va «Yana» doim bor (aks holda ilovadan chiqib bo'lmas holat)
        var seen = Set<Tab>(), tabs: [MenuTab] = []
        for it in cfg.tabs {
            guard case .tab(let t)? = MenuAction(spec: it.route), !seen.contains(t) else { continue }
            seen.insert(t)
            tabs.append(MenuTab(tab: t, title: it.title.isEmpty ? t.title : it.title, symbol: SymbolMap.tab(it.icon, fallback: t.symbol)))
        }
        if !seen.contains(.home) { tabs.insert(MenuTab(tab: .home, title: Tab.home.title, symbol: Tab.home.symbol), at: 0) }
        if !seen.contains(.more) { tabs.append(MenuTab(tab: .more, title: Tab.more.title, symbol: Tab.more.symbol)) }
        while tabs.count > 5, let i = tabs.lastIndex(where: { $0.tab != .home && $0.tab != .more }) { tabs.remove(at: i) }
        self.tabs = tabs

        func entries(_ items: [MenuItem]) -> [MenuEntry] {
            var ids = Set<String>()
            return items.compactMap { it in
                guard !it.title.isEmpty, ids.insert(it.id).inserted, let a = MenuAction(spec: it.route, title: it.title) else { return nil }
                if case .tab(let t) = a, t == .home { return nil }              // Asosiy tabda «Asosiy»ga o'tish ma'nosiz
                return MenuEntry(id: it.id, title: it.title, icon: it.icon, spec: it.route, action: a)
            }
        }
        home = entries(cfg.home)
        more = cfg.more.compactMap { g in
            let items = entries(g.items)
            return items.isEmpty ? nil : MenuSection(id: g.id, title: g.title, items: items)
        }
    }

    /// Ichki standart — serverdagi ITEMS (off:true bo'lmaganlari) bilan bir xil. Config kelmaguncha va u hech qachon bo'lmasa.
    static var builtIn: AppMenu { AppMenu(builtInConfig) }

    static var builtInConfig: MenuConfig {
        func i(_ id: String, _ icon: String, _ title: String, _ route: String) -> MenuItem { MenuItem(id: id, icon: icon, title: title, route: route) }
        return MenuConfig(
            tabs: [
                i("tab.home", "home", tr("Asosiy", "Главная", "Home"), "tab:home"),
                i("tab.explore", "compass", tr("Kashf eting", "Обзор", "Explore"), "tab:explore"),
                i("tab.map", "map", tr("Xarita", "Карта", "Map"), "tab:map"),
                i("tab.board", "plane", tr("Tablo", "Табло", "Flights"), "tab:board"),
                i("tab.more", "layout-grid", tr("Yana", "Ещё", "More"), "tab:more"),
            ],
            home: [
                i("home.places", "landmark", tr("Joylar", "Места", "Places"), "list:place"),
                i("home.regions", "map", tr("Hududlar", "Регионы", "Regions"), "regions"),
                i("home.board", "plane", tr("Tablo", "Табло", "Flights"), "tab:board"),
                i("home.weather", "cloud-sun", tr("Ob-havo", "Погода", "Weather"), "weather"),
                i("home.currency", "banknote", tr("Valyuta", "Валюта", "Currency"), "currency"),
                i("home.visa", "passport", tr("Viza", "Виза", "Visa"), "visa"),
                i("home.stay", "bed-double", tr("Mehmonxonalar", "Отели", "Hotels"), "list:venue:stay"),
                i("home.eat", "utensils", tr("Restoranlar", "Рестораны", "Restaurants"), "list:venue:eat"),
            ],
            more: [
                MenuGroupRaw(id: "travel", title: tr("Sayohat", "Путешествие", "Travel"), items: [
                    i("more.places", "landmark", tr("Joylar", "Места", "Places"), "list:place"),
                    i("more.regions", "map", tr("Hududlar", "Регионы", "Regions"), "regions"),
                    i("more.routes", "route", tr("Marshrutlar", "Маршруты", "Itineraries"), "list:route"),
                    i("more.stay", "bed-double", tr("Mehmonxonalar", "Отели", "Hotels"), "list:venue:stay"),
                    i("more.eat", "utensils", tr("Restoranlar", "Рестораны", "Restaurants"), "list:venue:eat"),
                    i("more.map", "map-pin", tr("Xarita", "Карта", "Map"), "tab:map"),
                ]),
                MenuGroupRaw(id: "culture", title: tr("Madaniyat", "Культура", "Culture"), items: [
                    i("more.history", "scroll-text", tr("Tarix", "История", "History"), "history"),
                    i("more.persons", "user", tr("Allomalar", "Великие личности", "Great minds"), "list:person"),
                    i("more.culture", "palette", tr("Madaniyat", "Культура", "Culture"), "culture"),
                    i("more.fests", "calendar", tr("Tadbirlar", "События", "Events"), "list:fest"),
                    i("more.guides", "info", tr("Sayohatchilarga", "Путешественникам", "Travel tips"), "list:guide"),
                ]),
                MenuGroupRaw(id: "transport", title: tr("Transport", "Транспорт", "Transport"), items: [
                    i("more.board", "plane", tr("Tablo", "Табло", "Flight board"), "tab:board"),
                    i("more.transport", "train-front", tr("Transport", "Транспорт", "Transport"), "transport"),
                    i("more.distances", "milestone", tr("Masofalar", "Расстояния", "Distances"), "distances"),
                ]),
                MenuGroupRaw(id: "services", title: tr("Xizmatlar", "Сервисы", "Services"), items: [
                    i("more.weather", "cloud-sun", tr("Ob-havo", "Погода", "Weather"), "weather"),
                    i("more.currency", "banknote", tr("Valyuta va banklar", "Валюта и банки", "Currency and banks"), "currency"),
                    i("more.visa", "passport", tr("Viza", "Виза", "Visa"), "visa"),
                    i("more.embassies", "landmark", tr("Elchixonalar", "Посольства", "Embassies"), "embassies"),
                    i("more.post", "mail", tr("Pochta indekslari", "Почтовые индексы", "Postal codes"), "post"),
                    i("more.gov", "building-2", tr("Davlat idoralari", "Госучреждения", "Government offices"), "gov"),
                ]),
                MenuGroupRaw(id: "app", title: tr("Ilova", "Приложение", "App"), items: [
                    i("more.saved", "bookmark", tr("Saqlanganlar", "Избранное", "Saved"), "saved"),
                    i("more.settings", "settings", tr("Sozlamalar", "Настройки", "Settings"), "settings"),
                    i("more.about", "info", tr("Ilova haqida", "О приложении", "About"), "about"),
                    i("more.site", "globe", tr("Saytni ochish", "Открыть сайт", "Open the website"), "web:site"),
                ]),
            ])
    }
}

/// Band rangi (route bo'yicha) — oldingi qattiq menyudagi ranglar saqlangan
enum MenuStyle {
    static func color(_ spec: String, home: Bool) -> Color {
        let p = spec.split(separator: ":").map(String.init)
        let head = p.first ?? ""
        switch head {
        case "list":
            switch (p.count > 1 ? p[1] : "", p.count > 2 ? p[2] : "") {
            case ("place", _): return Theme.accent
            case ("route", _): return Theme.gold
            case ("venue", "eat"): return home ? Theme.accent : Theme.bad
            case ("venue", _): return home ? Theme.gold : Theme.warn
            case ("person", _): return Theme.teal
            case ("fest", _): return Theme.bad
            case ("guide", _): return Theme.ok
            default: return Theme.accent
            }
        case "tab":
            switch p.count > 1 ? p[1] : "" {
            case "map": return Theme.ok
            case "board": return home ? Theme.ink2 : Theme.accent
            case "explore": return Theme.teal
            default: return Theme.accent
            }
        case "regions", "transport", "gov", "about", "rail": return Theme.teal
        case "history", "distances", "post": return Theme.gold
        case "culture", "saved", "search", "board", "item": return Theme.accent
        case "map", "currency": return Theme.ok
        case "weather": return Theme.warn
        case "visa": return Theme.bad
        case "embassies", "embassy": return Theme.ink2
        case "settings": return Theme.muted
        case "web": return Theme.ink2
        default: return Theme.accent
        }
    }
}
