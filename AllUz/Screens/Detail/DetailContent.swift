// Tafsilot sahifasining tayyor ma'lumoti: Item → DetailContent (yuklash paytida, asosiy oqimdan tashqarida bir marta hisoblanadi).
// body ichida hech qanday JSON tahlili yo'q — ko'rinishlar faqat shu tayyor ro'yxatlarni chizadi.
// Har bir maydon ixtiyoriy: yo'q yoki noto'g'ri bo'lsa — shunchaki ko'rsatilmaydi (hech qachon qulamaydi).
import Foundation

// MARK: - Qismlar

/// Bosilganda nima bo'ladi
enum DetailTap: Hashable, Sendable {
    case url(URL)
    case route(Route)
    case card(Card)
}

struct DetailFact: Identifiable, Hashable, Sendable {
    let id: String
    let symbol: String
    let label: String
    let value: String
    var tap: DetailTap? = nil
    var mono = false
}

struct DetailChip: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    var symbol: String? = nil
    var tap: DetailTap? = nil
}

struct DetailChipGroup: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let symbol: String
    let chips: [DetailChip]
}

/// Maqola bloki: sarlavha yoki paragraf
struct DetailBlock: Identifiable, Hashable, Sendable {
    let id: Int
    let heading: Bool
    let text: String
}

struct DetailPair: Identifiable, Hashable, Sendable {
    let id: Int
    let label: String
    let value: String
}

struct DetailSource: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let domain: String
    let path: String
}

struct DetailEvent: Identifiable, Hashable, Sendable {
    let id: String
    let when: String
    let title: String
    let text: String?
    let cards: [Card]
}

struct DetailStop: Identifiable, Hashable, Sendable {
    let id: Int
    let text: String
    let regionName: String?
    let region: String?
    let place: Card?
}

struct DetailDay: Identifiable, Hashable, Sendable {
    let id: Int          // kun raqami (0 — kunsiz)
    let stops: [DetailStop]
}

struct DetailTrainStop: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let arr: String?
    let dep: String?
    let dayOffset: Int
}

struct DetailMetroLine: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let note: String?
    let color: UInt32?
    let opened: Int?
    let stations: [String]
}

struct DetailBranch: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let address: String?
    let hours: String?
    let phone: String?
    let phoneURL: URL?
    let directions: URL?
}

struct DetailApp: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let ios: URL?
    let android: URL?
}

struct DetailRail: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    var kicker: String? = nil
    let cards: [Card]
    var more: ListSpec? = nil
    var portrait = false
}

struct DetailCount: Identifiable, Hashable, Sendable {
    let id: String
    let symbol: String
    let label: String
    let value: Int
    let spec: ListSpec
}

/// Tezkor amal (shisha tugmalar qatori)
enum DetailQuick: Hashable, Sendable, Identifiable {
    case directions(URL), call(URL), web(URL), telegram(URL), instagram(URL), mail(URL), board(String), railBoard(String)
    var id: String {
        switch self {
        case .directions: "dir"; case .call: "call"; case .web: "web"; case .telegram: "tg"; case .instagram: "ig"
        case .mail: "mail"; case .board: "board"; case .railBoard: "rail"
        }
    }
}

/// Sahifa bo'limlari (tartib bilan)
enum DetailPart: Hashable, Sendable {
    case title, actions, lead, facts, board, counts, info, chips, body, highlights, notes, tips
    case season, itinerary, timeline, train, metro, branches, apps, contacts, location
    case rail(Int), districts, places, disclaimer, sources
}

// MARK: - Tayyor sahifa

struct DetailContent: Sendable {
    let item: Item
    let title: String
    let kicker: String          // sarlavha ustidagi kichik yozuv
    let tagline: String?        // shior / rol
    let typeSymbol: String
    let images: [Img]
    let lat: Double?
    let lon: Double?
    let mapSpan: Double
    let address: String?
    let regionCard: Card?
    let districtCard: Card?
    let regionLabel: String?
    let districtLabel: String?

    var quick: [DetailQuick] = []
    var lead: String?
    var facts: [DetailFact] = []        // qisqa — 2 ustunli katak
    var rows: [DetailFact] = []         // uzun — to'liq kenglikdagi qatorlar (ish vaqti, chipta …)
    var info: [DetailPair] = []         // text.facts — «Qisqacha»
    var chips: [DetailChipGroup] = []
    var blocks: [DetailBlock] = []
    var collapsedCount: Int?            // uzun maqola: yig'ilganda nechta blok ko'rinadi
    var readMinutes = 0
    var highlights: [String] = []
    var notes: [DetailFact] = []
    var tips: [String] = []
    var season: Set<Int> = []
    var days: [DetailDay] = []
    var events: [DetailEvent] = []
    var trainStops: [DetailTrainStop] = []
    var metroLines: [DetailMetroLine] = []
    var branches: [DetailBranch] = []
    var apps: [DetailApp] = []
    var contacts: [DetailFact] = []
    var rails: [DetailRail] = []
    var districts: [Card] = []
    var counts: [DetailCount] = []
    var boardIATA: String?
    var railStation: String?
    var disclaimer: String?
    var sources: [DetailSource] = []
    var locationCards: [Card] = []
    var parts: [DetailPart] = []

    var hasCoords: Bool { lat != nil && lon != nil }

    static func load(_ ref: ItemRef) async throws -> DetailContent {
        let slug = ref.slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))) ?? ref.slug
        let type = ref.type.filter { $0.isLetter || $0 == "_" }
        let item: Item = try await API.shared.get("item/\(type)/\(slug)")
        return DetailContent(item)
    }
}

// MARK: - JSON yordamchilari

