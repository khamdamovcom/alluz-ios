// Shaharlararo masofalar: qayerdan → qayerga (qidiruvli ro'yxat, almashtirish), yo'l bo'yicha km (katta raqam), yo'l vaqti,
// to'g'ri chiziq, poyezd / samolyot / avtobus, mini xarita (ikki nuqta va yo'l chizig'i), mashhur yo'nalishlar.
// API: `distances` (shaharlar), `distances/<a>-<b>` (juftlik) — server: /opt/alluz/src/pages/app-distances.js. pair formati sayt bilan bir xil: «toshkent-samarqand».
import SwiftUI
import MapKit

struct DistancesScreen: View {
    let pair: String?

    var body: some View {
        Loadable(load: { try await API.shared.get("distances") as DistIndex }) { index in
            DistancesContent(index: index, pair: pair)
        }
        .background(Theme.paper)
        .navigationTitle(tr("Masofalar", "Расстояния", "Distances"))
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Modellar (server shartnomasi: docs/API.md «Masofalar»)
private struct DistCity: Decodable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let region: String?
    let regionName: String?
    let lat: Double
    let lon: Double
    let tier: String?
    let iata: String?
    let rail: Bool?
    let order: Int?
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
}
private struct DistPopular: Decodable, Hashable, Sendable {
    let pair: String
    let from: String
    let to: String
    let fromName: String
    let toName: String
    let km: Int
    let min: Int?
}
private struct DistSource: Decodable, Sendable { let road: String?; let attribution: String?; let license: String?; let fetched: String? }
private struct DistIndex: Decodable, Sendable {
    let cities: [DistCity]
    let popular: [DistPopular]
    let source: DistSource?
}
private struct DistTrain: Decodable, Hashable, Sendable {
    let slug: String?
    let number: String?
    let title: String
    let type: String?
    let dep: String
    let arr: String
    let plusDay: Int?
    let min: Int
    let from: String?
    let to: String?
    let days: String?
}
private struct DistTrains: Decodable, Sendable {
    struct Near: Decodable, Sendable { let slug: String; let name: String; let km: Int }
    let available: Bool
    let count: Int
    let fastest: DistTrain?
    let list: [DistTrain]
    let noStation: String?
    let nearest: Near?
}
private struct DistPlane: Decodable, Sendable {
    struct AP: Decodable, Sendable { let iata: String; let own: Bool; let km: Int }
    let from: AP?
    let to: AP?
    let noAirport: String?
    let same: Bool
    let count: Int
    let min: Int?
    let hasData: Bool
}
private struct DistBus: Decodable, Sendable { let count: Int; let daily: Int; let min: Int?; let departures: [String] }
private struct DistPair: Decodable, Sendable {
    struct Road: Decodable, Sendable { let km: Double; let min: Int? }
    struct Air: Decodable, Sendable { let km: Double }
    let pair: String
    let canonical: String?
    let from: DistCity
    let to: DistCity
    let road: Road
    let air: Air
    let line: [[Double]]?
    let train: DistTrains
    let plane: DistPlane
    let bus: DistBus
    let web: String?
}

// MARK: - Asosiy kontent
private struct DistancesContent: View {
    let index: DistIndex
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fromID: String
    @State private var toID: String
    @State private var result: DistPair?
    @State private var loading = false
    @State private var error: String?
    @State private var swapTurns = 0.0
    @State private var picking: DistPickSide?
    @State private var showAllTrains = false

    init(index: DistIndex, pair: String?) {
        self.index = index
        let ids = Set(index.cities.map(\.id))
        var a = "toshkent", b = "samarqand"
        if let pair {
            let p = pair.lowercased().split(separator: "-").map(String.init)
            if p.count == 2, ids.contains(p[0]), ids.contains(p[1]), p[0] != p[1] { a = p[0]; b = p[1] }
        }
        if !ids.contains(a) { a = index.cities.first?.id ?? a }
        if !ids.contains(b) || a == b { b = index.cities.first(where: { $0.id != a })?.id ?? b }
        _fromID = State(initialValue: a)
        _toID = State(initialValue: b)
    }

