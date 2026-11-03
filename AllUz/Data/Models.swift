// API modellari — server shartnomasi: docs/API.md (server: /opt/alluz/src/pages/app.js).
// Hamma maydonlar ixtiyoriy darajada yumshoq: server yangi maydon qo'shsa yoki biri bo'lmasa ham ilova buzilmaydi.
import Foundation

/// Rasm: URL = site + u + "-" + kenglik + ".webp"; kengliklar 480/960/1600/2400
struct Img: Codable, Hashable, Sendable {
    let u: String
    let w: Int?
    let h: Int?
    let focus: String?
    let title: String?
    let author: String?
    let license: String?
    let licenseUrl: String?
    let source: String?
    let sourceName: String?

    static let widths = [480, 960, 1600, 2400]
    /// Kerakli piksel kengligiga eng yaqin (kattaroq) nusxa
    func url(for pixels: CGFloat) -> URL? {
        let maxW = w ?? 2400
        let pick = Img.widths.first { CGFloat($0) >= pixels } ?? 2400
        let width = maxW < pick ? (Img.widths.last { $0 <= maxW } ?? 480) : pick
        return URL(string: AppConfig.site + u + "-\(width).webp")
    }
    var aspect: CGFloat? { if let w, let h, w > 0, h > 0 { return CGFloat(w) / CGFloat(h) }; return nil }
    /// «© muallif · litsenziya · manba» — CC talabi (rasm ostida ko'rsatiladi)
    var creditLine: String? {
        let parts = [author, license, sourceName != author ? sourceName : nil].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : "© " + parts.joined(separator: " · ")
    }
}

/// Qisqa yozuv (ro'yxat kartasi)
struct Card: Codable, Hashable, Identifiable, Sendable {
    let type: String?
    let slug: String?
    let name: String
    let sub: String?
    let kicker: String?
    let summary: String?
    let icon: String?
    let kind: String?
    let region: String?
    let rating: Int?
    let unesco: Bool?
    let lat: Double?
    let lon: Double?
    let img: Img?
    let web: String?

    var id: String { "\(type ?? "?"):\(slug ?? name)" }
    var ref: ItemRef? { if let type, let slug { return ItemRef(type: type, slug: slug) }; return nil }
    var hasCoords: Bool { lat != nil && lon != nil }
}

/// Yozuvga havola (tur + slug) — navigatsiya va sevimlilar kaliti
struct ItemRef: Codable, Hashable, Sendable {
    let type: String
    let slug: String
    var key: String { "\(type):\(slug)" }
}

/// To'liq yozuv: /item/:type/:slug
struct Item: Decodable, Sendable {
    let type: String
    let slug: String
    let name: String
    let sub: String?
    let kicker: String?
    let summary: String?
    let icon: String?
    let kind: String?
    let region: String?
    let rating: Int?
    let unesco: Bool?
    let lat: Double?
    let lon: Double?
    let img: Img?
    let web: String?
    /// Tildagi matn: name, kicker, summary, body [{h, p[]}], tips, facts … (turga qarab)
    let text: JSONValue
    /// Turga xos maydonlar (tilga tushirilgan): address, phones, website, hours, ticket, coords, built, …
    let data: JSONValue
    let images: [Img]
    /// Bog'langan yozuvlar: region, district, related, places, persons, era, stops …
    let refs: [String: [Card]]
    let regionName: String?
    let districtName: String?
    /// Hudud/tuman/davr uchun ichidagilar: places, stay, eat, persons, districts, events
    let sections: [String: JSONValue]?
    let counts: [String: Int]?

    var card: Card {
        Card(type: type, slug: slug, name: name, sub: sub, kicker: kicker, summary: summary, icon: icon, kind: kind, region: region,
             rating: rating, unesco: unesco, lat: lat, lon: lon, img: img, web: web)
    }
    var ref: ItemRef { ItemRef(type: type, slug: slug) }
    /// Matn bo'limlari
    var body: [TextSection] { text["body"]?.decode([TextSection].self) ?? [] }
    /// sections["places"] kabi kartalar ro'yxati
    func sectionCards(_ key: String) -> [Card] { sections?[key]?.decode([Card].self) ?? [] }
}