enum DetailJSON {
    /// Matn yoki son → tozalangan matn (bo'sh bo'lsa nil; bool — nil)
    static func str(_ v: JSONValue?) -> String? {
        switch v {
        case .string(let s)?:
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        case .number?: return v?.string
        default: return nil
        }
    }
    static func int(_ v: JSONValue?) -> Int? {
        guard let d = v?.double, d.isFinite, abs(d) < 1e12 else { return nil }
        return Int(d)
    }
    static func double(_ v: JSONValue?) -> Double? {
        guard let d = v?.double, d.isFinite else { return nil }
        return d
    }
    static func strs(_ v: JSONValue?) -> [String] {
        switch v {
        case .array(let a)?: return a.compactMap { str($0) }
        case .string?: return str(v).map { [$0] } ?? []
        default: return []
        }
    }
    static func cards(_ v: JSONValue?) -> [Card] {
        guard case .array(let a)? = v else { return [] }
        return a.compactMap { $0.decode(Card.self) }
    }
    /// [{h, p}] — p matn yoki matnlar massivi bo'lishi mumkin
    static func sections(_ v: JSONValue?) -> [(String?, [String])] {
        guard case .array(let a)? = v else { return [] }
        return a.compactMap { s in
            if case .string(let p) = s { return p.isEmpty ? nil : (nil, [p]) }
            let ps = strs(s["p"])
            let h = str(s["h"])
            return h == nil && ps.isEmpty ? nil : (h, ps)
        }
    }
    /// [[label, value]] yoki [{label, value}]
    static func pairs(_ v: JSONValue?) -> [(String, String)] {
        guard case .array(let a)? = v else { return [] }
        return a.compactMap { p in
            if case .array(let x) = p, x.count >= 2, let l = str(x[0]), let r = str(x[1]) { return (l, r) }
            if case .object(let o) = p, let l = str(o["label"] ?? o["k"]), let r = str(o["value"] ?? o["v"]) { return (l, r) }
            return nil
        }
    }
    static func coord(_ v: JSONValue?) -> (Double, Double)? {
        guard let a = v?.array, a.count == 2, let la = double(a[0]), let lo = double(a[1]), validCoord(la, lo) else { return nil }
        return (la, lo)
    }
    static func validCoord(_ lat: Double, _ lon: Double) -> Bool {
        abs(lat) <= 90 && abs(lon) <= 180 && !(lat == 0 && lon == 0)
    }
    /// ISO sana → «20 oktabr 2026»
    static func date(_ s: String?) -> String? {
        guard let s, let d = Fmt.date(s) else { return nil }
        let f = DateFormatter(); f.locale = Lang.current.locale; f.timeZone = TimeZone(identifier: "Asia/Tashkent")
        f.setLocalizedDateFormatFromTemplate("dMMMMy")
        return f.string(from: d)
    }
    /// oy + kun → «1 yanvar»
    static func dayMonth(_ m: Int, _ d: Int) -> String? {
        guard (1...12).contains(m), (1...31).contains(d) else { return nil }
        var c = DateComponents(); c.year = 2024; c.month = m; c.day = d
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Tashkent") ?? .current
        guard let date = cal.date(from: c) else { return nil }
        return Fmt.day(date)
    }
}

// MARK: - Qurish

extension DetailContent {
    init(_ it: Item) {
        let d = it.data, t = it.text
        item = it
        images = it.images.filter { !$0.u.isEmpty }

        // Sarlavha (server ba'zan slug qaytaradi — metro, avtobus qatnovi)
        var name = it.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if it.type == "metro", name == it.slug {
            name = it.slug == "toshkent" ? tr("Toshkent metrosi", "Ташкентский метрополитен", "Tashkent Metro") : DetailLabels.humanize(name) + " · Metro"
        }
        if it.type == "bus_route", name == it.slug || name.isEmpty {
            let a = DetailJSON.str(d["from_city"]), b = DetailJSON.str(d["to_city"])
            if a != nil || b != nil { name = [a, b].compactMap { $0 }.joined(separator: " — ") }
        }
        if name.isEmpty { name = DetailJSON.str(t["name"]) ?? DetailJSON.str(t["title"]) ?? DetailLabels.type(it.type) }
        title = name

        // Kicker: server «sub» (tayyor matn), tarjima kaliti qolib ketgan bo'lsa — o'zimizniki
        if let s = it.sub, !s.isEmpty, !s.contains("search.t.") { kicker = s }
        else { kicker = [DetailLabels.type(it.type), it.regionName].compactMap { $0 }.joined(separator: " · ") }

        let kick = it.kicker ?? DetailJSON.str(t["kicker"]) ?? DetailJSON.str(t["role"])
        tagline = kick.flatMap { $0.isEmpty || $0 == name ? nil : $0 }
        typeSymbol = it.icon != nil ? SymbolMap.symbol(it.icon) : SymbolMap.forType(it.type)

        // Koordinata
        var la = it.lat, lo = it.lon
        if la == nil || lo == nil, let c = DetailJSON.coord(d["coords"]) ?? DetailJSON.coord(d["hq"]?["coords"]) { la = c.0; lo = c.1 }
        if let a = la, let b = lo, DetailJSON.validCoord(a, b) { lat = a; lon = b } else { lat = nil; lon = nil }
        mapSpan = it.type == "region" ? 2.6 : it.type == "district" ? 0.22 : 0.012
        address = DetailJSON.str(d["address"]) ?? DetailJSON.str(d["hq"]?["address"])

        regionCard = it.refs["region"]?.first
        districtCard = it.refs["district"]?.first
        regionLabel = it.regionName ?? regionCard?.name
        districtLabel = it.districtName ?? districtCard?.name

        var b = DetailBuilder(item: it)
        b.build()

        quick = b.quick
        lead = DetailJSON.str(t["summary"]) ?? DetailJSON.str(t["lead"]) ?? DetailJSON.str(d["info"]?["summary"]) ?? it.summary.flatMap { $0.isEmpty ? nil : $0 }
        facts = b.facts
        rows = b.rows
        chips = b.chips
        highlights = DetailJSON.strs(t["highlights"])
        notes = b.notes
        tips = DetailJSON.strs(t["tips"])
        season = b.season
        days = b.days
        events = b.events
        trainStops = b.trainStops
        metroLines = b.metroLines
        branches = b.branches
        apps = b.apps
        contacts = b.contacts
        rails = b.rails
        districts = it.sectionCards("districts")
        counts = b.counts
        boardIATA = b.boardIATA
        railStation = b.railStation
        disclaimer = b.disclaimer
        sources = Self.sources(d["sources"])
        locationCards = [districtCard, regionCard].compactMap { $0 }.filter { $0.ref != it.ref }

        // «Qisqacha» — text.facts (katakda bor qiymatlar takrorlanmaydi)
        let shown = Set((facts + rows).map(\.value))
        let rawPairs = DetailJSON.pairs(t["facts"]).isEmpty ? DetailJSON.pairs(d["info"]?["facts"]) : DetailJSON.pairs(t["facts"])
        info = rawPairs.enumerated().filter { !shown.contains($0.element.1) }.map { DetailPair(id: $0.offset, label: $0.element.0, value: $0.element.1) }

        // Maqola
        var secs = DetailJSON.sections(t["body"])
        if secs.isEmpty { secs = DetailJSON.sections(d["info"]?["body"]) }
        if secs.isEmpty, let one = DetailJSON.str(t["text"]) { secs = [(nil, [one])] }
        var bl: [DetailBlock] = []
        for (h, ps) in secs {
            if let h { bl.append(DetailBlock(id: bl.count, heading: true, text: h)) }
            for p in ps { bl.append(DetailBlock(id: bl.count, heading: false, text: p)) }
        }
        // Xulosa birinchi paragraf bilan bir xil bo'lsa — takrorlanmasin
        if let l = lead, let first = bl.first(where: { !$0.heading }), first.text == l, bl.count > 1 {
            bl.removeAll { $0.id == first.id }
            bl = bl.enumerated().map { DetailBlock(id: $0.offset, heading: $0.element.heading, text: $0.element.text) }
        }
        blocks = bl
        collapsedCount = Self.collapse(bl)
        let words = ([lead ?? ""] + bl.map(\.text) + tips).reduce(0) { $0 + $1.split(whereSeparator: \.isWhitespace).count }
        readMinutes = bl.isEmpty ? 0 : max(1, Int((Double(words) / 200).rounded()))

        parts = Self.order(self)
    }

