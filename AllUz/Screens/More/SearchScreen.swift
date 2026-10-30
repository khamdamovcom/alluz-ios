// Qidiruv: .searchable, 300 ms debounce, API `search?q=` (≤40 natija). Natijalar tur bo'yicha guruhlanadi (birinchi uchragan tartibda).
// Bo'sh holatda: oxirgi qidiruvlar (UserDefaults, 10 ta, tozalash), mashhur so'rovlar va turlar bo'yicha tezkor havolalar.
// slug=null natija — CardRow → model.open(card) → model.openURL(card.web) (sayt havolasi ilova ichida yoki brauzer oynasida).
import SwiftUI

struct SearchScreen: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var presented = true
    @State private var state: SearchState = .idle
    @State private var history = SearchHistory.load()
    /// Klaviaturadagi «Search» / chip — debounce'siz darhol
    @State private var submitTick = 0
    @State private var immediate = false

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            Group {
                if trimmed.count < 2 {
                    SearchIdle(history: history,
                               pick: { q in Haptics.select(); immediate = true; query = q; submitTick += 1 },
                               clear: { withAnimation(Motion.spring) { history = []; SearchHistory.save([]) } })
                } else {
                    results
                }
            }
            .padding(.bottom, 24)
            .animation(Motion.gentle, value: state.key)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.paper)
        .navigationTitle(tr("Qidiruv", "Поиск", "Search"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, isPresented: $presented, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: tr("Joy, shahar, mehmonxona, taom…", "Место, город, отель, блюдо…", "Place, city, hotel, dish…"))
        .autocorrectionDisabled()
        .onSubmit(of: .search) { immediate = true; submitTick += 1; remember() }
        .task(id: "\(trimmed)|\(submitTick)|\(model.reloadToken)") { await run() }
    }

    // MARK: natijalar

    @ViewBuilder private var results: some View {
        switch state {
        case .idle, .loading:
            SearchLoadingRows().transition(.opacity)
        case .failed(let e):
            ErrorState(error: e) { immediate = true; submitTick += 1 }
        case .done(let q, let groups, let total):
            if total == 0 {
                EmptyState(title: tr("Hech narsa topilmadi", "Ничего не найдено", "Nothing found"),
                           text: tr("«\(q)» boʻyicha natija yoʻq. Boshqacha yozib koʻring yoki qisqaroq soʻz kiriting.",
                                    "По запросу «\(q)» ничего нет. Попробуйте другое написание или более короткое слово.",
                                    "No results for “\(q)”. Try a different spelling or a shorter word."),
                           symbol: "magnifyingglass")
            } else {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Text(tr("\(total) ta natija", "Найдено: \(total)", "\(total) results"))
                        .font(Theme.Font.caption).foregroundStyle(Theme.muted)
                        .padding(.horizontal, Theme.gutter).padding(.top, 8)
                        .contentTransition(.numericText())
                    ForEach(groups) { g in
                        Section {
                            ForEach(Array(g.cards.enumerated()), id: \.element.id) { i, card in
                                CardRow(card: card)
                                    .padding(.horizontal, Theme.gutter)
                                    .simultaneousGesture(TapGesture().onEnded { remember() })
                                    .appear(delay: 0.03 * Double(min(i, 8)), offset: 10)
                                if i < g.cards.count - 1 { Divider().overlay(Theme.line).padding(.leading, Theme.gutter + 96) }
                            }
                        } header: {
                            HStack(spacing: 8) {
                                Image(systemName: g.symbol).font(.footnote.weight(.semibold)).foregroundStyle(Theme.accent)
                                Text(g.title).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                                Text("\(g.cards.count)").font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.muted)
                                Spacer()
                            }
                            .padding(.horizontal, Theme.gutter).padding(.vertical, 8)
                            .background(Theme.paper)
                            .accessibilityAddTraits(.isHeader)
                        }
                    }
                }
            }
        }
    }

    // MARK: so'rov

    private func run() async {
        let q = trimmed
        let fast = immediate
        immediate = false
        guard q.count >= 2 else { state = .idle; return }
        if fast, case .done(let old, _, _) = state, old == q { return }      // shu so'rov natijasi allaqachon ekranda
        if case .done = state {} else { state = .loading }                      // yozayotganda eski natija turadi (miltillamaydi)
        // Yozilayotganda — 300 ms debounce; klaviaturadagi «Search» yoki chip bosilsa — darhol
        if !fast {
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
        }
        do {
            let r: SearchResult = try await API.shared.get("search", query: ["q": q])
            if Task.isCancelled { return }
            let groups = SearchGroup.make(r.items)
            withAnimation(Motion.gentle) { state = .done(q, groups, r.items.count) }
        } catch is CancellationError {
        } catch {
            if Task.isCancelled { return }
            withAnimation { state = .failed(error) }
        }
    }

    private func remember() {
        let q = trimmed
        guard q.count >= 2 else { return }
        history = SearchHistory.add(q, to: history)
    }
}

