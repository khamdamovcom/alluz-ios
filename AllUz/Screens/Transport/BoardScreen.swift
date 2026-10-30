// Aeroport tablosi («Tablo» tabi va .board(IATA)): 16 aeroport, Uchib ketish/Qo'nish, Kecha/Bugun/Ertaga, qidiruv,
// «hozir» chizig'i (o'tganlar xiraroq, ochilganda hozirgi vaqtga aylantiriladi), har 60 s jonli yangilanish (faqat ekran
// ko'rinib turganda), tortib yangilash, reys tafsiloti (BoardFlightSheet).
// Ma'lumot: GET /api/board?airport=&dir=&day= (sayt transport.js apiBoard) — vaqtlar Toshkent vaqtida.
import SwiftUI

// MARK: - Holat

@MainActor @Observable
final class BoardViewModel {
    private(set) var iata: String
    private(set) var dir: BoardDir = .dep
    private(set) var day: BoardDay = .today
    private(set) var query = ""
    /// Kalit → oxirgi javob (yo'nalish/kun almashganda darhol ko'rsatiladi)
    private var cache: [String: BoardResponse] = [:]
    private var errors: [String: Error] = [:]
    private var loadingKey: String?
    private(set) var list = BoardList.empty
    /// «Hozir» chizig'iga aylantirish so'rovi (yangi aeroport/yo'nalish/kun birinchi marta ko'rsatilganda)
    private(set) var scrollRequest = 0
    private var scrolledKeys: Set<String> = []
    private(set) var now = Date()

    init(iata: String) { self.iata = iata }

    var key: String { "\(iata)|\(dir.rawValue)|\(day.rawValue)" }
    var response: BoardResponse? { cache[key] }
    var error: Error? { errors[key] }
    var refreshing: Bool { loadingKey == key }
    var updatedAt: Date? { BoardTime.parse(response?.updatedAt) }
    /// 40 daqiqadan eski (sayt STALE_MS) yoki server shunday dedi
    var isStale: Bool {
        if response?.state == "stale" { return true }
        guard let u = updatedAt else { return false }
        return now.timeIntervalSince(u) > 40 * 60
    }

    func select(iata new: String) {
        guard new != iata else { return }
        iata = new
        UserDefaults.standard.set(new, forKey: BoardAirport.storeKey)
        rebuild()
    }
    func select(dir new: BoardDir) { guard new != dir else { return }; dir = new; rebuild() }
    func select(day new: BoardDay) { guard new != day else { return }; day = new; rebuild() }
    func apply(query q: String) { guard q != query else { return }; query = q; rebuild(scroll: false) }

    func load() async {
        let k = key, (a, d, dy) = (iata, dir, day)
        loadingKey = k
        defer { if loadingKey == k { loadingKey = nil } }
        do {
            let r: BoardResponse = try await API.shared.getRaw("/api/board", query: ["airport": a, "dir": d.rawValue, "day": dy.rawValue])
            cache[k] = r
            errors[k] = nil
            now = Date()
            if k == key { rebuild() }
        } catch is CancellationError {
        } catch {
            errors[k] = error
        }
    }

    func tick() { now = Date() }

    private func rebuild(scroll: Bool = true) {
        guard let r = cache[key] else { list = .empty; return }
        let new = BoardList.make(r, dir: dir, day: day, query: query)
        withAnimation(Motion.gentle) { list = new }
        // Bugungi ro'yxatda o'tgan reyslar ko'p bo'lsa — birinchi ochilishda «hozir»ga
        if scroll, day == .today, query.isEmpty, !scrolledKeys.contains(key) {
            scrolledKeys.insert(key)
            if new.past.count > 2 { scrollRequest += 1 }
        }
    }
}

// MARK: - Ekran

struct BoardScreen: View {
    let iata: String?

    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var phase
    @State private var vm: BoardViewModel
    @State private var airports = BoardAirportStore.shared
    @State private var search = ""
    @State private var selected: BoardItem?

    init(iata: String?) {
        self.iata = iata
        _vm = State(initialValue: BoardViewModel(iata: BoardAirport.resolve(iata)))
    }