    /// Uzun maqola (≈1600+ belgi) — boshidan ~700 belgi ko'rinadi, qolgani «Davomini o'qish»
    private static func collapse(_ bl: [DetailBlock]) -> Int? {
        let total = bl.reduce(0) { $0 + $1.text.count }
        guard total > 1600, bl.count > 2 else { return nil }
        var acc = 0, n = 0
        for b in bl {
            n += 1
            if !b.heading { acc += b.text.count }
            if acc >= 700 && !b.heading { break }
        }
        while n > 1, bl[n - 1].heading { n -= 1 }
        return n < bl.count - 1 ? n : nil
    }

    private static func sources(_ v: JSONValue?) -> [DetailSource] {
        var seen = Set<String>()
        return DetailJSON.strs(v).compactMap { s in
            guard let u = DetailLink.web(s), seen.insert(u.absoluteString).inserted else { return nil }
            var p = (u.path.removingPercentEncoding ?? u.path)
            if p == "/" { p = "" }
            if p.count > 42 { p = String(p.prefix(40)) + "…" }
            return DetailSource(id: u.absoluteString, url: u, domain: DetailLink.domain(u), path: p)
        }
        .prefix(30).map { $0 }
    }

    private static func order(_ c: DetailContent) -> [DetailPart] {
        var p: [DetailPart] = [.title]
        if !c.quick.isEmpty { p.append(.actions) }
        if c.lead != nil { p.append(.lead) }
        if !c.facts.isEmpty || !c.rows.isEmpty { p.append(.facts) }
        if c.boardIATA != nil || c.railStation != nil { p.append(.board) }
        if !c.counts.isEmpty { p.append(.counts) }
        if !c.season.isEmpty { p.append(.season) }
        if !c.info.isEmpty { p.append(.info) }
        if !c.chips.isEmpty { p.append(.chips) }
        if !c.blocks.isEmpty { p.append(.body) }
        if !c.highlights.isEmpty { p.append(.highlights) }
        if !c.notes.isEmpty { p.append(.notes) }
        if !c.tips.isEmpty { p.append(.tips) }
        if !c.days.isEmpty { p.append(.itinerary) }
        if !c.events.isEmpty { p.append(.timeline) }
        if !c.trainStops.isEmpty { p.append(.train) }
        if !c.metroLines.isEmpty { p.append(.metro) }
        if !c.apps.isEmpty { p.append(.apps) }
        if !c.contacts.isEmpty { p.append(.contacts) }
        if c.hasCoords || c.address != nil { p.append(.location) }
        if !c.branches.isEmpty { p.append(.branches) }
        for i in c.rails.indices { p.append(.rail(i)) }
        if !c.districts.isEmpty { p.append(.districts) }
        if !c.locationCards.isEmpty { p.append(.places) }
        if c.disclaimer != nil { p.append(.disclaimer) }
        if !c.sources.isEmpty { p.append(.sources) }
        return p
    }
}

// MARK: - Turga xos maydonlar

private struct DetailBuilder {
    let item: Item
    var d: JSONValue { item.data }
    var t: JSONValue { item.text }

    var quick: [DetailQuick] = []
    var facts: [DetailFact] = []
    var rows: [DetailFact] = []
    var chips: [DetailChipGroup] = []
    var notes: [DetailFact] = []
    var season: Set<Int> = []
    var days: [DetailDay] = []
    var events: [DetailEvent] = []
    var trainStops: [DetailTrainStop] = []
    var metroLines: [DetailMetroLine] = []
    var branches: [DetailBranch] = []
    var apps: [DetailApp] = []
    var contacts: [DetailFact] = []
    var rails: [DetailRail] = []
    var counts: [DetailCount] = []
    var boardIATA: String?
    var railStation: String?
    var disclaimer: String?
    private var used = Set<String>()

    init(item: Item) { self.item = item }