struct TextSection: Decodable, Hashable, Sendable {
    let h: String?
    let p: [String]?
}

struct ListPage: Decodable, Sendable {
    let type: String
    let total: Int
    let offset: Int
    let limit: Int
    let kinds: [String: Int]
    let kindLabels: [String: String]
    let items: [Card]
}

struct HomeAirport: Decodable, Hashable, Sendable {
    let iata: String
    let slug: String
    let name: String
    let city: String?
    let region: String?
}

struct HomeData: Decodable, Sendable {
    let hero: [Card]
    let regions: [Card]
    let top: [Card]
    let unesco: [Card]
    let routes: [Card]
    let fests: [Card]
    let persons: [Card]
    let cuisine: [Card]
    let guides: [Card]
    let airports: [HomeAirport]
}

struct SearchResult: Decodable, Sendable {
    let q: String
    let items: [Card]
}

struct MapData: Decodable, Sendable {
    let points: [[JSONValue]]
    /// [type, slug, lat, lon, name, kind, region, img(0/1), rating]
    var parsed: [MapPoint] {
        points.compactMap { p in
            guard p.count >= 9, let type = p[0].string, let slug = p[1].string, let lat = p[2].double, let lon = p[3].double else { return nil }
            return MapPoint(type: type, slug: slug, lat: lat, lon: lon, name: p[4].string ?? slug, kind: p[5].string, region: p[6].string,
                            hasImg: (p[7].int ?? 0) == 1, rating: p[8].int ?? 0)
        }
    }
}

struct MapPoint: Hashable, Identifiable, Sendable {
    let type: String
    let slug: String
    let lat: Double
    let lon: Double
    let name: String
    let kind: String?
    let region: String?
    let hasImg: Bool
    let rating: Int
    var id: String { "\(type):\(slug)" }
    var ref: ItemRef { ItemRef(type: type, slug: slug) }
}

struct ServerConfig: Decodable, Sendable {
    struct IOS: Decodable, Sendable { let minBuild: Int?; let latestBuild: Int?; let storeUrl: String? }
    struct Links: Decodable, Sendable { let privacy: String?; let about: String?; let photos: String? }
    /// Admin → Ilova: closed=true — ilova faqat shu xabarni ko'rsatadi (kill switch)
    struct AppState: Codable, Equatable, Sendable {
        var closed: Bool
        var title: String?
        var text: String?
        static let open = AppState(closed: false, title: nil, text: nil)
    }
    let site: String
    let langs: [String]
    let ios: IOS?
    let counts: [String: Int]
    let links: Links?
    /// Ilova holati (yo'q bo'lsa — ochiq)
    let app: AppState?
    /// Server menyusi (AppMenu.swift); yo'q yoki buzuq bo'lsa — nil (ichki standart ishlaydi)
    let menu: MenuConfig?

    private enum CodingKeys: String, CodingKey { case site, langs, ios, counts, links, app, menu }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        site = try c.decode(String.self, forKey: .site)          // majburiy — boshqa JSON (xato javobi) config deb olinmasin
        langs = (try? c.decode([String].self, forKey: .langs)) ?? ["uz", "ru", "en"]
        ios = try? c.decode(IOS.self, forKey: .ios)
        counts = (try? c.decode([String: Int].self, forKey: .counts)) ?? [:]
        links = try? c.decode(Links.self, forKey: .links)
        // Bitta maydon buzilsa ham qolgani ishlaydi; «closed» — faqat aniq true bo'lsa yopiq
        if let a = try? c.nestedContainer(keyedBy: AppKeys.self, forKey: .app) {
            app = AppState(closed: (try? a.decode(Bool.self, forKey: .closed)) ?? false,
                           title: try? a.decode(String.self, forKey: .title), text: try? a.decode(String.self, forKey: .text))
        } else { app = nil }
        menu = try? c.decode(MenuConfig.self, forKey: .menu)
    }
    private enum AppKeys: String, CodingKey { case closed, title, text }
}

enum AppConfig {
    static let site = "https://alluzbekistan.com"
    static let host = "alluzbekistan.com"
    /// App Store sahifasi (config.ios.storeUrl bo'lmasa)
    static let storeURL = "https://apps.apple.com/app/id6828710075"
}
