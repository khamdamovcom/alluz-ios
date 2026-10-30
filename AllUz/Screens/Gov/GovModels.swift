// Viza, pochta indekslari va davlat idoralari — server javoblari (server: /opt/alluz/src/pages/app-visa.js, app-post.js, app-gov.js;
// shartnoma: docs/API.md «Viza», «Pochta», «Davlat idoralari»). Bo'lim ichidagi umumiy yordamchilar ham shu yerda (prefiks Visa/Post/Gov).
import SwiftUI

// MARK: - Viza
struct VisaIndex: Decodable, Sendable {
    let asof: String?
    let asofText: String?
    let counts: [String: Int]
    let modes: [String: String]
    let countries: [VisaCountry]
    let guide: Card?
    let web: String?
}

struct VisaCountry: Decodable, Hashable, Identifiable, Sendable {
    let code: String
    let name: String
    let flag: String?
    let mode: String
    let days: Int?
    let unlimited: Bool
    let big: String?
    let term: String
    let transit: Bool
    /// Qidiruv kaliti: kod + uch tildagi nom + muqobil nomlar (kichik harf, apostrofsiz)
    let key: String
    var id: String { code }
    var visaMode: VisaMode { VisaMode(rawValue: mode) ?? .special }
}

struct VisaSource: Decodable, Hashable, Sendable {
    let label: String
    let url: String?
}

struct VisaDoc: Decodable, Hashable, Sendable {
    let key: String?
    let kind: String?
    let number: String?
    let date: String?
    let title: String
    let edition: String?
    let url: String?
}

struct VisaPhone: Decodable, Hashable, Sendable {
    let label: String?
    let value: String
    let tel: String
}

struct VisaLink: Decodable, Hashable, Sendable {
    let label: String
    let url: String?
}

struct VisaContact: Decodable, Hashable, Identifiable, Sendable {
    let id: String
    let icon: String
    let name: String
    let role: String?
    let phones: [VisaPhone]
    let emails: [String]
    let telegram: String?
    let website: String?
    let links: [VisaLink]
    let address: String?
    let note: String?
    let sources: [VisaSource]
}

struct VisaRuleItem: Decodable, Hashable, Sendable {
    let text: String
    let sources: [VisaSource]
}

struct VisaRuleSection: Decodable, Hashable, Identifiable, Sendable {
    let id: String
    let icon: String
    let title: String
    let items: [VisaRuleItem]
}

struct VisaTypeRow: Decodable, Hashable, Sendable {
    let code: String
    let name: String
    let term: String
}

struct VisaTypes: Decodable, Hashable, Sendable {
    let title: String
    let lead: String?
    let items: [VisaTypeRow]
    let note: String?
    let sources: [VisaSource]
}

struct VisaBlock: Decodable, Hashable, Sendable {
    let title: String
    let items: [String]
    let sources: [VisaSource]
}

struct VisaWarning: Decodable, Hashable, Sendable {
    let title: String
    let text: String
}

struct VisaSame: Decodable, Hashable, Identifiable, Sendable {
    let code: String
    let name: String
    let flag: String?
    var id: String { code }
}

struct VisaDetail: Decodable, Sendable {
    let code: String
    let name: String
    let flag: String?
    let mode: String
    let days: Int?
    let unlimited: Bool
    let big: String?
    let term: String
    let transit: Bool
    let modeLabel: String
    let headline: String
    let title: String
    let unit: String
    let note: String?
    let since: String?
    let sinceText: String?
    let special: String?
    let lead: [String]
    let conditions: [String]
    let stepsTitle: String?
    let steps: [String]
    let notes: [String]
    let evisaUrl: String?
    let evisaLabel: String?
    let embassiesUrl: String?
    let embassiesLabel: String?
    let after: VisaBlock
    let customs: VisaBlock
    let sourcesTitle: String
    let sources: [VisaDoc]
    let contactsTitle: String
    let contacts: [VisaContact]
    let rulesTitle: String
    let rules: [VisaRuleSection]
    let visaTypes: VisaTypes?
    let warning: VisaWarning?
    let same: [VisaSame]
    let asof: String?
    let asofText: String?
    let guide: Card?
    let web: String?
    var visaMode: VisaMode { VisaMode(rawValue: mode) ?? .special }
}

/// Kirish rejimi: rang va belgi (yashil — vizasiz, ko'k-firuza — e-viza, to'q sariq — viza kerak, terrakota — alohida shartlar)
enum VisaMode: String, Sendable {
    case visaFree = "visa_free", evisa, visaRequired = "visa_required", special

    var color: Color {
        switch self { case .visaFree: Theme.ok; case .evisa: Theme.teal; case .visaRequired: Theme.warn; case .special: Theme.accent }
    }
    var symbol: String {
        switch self {
        case .visaFree: "checkmark.seal.fill"; case .evisa: "iphone.gen3"; case .visaRequired: "person.text.rectangle"; case .special: "exclamationmark.circle"
        }
    }
}

// MARK: - Pochta
struct PostRegionsData: Decodable, Sendable {
    struct Region: Decodable, Hashable, Identifiable, Sendable {
        let slug: String
        let name: String
        let count: Int
        let active: Int
        let prefix: String
        let min: String
        let max: String
        var id: String { slug }
    }
    struct Soon: Decodable, Hashable, Sendable { let slug: String; let name: String }
    let total: Int
    let active: Int
    let regions: [Region]
    let soon: [Soon]
    let callCenter: String?
    let callCenterLabel: String?
    let web: String?
}