// MARK: - Holat va guruhlar

private enum SearchState {
    case idle, loading
    case failed(Error)
    case done(String, [SearchGroup], Int)
    var key: String {
        switch self {
        case .idle: "i"; case .loading: "l"; case .failed: "f"; case .done(let q, _, _): "d" + q
        }
    }
}

private struct SearchGroup: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let cards: [Card]

    /// Tur bo'yicha guruhlash (madaniyat turlari — bitta guruh), tartib — birinchi uchragan natija bo'yicha
    static func make(_ items: [Card]) -> [SearchGroup] {
        var order: [String] = []
        var map: [String: [Card]] = [:]
        for c in items {
            let k = key(c.type)
            if map[k] == nil { order.append(k) }
            map[k, default: []].append(c)
        }
        return order.map { k in SearchGroup(id: k, title: title(k), symbol: SymbolMap.forType(k == "culture" ? "cuisine" : k), cards: map[k] ?? []) }
    }
    static func key(_ type: String?) -> String {
        switch type {
        case "cuisine", "craft", "tradition", "holiday", "culture": "culture"
        case nil: "other"
        default: type!
        }
    }
    static func title(_ k: String) -> String {
        switch k {
        case "region": tr("Hududlar", "Регионы", "Regions")
        case "district": tr("Shahar va tumanlar", "Города и районы", "Cities and districts")
        case "place": tr("Joylar", "Места", "Places")
        case "venue": tr("Mehmonxona va restoranlar", "Отели и рестораны", "Hotels and restaurants")
        case "org": tr("Davlat idoralari", "Госучреждения", "Public offices")
        case "bank": tr("Banklar", "Банки", "Banks")
        case "post": tr("Pochta indekslari", "Почтовые индексы", "Postal codes")
        case "airport": tr("Aeroportlar", "Аэропорты", "Airports")
        case "rail_station": tr("Vokzallar", "Вокзалы", "Railway stations")
        case "train": tr("Poyezdlar", "Поезда", "Trains")
        case "bus_station": tr("Avtovokzallar", "Автовокзалы", "Bus stations")
        case "bus_route": tr("Avtobus yoʻnalishlari", "Автобусные маршруты", "Bus routes")
        case "city_transport", "metro": tr("Shahar transporti", "Городской транспорт", "City transport")
        case "person": tr("Allomalar", "Личности", "People")
        case "era": tr("Tarix", "История", "History")
        case "hist_event": tr("Tarixiy voqealar", "Исторические события", "Historical events")
        case "culture": tr("Madaniyat", "Культура", "Culture")
        case "fest": tr("Tadbirlar", "События", "Events")
        case "guide": tr("Maslahatlar", "Советы", "Tips")
        case "route": tr("Marshrutlar", "Маршруты", "Itineraries")
        default: tr("Boshqa", "Другое", "Other")
        }
    }
}

/// Oxirgi qidiruvlar — faqat shu telefonda (UserDefaults), 10 ta
private enum SearchHistory {
    static let key = "search.recent"
    static func load() -> [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }
    static func save(_ a: [String]) { UserDefaults.standard.set(a, forKey: key) }
    static func add(_ q: String, to a: [String]) -> [String] {
        var r = a.filter { $0.caseInsensitiveCompare(q) != .orderedSame }
        r.insert(q, at: 0)
        r = Array(r.prefix(10))
        save(r)
        return r
    }
}

// MARK: - Bo'sh holat

private struct SearchIdle: View {
    let history: [String]
    let pick: (String) -> Void
    let clear: () -> Void
    @Environment(AppModel.self) private var model

    private let popular: [String] = [
        tr("Registon", "Регистан", "Registan"), tr("Xiva", "Хива", "Khiva"), tr("Buxoro", "Бухара", "Bukhara"),
        tr("Samarqand", "Самарканд", "Samarkand"), tr("Osh", "Плов", "Plov"), tr("Shahrisabz", "Шахрисабз", "Shahrisabz"),
        tr("Chimyon", "Чимган", "Chimgan"), tr("Termiz", "Термез", "Termez"), tr("Orol dengizi", "Аральское море", "Aral Sea"),
        tr("Toshkent metrosi", "Ташкентское метро", "Tashkent Metro"), tr("Margʻilon", "Маргилан", "Margilan"), tr("Nukus", "Нукус", "Nukus"),
    ]

