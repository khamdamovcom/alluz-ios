// Elchixonalar API modellari (docs/API.md «Elchixonalar»; server: /opt/alluz/src/pages/app-embassies.js) va umumiy yordamchilar.
//   embassies?dir=in|out → EmbassyList; embassies/:slug → EmbassyDetail
// dir: "in" — xorijiy davlatning O'zbekistondagi vakolatxonasi, "out" — O'zbekistonning xorijdagi vakolatxonasi.
import SwiftUI

struct EmbassyPhone: Decodable, Hashable, Sendable {
    let value: String
    let tel: String
}

struct EmbassyRow: Decodable, Hashable, Identifiable, Sendable {
    let slug: String
    let dir: String
    let kind: String
    let kindLabel: String?
    let country: String
    let name: String
    let city: String?
    let address: String?
    let phone: EmbassyPhone?
    let website: String?
    let lat: Double?
    let lon: Double?
    let covers: [String]?
    let key: String?
    var id: String { slug }
    var isIn: Bool { dir == "in" }
}

struct EmbassyCountry: Decodable, Hashable, Identifiable, Sendable {
    let code: String
    let name: String
    let flag: String?
    let items: [EmbassyRow]
    var id: String { code }
}

struct EmbassyCountryInfo: Decodable, Hashable, Sendable {
    let code: String
    let name: String
    let flag: String?
}

struct EmbassyList: Decodable, Sendable {
    struct Groups: Decodable, Sendable {
        let inside: [EmbassyCountry]?
        let outside: [EmbassyCountry]?
        private enum CodingKeys: String, CodingKey { case inside = "in", outside = "out" }
    }
    let counts: [String: Int]?
    let kinds: [String: String]?
    let groups: Groups
    let web: String?

    func countries(_ dir: String) -> [EmbassyCountry] { (dir == "out" ? groups.outside : groups.inside) ?? [] }
}

struct EmbassyDetail: Decodable, Sendable {
    let row: EmbassyRow
    let countryInfo: EmbassyCountryInfo?
    let phones: [EmbassyPhone]
    let consularPhones: [EmbassyPhone]
    let emergencyPhones: [EmbassyPhone]
    let email: String?
    let telegram: String?
    let hours: String?
    let consularHours: String?
    let services: String?
    let coversInfo: [EmbassyCountryInfo]
    let related: [EmbassyRow]
    let same: [EmbassyRow]
    let sources: [String]
    let checked: String?
    let web: String?

    private enum CodingKeys: String, CodingKey {
        case countryInfo, phones, consularPhones, emergencyPhones, email, telegram, hours, consularHours, services, coversInfo, related, same, sources, checked, web
    }
    init(from decoder: Decoder) throws {
        row = try EmbassyRow(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        countryInfo = try? c.decode(EmbassyCountryInfo.self, forKey: .countryInfo)
        phones = (try? c.decode([EmbassyPhone].self, forKey: .phones)) ?? []
        consularPhones = (try? c.decode([EmbassyPhone].self, forKey: .consularPhones)) ?? []
        emergencyPhones = (try? c.decode([EmbassyPhone].self, forKey: .emergencyPhones)) ?? []
        email = try? c.decode(String.self, forKey: .email)
        telegram = try? c.decode(String.self, forKey: .telegram)
        hours = try? c.decode(String.self, forKey: .hours)
        consularHours = try? c.decode(String.self, forKey: .consularHours)
        services = try? c.decode(String.self, forKey: .services)
        coversInfo = (try? c.decode([EmbassyCountryInfo].self, forKey: .coversInfo)) ?? []
        related = (try? c.decode([EmbassyRow].self, forKey: .related)) ?? []
        same = (try? c.decode([EmbassyRow].self, forKey: .same)) ?? []
        sources = (try? c.decode([String].self, forKey: .sources)) ?? []
        checked = try? c.decode(String.self, forKey: .checked)
        web = try? c.decode(String.self, forKey: .web)
    }
}

// MARK: - Yordamchilar

enum EmbassyStyle {
    /// Vakolatxona turi rangi
    static func color(_ kind: String) -> Color {
        switch kind {
        case "embassy": Theme.accent
        case "consulate_general", "consulate": Theme.teal
        case "consular_office": Theme.gold
        case "mission": Theme.ink2
        default: Theme.muted                       // honorary
        }
    }
    static func symbol(_ kind: String) -> String {
        switch kind {
        case "embassy": "building.columns.fill"
        case "consulate_general", "consulate", "consular_office": "building.2.fill"
        case "mission": "globe"
        default: "person.crop.circle.badge.checkmark"
        }
    }
    static func dirTitle(_ dir: String) -> String {
        dir == "out" ? tr("Xorijda", "За рубежом", "Abroad") : tr("Oʻzbekistonda", "В Узбекистане", "In Uzbekistan")
    }
    static func dirLong(_ dir: String) -> String {
        dir == "out" ? tr("Oʻzbekistonning xorijdagi vakolatxonasi", "Представительство Узбекистана за рубежом", "Uzbek mission abroad")
                     : tr("Oʻzbekistondagi vakolatxona", "Представительство в Узбекистане", "Mission in Uzbekistan")
    }

