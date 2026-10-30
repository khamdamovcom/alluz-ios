// Vokzal tablosi (.railBoard(slug)): jonli tablosi bor vokzallar (tm.md.uz — rasmiy jo'nash tablolari, sayt 29 ta vokzal uchun
// oladi), keyingi poyezdlar: vaqt, raqam, nomi, qayerga, bo'sh joylar, platforma; poyezd ma'lumotidan — yetib kelish va yo'lda.
// Ma'lumot: GET /api/rail-board?station=<slug> (transport.js apiRailBoard; qatorlar HTML — data-k/data-v atributlaridan o'qiladi),
// vokzallar — /api/app/v1/list/rail_station?kind=vokzal, poyezd tafsiloti — /api/app/v1/item/train/<slug> (yetib kelish, yo'lda).
import SwiftUI

// MARK: - Ma'lumot

/// /api/rail-board javobi (sayt jadvali uchun HTML qatorlar)
private struct RailBoardResponse: Decodable, Sendable {
    let ok: Bool?
    let station: String?
    let rows: String?
    let okAt: Double?
    let stale: Bool?
}

private struct RailBoardRow: Identifiable, Hashable, Sendable {
    let number: String
    let at: Date
    let timeText: String
    /// Server yorlig'i: «Ertaga» yoki «01.11» (bugun — bo'sh)
    let dayLabel: String?
    let name: String?
    let dest: String
    let seats: [RailSeat]
    let platform: String?
    let train: String?
    var id: String { "\(number)|\(at.timeIntervalSince1970)" }
}

private struct RailSeat: Hashable, Sendable {
    let label: String
    let n: Int
}

/// Poyezd tafsilotidan (item/train) olinadigan qo'shimcha: turi, yetib kelish, yo'lda
private struct RailTrainInfo: Hashable, Sendable {
    let type: String?
    let arrive: String?
    let arrivePlus: Int
    let minutes: Int?
    let days: String?
}

private struct RailStop: Decodable, Sendable {
    let station: String?
    let arr: String?
    let dep: String?
    let day: Int?
}