struct PostOffice: Decodable, Hashable, Identifiable, Sendable {
    let slug: String
    let index: String
    let name: String
    let settlement: String?
    let address: String?
    let kind: String
    let kindLabel: String
    let status: String
    let statusLabel: String?
    let region: String
    let regionName: String?
    let district: String?
    let districtName: String?
    let hours: String?
    let phones: [String]
    let lat: Double?
    let lon: Double?
    let web: String?
    var id: String { slug }
    var ref: ItemRef { ItemRef(type: "post", slug: slug) }
    var isMain: Bool { kind == "pochtamt" }
    var isArchive: Bool { status == "arxiv" }
    /// Mahalliy qidiruv uchun (bir marta hisoblanadi — PostRegionView)
    var searchKey: String {
        [index, name, settlement, address, districtName].compactMap { $0 }.joined(separator: " ").postFolded
    }
    /// Sevimlilar va kontekst menyusi uchun karta ko'rinishi
    var card: Card {
        Card(type: "post", slug: slug, name: "\(index) — \(settlement ?? name)", sub: [kindLabel, districtName ?? regionName].compactMap { $0 }.joined(separator: " · "),
             kicker: nil, summary: address, icon: "mail", kind: kind, region: region, rating: nil, unesco: nil, lat: lat, lon: lon, img: nil, web: web)
    }
}

struct PostRegionData: Decodable, Sendable {
    struct Head: Decodable, Hashable, Sendable {
        let slug: String
        let name: String
        let count: Int
        let active: Int
        let prefix: String?
        let min: String?
        let max: String?
    }
    struct Group: Decodable, Hashable, Identifiable, Sendable {
        let key: String?
        let name: String
        let type: String?
        let count: Int
        let items: [PostOffice]
        var id: String { key ?? "_" }
    }
    let region: Head
    let groups: [Group]
    let web: String?
}

struct PostSearchData: Decodable, Sendable {
    let q: String
    /// index | dup | near | prefix | text | empty
    let mode: String
    let total: Int
    let items: [PostOffice]
}

extension String {
    /// Qidiruv uchun: kichik harf, diakritika va apostroflarsiz
    var postFolded: String {
        lowercased().folding(options: [.diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "ʻ", with: "").replacingOccurrences(of: "ʼ", with: "")
            .replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "’", with: "").replacingOccurrences(of: "‘", with: "")
            .replacingOccurrences(of: "`", with: "").replacingOccurrences(of: "ё", with: "е")
    }
}

// MARK: - Davlat idoralari
struct GovData: Decodable, Sendable {
    struct Filter: Decodable, Hashable, Sendable { let region: String; let district: String; let kind: String; let level: String; let q: String }
    struct Phone: Decodable, Hashable, Identifiable, Sendable {
        let num: String
        let tel: String
        let icon: String?
        let label: String
        let sub: String?
        var id: String { num }
    }
    struct Hotline: Decodable, Hashable, Identifiable, Sendable {
        let num: String
        let tel: String
        let icon: String?
        let kind: String?
        let count: Int
        let label: String
        let sub: String?
        let slug: String?
        var id: String { num }
    }
    struct Region: Decodable, Hashable, Identifiable, Sendable { let slug: String; let name: String; let count: Int; var id: String { slug } }
    struct District: Decodable, Hashable, Identifiable, Sendable { let slug: String; let name: String; let type: String?; let count: Int; var id: String { slug } }
    struct Kind: Decodable, Hashable, Identifiable, Sendable { let kind: String; let label: String; let icon: String; let rep: Bool; let count: Int; var id: String { kind } }
    struct Level: Decodable, Hashable, Identifiable, Sendable { let level: String; let label: String; let count: Int; var id: String { level } }
    struct Section: Decodable, Hashable, Identifiable, Sendable { let key: String; let title: String; var items: [Card]; var id: String { key } }
    struct Results: Decodable, Hashable, Sendable { let total: Int; let offset: Int; let limit: Int; var sections: [Section] }

    let total: Int
    let nRep: Int
    let nRegions: Int
    let nDistricts: Int
    let filter: Filter
    let emergency: [Phone]
    let hotlines: [Hotline]
    let regions: [Region]
    let districts: [District]
    let kinds: [Kind]
    let levels: [Level]
    let rep: [Card]
    var results: Results?
    let web: String?
}

// MARK: - Umumiy yordamchilar
enum GovSymbol {
    /// Sayt ikonkasi → SF Symbol (bo'limga xos qo'shimchalar, qolgani SymbolMap)
    static func of(_ icon: String?) -> String {
        switch icon {
        case "flame": "flame.fill"
        case "flame-kindling": "flame"
        case "heart-pulse": "cross.case.fill"
        case "life-buoy": "lifepreserver"
        case "siren": "light.beacon.max.fill"
        case "shield": "shield.lefthalf.filled"
        case "compass": "safari"
        case "calendar-days": "calendar"
        case "home": "house"
        case "baby": "figure.and.child.holdinghands"
        case "plane": "airplane"
        case "smartphone": "iphone.gen3"
        default: SymbolMap.symbol(icon)
        }
    }
}

enum GovLinks {
    /// Faqat raqam va «+» — tel: havola (boshqa belgilar olib tashlanadi)
    static func tel(_ raw: String) -> URL? {
        let digits = raw.filter { $0.isNumber || $0 == "+" }
        guard digits.count >= 3 else { return nil }
        return URL(string: "tel:" + digits)
    }
    /// Serverdan kelgan havola — faqat https
    static func https(_ s: String?) -> URL? {
        guard let s, let u = URL(string: s), u.scheme?.lowercased() == "https", u.host != nil else { return nil }
        return u
    }
    static func mail(_ s: String) -> URL? {
        guard s.contains("@"), !s.contains(" "), !s.contains("?") else { return nil }
        return URL(string: "mailto:" + s)
    }
}