    private var airport: BoardAirport? { airports.airport(vm.iata) }
    private var cityName: String { airport?.city ?? vm.iata }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    hero
                    BoardAirportChips(airports: airports.airports, selected: vm.iata) { pick($0) }
                        .padding(.bottom, 10)
                    Section {
                        content
                    } header: {
                        controls
                    }
                    footer
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: vm.scrollRequest) {
                Task {
                    try? await Task.sleep(for: .milliseconds(120))
                    withAnimation(Motion.spring) { proxy.scrollTo("board-now", anchor: UnitPoint(x: 0.5, y: 0.22)) }
                }
            }
        }
        .background(Theme.paper)
        .navigationTitle(cityName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleMenu {
            ForEach(airports.airports) { a in
                Button { pick(a.iata) } label: {
                    if a.iata == vm.iata { Label("\(a.city) · \(a.iata)", systemImage: "checkmark") } else { Text("\(a.city) · \(a.iata)") }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await vm.load(); Haptics.soft() } } label: {
                    ZStack {
                        if vm.refreshing { ProgressView().controlSize(.small).transition(.opacity) }
                        else { Image(systemName: "arrow.clockwise").transition(.opacity) }
                    }
                    .animation(Motion.snappy, value: vm.refreshing)
                }
                .disabled(vm.refreshing)
                .accessibilityLabel(tr("Yangilash", "Обновить", "Refresh"))
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: tr("Reys, shahar yoki aviakompaniya", "Рейс, город или авиакомпания", "Flight, city or airline"))
        .refreshable { await vm.load() }
        // Jonli yangilanish: faqat ekran ko'rinib turganda va ilova faol bo'lsa (ekran yopilsa — Task bekor bo'ladi)
        .task(id: "\(vm.key)|\(phase == .active)|\(model.reloadToken)") {
            guard phase == .active else { return }
            await vm.load()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                if Task.isCancelled { break }
                await vm.load()
            }
        }
        // «Hozir» chizig'i daqiqasiga bir siljiydi
        .task(id: phase == .active) {
            while !Task.isCancelled && phase == .active {
                try? await Task.sleep(for: .seconds(30))
                vm.tick()
            }
        }
        .task(id: search) {
            if !search.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
            if !Task.isCancelled { vm.apply(query: search) }
        }
        .task { await airports.ensure() }
        .sheet(item: $selected) { sel in
            BoardFlightSheet(item: vm.list.item(sel.id) ?? sel, dir: vm.dir, day: vm.day, airport: airport ?? BoardAirport(iata: vm.iata, slug: "", region: "", city: vm.iata, name: vm.iata),
                             source: vm.response?.source, updatedAt: vm.updatedAt)
        }
    }

    private func pick(_ code: String) {
        Haptics.select()
        search = ""
        vm.select(iata: code)
    }

    // MARK: Sarlavha

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                BoardLiveDot(color: vm.isStale ? Theme.warn : Theme.ok, size: 7, pulsing: !vm.isStale)
                Kicker(text: tr("Jonli tablo", "Онлайн-табло", "Live board"))
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(cityName).font(Theme.Font.display(34)).foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.opacity)
                Text(vm.iata).font(Theme.Font.mono).foregroundStyle(Theme.muted)
                    .contentTransition(.numericText())
            }
            .animation(Motion.spring, value: vm.iata)
            if let a = airport {
                Button { model.open(.item(ItemRef(type: "airport", slug: a.slug))) } label: {
                    HStack(spacing: 4) {
                        Text(a.name).multilineTextAlignment(.leading)
                        Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                    }
                    .font(Theme.Font.sub).foregroundStyle(Theme.ink2)
                }
                .buttonStyle(.plain)
                .accessibilityHint(tr("Aeroport haqida", "Об аэропорте", "About the airport"))
            }
            Text(dateLine).font(Theme.Font.caption).foregroundStyle(Theme.muted)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var dateLine: String {
        let d = BoardTime.date(ymd: vm.response?.date) ?? vm.now
        let day = Fmt.day(d, weekday: true)
        return "\(day.prefix(1).uppercased())\(day.dropFirst()) · \(tr("Toshkent vaqti", "Время ташкентское", "Tashkent time")) \(BoardTime.time(vm.now))"
    }

    // MARK: Boshqaruv (yuqoriga yopishib turadi)

    private var controls: some View {
        VStack(spacing: 8) {
            BoardSegment(items: BoardDir.allCases, selection: Binding(get: { vm.dir }, set: { vm.select(dir: $0) }),
                         title: { $0.title }, symbol: { $0.symbol })
            HStack(spacing: 8) {
                BoardSegment(items: BoardDay.allCases, selection: Binding(get: { vm.day }, set: { vm.select(day: $0) }),
                             title: { $0.title }, compact: true)
                Spacer(minLength: 4)
                BoardUpdatedBadge(updated: vm.updatedAt, refreshing: vm.refreshing, stale: vm.isStale)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 8)
        .background(Theme.paper.opacity(0.94))
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line.opacity(0.6)).frame(height: 0.5) }
    }

    // MARK: Ro'yxat

    @ViewBuilder private var content: some View {
        if let r = vm.response {
            notes(r)
            if vm.list.isEmpty {
                emptyView(r)
            } else {
                ForEach(vm.list.past) { row($0, dim: true) }
                if vm.list.showsNow {
                    BoardNowLine(now: vm.now, count: vm.list.upcoming.count).id("board-now")
                    if vm.list.upcoming.isEmpty {
                        EmptyState(title: tr("Bugun boshqa reys yoʻq", "Сегодня больше рейсов нет", "No more flights today"), symbol: "moon.stars")
                            .frame(minHeight: 200)
                    }
                }
                ForEach(vm.list.upcoming) { row($0, dim: false) }
            }
        } else if let e = vm.error {
            errorView(e)
        } else {
            BoardSkeleton()
        }
    }

    private func row(_ it: BoardItem, dim: Bool) -> some View {
        Button {
            Haptics.tap()
            selected = it
        } label: {
            BoardFlightRow(item: it, dir: vm.dir, dim: dim)
        }
        .buttonStyle(.press)
        .transition(.opacity)
        .accessibilityLabel(it.voiceLabel(dir: vm.dir))
        .accessibilityHint(tr("Reys tafsilotlari", "Подробности рейса", "Flight details"))
    }

    @ViewBuilder private func notes(_ r: BoardResponse) -> some View {
        let n = noteItems(r)
        if !n.isEmpty {
            VStack(spacing: 8) {
                ForEach(n, id: \.0) { BoardNote(text: $0.0, symbol: $0.1, tint: $0.2) }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 12)
        }
    }

    private func noteItems(_ r: BoardResponse) -> [(String, String, Color)] {
        var out: [(String, String, Color)] = []
        if vm.isStale, let u = vm.updatedAt {
            let t = (BoardTime.ymd(u) == BoardTime.ymd(vm.now) ? "" : BoardTime.dayMonth(u) + " ") + BoardTime.time(u)
            out.append((tr("Maʼlumot eskirgan: oxirgi yangilanish \(t). Manba vaqtincha javob bermayapti.",
                           "Данные устарели: последнее обновление \(t). Источник временно не отвечает.",
                           "Data may be out of date: last updated \(t). The source is temporarily not responding."), "exclamationmark.triangle", Theme.warn))
        } else if vm.error != nil {
            out.append((tr("Yangilab boʻlmadi — oxirgi maʼlumot koʻrsatilmoqda.", "Не удалось обновить — показаны последние данные.",
                           "Couldn’t refresh — showing the latest data."), "wifi.exclamationmark", Theme.warn))
        }
        if r.observed == true {
            out.append((tr("Kechagi roʻyxat — saytimiz kun davomida kuzatgan reyslar, toʻliq boʻlmasligi mumkin.",
                           "Вчерашний список — рейсы, которые наш сайт видел в течение дня; он может быть неполным.",
                           "Yesterday’s list shows the flights our site saw during the day and may be incomplete."), "info.circle", Theme.teal))
        }
        return out
    }

    @ViewBuilder private func emptyView(_ r: BoardResponse) -> some View {
        Group {
            if !vm.query.isEmpty {
                EmptyState(title: tr("Qidiruv boʻyicha reys topilmadi", "По запросу рейсов не найдено", "No flights match your search"),
                           text: tr("Reys raqami, shahar yoki aviakompaniya nomini yozing.", "Введите номер рейса, город или авиакомпанию.", "Try a flight number, city or airline."))
            } else {
                switch r.state ?? "ok" {
                case "pending":
                    EmptyState(title: tr("Tablo hali yuklanmoqda", "Табло ещё загружается", "Board is loading"),
                               text: tr("Tablo maʼlumoti hali olinmagan — birozdan keyin paydo boʻladi.", "Данные табло ещё не получены — появятся через несколько минут.",
                                        "Board data has not arrived yet — it will appear in a few minutes."), symbol: "clock")
                case "error":
                    EmptyState(title: tr("Tablo javob bermayapti", "Табло не отвечает", "Board not responding"),
                               text: tr("Aeroport tablosi hozir javob bermayapti. Birozdan keyin qayta urinamiz.", "Табло аэропорта сейчас не отвечает. Мы повторим попытку позже.",
                                        "The airport board is not responding right now. We will try again shortly."), symbol: "exclamationmark.triangle")
                case "unsupported":
                    EmptyState(title: tr("Kechagi reyslar yoʻq", "Нет вчерашних рейсов", "No data for yesterday"),
                               text: tr("Bu aeroport manbasi kechagi reyslarni bermaydi.", "Источник этого аэропорта не показывает вчерашние рейсы.",
                                        "This airport’s source does not publish yesterday’s flights."), symbol: "calendar")
                default:
                    EmptyState(title: tr("Bu kunga reyslar eʼlon qilinmagan", "Рейсов на этот день нет", "No flights listed for this day"),
                               text: tr("Kichik aeroportlarda reyslar har kuni boʻlmaydi — boshqa kunni yoki yoʻnalishni tanlang.",
                                        "В небольших аэропортах рейсы бывают не каждый день — выберите другой день или направление.",
                                        "Smaller airports don’t have flights every day — try another day or direction."), symbol: "airplane")
                }
            }
        }
        .transition(.opacity)
    }

    @ViewBuilder private func errorView(_ e: Error) -> some View {
        if (e as? APIError) == .notFound {
            EmptyState(title: tr("Jonli tablo yoʻq", "Нет онлайн-табло", "No live board"),
                       text: tr("Bu aeroport uchun jonli tablo manbasi yoʻq. Yuqoridan boshqa aeroportni tanlang.",
                                "Для этого аэропорта нет источника онлайн-табло. Выберите другой аэропорт выше.",
                                "There is no live board source for this airport. Pick another airport above."), symbol: "airplane.circle")
        } else {
            ErrorState(error: e) { Task { await vm.load() } }
        }
    }

    // MARK: Pastki qism — manba

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let s = vm.response?.source, let host = BoardSource.host(s) {
                Button { model.openWeb(BoardSource.home(s)) } label: {
                    Label("\(tr("Manba", "Источник", "Source")): \(host)", systemImage: "link")
                        .font(Theme.Font.caption.weight(.medium)).foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
            Text(tr("Vaqtlar — Toshkent vaqti (UTC+5). Rasmiy aeroport tablolaridan; vaqtlar oʻzgarishi mumkin — aniq maʼlumotni aviakompaniyangizdan oling.",
                    "Время — ташкентское (UTC+5). С официальных табло аэропортов; время может меняться — уточняйте у своей авиакомпании.",
                    "Times are Tashkent time (UTC+5), from the official airport boards. Times may change — always check with your airline."))
                .font(Theme.Font.caption).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }
}