    /// Qisqa qiymat — katakka, uzun — qatorga
    mutating func fact(_ key: String, _ symbol: String, _ label: String, _ value: String?, tap: DetailTap? = nil, mono: Bool = false, row: Bool = false) {
        guard let value, !value.isEmpty, used.insert(key).inserted else { return }
        let f = DetailFact(id: key, symbol: symbol, label: label, value: value, tap: tap, mono: mono)
        if row || value.count > 30 { rows.append(f) } else { facts.append(f) }
    }
    mutating func chipGroup(_ id: String, _ title: String, _ symbol: String, _ list: [DetailChip]) {
        guard !list.isEmpty, used.insert("chips:" + id).inserted else { return }
        chips.append(DetailChipGroup(id: id, title: title, symbol: symbol, chips: list))
    }
    func s(_ k: String) -> String? { DetailJSON.str(d[k]) }
    func i(_ k: String) -> Int? { DetailJSON.int(d[k]) }

    mutating func build() {
        switch item.type {
        case "place": place()
        case "venue": venue()
        case "region", "district": area()
        case "person": person()
        case "airport": airport()
        case "org": org()
        case "bank": bank()
        case "post": post()
        case "fest": fest()
        case "holiday": holiday()
        case "route": route()
        case "guide": fact("updated", "clock.arrow.circlepath", tr("Yangilangan", "Обновлено", "Updated"), DetailJSON.date(s("updated")))
        case "era": era()
        case "hist_event": histEvent()
        case "rail_station": railStationInfo()
        case "train": train()
        case "bus_station": busStation()
        case "bus_route": busRoute()
        case "city_transport": cityTransport()
        case "metro": metro()
        default: break
        }
        common()
        refRails()
        quickActions()
    }

    // MARK: turlar

    mutating func place() {
        if let k = item.kind ?? s("category") { fact("category", "square.grid.2x2", tr("Turi", "Тип", "Type"), DetailLabels.category(k)) }
        if let era = item.refs["era"]?.first {
            fact("era", "hourglass", tr("Davr", "Эпоха", "Era"), era.name, tap: .card(era))
        }
        fact("built", "hammer", tr("Qurilgan", "Построен", "Built"), s("built"))
        if let m = i("duration_min"), m > 0 { fact("duration", "timer", tr("Koʻrish uchun", "На осмотр", "Time to visit"), "~" + Fmt.duration(minutes: m)) }
        fact("ticket", "ticket", tr("Chipta", "Билеты", "Tickets"), s("ticket"), row: true)
    }

    mutating func venue() {
        let kind = item.kind ?? s("kind")
        let stay = kind.map { DetailLabels.stayKinds.contains($0) } ?? true
        if let k = kind { fact("kind", stay ? "bed.double" : "fork.knife", tr("Turi", "Тип", "Type"), DetailLabels.venueKind(k)) }
        if let n = i("stars"), (1...5).contains(n) {
            fact("stars", "star", tr("Yulduz", "Звёздность", "Stars"), String(repeating: "★", count: n))
        }
        if let n = i("price"), let p = DetailLabels.price(n, stay: stay) {
            fact("price", "banknote", stay ? tr("Narx (kecha)", "Цена (ночь)", "Price (night)") : tr("Oʻrtacha hisob", "Средний чек", "Average bill"), p)
        }
        fact("checkin", "arrow.down.to.line", tr("Kirish", "Заезд", "Check-in"), s("checkin").map { tr("\($0) dan", "с \($0)", "from \($0)") })
        fact("checkout", "arrow.up.to.line", tr("Chiqish", "Выезд", "Check-out"), s("checkout").map { tr("\($0) gacha", "до \($0)", "until \($0)") })
        if let n = i("rooms"), n > 0 { fact("rooms", "door.left.hand.closed", tr("Xonalar", "Номеров", "Rooms"), Fmt.num(n)) }
        if let y = i("opened"), y > 1000 { fact("opened", "calendar", tr("Ochilgan", "Открыт", "Opened"), "\(y)") }
        let feats = DetailJSON.strs(d["features"]).map { k -> DetailChip in
            let (l, sym) = DetailLabels.feature(k); return DetailChip(id: k, label: l, symbol: sym)
        }
        chipGroup("features", tr("Qulayliklar", "Удобства", "Amenities"), "sparkles", feats)
        chipGroup("cuisine", tr("Oshxona", "Кухня", "Cuisine"), "fork.knife",
                  DetailJSON.strs(d["cuisine"]).map { DetailChip(id: $0, label: DetailLabels.cuisine($0)) })
        disclaimer = tr("Narx va ish vaqti oʻzgarishi mumkin — borishdan oldin telefon orqali aniqlang. Bron qilish shu yerda emas: joyning oʻzi bilan bogʻlaning.",
                        "Цены и часы работы могут меняться — уточняйте по телефону перед визитом. Бронирование — напрямую у заведения.",
                        "Prices and hours can change — call ahead before you go. We do not take bookings: contact the venue directly.")
    }