    private func city(_ id: String) -> DistCity? { index.cities.first { $0.id == id } }
    private var pairKey: String { "\(fromID)-\(toID)" }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    picker.id("top").padding(.horizontal, Theme.gutter).appear()
                    resultSection
                    popularSection(proxy)
                    sourceNote.padding(.horizontal, Theme.gutter)
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
        }
        .toolbar {
            if let web = result?.web, let u = URL(string: AppConfig.site + web) {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: u) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel(tr("Ulashish", "Поделиться", "Share"))
                }
            }
        }
        .task(id: pairKey) { await loadPair() }
        .sheet(item: $picking) { side in
            DistCityPicker(cities: index.cities, selected: side == .from ? fromID : toID,
                           excluded: side == .from ? toID : fromID, title: side.title) { id in
                picking = nil
                withAnimation(Motion.spring) { if side == .from { fromID = id } else { toID = id } }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func loadPair() async {
        loading = true
        defer { loading = false }
        do {
            let r: DistPair = try await API.shared.get("distances/\(pairKey)")
            withAnimation(Motion.spring) { result = r; error = nil; showAllTrains = false }
        } catch is CancellationError {
        } catch {
            withAnimation(Motion.gentle) { self.error = error.localizedDescription }
        }
    }

    // MARK: qayerdan / qayerga
    private var picker: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                cityRow(.from, city(fromID))
                Divider().overlay(Theme.line).padding(.leading, 44)
                cityRow(.to, city(toID))
            }
            Button {
                Haptics.tap()
                withAnimation(Motion.spring) {
                    swap(&fromID, &toID)
                    swapTurns += 1
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.accentInk)
                    .frame(width: 48, height: 48)
                    .background(Theme.accent, in: Circle())
                    .rotationEffect(.degrees(reduceMotion ? 0 : swapTurns * 180))
            }
            .buttonStyle(.press)
            .accessibilityLabel(tr("Yoʻnalishni almashtirish", "Поменять направление", "Swap direction"))
        }
        .padding(.vertical, 6).padding(.leading, 14).padding(.trailing, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
    }

    private func cityRow(_ side: DistPickSide, _ c: DistCity?) -> some View {
        Button { Haptics.select(); picking = side } label: {
            HStack(spacing: 12) {
                Image(systemName: side == .from ? "circle.circle.fill" : "mappin.circle.fill")
                    .font(.system(size: 22)).foregroundStyle(side == .from ? Theme.teal : Theme.accent)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(side.title).font(Theme.Font.caption).foregroundStyle(Theme.muted)
                    Text(c?.name ?? "—").font(Theme.Font.title3).foregroundStyle(Theme.ink)
                        .contentTransition(.interpolate)
                        .id(c?.id)
                        .transition(.push(from: side == .from ? .bottom : .top).combined(with: .opacity))
                }
                .clipped()
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            }
            .frame(minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityLabel("\(side.title): \(c?.name ?? "")")
        .accessibilityHint(tr("Shaharni tanlash", "Выбрать город", "Choose a city"))
    }

    // MARK: natija
    @ViewBuilder private var resultSection: some View {
        if let r = result {
            VStack(alignment: .leading, spacing: 16) {
                hero(r).padding(.horizontal, Theme.gutter)
                DistMiniMap(pair: r)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
                    .padding(.horizontal, Theme.gutter)
                modes(r).padding(.horizontal, Theme.gutter)
            }
            .opacity(loading ? 0.55 : 1)
            .animation(Motion.gentle, value: loading)
        } else if let error {
            ErrorState(error: DistError(message: error)) { Task { await loadPair() } }
        } else {
            RoundedRectangle(cornerRadius: Theme.Radius.l).fill(Theme.paper3).frame(height: 180).overlay(Shimmer())
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l))
                .padding(.horizontal, Theme.gutter)
                .accessibilityLabel(tr("Yuklanmoqda", "Загрузка", "Loading"))
        }
    }

    private func hero(_ r: DistPair) -> some View {
        let km = Int(r.road.km.rounded())
        return VStack(alignment: .leading, spacing: 10) {
            Kicker(text: tr("Yoʻl boʻyicha", "По дороге", "By road"))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Fmt.num(km))
                    .font(Theme.Font.display(64).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(value: Double(km)))
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(tr("km", "км", "km")).font(Theme.Font.title).foregroundStyle(Theme.muted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(tr("\(km) kilometr yoʻl boʻyicha", "\(km) км по дороге", "\(km) kilometres by road"))
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { heroStats(r) }
                VStack(alignment: .leading, spacing: 8) { heroStats(r) }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
    }

    @ViewBuilder private func heroStats(_ r: DistPair) -> some View {
        if let m = r.road.min {
            statPill("car.fill", "≈ " + Fmt.duration(minutes: m), tr("avtomobilda", "на машине", "by car"), Theme.accent)
        }
        statPill("location.north.line.fill", Fmt.km(r.air.km), tr("toʻgʻri chiziq", "по прямой", "straight line"), Theme.teal)
    }

    private func statPill(_ symbol: String, _ value: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(Theme.Font.headline.monospacedDigit()).foregroundStyle(Theme.ink).contentTransition(.numericText())
                Text(label).font(Theme.Font.caption).foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: transport turlari
    private func modes(_ r: DistPair) -> some View {
        VStack(spacing: 12) {
            modeCard("tram.fill", tr("Poyezdda", "На поезде", "By train"), Theme.teal) { trainBody(r) }
            modeCard("airplane", tr("Samolyotda", "На самолёте", "By plane"), Color(uiColor: .systemBlue)) { planeBody(r) }
            modeCard("bus.fill", tr("Avtobusda", "На автобусе", "By bus"), Theme.gold) { busBody(r) }
        }
    }

    private func modeCard<C: View>(_ symbol: String, _ title: String, _ color: Color, @ViewBuilder content: () -> C) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Theme.Font.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                content()
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func trainBody(_ r: DistPair) -> some View {
        let t = r.train
        if let f = t.fastest {
            Text(Fmt.duration(minutes: f.min)).font(Theme.Font.title3.monospacedDigit()).foregroundStyle(Theme.ink).contentTransition(.numericText())
            Text(trainLine(f)).font(Theme.Font.sub).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
            if t.count > 0 {
                Button {
                    Haptics.select()
                    withAnimation(Motion.spring) { showAllTrains.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAllTrains ? tr("Yashirish", "Скрыть", "Hide")
                                           : tr("Barcha poyezdlar (\(t.count))", "Все поезда (\(t.count))", "All trains (\(t.count))"))
                        Image(systemName: "chevron.down").rotationEffect(.degrees(showAllTrains ? 180 : 0))
                    }
                    .font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.accent)
                    .frame(minHeight: 36)
                }
                .buttonStyle(.plain)
                if showAllTrains {
                    VStack(spacing: 0) {
                        ForEach(Array(t.list.enumerated()), id: \.offset) { i, tr0 in
                            trainRow(tr0)
                            if i < t.list.count - 1 { Divider().overlay(Theme.line) }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        } else if t.available {
            Text(tr("Toʻgʻri poyezd yoʻq", "Прямых поездов нет", "No direct trains")).font(Theme.Font.headline).foregroundStyle(Theme.ink)
        } else {
            let miss = t.noStation.flatMap(city)?.name ?? ""
            Text(tr("\(miss) shahrida vokzal yoʻq", "В городе \(miss) нет вокзала", "\(miss) has no railway station"))
                .font(Theme.Font.headline).foregroundStyle(Theme.ink)
            if let n = t.nearest {
                Text(tr("Eng yaqini: \(n.name) — \(Fmt.km(Double(n.km)))", "Ближайший: \(n.name) — \(Fmt.km(Double(n.km)))",
                        "Nearest: \(n.name) — \(Fmt.km(Double(n.km)))"))
                    .font(Theme.Font.sub).foregroundStyle(Theme.ink2)
            }
        }
    }

    private func trainLine(_ f: DistTrain) -> String {
        var s = "\(f.title) · \(f.dep) → \(f.arr)"
        if let p = f.plusDay, p > 0 { s += " (+\(p))" }
        if let a = f.from, let b = f.to { s += "\n\(a) → \(b)" }
        return s
    }

    private func trainRow(_ t: DistTrain) -> some View {
        Button {
            if let slug = t.slug { Haptics.tap(); app.open(.item(ItemRef(type: "train", slug: slug))) }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(t.title).font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.ink)
                        if let k = trainType(t.type) {
                            Text(k).font(.caption2.weight(.bold)).foregroundStyle(Theme.teal)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.teal.opacity(0.12), in: Capsule())
                        }
                    }
                    if let d = t.days { Text(d).font(Theme.Font.caption).foregroundStyle(Theme.muted).lineLimit(2) }
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(t.dep) → \(t.arr)\((t.plusDay ?? 0) > 0 ? " +\(t.plusDay!)" : "")")
                        .font(Theme.Font.sub.monospacedDigit().weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(Fmt.duration(minutes: t.min)).font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.muted)
                }
            }
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .disabled(t.slug == nil)
        .accessibilityElement(children: .combine)
    }

    private func trainType(_ t: String?) -> String? {
        switch t {
        case "highspeed": tr("Tezyurar", "Скоростной", "High-speed")
        case "fast": tr("Tez", "Скорый", "Fast")
        case "night": tr("Tungi", "Ночной", "Night")
        case "passenger": tr("Yoʻlovchi", "Пассажирский", "Passenger")
        case "suburban": tr("Elektrichka", "Пригородный", "Suburban")
        default: nil
        }
    }

    @ViewBuilder private func planeBody(_ r: DistPair) -> some View {
        let p = r.plane
        if let miss = p.noAirport {
            Text(tr("\(city(miss)?.name ?? miss) yaqinida aeroport yoʻq", "Рядом с городом \(city(miss)?.name ?? miss) нет аэропорта",
                    "No airport near \(city(miss)?.name ?? miss)"))
                .font(Theme.Font.headline).foregroundStyle(Theme.ink)
        } else if p.same {
            Text(tr("Ikkala shahar bitta aeroportga yaqin", "Оба города у одного аэропорта", "Both cities share one airport"))
                .font(Theme.Font.headline).foregroundStyle(Theme.ink)
        } else if p.count > 0 {
            Text(p.min.map { Fmt.duration(minutes: $0) } ?? tr("\(p.count) ta reys", "Рейсов: \(p.count)", "\(p.count) flights"))
                .font(Theme.Font.title3.monospacedDigit()).foregroundStyle(Theme.ink)
            Text(tr("Bugun va ertaga: \(p.count) ta toʻgʻri reys", "Сегодня и завтра: прямых рейсов — \(p.count)",
                    "Today and tomorrow: \(p.count) direct flights") + airportsLine(p))
                .font(Theme.Font.sub).foregroundStyle(Theme.ink2)
            if let iata = p.from?.iata {
                Button { Haptics.tap(); app.open(.board(iata)) } label: {
                    Label(tr("Tabloni ochish", "Открыть табло", "Open flight board"), systemImage: "airplane.departure")
                        .font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.accent).frame(minHeight: 36)
                }
                .buttonStyle(.plain)
            }
        } else {
            Text(p.hasData ? tr("Bugun va ertaga toʻgʻri reys yoʻq", "Сегодня и завтра прямых рейсов нет", "No direct flights today or tomorrow")
                           : tr("Reyslar haqida maʼlumot yoʻq", "Нет данных о рейсах", "No flight data"))
                .font(Theme.Font.headline).foregroundStyle(Theme.ink)
            let line = airportsLine(p)
            if !line.isEmpty { Text(line.trimmingCharacters(in: .whitespaces)).font(Theme.Font.sub).foregroundStyle(Theme.ink2) }
        }
    }

    private func airportsLine(_ p: DistPlane) -> String {
        guard let a = p.from, let b = p.to else { return "" }
        return " · \(a.iata) → \(b.iata)"
    }

    @ViewBuilder private func busBody(_ r: DistPair) -> some View {
        let b = r.bus
        if b.count > 0 {
            Text(b.min.map { Fmt.duration(minutes: $0) } ?? tr("\(b.count) ta yoʻnalish", "Маршрутов: \(b.count)", "\(b.count) routes"))
                .font(Theme.Font.title3.monospacedDigit()).foregroundStyle(Theme.ink)
            Text(tr("\(b.count) ta yoʻnalish · kuniga \(b.daily) ta qatnov", "Маршрутов: \(b.count) · рейсов в день: \(b.daily)",
                    "\(b.count) routes · \(b.daily) departures a day"))
                .font(Theme.Font.sub).foregroundStyle(Theme.ink2)
            if !b.departures.isEmpty {
                Text(tr("Joʻnash: ", "Отправление: ", "Departs: ") + b.departures.joined(separator: ", "))
                    .font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.muted)
            }
        } else {
            Text(tr("Toʻgʻri avtobus maʼlumoti yoʻq", "Нет данных о прямых автобусах", "No direct bus data"))
                .font(Theme.Font.headline).foregroundStyle(Theme.ink)
        }
    }

    // MARK: mashhur yo'nalishlar
    private func popularSection(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Mashhur yoʻnalishlar", "Популярные направления", "Popular routes"))
            VStack(spacing: 0) {
                ForEach(Array(index.popular.enumerated()), id: \.element.pair) { i, p in
                    Button {
                        Haptics.select()
                        withAnimation(Motion.spring) { fromID = p.from; toID = p.to; proxy.scrollTo("top", anchor: .top) }
                    } label: {
                        HStack(spacing: 10) {
                            Text(p.fromName).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                            Image(systemName: "arrow.right").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                            Text(p.toName).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                            Spacer(minLength: 6)
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(Fmt.km(Double(p.km))).font(Theme.Font.sub.monospacedDigit().weight(.semibold)).foregroundStyle(Theme.ink2)
                                if let m = p.min { Text(Fmt.duration(minutes: m)).font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.muted) }
                            }
                        }
                        .padding(.vertical, 10)
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.press)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(p.from == fromID && p.to == toID ? .isSelected : [])
                    if i < index.popular.count - 1 { Divider().overlay(Theme.line) }
                }
            }
            .padding(.horizontal, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
            .padding(.horizontal, Theme.gutter)
        }
    }

    private var sourceNote: some View {
        Text(tr("Yoʻl masofasi va vaqti — OSRM, © OpenStreetMap hissadorlari (ODbL). Vaqt taxminiy, toʻxtashlarsiz.",
                "Расстояние и время в пути — OSRM, © участники OpenStreetMap (ODbL). Время примерное, без остановок.",
                "Road distance and time — OSRM, © OpenStreetMap contributors (ODbL). Times are approximate, without stops."))
            .font(.caption2).foregroundStyle(Theme.muted)
    }
}