/// Manba havolasi: to'liq API manzili emas — sayt bosh sahifasi
enum BoardSource {
    static func host(_ s: String) -> String? {
        guard let u = URL(string: s), let h = u.host else { return nil }
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }
    static func home(_ s: String) -> String? {
        guard let u = URL(string: s), u.scheme == "https", let h = u.host else { return nil }
        let site = h.hasPrefix("api.") ? String(h.dropFirst(4)) : h
        return "https://\(site)/"
    }
}

// MARK: - Aeroport chiplari

struct BoardAirportChips: View {
    let airports: [BoardAirport]
    let selected: String
    let pick: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(airports) { a in
                        let on = a.iata == selected
                        Button { if !on { pick(a.iata) } } label: {
                            HStack(spacing: 6) {
                                Text(a.city).font(Theme.Font.sub.weight(.semibold))
                                Text(a.iata).font(Theme.Font.boardCode)
                                    .foregroundStyle(on ? Theme.accentInk.opacity(0.8) : Theme.muted)
                            }
                            .padding(.horizontal, 14).frame(minHeight: 38)
                            .foregroundStyle(on ? Theme.accentInk : Theme.ink)
                            .background(on ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.card), in: Capsule())
                            .overlay(Capsule().strokeBorder(on ? .clear : Theme.line))
                        }
                        .buttonStyle(.press)
                        .id(a.iata)
                        .accessibilityLabel("\(a.city), \(a.iata)")
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 2)
                .animation(Motion.snappy, value: selected)
            }
            .onAppear { proxy.scrollTo(selected, anchor: .center) }
            .onChange(of: selected) { withAnimation(Motion.spring) { proxy.scrollTo(selected, anchor: .center) } }
        }
    }
}