    /// Qidiruv so'rovi → kalit bilan bir xil ko'rinish (server `key`: kichik harf, apostrofsiz, «й» → «и», tinish belgisiz)
    static func tokens(_ q: String) -> [String] {
        var s = q.lowercased()
        for (a, b) in [("й", "и"), ("ё", "е"), ("ʻ", ""), ("ʼ", ""), ("'", ""), ("`", ""), ("‘", ""), ("’", "")] { s = s.replacingOccurrences(of: a, with: b) }
        s = String(s.map { $0.isLetter || $0.isNumber ? $0 : " " })
        return s.split(separator: " ").map(String.init)
    }

    /// Server URL'i (http ham bo'lishi mumkin) — faqat http/https va xost bilan
    static func web(_ s: String?) -> URL? {
        guard let s, let u = URL(string: s), let sc = u.scheme?.lowercased(), sc == "https" || sc == "http", u.host?.isEmpty == false else { return nil }
        return u
    }
    static func domain(_ u: URL) -> String {
        var h = u.host ?? u.absoluteString
        if h.hasPrefix("www.") { h.removeFirst(4) }
        return h
    }
    static func tel(_ p: EmbassyPhone) -> URL? {
        let d = p.tel.filter { $0.isNumber || $0 == "+" }
        return d.count >= 3 ? URL(string: "tel:" + d) : nil
    }
    /// "2026-11-03" → "03.11.2026"
    static func date(_ s: String) -> String { s.split(separator: "-").reversed().joined(separator: ".") }
}

/// Tur belgisi (kichik kapsula)
struct EmbassyKindBadge: View {
    let kind: String
    let label: String?
    var body: some View {
        let c = EmbassyStyle.color(kind)
        Text(label ?? kind)
            .font(Theme.Font.caption.weight(.semibold))
            .foregroundStyle(c)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(c.opacity(0.13), in: Capsule())
            .lineLimit(1)
    }
}

/// Ro'yxat qatori: tur, nom, shahar · manzil, telefon (alohida qo'ng'iroq tugmasi)
struct EmbassyRowView: View {
    let row: EmbassyRow
    var showFlag: String? = nil
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            NavigationLink(value: Route.embassy(row.slug)) {
                HStack(alignment: .top, spacing: 12) {
                    if let f = showFlag {
                        Text(f).font(.system(size: 28)).frame(width: 36).accessibilityHidden(true)
                    } else {
                        Image(systemName: EmbassyStyle.symbol(row.kind))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(EmbassyStyle.color(row.kind))
                            .frame(width: 36, height: 36)
                            .background(EmbassyStyle.color(row.kind).opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        EmbassyKindBadge(kind: row.kind, label: row.kindLabel)
                        Text(row.name).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        let place = [row.city, row.address].compactMap { $0?.isEmpty == false ? $0 : nil }
                        if !place.isEmpty {
                            Text(place.count == 2 && row.address!.contains(row.city!) ? row.address! : place.joined(separator: " · "))
                                .font(Theme.Font.caption).foregroundStyle(Theme.muted)
                                .lineLimit(2).multilineTextAlignment(.leading)
                        }
                        if let p = row.phone {
                            Label(p.value, systemImage: "phone").font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.ink2).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.press)
            if let p = row.phone, let u = EmbassyStyle.tel(p) {
                Button { Haptics.tap(); model.openURL(u) } label: {
                    Image(systemName: "phone.fill").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                        .background(Theme.accent.opacity(0.12), in: Circle())
                }
                .buttonStyle(.press)
                .accessibilityLabel(tr("Qoʻngʻiroq qilish: \(p.value)", "Позвонить: \(p.value)", "Call \(p.value)"))
            }
        }
        .padding(.vertical, 10)
    }
}