private struct DistError: LocalizedError { let message: String; var errorDescription: String? { message } }

private enum DistPickSide: String, Identifiable {
    case from, to
    var id: String { rawValue }
    var title: String { self == .from ? tr("Qayerdan", "Откуда", "From") : tr("Qayerga", "Куда", "To") }
}

// MARK: - Mini xarita (ikki nuqta va yo'l chizig'i; chiziq bo'lmasa — to'g'ri chiziq, uzuq)
private struct DistMiniMap: View {
    let pair: DistPair
    @State private var position: MapCameraPosition = .automatic

    private var coords: [CLLocationCoordinate2D] {
        if let line = pair.line, line.count > 1 {
            return line.compactMap { $0.count >= 2 ? CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) : nil }
        }
        return [pair.from.coordinate, pair.to.coordinate]
    }

    var body: some View {
        Map(position: $position, interactionModes: []) {
            MapPolyline(coordinates: coords)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: pair.line == nil ? [8, 6] : []))
            Annotation(pair.from.name, coordinate: pair.from.coordinate) { pin(Theme.teal, "circle.fill") }
            Annotation(pair.to.name, coordinate: pair.to.coordinate) { pin(Theme.accent, "mappin") }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .onAppear { position = .rect(rect) }
        .onChange(of: pair.pair) { withAnimation(Motion.gentle) { position = .rect(rect) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("Xarita: \(pair.from.name) — \(pair.to.name)", "Карта: \(pair.from.name) — \(pair.to.name)",
                               "Map: \(pair.from.name) — \(pair.to.name)"))
    }

    private func pin(_ color: Color, _ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(color, in: Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
    }

    /// Ikkala nuqta va chiziq sig'adigan to'rtburchak (+ chetdan joy)
    private var rect: MKMapRect {
        let pts = (coords + [pair.from.coordinate, pair.to.coordinate]).map(MKMapPoint.init)
        let xs = pts.map(\.x), ys = pts.map(\.y)
        let r = MKMapRect(x: xs.min()!, y: ys.min()!, width: max(xs.max()! - xs.min()!, 1), height: max(ys.max()! - ys.min()!, 1))
        let padX = r.width * 0.18 + 20000, padY = r.height * 0.25 + 20000
        return r.insetBy(dx: -padX, dy: -padY)
    }
}