// MARK: - Reys qatori

struct BoardFlightRow: View {
    let item: BoardItem
    let dir: BoardDir
    var dim = false
    @ScaledMetric(relativeTo: .title3) private var timeW: CGFloat = 64

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timeColumn.frame(width: timeW, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.city).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                        .strikethrough(item.cancelled, color: Theme.bad.opacity(0.7))
                        .lineLimit(2)
                    if let i = item.otherIata { Text(i).font(Theme.Font.boardCode).foregroundStyle(Theme.muted) }
                }
                HStack(spacing: 4) {
                    Text(item.f.flight).font(Theme.Font.boardCode).foregroundStyle(Theme.ink2)
                    if !item.airline.isEmpty { Text("· \(item.airline)").lineLimit(1) }
                    if !item.f.codeshares.isEmpty { Text("+\(item.f.codeshares.count)").font(Theme.Font.boardCode).foregroundStyle(Theme.teal) }
                }
                .font(Theme.Font.caption).foregroundStyle(Theme.muted)
                statusLine.padding(.top, 2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.line)
                .padding(.top, 6)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(item.tone == .boarding && !dim ? Theme.accent.opacity(0.05) : .clear)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line.opacity(0.5)).frame(height: 0.5).padding(.leading, Theme.gutter) }
        .opacity(dim ? 0.55 : 1)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var timeColumn: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let nt = item.newTimeText {
                HStack(alignment: .top, spacing: 1) {
                    Text(nt).font(Theme.Font.boardTime)
                        .foregroundStyle(item.cancelled ? Theme.muted : item.early ? Theme.ok : Theme.warn)
                    if item.newShift != 0 {
                        Text(item.newShift > 0 ? "+\(item.newShift)" : "\(item.newShift)").font(Theme.Font.boardCode).foregroundStyle(Theme.warn)
                    }
                }
                Text(item.timeText).font(Theme.Font.boardTimeSmall).foregroundStyle(Theme.muted)
                    .strikethrough(true, color: Theme.muted)
            } else {
                Text(item.timeText).font(Theme.Font.boardTime).foregroundStyle(item.cancelled ? Theme.muted : Theme.ink)
                    .strikethrough(item.cancelled, color: Theme.bad.opacity(0.7))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .contentTransition(.numericText())
        .animation(Motion.spring, value: item.newTimeText)
    }

    private var statusLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { pill; bits }
            VStack(alignment: .leading, spacing: 6) { pill; bits }
        }
    }
    private var pill: some View { BoardStatusPill(label: item.label, tone: item.tone).fixedSize() }
    @ViewBuilder private var bits: some View {
        if !item.bits.isEmpty {
            HStack(spacing: 4) { ForEach(item.bits, id: \.self) { BoardBitTag(bit: $0) } }
        }
    }
}

// MARK: - «Hozir» chizig'i

struct BoardNowLine: View {
    let now: Date
    let count: Int
    var body: some View {
        HStack(spacing: 8) {
            BoardLiveDot(color: Theme.accent, size: 8)
            Text("\(tr("Hozir", "Сейчас", "Now")) \(BoardTime.time(now))")
                .font(Theme.Font.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText())
                .animation(Motion.gentle, value: BoardTime.time(now))
            Rectangle().fill(Theme.accent.opacity(0.6)).frame(height: 1.5)
            if count > 0 {
                Text(tr("Keyingi: \(count)", "Далее: \(count)", "Next: \(count)"))
                    .font(Theme.Font.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tr("Hozir", "Сейчас", "Now")) \(BoardTime.time(now)). \(tr("Keyingi reyslar", "Следующие рейсы", "Upcoming flights")): \(count)")
    }
}
