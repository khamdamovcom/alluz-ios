// Transport markazi (.transport): jonli tablo (katta karta), bo'limlar (poyezdlar, vokzal tablosi, metro, avtovokzallar,
// shahar transporti, vokzallar, aeroportlar, masofalar) va 16 aeroport — har birida bugungi reyslar soni va keyingi reys.
// Aeroport soni — /api/board (bugun, uchish + qo'nish; har aeroport qatori ko'ringanda yuklanadi, 2 daqiqa keshlanadi).
// Bo'limlar soni — config.counts (AppModel.config).
import SwiftUI

// MARK: - Aeroport statistikasi (bugun)

struct TransportAirportStat: Hashable, Sendable {
    let dep: Int
    let arr: Int
    let upcoming: Int
    let delayed: Int
    let cancelled: Int
    let next: BoardItem?
    let nextDir: BoardDir?
    let at: Date
}

@MainActor @Observable
final class TransportStatsStore {
    static let shared = TransportStatsStore()
    private(set) var stats: [String: TransportAirportStat] = [:]
    private var loading: Set<String> = []
    private var lang = Lang.current

    func ensure(_ iata: String) async {
        if lang != Lang.current { stats = [:]; lang = Lang.current }
        if let s = stats[iata], Date().timeIntervalSince(s.at) < 120 { return }
        guard !loading.contains(iata) else { return }
        loading.insert(iata)
        defer { loading.remove(iata) }
        async let d: BoardResponse? = try? API.shared.getRaw("/api/board", query: ["airport": iata, "dir": "dep", "day": "today"])
        async let a: BoardResponse? = try? API.shared.getRaw("/api/board", query: ["airport": iata, "dir": "arr", "day": "today"])
        let (dr, ar) = await (d, a)
        guard dr != nil || ar != nil else { return }
        let dep = (dr?.flights ?? []).map { BoardItem($0, dir: .dep) }
        let arr = (ar?.flights ?? []).map { BoardItem($0, dir: .arr) }
        let up = (dep.map { ($0, BoardDir.dep) } + arr.map { ($0, BoardDir.arr) }).filter { !$0.0.past }
            .sorted { ($0.0.eff ?? .distantFuture) < ($1.0.eff ?? .distantFuture) }
        let stat = TransportAirportStat(
            dep: dep.count, arr: arr.count, upcoming: up.count,
            delayed: up.filter { $0.0.f.status == "delayed" }.count,
            cancelled: (dep + arr).filter(\.cancelled).count,
            next: up.first?.0, nextDir: up.first?.1, at: Date())
        withAnimation(Motion.gentle) { stats[iata] = stat }
    }
}

// MARK: - Ekran

struct TransportHub: View {
    @Environment(AppModel.self) private var model
    @State private var airports = BoardAirportStore.shared
    @State private var stats = TransportStatsStore.shared

    private struct Mode: Identifiable {
        let id: String
        let title: String
        let sub: String
        let symbol: String
        let tint: Color
        let route: Route
    }

    private func count(_ k: String) -> Int? { model.config?.counts[k] }