/// Sayt jadval qatorlaridan o'qish: <tr class="fb__r" data-k="753М|2026-10-30T17:16:00+05:00"> … <td data-c="t" data-v="17:16|">
private enum RailBoardParser {
    static func parse(_ html: String) -> (rows: [RailBoardRow], message: String?) {
        var rows: [RailBoardRow] = []
        var message: String?
        for chunk in html.components(separatedBy: "<tr").dropFirst() {
            if chunk.contains("fb__msg") {
                if let b = first(#"<b>([\s\S]*?)</b>"#, in: chunk) { message = text(b) }
                continue
            }
            guard chunk.contains("fb__r"), let k = first(#"data-k="([^"]*)""#, in: chunk) else { continue }
            let kp = unescape(k).components(separatedBy: "|")
            guard kp.count >= 2, let at = BoardTime.parse(kp[1]) else { continue }
            var v: [String: String] = [:]
            for m in all(#"data-c="(\w+)" data-v="([^"]*)""#, in: chunk) where m.count == 2 { v[m[0]] = unescape(m[1]) }
            let t = (v["t"] ?? "").components(separatedBy: "|")
            let trn = (v["trn"] ?? "").components(separatedBy: "|")
            let seats: [RailSeat] = (v["seat"] ?? "").split(separator: ",").compactMap { s in
                let str = String(s)
                guard let r = str.range(of: #"\d+$"#, options: .regularExpression), let n = Int(str[r]) else { return nil }
                return RailSeat(label: seatLabel(String(str[..<r.lowerBound])), n: n)
            }
            let slug = first(#"/transport/poyezdlar/([^"/?#]+)""#, in: chunk).map(unescape)
            rows.append(RailBoardRow(
                number: kp[0], at: at, timeText: t.first.flatMap { $0.isEmpty ? nil : $0 } ?? BoardTime.time(at),
                dayLabel: t.count > 1 && !t[1].isEmpty ? t[1] : nil,
                name: trn.count > 1 && !trn[1].isEmpty ? trn[1] : nil,
                dest: v["dest"].flatMap { $0.isEmpty ? nil : $0 } ?? "—",
                seats: seats, platform: v["plat"].flatMap { $0.isEmpty ? nil : $0 }, train: slug?.removingPercentEncoding ?? slug))
        }
        return (rows, message)
    }

    /// Manbadagi vagon turi (LYUKS, KUPE, PLATSKART, O'TIRADIGAN, UMUMIY) → joriy til (sayt SEAT jadvali)
    static func seatLabel(_ raw: String) -> String {
        let s = raw.lowercased()
        if s.contains("lyuks") || s.contains("люкс") { return tr("Lyuks", "Люкс", "Deluxe") }
        if s.contains("kupe") || s.contains("купе") { return tr("Kupe", "Купе", "Compartment") }
        if s.contains("platskart") || s.contains("плац") { return tr("Platskart", "Плацкарт", "Open sleeper") }
        if s.contains("tiradigan") || s.contains("сид") || s.contains("cид") { return tr("Oʻtiradigan", "Сидячий", "Seated") }   // manbada ba'zan lotin «C»
        if s.contains("umumiy") || s.contains("общ") { return tr("Umumiy", "Общий", "Common") }
        return raw.capitalized
    }

    private static func first(_ p: String, in s: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: p),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)), m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[r])
    }
    private static func all(_ p: String, in s: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: p) else { return [] }
        return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { m in
            (1..<m.numberOfRanges).compactMap { Range(m.range(at: $0), in: s).map { String(s[$0]) } }
        }
    }
    private static func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&#x27;", with: "'").replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
    private static func text(_ s: String) -> String {
        unescape(s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Poyezd bekatlari → shu bekatdan oxirgi bekatgacha (sayt stopTimes mantiqi)
    static func info(_ item: Item, station: String) -> RailTrainInfo {
        let stops = item.data["stops"]?.decode([RailStop].self) ?? []
        let mins = minutes(stops)
        var arrive: String?, plus = 0, dur: Int?
        if let k = stops.firstIndex(where: { $0.station == station }), k < stops.count - 1,
           let d = mins[k].d ?? mins[k].a, let last = mins.last, let a = last.a ?? last.d, a >= d {
            arrive = mm(a); plus = a / 1440 - d / 1440; dur = a - d
        }
        return RailTrainInfo(type: item.data["type"]?.string, arrive: arrive, arrivePlus: plus,
                             minutes: dur ?? item.data["duration_min"]?.int, days: item.data["days"]?.string)
    }
    private static func toMin(_ s: String?) -> Int? {
        guard let s, let r = s.range(of: #"^\d{1,2}:\d{2}$"#, options: .regularExpression) else { return nil }
        let p = s[r].split(separator: ":"); return Int(p[0])! * 60 + Int(p[1])!
    }
    private static func minutes(_ stops: [RailStop]) -> [(a: Int?, d: Int?)] {
        let withDay = stops.contains { $0.day != nil }
        var base = 0, prev: Int?
        return stops.map { s in
            var a = toMin(s.arr), d = toMin(s.dep)
            if withDay {
                let off = (s.day ?? 0) * 1440
                if a != nil { a! += off }
                if d != nil { d! += off; if let aa = a, d! < aa { d! += 1440 } }
                return (a, d)
            }
            func fix(_ v: Int?) -> Int? {
                guard let v else { return nil }
                var x = v + base
                if let p = prev, x < p { base += 1440; x += 1440 }
                prev = x
                return x
            }
            let fa = fix(a), fd = fix(d)
            return (fa, fd)
        }
    }
    private static func mm(_ m: Int) -> String { String(format: "%02d:%02d", (m % 1440) / 60, m % 60) }
}

/// Vokzallar (jonli tablosi bor — «vokzal» turidagilar), mashhurlari oldin
private struct RailStation: Identifiable, Hashable, Sendable {
    let slug: String
    let name: String
    let sub: String?
    var id: String { slug }
    /// «Samarqand vokzali» → «Samarqand», «Вокзал Самарканд» → «Самарканд», «Samarkand Station» → «Samarkand»
    var short: String {
        name.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #" (vokzali|bekati)$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"^(Вокзал|Станция) "#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #" ([Ss]tation)$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
    static let popular = ["toshkent-shimoliy-vokzali", "toshkent-janubiy-vokzali", "samarqand-vokzali", "buxoro-vokzali", "xiva-vokzali", "urganch-vokzali",
                          "qarshi-vokzali", "andijon-vokzali", "namangan-vokzali", "margilon-vokzali", "qoqon-vokzali", "termiz-vokzali", "nukus-vokzali",
                          "navoiy-vokzali", "jizzax-vokzali", "guliston-vokzali", "shahrisabz-vokzali"]
    static let storeKey = "rail.station"
    static func resolve(_ s: String?) -> String {
        if let s, !s.isEmpty { return s }
        return UserDefaults.standard.string(forKey: storeKey) ?? "toshkent-shimoliy-vokzali"
    }
}

@MainActor @Observable
private final class RailBoardViewModel {
    private(set) var station: String
    private(set) var stations: [RailStation] = []
    private(set) var rows: [RailBoardRow] = []
    private(set) var message: String?
    private(set) var updatedAt: Date?
    private(set) var stale = false
    private(set) var loaded = false
    private(set) var noBoard = false
    private(set) var error: Error?
    private(set) var refreshing = false
    private(set) var info: [String: RailTrainInfo] = [:]
    private(set) var now = Date()
    private var infoStation = ""

    init(station: String) { self.station = station }

    var current: RailStation? { stations.first { $0.slug == station } }

    func select(_ s: String) {
        guard s != station else { return }
        station = s
        UserDefaults.standard.set(s, forKey: RailStation.storeKey)
        withAnimation(Motion.gentle) { rows = []; loaded = false; noBoard = false; error = nil; message = nil; updatedAt = nil }
    }

    func loadStations() async {
        guard stations.isEmpty, let page: ListPage = try? await API.shared.get("list/rail_station", query: ["kind": "vokzal", "limit": "200"]) else { return }
        let all = page.items.compactMap { c in c.slug.map { RailStation(slug: $0, name: c.name, sub: c.sub) } }
        let pop = RailStation.popular
        stations = all.sorted {
            let x = pop.firstIndex(of: $0.slug) ?? 99, y = pop.firstIndex(of: $1.slug) ?? 99
            return x != y ? x < y : $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }

    func load() async {
        let s = station
        refreshing = true
        defer { if s == station { refreshing = false } }
        do {
            let r: RailBoardResponse = try await API.shared.getRaw("/api/rail-board", query: ["station": s])
            guard s == station else { return }
            let p = RailBoardParser.parse(r.rows ?? "")
            now = Date()
            withAnimation(Motion.gentle) {
                rows = p.rows; message = p.message; stale = r.stale ?? false
                updatedAt = r.okAt.map { Date(timeIntervalSince1970: $0 / 1000) }
                loaded = true; noBoard = false; error = nil
            }
            await enrich(p.rows, station: s)
        } catch is CancellationError {
        } catch {
            guard s == station else { return }
            if (error as? APIError) == .notFound { withAnimation { noBoard = true; loaded = true } }
            else if !loaded { withAnimation { self.error = error } }
        }
    }

    /// Poyezdlar tafsiloti (yetib kelish, yo'lda) — har poyezd bir marta
    private func enrich(_ rows: [RailBoardRow], station s: String) async {
        if infoStation != s { info = [:]; infoStation = s }
        let need = Array(Set(rows.compactMap(\.train))).filter { info[$0] == nil }
        guard !need.isEmpty else { return }
        let got = await withTaskGroup(of: (String, RailTrainInfo?).self) { g in
            for slug in need.prefix(16) {
                g.addTask {
                    let it: Item? = try? await API.shared.get("item/train/\(slug)")
                    return (slug, it.map { RailBoardParser.info($0, station: s) })
                }
            }
            var out: [String: RailTrainInfo] = [:]
            for await (k, v) in g { if let v { out[k] = v } }
            return out
        }
        guard s == station else { return }
        withAnimation(Motion.gentle) { info.merge(got) { $1 } }
    }

    func tick() { now = Date() }
}

// MARK: - Ekran

struct RailBoardScreen: View {
    let station: String?

    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var phase
    @State private var vm: RailBoardViewModel
    @State private var picker = false

    init(station: String?) {
        self.station = station
        _vm = State(initialValue: RailBoardViewModel(station: RailStation.resolve(station)))
    }

    private var title: String { vm.current?.short ?? tr("Vokzal tablosi", "Табло вокзала", "Station board") }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                hero
                chips.padding(.bottom, 12)
                content
                footer
            }
        }
        .background(Theme.paper)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { picker = true } label: { Image(systemName: "list.bullet") }
                    .accessibilityLabel(tr("Vokzalni tanlash", "Выбрать вокзал", "Choose station"))
            }
        }
        .refreshable { await vm.load() }
        .task(id: "\(vm.station)|\(phase == .active)|\(model.reloadToken)") {
            guard phase == .active else { return }
            await vm.load()
            // Vokzal tablosi manbada 5 daqiqada yangilanadi — 2 daqiqada bir so'raymiz (sayt ham shunday)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(120))
                if Task.isCancelled { break }
                vm.tick()
                await vm.load()
            }
        }
        // «… qoldi» yorliqlari yangilanib turadi
        .task(id: phase == .active) {
            while !Task.isCancelled && phase == .active {
                try? await Task.sleep(for: .seconds(30))
                vm.tick()
            }
        }
        .task { await vm.loadStations() }
        .sheet(isPresented: $picker) {
            RailStationPicker(stations: vm.stations, selected: vm.station) { s in vm.select(s); picker = false }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                BoardLiveDot(color: vm.stale ? Theme.warn : Theme.ok, size: 7, pulsing: !vm.stale)
                Kicker(text: tr("Jonli · vokzal tablosi", "Онлайн · табло вокзала", "Live · station board"))
            }
            Text(title).font(Theme.Font.display(34)).foregroundStyle(Theme.ink).lineLimit(2).minimumScaleFactor(0.7)
                .contentTransition(.opacity).animation(Motion.spring, value: title)
            if let s = vm.current {
                Button { model.open(.item(ItemRef(type: "rail_station", slug: s.slug))) } label: {
                    HStack(spacing: 4) {
                        Text(s.name).multilineTextAlignment(.leading)
                        Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                    }
                    .font(Theme.Font.sub).foregroundStyle(Theme.ink2)
                }
                .buttonStyle(.plain)
                .accessibilityHint(tr("Vokzal haqida", "О вокзале", "About the station"))
            }
            HStack {
                Text(tr("Keyingi poyezdlar", "Ближайшие поезда", "Next departures")).font(Theme.Font.caption).foregroundStyle(Theme.muted)
                Spacer()
                BoardUpdatedBadge(updated: vm.updatedAt, refreshing: vm.refreshing, stale: vm.stale)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    @ViewBuilder private var chips: some View {
        if !vm.stations.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.stations) { s in
                            let on = s.slug == vm.station
                            Button { if !on { Haptics.select(); vm.select(s.slug) } } label: {
                                Text(s.short).font(Theme.Font.sub.weight(.semibold))
                                    .padding(.horizontal, 14).frame(minHeight: 38)
                                    .foregroundStyle(on ? Theme.accentInk : Theme.ink)
                                    .background(on ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.card), in: Capsule())
                                    .overlay(Capsule().strokeBorder(on ? .clear : Theme.line))
                            }
                            .buttonStyle(.press)
                            .id(s.slug)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                        Button { picker = true } label: {
                            Label(tr("Hammasi", "Все", "All"), systemImage: "list.bullet").font(Theme.Font.sub.weight(.semibold))
                                .padding(.horizontal, 14).frame(minHeight: 38)
                                .foregroundStyle(Theme.accent)
                                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.5)))
                        }
                        .buttonStyle(.press)
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 2)
                    .animation(Motion.snappy, value: vm.station)
                }
                .onAppear { proxy.scrollTo(vm.station, anchor: .center) }
                .onChange(of: vm.station) { withAnimation(Motion.spring) { proxy.scrollTo(vm.station, anchor: .center) } }
            }
        }
    }

    @ViewBuilder private var content: some View {
        if vm.noBoard {
            VStack(spacing: 12) {
                EmptyState(title: tr("Jonli tablo yoʻq", "Нет онлайн-табло", "No live board"),
                           text: tr("Bu bekat uchun jonli tablo yoʻq. Jadvalni bekat sahifasida koʻring.",
                                    "Для этой станции нет онлайн-табло. Расписание — на странице станции.",
                                    "There is no live board for this stop. See the timetable on the station page."), symbol: "tram")
                Button(tr("Bekat sahifasi", "Страница станции", "Station page")) { model.open(.item(ItemRef(type: "rail_station", slug: vm.station))) }
                    .primaryButton().tint(Theme.accent)
            }
            .frame(maxWidth: .infinity)
        } else if let e = vm.error {
            ErrorState(error: e) { Task { await vm.load() } }
        } else if !vm.loaded {
            BoardSkeleton(rows: 6)
        } else {
            if vm.stale, let u = vm.updatedAt {
                BoardNote(text: tr("Vokzal tablosi \(BoardTime.time(u)) holatiga koʻra — yangilanmoqda.", "Табло вокзала по состоянию на \(BoardTime.time(u)) — обновляется.",
                                   "Station board as of \(BoardTime.time(u)) — refreshing."), symbol: "exclamationmark.triangle", tint: Theme.warn)
                    .padding(.horizontal, Theme.gutter).padding(.bottom, 8)
            }
            if vm.rows.isEmpty {
                EmptyState(title: tr("Hozircha poyezd koʻrinmayapti", "Сейчас поездов нет", "No trains right now"),
                           text: vm.message ?? tr("Vokzal tablosida hozircha keyingi poyezdlar koʻrinmayapti.", "На табло вокзала сейчас нет ближайших поездов.",
                                                  "The station board shows no upcoming trains right now."), symbol: "tram")
            } else {
                ForEach(Array(vm.rows.enumerated()), id: \.element.id) { i, r in
                    Button {
                        if let t = r.train { Haptics.tap(); model.open(.item(ItemRef(type: "train", slug: t))) }
                    } label: {
                        RailBoardRowView(row: r, info: r.train.flatMap { vm.info[$0] }, now: vm.now, first: i == 0)
                    }
                    .buttonStyle(.press)
                    .disabled(r.train == nil)
                    .appear(delay: 0.03 * Double(min(i, 10)))
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Vokzal tablosidan (tm.md.uz); jadvaldan farq qilsa, chiptadagi vaqtga tayaning. Vaqtlar — Toshkent vaqti.",
                    "С табло вокзала (tm.md.uz); если отличается от расписания — ориентируйтесь на билет. Время — ташкентское.",
                    "From the station board (tm.md.uz); if it differs from the timetable, trust your ticket. Times are Tashkent time."))
                .font(Theme.Font.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            Button { model.openWeb("https://eticket.railway.uz/") } label: {
                Label(tr("Chipta sotib olish — eticket.railway.uz", "Купить билет — eticket.railway.uz", "Buy tickets — eticket.railway.uz"), systemImage: "ticket")
                    .font(Theme.Font.sub.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
            }
            .primaryButton().tint(Theme.accent)
            Button { model.open(.list(ListSpec(type: "train"))) } label: {
                Label(tr("Barcha poyezdlar jadvali", "Расписание всех поездов", "All train timetables"), systemImage: "tram.fill")
                    .font(Theme.Font.sub.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
            }
            .secondaryButton().tint(Theme.accent)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }
}

// MARK: - Poyezd qatori

private struct RailBoardRowView: View {
    let row: RailBoardRow
    let info: RailTrainInfo?
    let now: Date
    let first: Bool
    @ScaledMetric(relativeTo: .title3) private var timeW: CGFloat = 64

    private var minutesLeft: Int { Int((row.at.timeIntervalSince(now) / 60).rounded(.down)) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.timeText).font(Theme.Font.boardTime).foregroundStyle(minutesLeft < 0 ? Theme.muted : Theme.ink)
                if let d = row.dayLabel { Text(d).font(Theme.Font.caption.weight(.semibold)).foregroundStyle(Theme.teal).lineLimit(1) }
            }
            .frame(width: timeW, alignment: .leading)
            .lineLimit(1).minimumScaleFactor(0.7)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: "arrow.right").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                    Text(row.dest).font(Theme.Font.headline).foregroundStyle(Theme.ink).lineLimit(2)
                }
                HStack(spacing: 4) {
                    Text(row.number).font(Theme.Font.boardCode).foregroundStyle(Theme.ink2)
                    if let n = row.name { Text("· \(n)").lineLimit(1) }
                    if let t = info?.type, let l = typeLabel(t), l != row.name {
                        Text(l).font(Theme.Font.boardCaption2Bold).foregroundStyle(Theme.teal)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Theme.teal.opacity(0.12), in: Capsule())
                    }
                }
                .font(Theme.Font.caption).foregroundStyle(Theme.muted)
                if let journey { Text(journey).font(Theme.Font.caption).foregroundStyle(Theme.ink2).lineLimit(2) }
                HStack(spacing: 6) {
                    if let s = status { BoardStatusPill(label: s.0, tone: s.1).fixedSize() }
                    seatsView
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
            if let p = row.platform {
                VStack(spacing: 0) {
                    Text(p).font(Theme.Font.boardTime).foregroundStyle(Theme.ink)
                    Text(tr("platf.", "платф.", "platf.")).font(Theme.Font.caption).foregroundStyle(Theme.muted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(tr("Platforma", "Платформа", "Platform")) \(p)")
            } else if row.train != nil {
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.line).padding(.top, 6)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 12)
        .background(first && minutesLeft >= 0 ? Theme.accent.opacity(0.05) : .clear)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line.opacity(0.5)).frame(height: 0.5).padding(.leading, Theme.gutter) }
        .opacity(minutesLeft < 0 ? 0.55 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(row.train != nil ? tr("Poyezd jadvali", "Расписание поезда", "Train timetable") : "")
    }

    private var journey: String? {
        guard let info else { return nil }
        var p: [String] = []
        if let a = info.arrive { p.append("\(tr("yetib kelish", "прибытие", "arrives")) \(a)\(info.arrivePlus > 0 ? " (+\(info.arrivePlus))" : "")") }
        if let m = info.minutes, m > 0 { p.append("\(tr("yoʻlda", "в пути", "journey")) \(Fmt.duration(minutes: m))") }
        guard !p.isEmpty else { return nil }
        let s = p.joined(separator: " · ")
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    private var status: (String, BoardTone)? {
        let m = minutesLeft
        if m < 0 { return (tr("Joʻnab ketdi", "Отправился", "Departed"), .done) }
        if m <= 180 {
            let t = m < 1 ? tr("hozir", "сейчас", "now") : Fmt.duration(minutes: m)
            return (tr("\(t) qoldi", "через \(t)", "in \(t)"), m <= 30 ? .boarding : .onTime)
        }
        return nil
    }

    @ViewBuilder private var seatsView: some View {
        if !row.seats.isEmpty {
            let free = row.seats.filter { $0.n > 0 }
            if free.isEmpty {
                Text(tr("Boʻsh joy yoʻq", "Мест нет", "No free seats")).font(Theme.Font.caption.weight(.semibold)).foregroundStyle(Theme.bad)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Theme.bad.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) { ForEach(free, id: \.self) { seat($0) } }
                    HStack(spacing: 4) { ForEach(free.prefix(2), id: \.self) { seat($0) } }
                    Text("\(tr("Boʻsh joy", "Свободно", "Free seats")): \(free.reduce(0) { $0 + $1.n })")
                        .font(Theme.Font.caption.weight(.semibold)).foregroundStyle(Theme.ok)
                }
            }
        }
    }
    private func seat(_ s: RailSeat) -> some View {
        BoardBitTag(bit: BoardInfoBit(symbol: "chair", label: s.label, value: "\(s.n)"))
    }

    private func typeLabel(_ t: String) -> String? {
        switch t {
        case "highspeed": tr("Tezyurar", "Скоростной", "High-speed")
        case "fast": tr("Tezkor", "Скорый", "Express")
        case "passenger": tr("Yoʻlovchi", "Пассажирский", "Passenger")
        case "night": tr("Tungi", "Ночной", "Night")
        case "suburban": tr("Shahar atrofi", "Пригородный", "Suburban")
        default: nil
        }
    }
}


