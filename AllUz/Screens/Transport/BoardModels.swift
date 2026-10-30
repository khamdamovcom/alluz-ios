// Aeroport tablosi ma'lumoti: /api/board javobi (transport.js apiBoard), aeroportlar ro'yxati, holat ranglari, vaqt formatlari,
// ro'yxat qurilishi (o'tgan / hozir / keyingi). Ekranlar: BoardScreen, BoardFlightSheet, TransportHub.
import SwiftUI

// MARK: - API javobi

/// GET /api/board?airport=TAS&dir=dep|arr&day=yesterday|today|tomorrow
struct BoardResponse: Decodable, Sendable {
    let airport: String
    let dir: String
    let day: String
    let date: String?
    /// ok | stale (40 daqiqadan eski) | pending (hali olinmagan) | error | unsupported (manba bu kunni bermaydi)
    let state: String?
    let updatedAt: String?
    let source: String?
    /// «Kecha» ro'yxati sayt kuzatgan reyslardan (to'liq bo'lmasligi mumkin)
    let observed: Bool?
    let flights: [BoardFlight]
}

struct BoardFlight: Decodable, Hashable, Identifiable, Sendable {
    struct Airline: Decodable, Hashable, Sendable { let code: String?; let name: String? }
    struct Other: Decodable, Hashable, Sendable { let iata: String?; let city: String? }

    let key: String
    let flight: String
    let airline: Airline?
    let direction: String?
    let airport: String?
    let other: Other?
    let scheduled: String
    let estimated: String?
    let actual: String?
    let status: String?
    let statusText: String?
    let statusLabel: String?
    let terminal: String?
    let gate: String?
    let desks: String?
    let belt: String?
    let aircraft: String?
    let codeshares: [String]
    /// Shahar nomi joriy tilda (server tarjima qilgan)
    let city: String?
    let past: Bool
    let removedFromSource: Bool
    var id: String { key }

    private enum K: String, CodingKey {
        case key, flight, airline, direction, airport, other, scheduled, estimated, actual, status, statusText, statusLabel
        case terminal, gate, desks, belt, aircraft, codeshares, city, past, removedFromSource
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        key = try c.decode(String.self, forKey: .key)
        flight = c.loose(.flight) ?? key
        airline = try? c.decodeIfPresent(Airline.self, forKey: .airline)
        direction = c.loose(.direction)
        airport = c.loose(.airport)
        other = try? c.decodeIfPresent(Other.self, forKey: .other)
        scheduled = c.loose(.scheduled) ?? ""
        estimated = c.loose(.estimated)
        actual = c.loose(.actual)
        status = c.loose(.status)
        statusText = c.loose(.statusText)
        statusLabel = c.loose(.statusLabel)
        terminal = c.loose(.terminal)
        gate = c.loose(.gate)
        desks = c.loose(.desks)
        belt = c.loose(.belt)
        aircraft = c.loose(.aircraft)
        codeshares = ((try? c.decodeIfPresent([String].self, forKey: .codeshares)) ?? nil)?.filter { !$0.isEmpty } ?? []
        city = c.loose(.city)
        past = ((try? c.decodeIfPresent(Bool.self, forKey: .past)) ?? nil) ?? false
        removedFromSource = ((try? c.decodeIfPresent(Bool.self, forKey: .removedFromSource)) ?? nil) ?? false
    }
}

private extension KeyedDecodingContainer {
    /// Matn yoki son — bo'sh bo'lsa nil (terminal/gate ba'zan son bo'lib keladi)
    func loose(_ k: Key) -> String? {
        if let s = try? decodeIfPresent(String.self, forKey: k) { let t = s.trimmingCharacters(in: .whitespaces); return t.isEmpty ? nil : t }
        if let n = try? decodeIfPresent(Double.self, forKey: k) { return n.rounded() == n && abs(n) < 1e15 ? String(Int(n)) : String(n) }
        return nil
    }
}

// MARK: - Tanlovlar

enum BoardDir: String, CaseIterable, Identifiable, Sendable {
    case dep, arr
    var id: String { rawValue }
    var title: String { self == .dep ? tr("Uchib ketish", "Вылет", "Departures") : tr("Qoʻnish", "Прилёт", "Arrivals") }
    var symbol: String { self == .dep ? "airplane.departure" : "airplane.arrival" }
    /// Ustun nomi: Qayerga / Qayerdan
    var cityLabel: String { self == .dep ? tr("Qayerga", "Куда", "To") : tr("Qayerdan", "Откуда", "From") }
}