    private struct QuickType: Identifiable { let id: String; let title: String; let symbol: String; let route: Route }
    private let types: [QuickType] = [
        .init(id: "place", title: tr("Joylar", "Места", "Places"), symbol: "building.columns", route: .list(ListSpec(type: "place"))),
        .init(id: "region", title: tr("Hududlar", "Регионы", "Regions"), symbol: "map", route: .regions),
        .init(id: "stay", title: tr("Mehmonxonalar", "Отели", "Hotels"), symbol: "bed.double",
              route: .list(ListSpec(type: "venue", kind: "stay", title: tr("Mehmonxonalar", "Отели", "Hotels")))),
        .init(id: "eat", title: tr("Restoranlar", "Рестораны", "Restaurants"), symbol: "fork.knife",
              route: .list(ListSpec(type: "venue", kind: "eat", title: tr("Restoranlar", "Рестораны", "Restaurants")))),
        .init(id: "person", title: tr("Allomalar", "Личности", "Great minds"), symbol: "person", route: .list(ListSpec(type: "person"))),
        .init(id: "fest", title: tr("Tadbirlar", "События", "Events"), symbol: "calendar", route: .list(ListSpec(type: "fest"))),
        .init(id: "route", title: tr("Marshrutlar", "Маршруты", "Itineraries"), symbol: "point.topleft.down.to.point.bottomright.curvepath",
              route: .list(ListSpec(type: "route"))),
        .init(id: "gov", title: tr("Davlat idoralari", "Госучреждения", "Public offices"), symbol: "building.2", route: .gov),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tr("Oxirgi qidiruvlar", "Недавние запросы", "Recent searches")).font(Theme.Font.title3).foregroundStyle(Theme.ink)
                        Spacer()
                        Button(tr("Tozalash", "Очистить", "Clear"), action: clear)
                            .font(Theme.Font.sub.weight(.semibold)).tint(Theme.accent).frame(minHeight: 44)
                    }
                    ForEach(history, id: \.self) { q in
                        Button { pick(q) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath").foregroundStyle(Theme.muted)
                                Text(q).font(Theme.Font.body).foregroundStyle(Theme.ink).lineLimit(1)
                                Spacer()
                                Image(systemName: "arrow.up.left").font(.footnote).foregroundStyle(Theme.muted)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.press)
                        .accessibilityHint(tr("Shu soʻrovni qidirish", "Повторить поиск", "Search again"))
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
                .padding(.horizontal, Theme.gutter)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(tr("Mashhur soʻrovlar", "Популярные запросы", "Popular searches")).font(Theme.Font.title3).foregroundStyle(Theme.ink)
                SearchFlow(spacing: 8) {
                    ForEach(popular, id: \.self) { q in
                        Button { pick(q) } label: {
                            Text(q).font(Theme.Font.sub.weight(.medium)).foregroundStyle(Theme.ink)
                                .padding(.horizontal, 14).frame(minHeight: 38)
                                .background(Theme.card, in: Capsule())
                                .overlay(Capsule().strokeBorder(Theme.line))
                        }
                        .buttonStyle(.press)
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .appear(delay: 0.05)

            VStack(alignment: .leading, spacing: 12) {
                Text(tr("Boʻlimlar", "Разделы", "Browse")).font(Theme.Font.title3).foregroundStyle(Theme.ink)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(types) { t in
                        Button { Haptics.tap(); model.open(t.route) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: t.symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.accent)
                                    .frame(width: 34, height: 34)
                                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                Text(t.title).font(Theme.Font.sub.weight(.medium)).foregroundStyle(Theme.ink)
                                    .lineLimit(2).minimumScaleFactor(0.85).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
                        }
                        .buttonStyle(.press)
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .appear(delay: 0.1)
        }
        .padding(.top, 12)
    }
}

/// Yuklanayotganda — qator qoliplari
private struct SearchLoadingRows: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.paper3).frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(Theme.paper3).frame(width: 170, height: 14)
                        Capsule().fill(Theme.paper3).frame(width: 110, height: 10)
                        Capsule().fill(Theme.paper3).frame(maxWidth: 220).frame(height: 10)
                    }
                }
            }
        }
        .overlay(Shimmer())
        .padding(Theme.gutter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("Qidirilmoqda", "Идёт поиск", "Searching"))
    }
}

/// Chiplar uchun oqim tartibi (satrga sig'magani keyingi qatorga o'tadi)
struct SearchFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0, x + sz.width > maxW { y += rowH + spacing; x = 0; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x + sz.width > bounds.maxX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}