    private var modes: [Mode] {
        let n = { (k: String) -> String in count(k).map { Fmt.num($0) } ?? "" }
        return [
            Mode(id: "train", title: tr("Poyezdlar", "Поезда", "Trains"),
                 sub: count("train") != nil ? tr("\(n("train")) ta poyezd jadvali", "Расписание \(n("train")) поездов", "\(n("train")) train timetables")
                                            : tr("Jadval va chiptalar", "Расписание и билеты", "Timetables and tickets"),
                 symbol: "tram.fill", tint: Theme.teal, route: .list(ListSpec(type: "train"))),
            Mode(id: "railboard", title: tr("Vokzal tablosi", "Табло вокзала", "Station board"),
                 sub: tr("Jonli: keyingi poyezdlar va boʻsh joylar", "Онлайн: ближайшие поезда и места", "Live: next trains and free seats"),
                 symbol: "train.side.front.car", tint: Theme.accent, route: .railBoard(nil)),
            Mode(id: "metro", title: tr("Toshkent metrosi", "Ташкентское метро", "Tashkent Metro"),
                 sub: tr("Liniyalar, bekatlar, yoʻl haqi", "Линии, станции, проезд", "Lines, stations and fares"),
                 symbol: "tram.fill.tunnel", tint: Theme.bad, route: .item(ItemRef(type: "metro", slug: "toshkent"))),
            Mode(id: "bus", title: tr("Avtovokzallar", "Автовокзалы", "Bus stations"),
                 sub: count("bus_station") != nil
                    ? tr("\(n("bus_station")) ta avtovokzal · \(n("bus_route")) ta yoʻnalish", "\(n("bus_station")) автовокзалов · \(n("bus_route")) маршрутов",
                         "\(n("bus_station")) bus stations · \(n("bus_route")) routes")
                    : tr("Shaharlararo avtobuslar", "Междугородние автобусы", "Intercity buses"),
                 symbol: "bus.fill", tint: Theme.gold, route: .list(ListSpec(type: "bus_station"))),
            Mode(id: "city", title: tr("Shahar transporti", "Городской транспорт", "City transport"),
                 sub: tr("Yoʻl haqi, toʻlov usullari, yoʻnalishlar", "Стоимость проезда, оплата, маршруты", "Fares, payment and routes"),
                 symbol: "bus.doubledecker.fill", tint: Theme.ok, route: .list(ListSpec(type: "city_transport"))),
            Mode(id: "stations", title: tr("Vokzallar", "Вокзалы", "Stations"),
                 sub: count("rail_station") != nil ? tr("\(n("rail_station")) ta vokzal va bekat", "\(n("rail_station")) вокзалов и станций", "\(n("rail_station")) stations")
                                                   : tr("Vokzallar va bekatlar", "Вокзалы и станции", "Stations and stops"),
                 symbol: "building.columns.fill", tint: Theme.teal, route: .list(ListSpec(type: "rail_station"))),
            Mode(id: "airports", title: tr("Aeroportlar", "Аэропорты", "Airports"),
                 sub: count("airport") != nil ? tr("\(n("airport")) ta aeroport: aloqa, terminallar", "\(n("airport")) аэропортов: контакты, терминалы", "\(n("airport")) airports: contacts, terminals")
                                              : tr("Aloqa va terminallar", "Контакты и терминалы", "Contacts and terminals"),
                 symbol: "airplane.circle.fill", tint: Theme.accent, route: .list(ListSpec(type: "airport"))),
            Mode(id: "distances", title: tr("Masofalar", "Расстояния", "Distances"),
                 sub: tr("Shaharlar orasida: km, yoʻl vaqti", "Между городами: км и время в пути", "Between cities: km and travel time"),
                 symbol: "point.topleft.down.curvedto.point.bottomright.up", tint: Theme.gold, route: .distances(nil)),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                hero
                boardCard.appear(delay: 0.04)
                grid
                airportsSection
            }
            .padding(.bottom, 40)
        }
        .background(Theme.paper)
        .navigationTitle(tr("Transport", "Транспорт", "Transport"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await airports.ensure() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: tr("Qanday borish", "Как добраться", "Getting around"))
            Text(tr("Oʻzbekiston boʻylab transport", "Транспорт по Узбекистану", "Getting around Uzbekistan"))
                .font(Theme.Font.display(32)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            Text(tr("Aeroportlarning jonli tablosi, poyezdlar jadvali, Toshkent metrosi, avtovokzallar va shahar transporti — safarni rejalash uchun hammasi bir joyda.",
                    "Онлайн-табло аэропортов, расписание поездов, ташкентское метро, автовокзалы и городской транспорт — всё для планирования поездки в одном месте.",
                    "Live airport boards, train timetables, the Tashkent Metro, bus stations and city transport — everything you need to plan a trip, in one place."))
                .font(Theme.Font.body).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 8)
        .appear()
    }

    // MARK: Jonli tablo — katta karta