    mutating func area() {
        let isRegion = item.type == "region"
        if !isRegion, let k = s("type") { fact("dtype", "building.2", tr("Maqomi", "Статус", "Status"), DetailLabels.districtType(k)) }
        fact("capital", "building.columns", tr("Markaz", "Центр", "Capital"), s("capital") ?? s("center"))
        if let p = i("population"), p > 0 {
            let y = i("population_year").map { " (\($0))" } ?? ""
            fact("population", "person.3", tr("Aholisi", "Население", "Population"), Fmt.num(p) + y)
        }
        if let a = DetailJSON.double(d["area_km2"]), a > 0 {
            fact("area", "square.dashed", tr("Maydoni", "Площадь", "Area"), (a >= 100 ? Fmt.num(Int(a.rounded())) : Fmt.num(a, digits: 1)) + " km²")
        }
        if let y = i("founded") { fact("founded", "calendar", isRegion ? tr("Tashkil topgan", "Образована", "Established") : tr("Asos solingan", "Основан", "Founded"), DetailLabels.year(y)) }
        else { fact("founded", "calendar", tr("Asos solingan", "Основан", "Founded"), s("founded")) }
        let dc = item.sectionCards("districts").count
        if dc > 0 { fact("districts", "square.grid.3x3", tr("Shahar va tumanlar", "Города и районы", "Cities & districts"), "\(dc)") }
        fact("best_time", "sun.max", tr("Eng yaxshi vaqt", "Лучшее время", "Best time to go"), DetailJSON.str(t["best_time"]), row: true)

        // Ichidagilar: sonlar va karusellar
        let reg = isRegion ? item.slug : (item.region ?? s("region") ?? "")
        let dist: String? = isRegion ? nil : (s("dslug") ?? item.slug.components(separatedBy: "--").last)
        func spec(_ type: String, _ kind: String? = nil, _ title: String? = nil) -> ListSpec {
            ListSpec(type: type, region: reg.isEmpty ? nil : reg, district: dist, kind: kind, title: title)
        }
        if let c = item.counts {
            let all: [(String, String, String, String)] = [
                ("places", "building.columns", tr("Joylar", "Места", "Sights"), "place"),
                ("venues", "bed.double", tr("Tunash va ovqat", "Отели и еда", "Stay & eat"), "venue"),
                ("orgs", "building.2", tr("Idoralar", "Учреждения", "Offices"), "org"),
            ]
            counts = all.compactMap { k, sym, l, type in
                guard let n = c[k], n > 0 else { return nil }
                return DetailCount(id: k, symbol: sym, label: l, value: n, spec: spec(type, nil, "\(l) · \(item.name)"))
            }
        }
        let place = item.sectionCards("places"), stayC = item.sectionCards("stay"), eatC = item.sectionCards("eat"), pers = item.sectionCards("persons")
        if !place.isEmpty {
            rails.append(DetailRail(id: "s.places", title: tr("Diqqatga sazovor joylar", "Достопримечательности", "Top sights"), cards: place,
                                    more: spec("place", nil, tr("Joylar", "Места", "Sights") + " · " + item.name)))
        }
        if !stayC.isEmpty {
            rails.append(DetailRail(id: "s.stay", title: tr("Qayerda tunash", "Где остановиться", "Where to stay"), cards: stayC,
                                    more: spec("venue", "stay", tr("Qayerda tunash", "Где остановиться", "Where to stay") + " · " + item.name)))
        }
        if !eatC.isEmpty {
            rails.append(DetailRail(id: "s.eat", title: tr("Qayerda ovqatlanish", "Где поесть", "Where to eat"), cards: eatC,
                                    more: spec("venue", "eat", tr("Qayerda ovqatlanish", "Где поесть", "Where to eat") + " · " + item.name)))
        }
        if !pers.isEmpty {
            rails.append(DetailRail(id: "s.persons", title: tr("Shu yerlik allomalar", "Знаменитые уроженцы", "Notable people"), cards: pers, portrait: true))
        }
    }

    mutating func person() {
        let born = i("born"), died = i("died")
        if born != nil || died != nil {
            var v = [born.map(DetailLabels.year), died.map(DetailLabels.year)].map { $0 ?? "?" }.joined(separator: " – ")
            if let b = born, let e = died, e > b, e - b < 130 {
                let n = e - b
                v += " · " + tr("\(n) yosh", "\(n) " + DetailLabels.ruPlural(n, "год", "года", "лет"), "aged \(n)")
            }
            fact("life", "calendar", tr("Yashagan yillari", "Годы жизни", "Lived"), v)
        }
        if let f = s("field") ?? item.kind { fact("field", "graduationcap", tr("Soha", "Сфера", "Field"), DetailLabels.field(f)) }
    }

    mutating func airport() {
        let iata = s("iata")?.uppercased(), icao = s("icao")?.uppercased()
        if iata != nil || icao != nil {
            fact("codes", "airplane", "IATA / ICAO", [iata, icao].compactMap { $0 }.joined(separator: " / "), mono: true)
        }
        fact("city", "building.2", tr("Shahar", "Город", "City"), DetailJSON.str(t["city"]))
        if let iata, iata.count == 3, iata.allSatisfy({ $0.isLetter }) { boardIATA = iata }
    }

    mutating func org() {
        if let k = s("kind") ?? item.kind { fact("kind", "building.2", tr("Turi", "Тип", "Type"), DetailLabels.orgKind(k)) }
        if let l = s("level") { fact("level", "chart.bar.doc.horizontal", tr("Darajasi", "Уровень", "Level"), DetailLabels.orgLevel(l)) }
        fact("reception", "person.badge.clock", tr("Qabul", "Приём граждан", "Reception"), s("reception"), row: true)
    }

    mutating func bank() {
        if let o = s("ownership") { fact("own", "building.columns", tr("Turi", "Тип", "Type"), DetailLabels.ownership(o)) }
        if let y = i("founded") { fact("founded", "calendar", tr("Tashkil topgan", "Основан", "Founded"), "\(y)") }
        fact("swift", "globe", "SWIFT", s("swift"), mono: true)
        fact("mfo", "number", tr("MFO", "МФО", "Bank code (MFO)"), s("mfo"), mono: true)
        if let n = DetailJSON.str(d["license"]?["number"]) {
            let dt = DetailJSON.date(DetailJSON.str(d["license"]?["date"])).map { " · " + $0 } ?? ""
            fact("license", "checkmark.seal", tr("Litsenziya", "Лицензия", "Licence"), "№ \(n)" + dt)
        }
        chipGroup("cards", tr("Kartalar", "Карты", "Cards"), "creditcard",
                  DetailJSON.strs(d["cards"]).map { DetailChip(id: $0, label: DetailLabels.cardBrand($0)) })
        chipGroup("services", tr("Xizmatlar", "Услуги", "Services"), "checklist",
                  DetailJSON.strs(d["services"]).map { let (l, sym) = DetailLabels.bankService($0); return DetailChip(id: $0, label: l, symbol: sym) })
        chipGroup("transfers", tr("Pul oʻtkazmalari", "Денежные переводы", "Money transfers"), "arrow.left.arrow.right",
                  DetailJSON.strs(d["transfers"]).map { DetailChip(id: $0, label: $0) })
        if case .array(let a)? = d["apps"] {
            apps = a.enumerated().compactMap { n, v in
                guard let name = DetailJSON.str(v["name"]) else { return nil }
                let ios = DetailLink.appStore(DetailJSON.str(v["ios"])), and = DetailLink.web(DetailJSON.str(v["android"]))
                guard ios != nil || and != nil else { return nil }
                return DetailApp(id: "\(n)", name: name, ios: ios, android: and)
            }
        }
        if case .array(let a)? = d["branches"] {
            branches = a.prefix(200).enumerated().compactMap { n, v in
                guard let name = DetailJSON.str(v["name"]) ?? DetailJSON.str(v["address"]) else { return nil }
                let ph = DetailJSON.strs(v["phones"]).first
                let c = DetailJSON.coord(v["coords"])
                return DetailBranch(id: n, name: name, address: DetailJSON.str(v["address"]), hours: DetailJSON.str(v["hours"]),
                                    phone: ph.map(DetailLink.phoneText), phoneURL: DetailLink.tel(ph),
                                    directions: c.flatMap { DetailLink.directions(lat: $0.0, lon: $0.1) })
            }
        }
    }