// MARK: - Vokzal tanlash (qidiruv bilan)

private struct RailStationPicker: View {
    let stations: [RailStation]
    let selected: String
    let pick: (String) -> Void
    @State private var q = ""
    @Environment(\.dismiss) private var dismiss

    private var shown: [RailStation] {
        let n = BoardSearch.norm(q)
        guard !n.isEmpty else { return stations.sorted { $0.name.localizedCompare($1.name) == .orderedAscending } }
        return stations.filter { BoardSearch.norm($0.name + " " + ($0.sub ?? "")).contains(n) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(shown) { s in
                    Button { Haptics.select(); pick(s.slug) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.name).font(Theme.Font.body).foregroundStyle(Theme.ink)
                                if let sub = s.sub { Text(sub).font(Theme.Font.caption).foregroundStyle(Theme.muted) }
                            }
                            Spacer()
                            if s.slug == selected { Image(systemName: "checkmark").foregroundStyle(Theme.accent).fontWeight(.semibold) }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.card)
                    .accessibilityAddTraits(s.slug == selected ? .isSelected : [])
                }
            }
            .overlay { if shown.isEmpty { EmptyState() } }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: tr("Vokzal nomi", "Название вокзала", "Station name"))
            .navigationTitle(tr("Vokzallar", "Вокзалы", "Stations"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(tr("Yopish", "Закрыть", "Close")) { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
