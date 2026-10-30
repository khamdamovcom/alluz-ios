// Navigatsiya: 5 ta tab (har birida NavigationStack) va Route — ilovadagi barcha ekranlar.
// Ochish: model.open(.item(ref)), model.open(card), model.openWeb(url). Route → View: RouteViews.swift.
// Sayt havolalari (universal link / alluz://) → Route: Route(webPath:) — sayt URL shartnomasi (/opt/alluz/src/urls.js) bilan bir xil.
import Foundation

enum Tab: String, CaseIterable, Hashable, Sendable {
    case home, explore, map, board, more
    var title: String {
        switch self {
        case .home: tr("Asosiy", "Главная", "Home")
        case .explore: tr("Kashf eting", "Обзор", "Explore")
        case .map: tr("Xarita", "Карта", "Map")
        case .board: tr("Tablo", "Табло", "Flights")
        case .more: tr("Yana", "Ещё", "More")
        }
    }
    var symbol: String {
        switch self {
        case .home: "house"; case .explore: "safari"; case .map: "map"; case .board: "airplane.departure"; case .more: "square.grid.2x2"
        }
    }
}

/// Ro'yxat so'rovi: /list/:type?region=&kind=&unesco=1
struct ListSpec: Hashable, Codable, Sendable {
    var type: String
    var region: String? = nil
    var district: String? = nil
    var kind: String? = nil
    var unesco = false
    /// Sarlavha (bo'lmasa tur nomi)
    var title: String? = nil
}

enum Route: Hashable, Sendable {
    // Kontent
    case item(ItemRef)                 // istalgan yozuv (joy, hudud, tuman, mehmonxona, alloma, davr, bayram …) — ItemDetailView
    case list(ListSpec)                // filtrli ro'yxat — ListScreen
    case regions                       // 14 hudud — RegionsScreen
    case culture                       // madaniyat: oshxona, hunarmandchilik, an'analar, bayramlar, festivallar — CultureHub
    case history                       // tarix: davrlar va voqealar — HistoryScreen
    case gallery([Img], Int)           // to'liq ekran galereya — GalleryScreen
    // Transport
    case board(String?)                // aeroport tablosi (IATA) — BoardScreen
    case railBoard(String?)            // vokzal tablosi (bekat slug) — RailBoardScreen
    case transport                     // transport markazi — TransportHub
    // Xizmatlar
    case weather(String?)              // ob-havo (hudud slug) — WeatherScreen
    case currency                      // valyuta kurslari va banklar — CurrencyScreen
    case visa(String?)                 // viza (davlat kodi) — VisaScreen
    case post(String?)                 // pochta indekslari (hudud) — PostScreen
    case gov                           // davlat idoralari — GovScreen
    case distances(String?)            // shaharlar orasidagi masofa (juftlik) — DistancesScreen
    // Ilova
    case search                        // SearchScreen
    case saved                         // sevimlilar — SavedScreen
    case settings                      // SettingsScreen
    case about                         // AboutScreen

    /// Skrinshot/sinov rejimi uchun matn ko'rinishi: "item:place:registon", "list:venue:stay", "board:TAS", "weather", "tab:map"
    init?(spec: String) {
        let p = spec.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        let a1 = p.count > 1 && !p[1].isEmpty ? p[1] : nil, a2 = p.count > 2 && !p[2].isEmpty ? p[2] : nil
        switch p[0] {
        case "item": guard let a1, let a2 else { return nil }; self = .item(ItemRef(type: a1, slug: a2))
        case "list": guard let a1 else { return nil }; self = .list(ListSpec(type: a1, kind: a2))
        case "regions": self = .regions
        case "culture": self = .culture
        case "history": self = .history
        case "board": self = .board(a1)
        case "rail": self = .railBoard(a1)
        case "transport": self = .transport
        case "weather": self = .weather(a1)
        case "currency": self = .currency
        case "visa": self = .visa(a1)
        case "post": self = .post(a1)
        case "gov": self = .gov
        case "distances": self = .distances(a1)
        case "search": self = .search
        case "saved": self = .saved
        case "settings": self = .settings
        case "about": self = .about
        default: return nil
        }
    }

    /// Sayt yo'li (tilsiz yoki /ru, /en bilan) → Route. Tanilmasa nil (sayt brauzerda ochiladi).
    init?(webPath raw: String) {
        var parts = raw.split(separator: "/").map(String.init)
        if let f = parts.first, ["ru", "en", "uz"].contains(f) { parts.removeFirst() }
        guard let first = parts.first else { return nil }
        let s1 = parts.count > 1 ? parts[1] : nil, s2 = parts.count > 2 ? parts[2] : nil
        let item: (String, String?) -> Route? = { t, s in s.map { .item(ItemRef(type: t, slug: $0)) } }
        let r: Route?
        switch first {
        case "joylar": r = item("place", s1) ?? .list(ListSpec(type: "place"))
        case "hududlar":
            if let s1, let s2 { r = .item(ItemRef(type: "district", slug: "\(s1)--\(s2)")) } else { r = item("region", s1) ?? .regions }
        case "mehmonxonalar": r = item("venue", s1) ?? .list(ListSpec(type: "venue", kind: "stay"))
        case "restoranlar": r = item("venue", s1) ?? .list(ListSpec(type: "venue", kind: "eat"))
        case "allomalar": r = item("person", s1) ?? .list(ListSpec(type: "person"))
        case "tarix": r = item("era", s1) ?? .history
        case "madaniyat": r = s1.map { Route.culture(slug: $0) } ?? .culture
        case "tadbirlar": r = item("fest", s1) ?? .list(ListSpec(type: "fest"))
        case "sayohatchilarga": r = item("guide", s1) ?? .list(ListSpec(type: "guide"))
        case "marshrutlar": r = item("route", s1) ?? .list(ListSpec(type: "route"))
        case "davlat-idoralari": r = item("org", s1) ?? .gov
        case "banklar": r = item("bank", s1) ?? .currency
        case "tablo": r = .board(s1?.uppercased())
        case "transport":
            switch s1 {
            case "aeroportlar": r = item("airport", s2) ?? .list(ListSpec(type: "airport"))
            case "poyezdlar": r = item("train", s2) ?? .list(ListSpec(type: "train"))
            case "vokzallar": r = item("rail_station", s2) ?? .list(ListSpec(type: "rail_station"))
            case "avtovokzallar": r = item("bus_station", s2) ?? .list(ListSpec(type: "bus_station"))
            case "shahar": r = item("city_transport", s2) ?? .transport
            case "metro": r = .item(ItemRef(type: "metro", slug: "toshkent"))
            default: r = .transport
            }
        case "ob-havo": r = .weather(s1)
        case "viza": r = .visa(s1)
        case "pochta-indekslari": r = s2 != nil ? .item(ItemRef(type: "post", slug: s2!)) : .post(s1)
        case "masofalar": r = .distances(s1)
        case "qidiruv": r = .search
        case "haqida": r = .about
        default: r = nil
        }
        guard let r else { return nil }
        self = r
    }
}

extension Route {
    /// /madaniyat/:slug — tur slug'dan noma'lum (oshxona/hunar/an'ana/bayram): server «culture» turini o'zi topadi (javobda haqiqiy type)
    static func culture(slug: String) -> Route { .item(ItemRef(type: "culture", slug: slug)) }
}