    mutating func post() {
        fact("index", "envelope", tr("Indeks", "Индекс", "Postcode"), s("index"), mono: true)
        if let k = s("kind") ?? item.kind { fact("kind", "building", tr("Turi", "Тип", "Type"), DetailLabels.postKind(k)) }
        fact("settlement", "house", tr("Aholi punkti", "Населённый пункт", "Place"), s("settlement"))
        if let st = s("status") {
            fact("status", "checkmark.circle", tr("Holati", "Статус", "Status"), st == "faol" ? tr("Ishlayapti", "Работает", "Open") : DetailLabels.humanize(st))
        }
        chipGroup("services", tr("Xizmatlar", "Услуги", "Services"), "shippingbox",
                  DetailJSON.strs(d["services"]).map { DetailChip(id: $0, label: DetailLabels.postService($0)) })
    }

    mutating func fest() {
        if let m = i("month"), (1...12).contains(m) {
            let name = Fmt.month(m)
            fact("month", "calendar", tr("Oy", "Месяц", "Month"), name.prefix(1).uppercased() + name.dropFirst())
        }
        if let r = s("recurring") { fact("recurring", "repeat", tr("Takrorlanishi", "Периодичность", "Frequency"), DetailLabels.recurring(r)) }
        let start = DetailJSON.date(s("start")), end = DetailJSON.date(s("end"))
        if start != nil || end != nil {
            fact("dates", "calendar.badge.clock", tr("Sanalar", "Даты", "Dates"), [start, end].compactMap { $0 }.joined(separator: " – "))
        }
        if let p = item.refs["place"]?.first {
            fact("place", "mappin.and.ellipse", tr("Oʻtkaziladigan joy", "Место проведения", "Venue"), p.name, tap: .card(p))
        }
        if let w = DetailJSON.str(t["when"]) {
            notes.append(DetailFact(id: "when", symbol: "calendar.badge.clock", label: tr("Qachon", "Когда", "When"), value: w))
        }
    }

    mutating func holiday() {
        if let m = i("month"), let dd = i("day") {
            fact("date", "calendar", tr("Sana", "Дата", "Date"), DetailJSON.dayMonth(m, dd))
        } else if let m = i("month"), (1...12).contains(m) {
            fact("date", "calendar", tr("Oy", "Месяц", "Month"), Fmt.month(m))
        }
        if d["day_off"]?.bool == true {
            fact("dayoff", "bed.double", tr("Dam olish kuni", "Выходной день", "Day off"), tr("Ha", "Да", "Yes"))
        }
        if d["lunar"]?.bool == true {
            fact("lunar", "moon", tr("Taqvim", "Календарь", "Calendar"), tr("Hijriy taqvim", "Лунный (хиджра)", "Lunar (Hijri)"))
        }
    }

    mutating func route() {
        if let n = i("days"), n > 0 {
            fact("days", "calendar", tr("Davomiyligi", "Длительность", "Duration"),
                 tr("\(n) kun", "\(n) " + DetailLabels.ruPlural(n, "день", "дня", "дней"), n == 1 ? "1 day" : "\(n) days"))
        }
        if let th = s("theme") { fact("theme", "sparkles", tr("Mavzu", "Тема", "Theme"), DetailLabels.routeTheme(th)) }
        let regs = item.refs["regions"] ?? []
        if !regs.isEmpty { fact("regions", "map", tr("Hududlar", "Регионы", "Regions"), "\(regs.count)") }
        season = Set((d["best_season"]?.array ?? []).compactMap { DetailJSON.int($0) }.filter { (1...12).contains($0) })

        // Kun-baykun
        let regionNames = Dictionary(regs.compactMap { c in c.slug.map { ($0, c.name) } }, uniquingKeysWith: { a, _ in a })
        let placeCards = Dictionary((item.refs["stops"] ?? []).compactMap { c in c.slug.map { ($0, c) } }, uniquingKeysWith: { a, _ in a })
        guard case .array(let raw)? = d["stops"] else { return }
        var grouped: [(Int, [DetailStop])] = []
        for (n, v) in raw.enumerated() {
            guard let text = DetailJSON.str(v["text"]) ?? DetailJSON.str(v["place"]) else { continue }
            let day = DetailJSON.int(v["day"]) ?? 0
            let reg = DetailJSON.str(v["region"])
            let pl = DetailJSON.str(v["place"]).flatMap { placeCards[$0] }
            let stop = DetailStop(id: n, text: text, regionName: reg.flatMap { regionNames[$0] }, region: reg, place: pl)
            if let last = grouped.last, last.0 == day { grouped[grouped.count - 1].1.append(stop) } else { grouped.append((day, [stop])) }
        }
        // bir xil kun ikki joyda kelsa ham alohida guruh — id noyob bo'lsin
        var seen = Set<Int>()
        days = grouped.map { day, stops in
            var id = day
            while !seen.insert(id).inserted { id += 1000 }
            return DetailDay(id: id, stops: stops)
        }
    }