enum BoardDay: String, CaseIterable, Identifiable, Sendable {
    case yesterday, today, tomorrow
    var id: String { rawValue }
    var title: String {
        switch self {
        case .yesterday: tr("Kecha", "Вчера", "Yesterday")
        case .today: tr("Bugun", "Сегодня", "Today")
        case .tomorrow: tr("Ertaga", "Завтра", "Tomorrow")
        }
    }
}

// MARK: - Aeroportlar (tablosi bor 16 ta — sayt BOARD_AIRPORTS tartibida)

struct BoardAirport: Hashable, Identifiable, Sendable {
    let iata: String
    let slug: String
    let region: String
    let city: String
    let name: String
    var id: String { iata }

    /// Darhol ko'rsatish uchun (tarmoqsiz). Server nomlari (home.airports) kelgach — BoardAirportStore almashtiradi.
    static var builtIn: [BoardAirport] {
        let rows: [(String, String, String, String, String, String)] = [
            ("TAS", "toshkent-aeroporti", "toshkent-shahri", "Toshkent", "Ташкент", "Tashkent"),
            ("SKD", "samarqand-aeroporti", "samarqand", "Samarqand", "Самарканд", "Samarkand"),
            ("BHK", "buxoro-aeroporti", "buxoro", "Buxoro", "Бухара", "Bukhara"),
            ("UGC", "urganch-aeroporti", "xorazm", "Urganch", "Ургенч", "Urgench"),
            ("NCU", "nukus-aeroporti", "qoraqalpogiston", "Nukus", "Нукус", "Nukus"),
            ("NMA", "namangan-aeroporti", "namangan", "Namangan", "Наманган", "Namangan"),
            ("AZN", "andijon-aeroporti", "andijon", "Andijon", "Андижан", "Andijan"),
            ("FEG", "fargona-aeroporti", "fargona", "Fargʻona", "Фергана", "Fergana"),
            ("KSQ", "qarshi-aeroporti", "qashqadaryo", "Qarshi", "Карши", "Karshi"),
            ("TMJ", "termiz-aeroporti", "surxondaryo", "Termiz", "Термез", "Termez"),
            ("NVI", "navoiy-aeroporti", "navoiy", "Navoiy", "Навои", "Navoi"),
            ("OMN", "zomin-aeroporti", "jizzax", "Zomin", "Зомин", "Zomin"),
            ("OQN", "qoqon-aeroporti", "fargona", "Qoʻqon", "Коканд", "Kokand"),
            ("RBZ", "shahrisabz-aeroporti", "qashqadaryo", "Shahrisabz", "Шахрисабз", "Shahrisabz"),
            ("IYO", "sariosiyo-aeroporti", "surxondaryo", "Sariosiyo", "Сариасия", "Sariosiyo"),
            ("MOK", "moynoq-aeroporti", "qoraqalpogiston", "Moʻynoq", "Муйнак", "Muynak"),
        ]
        return rows.map { r in
            let city = tr(r.3, r.4, r.5)
            return BoardAirport(iata: r.0, slug: r.1, region: r.2, city: city,
                                name: tr("\(city) aeroporti", "Аэропорт \(city)", "\(city) Airport"))
        }
    }

    static let storeKey = "board.airport"
    /// Route'dagi IATA → o'sha; bo'lmasa oxirgi tanlangan; bo'lmasa TAS
    static func resolve(_ iata: String?) -> String {
        if let i = iata?.uppercased(), i.count == 3, i.allSatisfy({ $0.isLetter }) { return i }
        if let s = UserDefaults.standard.string(forKey: storeKey), s.count == 3 { return s }
        return "TAS"
    }
}

/// Aeroport nomlari serverdan (home.airports, joriy tilda) — bir marta yuklanadi, hamma ekranlar ulashadi
@MainActor @Observable
final class BoardAirportStore {
    static let shared = BoardAirportStore()
    private(set) var airports: [BoardAirport] = BoardAirport.builtIn
    private var loadedLang: Lang?
    private var loading = false