    private var boardCard: some View {
        Button { Haptics.tap(); model.open(.board(nil)) } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    BoardLiveDot(color: Theme.accentInk, size: 7)
                    Text(tr("JONLI TABLO", "ОНЛАЙН-ТАБЛО", "LIVE BOARD")).font(Theme.Font.kicker).tracking(1.1)
                    Spacer()
                    Image(systemName: "airplane.departure").font(.title2.weight(.semibold))
                        .symbolEffect(.pulse, options: .repeating.speed(0.4))
                }
                Text(tr("Aeroportlar tablosi", "Табло аэропортов", "Airport flight board")).font(Theme.Font.display(28))
                    .fixedSize(horizontal: false, vertical: true)
                Text(tr("Hozir qaysi reys uchyapti, qaysi biri kechikyapti — 16 aeroport, rasmiy tablolardan.",
                        "Какие рейсы вылетают сейчас и какие задерживаются — 16 аэропортов, с официальных табло.",
                        "What is departing now and what is delayed — 16 airports, live from the official boards."))
                    .font(Theme.Font.sub).opacity(0.9).fixedSize(horizontal: false, vertical: true)
                if let tas = stats.stats["TAS"] {
                    HStack(spacing: 14) {
                        hubStat("airplane.departure", tas.dep, tr("uchish", "вылетов", "departures"))
                        hubStat("airplane.arrival", tas.arr, tr("qoʻnish", "прилётов", "arrivals"))
                        if tas.delayed > 0 { hubStat("clock.badge.exclamationmark", tas.delayed, tr("kechikmoqda", "задерж.", "delayed")) }
                    }
                    .font(Theme.Font.caption.weight(.semibold))
                    .transition(.opacity)
                }
                HStack {
                    Text(tr("Tabloni ochish", "Открыть табло", "Open the board")).font(Theme.Font.headline)
                    Image(systemName: "arrow.right").font(.headline)
                }
                .padding(.top, 2)
            }
            .foregroundStyle(Theme.accentInk)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack(alignment: .bottomTrailing) {
                    LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "airplane").font(.system(size: 120, weight: .bold)).foregroundStyle(Theme.accentInk.opacity(0.08))
                        .rotationEffect(.degrees(-20)).offset(x: 20, y: 24)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .shadow(color: Theme.accent.opacity(0.25), radius: 14, y: 6)
        }
        .buttonStyle(.press)
        .padding(.horizontal, Theme.gutter)
        .task { await stats.ensure("TAS") }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func hubStat(_ symbol: String, _ n: Int, _ label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text("\(n)").contentTransition(.numericText())
            Text(label).opacity(0.85)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Theme.accentInk.opacity(0.14), in: Capsule())
    }

    // MARK: Bo'limlar

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(Array(modes.enumerated()), id: \.element.id) { i, m in
                Button { Haptics.tap(); model.open(m.route) } label: { modeCard(m) }
                    .buttonStyle(.press)
                    .appear(delay: 0.06 + 0.035 * Double(i))
            }
        }
        .padding(.horizontal, Theme.gutter)
    }

    private func modeCard(_ m: Mode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: m.symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(m.tint)
                .frame(width: 42, height: 42)
                .background(m.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(m.title).font(Theme.Font.headline).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(m.sub).font(Theme.Font.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.l))
        .accessibilityElement(children: .combine)
    }

    // MARK: Aeroportlar — bugun

    private var airportsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Aeroportlar tablosi", "Табло аэропортов", "Airport boards"),
                          kicker: tr("Bugun", "Сегодня", "Today"),
                          actionTitle: tr("Tablo", "Табло", "Board")) { model.open(.board(nil)) }
            LazyVStack(spacing: 0) {
                ForEach(airports.airports) { a in
                    Button { Haptics.tap(); model.open(.board(a.iata)) } label: {
                        TransportAirportRow(airport: a, stat: stats.stats[a.iata])
                    }
                    .buttonStyle(.press)
                    .task { await stats.ensure(a.iata) }
                }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
            .padding(.horizontal, Theme.gutter)
        }
    }
}

private struct TransportAirportRow: View {
    let airport: BoardAirport
    let stat: TransportAirportStat?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(airport.iata).font(Theme.Font.boardCode).foregroundStyle(Theme.accent)
                .frame(width: 46, height: 34)
                .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(airport.city).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                Group {
                    if let s = stat {
                        if s.dep + s.arr == 0 {
                            Text(tr("Bugun reys yoʻq", "Сегодня рейсов нет", "No flights today"))
                        } else if let n = s.next {
                            Text("\(tr("Keyingi", "Ближайший", "Next")): \(n.newTimeText ?? n.timeText) · \(n.f.flight) \(s.nextDir == .arr ? "←" : "→") \(n.city)")
                        } else {
                            Text(tr("Bugun boshqa reys yoʻq", "Сегодня больше рейсов нет", "No more flights today"))
                        }
                    } else {
                        Text(airport.name)
                    }
                }
                .font(Theme.Font.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 6)
            if let s = stat, s.dep + s.arr > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 8) {
                        Label("\(s.dep)", systemImage: "airplane.departure")
                        Label("\(s.arr)", systemImage: "airplane.arrival")
                    }
                    .font(Theme.Font.caption.weight(.semibold).monospacedDigit()).foregroundStyle(Theme.ink2)
                    .labelStyle(TransportCompactLabel())
                    if s.delayed > 0 {
                        Text(tr("\(s.delayed) kechikmoqda", "\(s.delayed) задерж.", "\(s.delayed) delayed"))
                            .font(Theme.Font.boardCaption2Bold).foregroundStyle(Theme.warn)
                    }
                }
                .contentTransition(.numericText())
                .transition(.opacity)
            } else if stat == nil {
                ProgressView().controlSize(.small)
            }
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.line)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line.opacity(0.5)).frame(height: 0.5).padding(.leading, 72) }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voice)
        .accessibilityHint(tr("Tabloni ochish", "Открыть табло", "Open the board"))
    }

    private var voice: String {
        var s = "\(airport.city), \(airport.iata)"
        if let st = stat {
            s += ". " + tr("Bugun: \(st.dep) uchish, \(st.arr) qoʻnish", "Сегодня: вылетов \(st.dep), прилётов \(st.arr)", "Today: \(st.dep) departures, \(st.arr) arrivals")
            if st.delayed > 0 { s += ", " + tr("\(st.delayed) kechikmoqda", "задерживается \(st.delayed)", "\(st.delayed) delayed") }
        }
        return s
    }
}

private struct TransportCompactLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) { configuration.icon.font(.caption2); configuration.title }
    }
}