    mutating func era() {
        fact("years", "hourglass", tr("Yillar", "Годы", "Years"), DetailJSON.str(t["years"]) ?? s("years"))
        guard case .array(let a)? = item.sections?["events"] else { return }
        var ev: [(Int, DetailEvent)] = []
        for (n, e) in a.enumerated() {
            guard let name = DetailJSON.str(e["name"]) ?? DetailJSON.str(e["text"]?["title"]) else { continue }
            let year = DetailJSON.int(e["data"]?["year"])
            let when = DetailJSON.str(e["data"]?["date"]) ?? year.map(DetailLabels.year) ?? ""
            let text = DetailJSON.str(e["text"]?["text"]) ?? DetailJSON.str(e["summary"])
            let cards = DetailJSON.cards(e["refs"]?["places"])
            ev.append((year ?? Int.max - a.count + n, DetailEvent(id: DetailJSON.str(e["slug"]) ?? "e\(n)", when: when, title: name, text: text, cards: cards)))
        }
        events = ev.sorted { $0.0 < $1.0 }.map(\.1)
        if !events.isEmpty { fact("events", "list.bullet.indent", tr("Voqealar", "События", "Events"), "\(events.count)") }
    }

    mutating func histEvent() {
        let year = i("year")
        fact("date", "calendar", tr("Sana", "Дата", "Date"), s("date") ?? year.map(DetailLabels.year))
        if let era = item.refs["era"]?.first { fact("era", "hourglass", tr("Davr", "Эпоха", "Era"), era.name, tap: .card(era)) }
    }

    mutating func railStationInfo() {
        let trains = DetailJSON.strs(d["trains"])
        if !trains.isEmpty { fact("trains", "tram", tr("Poyezdlar", "Поезда", "Trains"), "\(trains.count)") }
        railStation = item.slug
    }

    mutating func train() {
        fact("number", "number", tr("Poyezd raqami", "Номер поезда", "Train number"), s("number"), mono: true)
        if let k = s("type") ?? item.kind { fact("ttype", "tram", tr("Turi", "Тип", "Type"), DetailLabels.trainType(k)) }
        fact("route", "arrow.left.arrow.right", tr("Yoʻnalish", "Маршрут", "Route"), s("route"))
        if let m = i("duration_min"), m > 0 { fact("duration", "timer", tr("Yoʻlda", "В пути", "Journey"), Fmt.duration(minutes: m)) }
        fact("days", "calendar", tr("Qatnov kunlari", "Дни курсирования", "Runs"), s("days"))
        fact("operator", "building.2", tr("Tashuvchi", "Перевозчик", "Operator"), s("operator"))
        chipGroup("cars", tr("Vagonlar", "Вагоны", "Carriages"), "bed.double",
                  DetailJSON.strs(d["car_types"]).map { DetailChip(id: $0, label: $0.prefix(1).uppercased() + $0.dropFirst()) })
        if case .array(let a)? = d["stops"] {
            trainStops = a.enumerated().compactMap { n, v in
                guard let st = DetailJSON.str(v["station"]) ?? DetailJSON.str(v["name"]) else { return nil }
                let nm = DetailJSON.str(v["text"]?["name"]) ?? DetailJSON.str(v["station_name"]) ?? DetailLabels.stationName(st)
                return DetailTrainStop(id: n, name: nm, arr: DetailJSON.str(v["arr"]), dep: DetailJSON.str(v["dep"]), dayOffset: DetailJSON.int(v["day"]) ?? 0)
            }
        }
    }

    mutating func busStation() {
        chipGroup("dest", tr("Yoʻnalishlar", "Направления", "Destinations"), "bus",
                  DetailJSON.strs(t["destinations"]).map { DetailChip(id: $0, label: $0) })
    }

    mutating func busRoute() {
        let a = s("from_city"), b = s("to_city")
        if a != nil || b != nil { fact("way", "arrow.right", tr("Yoʻnalish", "Направление", "Route"), [a, b].compactMap { $0 }.joined(separator: " → "), row: true) }
        if let m = i("duration_min"), m > 0 { fact("duration", "timer", tr("Yoʻlda", "В пути", "Journey"), Fmt.duration(minutes: m)) }
        fact("price", "banknote", tr("Narxi", "Цена", "Fare"), s("price"))
        if d["international"]?.bool == true { fact("intl", "globe", tr("Qatnov", "Рейс", "Service"), tr("Xalqaro", "Международный", "International")) }
        fact("days", "calendar", tr("Jadval", "Расписание", "Schedule"), s("days"), row: true)
        fact("operator", "building.2", tr("Tashuvchi", "Перевозчик", "Operator"), s("operator"), row: true)
        fact("note", "info.circle", tr("Izoh", "Примечание", "Note"), s("note"), row: true)
        chipGroup("dep", tr("Joʻnash vaqtlari", "Время отправления", "Departures"), "clock",
                  DetailJSON.strs(d["departures"]).map { DetailChip(id: $0, label: $0) })
        if let from = s("from") {
            rows.append(DetailFact(id: "fromst", symbol: "bus", label: tr("Avtovokzal", "Автовокзал", "Bus station"), value: DetailLabels.stationName(from),
                                   tap: .route(.item(ItemRef(type: "bus_station", slug: from)))))
        }
    }

    mutating func cityTransport() {
        fact("city", "building.2", tr("Shahar", "Город", "City"), s("city"))
        fact("fare", "creditcard", tr("Yoʻl haqi", "Стоимость проезда", "Fare"), s("fare"), row: true)
        chipGroup("modes", tr("Transport turlari", "Виды транспорта", "Modes"), "bus",
                  DetailJSON.strs(d["modes"]).map { let (l, sym) = DetailLabels.transportMode($0); return DetailChip(id: $0, label: l, symbol: sym) })
    }