    func ensure() async {
        let lang = Lang.current
        if loadedLang == lang || loading { return }
        if loadedLang != nil { airports = BoardAirport.builtIn }   // til almashdi
        loading = true
        defer { loading = false }
        guard let home: HomeData = try? await API.shared.get("home"), !home.airports.isEmpty else { return }
        let built = Dictionary(uniqueKeysWithValues: BoardAirport.builtIn.map { ($0.iata, $0) })
        let order = BoardAirport.builtIn.map(\.iata)
        let server = home.airports.map { a -> BoardAirport in
            let b = built[a.iata]
            return BoardAirport(iata: a.iata, slug: a.slug, region: a.region ?? b?.region ?? "", city: a.city ?? b?.city ?? a.iata, name: a.name)
        }
        // Tablosi borlari (builtIn tartibi) — server ro'yxatida bo'lmasa ham qoladi
        var out = order.compactMap { i in server.first { $0.iata == i } ?? built[i] }
        out += server.filter { !order.contains($0.iata) }
        airports = out
        loadedLang = lang
    }
    func airport(_ iata: String) -> BoardAirport? { airports.first { $0.iata == iata } }
}

// MARK: - Holat rangi

enum BoardTone: Hashable, Sendable {
    case onTime, info, boarding, warn, bad, done, neutral
    var color: Color {
        switch self {
        case .onTime: Theme.ok
        case .info: Theme.teal
        case .boarding: Theme.accent
        case .warn: Theme.warn
        case .bad: Theme.bad
        case .done, .neutral: Theme.muted
        }
    }

    /// Sayt TONE jadvali asosida: o'z vaqtida — yashil, kechikadi — sariq, bekor — qizil, uchdi/qo'ndi — kulrang
    static func of(_ status: String?) -> BoardTone {
        switch status ?? "" {
        case "scheduled": .onTime
        case "checkin": .info
        case "boarding": .boarding
        case "gate-closed", "delayed": .warn
        case "cancelled", "diverted": .bad
        case "departed", "arrived": .done
        default: .neutral
        }
    }
}

// MARK: - Vaqt (O'zbekiston vaqti, Asia/Tashkent) — formatlar bir marta yaratiladi

enum BoardTime {
    static let tz = TimeZone(identifier: "Asia/Tashkent") ?? .current
    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()
    private static let hm: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm"; f.timeZone = tz; return f
    }()
    private static let ymd: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; f.timeZone = tz; return f
    }()
    private static let dm: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "dd.MM"; f.timeZone = tz; return f
    }()

    static func parse(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        return iso.date(from: s) ?? isoFrac.date(from: s)
    }
    static func time(_ d: Date) -> String { hm.string(from: d) }
    static func ymd(_ d: Date) -> String { ymd.string(from: d) }
    static func dayMonth(_ d: Date) -> String { dm.string(from: d) }
    /// Ikki vaqt orasidagi kalendar kuni farqi (Toshkent bo'yicha)
    static func dayShift(_ a: Date, _ b: Date) -> Int {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return cal.dateComponents([.day], from: cal.startOfDay(for: a), to: cal.startOfDay(for: b)).day ?? 0
    }
    /// «2026-10-30» → Date (Toshkent yarim tuni)
    static func date(ymd s: String?) -> Date? { s.flatMap { ymd.date(from: $0) } }
}