// MARK: - Shahar tanlash (qidiruvli ro'yxat)
private struct DistCityPicker: View {
    let cities: [DistCity]
    let selected: String
    let excluded: String
    let title: String
    let onPick: (String) -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [DistCity] {
        let q = MapText.norm(query.trimmingCharacters(in: .whitespaces))
        guard !q.isEmpty else { return cities }
        return cities.filter { MapText.norm($0.name).contains(q) || MapText.norm($0.regionName ?? "").contains(q) || $0.id.contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                let list = filtered
                if list.isEmpty {
                    EmptyState().listRowBackground(Color.clear)
                }
                ForEach(list) { c in
                    Button { Haptics.select(); onPick(c.id) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name).font(Theme.Font.headline).foregroundStyle(c.id == excluded ? Theme.muted : Theme.ink)
                                if let r = c.regionName { Text(r).font(Theme.Font.caption).foregroundStyle(Theme.muted) }
                            }
                            Spacer(minLength: 8)
                            HStack(spacing: 6) {
                                if c.iata != nil { Image(systemName: "airplane").accessibilityLabel(tr("Aeroport", "Аэропорт", "Airport")) }
                                if c.rail == true { Image(systemName: "tram.fill").accessibilityLabel(tr("Vokzal", "Вокзал", "Railway station")) }
                            }
                            .font(.caption).foregroundStyle(Theme.muted)
                            if c.id == selected { Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Theme.accent) }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(c.id == excluded)
                    .listRowBackground(Theme.card)
                    .accessibilityAddTraits(c.id == selected ? .isSelected : [])
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: tr("Shahar qidirish", "Поиск города", "Search city"))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Yopish", "Закрыть", "Close")) { dismiss() }
                }
            }
        }
    }
}