    mutating func metro() {
        guard case .array(let a)? = d["lines"] else { return }
        metroLines = a.enumerated().compactMap { n, l in
            let name = DetailJSON.str(l["text"]?["name"]) ?? DetailJSON.str(l["name"]) ?? DetailJSON.str(l["slug"]).map(DetailLabels.humanize)
            guard let name else { return nil }
            let st = (l["stations"]?.array ?? []).compactMap { s in DetailJSON.str(s["text"]?["name"]) ?? DetailJSON.str(s["name"]) }
            let hex = DetailJSON.str(l["color"]).flatMap { c -> UInt32? in
                let h = c.hasPrefix("#") ? String(c.dropFirst()) : c
                return h.count == 6 ? UInt32(h, radix: 16) : nil
            }
            return DetailMetroLine(id: DetailJSON.str(l["slug"]) ?? "l\(n)", name: name, note: DetailJSON.str(l["text"]?["note"]),
                                   color: hex, opened: DetailJSON.int(l["opened"]), stations: st)
        }
    }

    // MARK: umumiy maydonlar (har turda bo'lishi mumkin)

    mutating func common() {
        if let m = i("duration_min"), m > 0, item.type != "place" {
            fact("duration", "timer", tr("Davomiyligi", "Длительность", "Duration"), Fmt.duration(minutes: m))
        }
        fact("hours", "clock", tr("Ish vaqti", "Часы работы", "Opening hours"), s("hours") ?? DetailJSON.str(d["hq"]?["hours"]), row: true)

        // Aloqa
        let phones = DetailJSON.strs(d["phones"])
        for (n, p) in phones.prefix(6).enumerated() {
            guard let u = DetailLink.tel(p) else { continue }
            contacts.append(DetailFact(id: "ph\(n)", symbol: "phone", label: tr("Telefon", "Телефон", "Phone"), value: DetailLink.phoneText(p), tap: .url(u)))
        }
        if let h = s("hotline"), let u = DetailLink.tel(h) {
            contacts.append(DetailFact(id: "hotline", symbol: "phone.badge.waveform", label: tr("Ishonch telefoni", "Телефон доверия", "Hotline"), value: DetailLink.phoneText(h), tap: .url(u)))
        }
        if let h = s("short_number"), let u = DetailLink.tel(h) {
            contacts.append(DetailFact(id: "short", symbol: "phone.circle", label: tr("Qisqa raqam", "Короткий номер", "Short number"), value: h, tap: .url(u)))
        }
        if let e = s("email"), let u = DetailLink.mail(e) {
            contacts.append(DetailFact(id: "email", symbol: "envelope", label: "Email", value: e, tap: .url(u)))
        }
        if let w = DetailLink.web(s("website")) {
            contacts.append(DetailFact(id: "web", symbol: "globe", label: tr("Sayt", "Сайт", "Website"), value: DetailLink.domain(w), tap: .url(w)))
        }
        if let tg = DetailLink.telegram(s("telegram")) {
            contacts.append(DetailFact(id: "tg", symbol: "paperplane", label: "Telegram", value: "@" + tg.lastPathComponent, tap: .url(tg)))
        }
        if let ig = DetailLink.instagram(s("instagram")) {
            contacts.append(DetailFact(id: "ig", symbol: "camera", label: "Instagram", value: "@" + ig.lastPathComponent, tap: .url(ig)))
        }
    }

    // MARK: bog'langan yozuvlar (refs) — karusellar

    mutating func refRails() {
        let skip: Set<String> = ["region", "district", "stops", "era", "place"]
        let order = ["related", "places", "persons", "people", "events", "stations", "airports", "regions"]
        let keys = order.filter { item.refs[$0] != nil } + item.refs.keys.filter { !order.contains($0) && !skip.contains($0) }.sorted()
        for k in keys {
            guard let cards = item.refs[k]?.filter({ $0.ref != item.ref }), !cards.isEmpty else { continue }
            // Davr va hudud kartalari yuqorida (fakt/havola) bor — takrorlanmasin
            if k == "regions", item.type == "region" { continue }
            let title: String
            switch k {
            case "related": title = item.type == "place" ? tr("Yaqin joylar", "Рядом", "Nearby") : tr("Oʻxshash", "Похожее", "Related")
            case "places": title = ["craft", "cuisine", "tradition"].contains(item.type) ? tr("Qayerda koʻrish", "Где увидеть", "Where to see it") : tr("Bogʻliq joylar", "Связанные места", "Related places")
            case "persons", "people": title = tr("Allomalar", "Личности", "People")
            case "events": title = tr("Voqealar", "События", "Events")
            case "stations": title = tr("Vokzallar", "Вокзалы", "Stations")
            case "airports": title = tr("Aeroportlar", "Аэропорты", "Airports")
            case "regions": title = item.type == "route" ? tr("Marshrut hududlari", "Регионы маршрута", "Regions on the route") : tr("Hududlar", "Регионы", "Regions")
            default: title = tr("Bogʻliq", "Связанное", "Related")
            }
            rails.append(DetailRail(id: "r." + k, title: title, cards: cards, portrait: k == "persons" || k == "people"))
        }
    }

    // MARK: tezkor amallar

    mutating func quickActions() {
        if let la = item.lat, let lo = item.lon, DetailJSON.validCoord(la, lo), item.type != "region", let u = DetailLink.directions(lat: la, lon: lo) {
            quick.append(.directions(u))
        } else if let c = DetailJSON.coord(d["coords"]) ?? DetailJSON.coord(d["hq"]?["coords"]), item.type != "region", let u = DetailLink.directions(lat: c.0, lon: c.1) {
            quick.append(.directions(u))
        }
        if let iata = boardIATA { quick.append(.board(iata)) }
        if let st = railStation { quick.append(.railBoard(st)) }
        for c in contacts {
            guard case .url(let u)? = c.tap else { continue }
            switch c.id {
            case "ph0": quick.append(.call(u))
            case "web": quick.append(.web(u))
            case "tg": quick.append(.telegram(u))
            case "ig": quick.append(.instagram(u))
            default: break
            }
        }
        if !quick.contains(where: { if case .call = $0 { return true }; return false }),
           let h = contacts.first(where: { $0.id == "hotline" || $0.id == "short" }), case .url(let u)? = h.tap {
            quick.insert(.call(u), at: min(1, quick.count))
        }
    }
}