/// Qidiruv uchun: kichik harf, diakritikasiz, tutuq belgilarisiz (sayt norm() bilan bir xil)
enum BoardSearch {
    static func norm(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil).lowercased()
            .replacingOccurrences(of: "[ʻʼ'’‘`´]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Ko'rinish uchun tayyor qator (body ichida hisob yo'q)

struct BoardInfoBit: Hashable, Sendable {
    let symbol: String
    let label: String     // «Chiqish», «Terminal» …
    let value: String
}

struct BoardItem: Identifiable, Hashable, Sendable {
    let f: BoardFlight
    var id: String { f.key }
    let sched: Date?
    let eff: Date?
    let timeText: String
    /// Yangi vaqt (rejadagidan farq qilsa)
    let newTimeText: String?
    /// Yangi vaqt boshqa kunda (+1 / −1)
    let newShift: Int
    /// Yangi vaqt rejadagidan erta (yashil) yoki kech (sariq)
    let early: Bool
    let tone: BoardTone
    let label: String
    let city: String
    let otherIata: String?
    let airline: String
    let past: Bool
    let cancelled: Bool
    let bits: [BoardInfoBit]
    let search: String

    init(_ f: BoardFlight, dir: BoardDir) {
        self.f = f
        let s = BoardTime.parse(f.scheduled)
        let alt = BoardTime.parse(f.actual) ?? BoardTime.parse(f.estimated)
        sched = s
        eff = alt ?? s
        timeText = s.map(BoardTime.time) ?? "—"
        if let s, let alt, Int((alt.timeIntervalSince(s) / 60).rounded()) != 0 {
            newTimeText = BoardTime.time(alt)
            newShift = BoardTime.dayShift(s, alt)
            early = alt < s
        } else { newTimeText = nil; newShift = 0; early = false }
        var tone = BoardTone.of(f.status)
        // Rejadagi holat, lekin vaqti ancha surilgan — sariq (sayt ham yangi vaqtni ajratib ko'rsatadi)
        if tone == .onTime, let s, let alt, alt.timeIntervalSince(s) >= 30 * 60 { tone = .warn }
        self.tone = tone
        label = f.statusLabel ?? f.statusText ?? "—"
        city = f.city ?? f.other?.city ?? f.other?.iata ?? "—"
        otherIata = f.other?.iata
        airline = f.airline?.name ?? f.airline?.code ?? ""
        past = f.past
        cancelled = f.status == "cancelled"
        var b: [BoardInfoBit] = []
        if let t = f.terminal { b.append(.init(symbol: "building.2", label: tr("Terminal", "Терминал", "Terminal"), value: t)) }
        if dir == .dep {
            if let d = f.desks { b.append(.init(symbol: "person.badge.clock", label: tr("Stoyka", "Стойки", "Check-in"), value: d)) }
            if let g = f.gate { b.append(.init(symbol: "door.left.hand.open", label: tr("Chiqish", "Выход", "Gate"), value: g)) }
        } else if let l = f.belt {
            b.append(.init(symbol: "suitcase.rolling", label: tr("Lenta", "Лента", "Belt"), value: l))
        }
        bits = b
        let parts = [f.flight, f.flight.replacingOccurrences(of: " ", with: "")] + f.codeshares + f.codeshares.map { $0.replacingOccurrences(of: " ", with: "") }
            + [f.airline?.name, f.airline?.code, f.city, f.other?.city, f.other?.iata].compactMap { $0 }
        search = BoardSearch.norm(parts.joined(separator: " "))
    }

    /// VoiceOver uchun to'liq jumla
    func voiceLabel(dir: BoardDir) -> String {
        var s = [f.flight, airline, "\(dir.cityLabel) \(city)", "\(tr("jadval boʻyicha", "по расписанию", "scheduled")) \(timeText)"]
        if let n = newTimeText { s.append("\(tr("yangi vaqt", "новое время", "new time")) \(n)") }
        s.append(label)
        s += bits.map { "\($0.label) \($0.value)" }
        return s.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// Ekrandagi ro'yxat: bugun — o'tganlar (xira) + «hozir» chizig'i + keyingilar; boshqa kunlar — jadval tartibida
struct BoardList: Sendable {
    var past: [BoardItem] = []
    var upcoming: [BoardItem] = []
    var total = 0
    var showsNow = false

    static let empty = BoardList()

    static func make(_ r: BoardResponse, dir: BoardDir, day: BoardDay, query: String) -> BoardList {
        let all = r.flights.map { BoardItem($0, dir: dir) }
        let q = BoardSearch.norm(query)
        let list = q.isEmpty ? all : all.filter { $0.search.contains(q) }
        var out = BoardList(total: all.count)
        let far = Date.distantFuture
        if day == .today {
            out.showsNow = true
            out.past = list.filter(\.past).sorted { ($0.eff ?? far, $0.f.flight) < ($1.eff ?? far, $1.f.flight) }
            out.upcoming = list.filter { !$0.past }.sorted { ($0.eff ?? far, $0.f.flight) < ($1.eff ?? far, $1.f.flight) }
        } else {
            out.upcoming = list.sorted { ($0.sched ?? far, $0.f.flight) < ($1.sched ?? far, $1.f.flight) }
        }
        return out
    }
    var isEmpty: Bool { past.isEmpty && upcoming.isEmpty }
    func item(_ id: String) -> BoardItem? { upcoming.first { $0.id == id } ?? past.first { $0.id == id } }
}

extension Theme.Font {
    /// Tablo vaqti — katta, bir xil kenglikdagi raqamlar (Dynamic Type bilan)
    static let boardTime = SwiftUI.Font.system(.title3, design: .monospaced).weight(.bold)
    static let boardTimeSmall = SwiftUI.Font.system(.caption, design: .monospaced).weight(.medium)
    static let boardCode = SwiftUI.Font.system(.caption, design: .monospaced).weight(.semibold)
    static let boardCaption2Bold = SwiftUI.Font.caption2.weight(.bold)
}
