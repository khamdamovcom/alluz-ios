// Universal ro'yxat: /list/:type — tur chiplari, hudud filtri, ichki qidiruv (300 ms debounce), saralash, ro'yxat ↔ katak,
// cheksiz aylantirish (offset/limit=40), jami soni, bo'sh holat. Venue: spec.kind = stay|eat — guruh, ichida faqat shu guruh turlari.
import SwiftUI
import Observation

struct ListScreen: View {
    let spec: ListSpec
    @State private var vm: ExListModel
    @AppStorage("ex.list.grid") private var grid = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    init(spec: ListSpec) {
        self.spec = spec
        _vm = State(initialValue: ExListModel(spec: spec))
    }

    private var title: String {
        if let t = spec.title, !t.isEmpty { return t }
        if spec.unesco && spec.type == "place" { return tr("UNESCO merosi", "Наследие ЮНЕСКО", "UNESCO heritage") }
        return ExTypes.title(spec.type, group: vm.group)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    content
                } header: {
                    filterBar
                }
            }
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $vm.query, placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: tr("Nomi boʻyicha qidirish", "Поиск по названию", "Search by name"))
        .autocorrectionDisabled()
        .toolbar { toolbar }
        .task(id: vm.filterKey) { await vm.reload(debounced: true) }
        .task { if ExTypes.regionFiltered.contains(spec.type) { await ExRegionStore.shared.load() } }
        .refreshable { await vm.reload(debounced: false) }
    }

    // MARK: Filtr paneli (yuqoriga yopishadi)
    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !vm.chips.isEmpty {
                ChipBar(items: vm.chips.map { ($0.key, $0.label, Optional($0.count)) }, selected: $vm.kind)
            }
            HStack(spacing: 10) {
                Group {
                    if vm.phase == .loading && vm.items.isEmpty {
                        Text(tr("Yuklanmoqda…", "Загрузка…", "Loading…"))
                    } else {
                        Text(ExTypes.count(vm.total, spec.type, group: vm.group))
                            .contentTransition(.numericText(value: Double(vm.total)))
                    }
                }
                .font(Theme.Font.sub.weight(.semibold))
                .foregroundStyle(Theme.ink2)
                .animation(Motion.snappy, value: vm.total)
                if vm.isRefreshing { ProgressView().controlSize(.small) }
                Spacer(minLength: 4)
                if ExTypes.regionFiltered.contains(spec.type) { regionMenu }
            }
            .padding(.horizontal, Theme.gutter)
        }
        .padding(.top, 6)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper)
    }

    private var regionMenu: some View {
        let regions = ExRegionStore.shared.items
        let name = ExRegionStore.shared.name(vm.region) ?? (vm.region == nil ? tr("Barcha hududlar", "Все регионы", "All regions") : vm.region!)
        return Menu {
            Picker(tr("Hudud", "Регион", "Region"), selection: Binding(get: { vm.region }, set: { r in
                Haptics.select(); withAnimation(Motion.snappy) { vm.region = r }
            })) {
                Text(tr("Barcha hududlar", "Все регионы", "All regions")).tag(String?.none)
                ForEach(regions) { r in Text(r.name).tag(r.slug) }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "mappin.and.ellipse")
                Text(name).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .font(Theme.Font.sub.weight(.medium))
            .foregroundStyle(vm.region == nil ? Theme.ink : Theme.accentInk)
            .padding(.horizontal, 12).frame(minHeight: 36)
            .background(vm.region == nil ? AnyShapeStyle(Theme.card) : AnyShapeStyle(Theme.accent), in: Capsule())
            .overlay(Capsule().strokeBorder(vm.region == nil ? Theme.line : .clear))
            .contentShape(Capsule())
        }
        .accessibilityLabel(tr("Hudud: \(name)", "Регион: \(name)", "Region: \(name)"))
    }

    // MARK: Asboblar paneli: saralash, UNESCO, ko'rinish
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Picker(tr("Saralash", "Сортировка", "Sort"), selection: Binding(get: { vm.sortByName }, set: { v in
                    Haptics.select(); vm.sortByName = v
                })) {
                    Label(vm.defaultSortTitle, systemImage: vm.defaultSortSymbol).tag(false)
                    Label(tr("Nomi boʻyicha (A–Z)", "По названию (А–Я)", "By name (A–Z)"), systemImage: "textformat").tag(true)
                }
                if spec.type == "place" {
                    Toggle(isOn: Binding(get: { vm.unesco }, set: { v in Haptics.select(); vm.unesco = v })) {
                        Label(tr("Faqat UNESCO", "Только ЮНЕСКО", "UNESCO only"), systemImage: "globe.europe.africa")
                    }
                }
                if vm.hasFilters {
                    Divider()
                    Button(role: .destructive) { withAnimation(Motion.snappy) { vm.clearFilters() } } label: {
                        Label(tr("Filtrlarni tozalash", "Сбросить фильтры", "Clear filters"), systemImage: "xmark.circle")
                    }
                }
            } label: {
                Image(systemName: vm.hasFilters || vm.sortByName ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
            .accessibilityLabel(tr("Saralash va filtr", "Сортировка и фильтр", "Sort and filter"))

            Button {
                Haptics.select()
                withAnimation(reduce ? nil : Motion.spring) { grid.toggle() }
            } label: {
                Image(systemName: grid ? "list.bullet" : "square.grid.2x2")
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(grid ? tr("Roʻyxat koʻrinishi", "Список", "List view") : tr("Katak koʻrinishi", "Сетка", "Grid view"))
        }
    }

    // MARK: Kontent
    @ViewBuilder private var content: some View {
        switch vm.phase {
        case .loading where vm.items.isEmpty:
            SkeletonList(rows: 5).transition(.opacity)
        case .failed(let error) where vm.items.isEmpty:
            ErrorState(error: error) { Task { await vm.reload(debounced: false) } }
        default:
            if vm.items.isEmpty {
                VStack(spacing: 4) {
                    EmptyState(text: vm.hasFilters || !vm.query.isEmpty
                               ? tr("Filtr yoki qidiruvni oʻzgartirib koʻring.", "Попробуйте изменить фильтры или запрос.", "Try changing the filters or search.")
                               : nil)
                    if vm.hasFilters || !vm.query.isEmpty {
                        Button(tr("Filtrlarni tozalash", "Сбросить фильтры", "Clear filters")) {
                            withAnimation(Motion.snappy) { vm.clearFilters(); vm.query = "" }
                        }
                        .secondaryButton().tint(Theme.accent)
                    }
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            } else {
                Group {
                    if grid { gridView.transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top))) }
                    else { listView.transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top))) }
                }
                .opacity(vm.isRefreshing ? 0.55 : 1)
                .animation(Motion.gentle, value: vm.isRefreshing)
                footer
            }
        }
    }

    private var listView: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(vm.items) { card in
                VStack(spacing: 0) {
                    CardRow(card: card)
                    Divider().overlay(Theme.line.opacity(0.5)).padding(.leading, 96)
                }
                .padding(.horizontal, Theme.gutter)
                .transition(.opacity)
            }
        }
    }

    private var gridView: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14, alignment: .top), GridItem(.flexible(), spacing: 14, alignment: .top)],
                  alignment: .leading, spacing: 18) {
            ForEach(Array(vm.items.enumerated()), id: \.element.id) { i, card in
                Group {
                    if card.img == nil, let symbol = symbolCard(card) {
                        ExSymbolCard(card: card, symbol: symbol, tint: ExKinds.tint(i), height: 200)
                    } else {
                        CardTile(card: card, width: nil, imageHeight: 132)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 4)
    }

    /// Oxiriga yetganda — keyingi sahifa
    @ViewBuilder private var footer: some View {
        if vm.canLoadMore {
            HStack { Spacer(); ProgressView().padding(.vertical, 20); Spacer() }
                .task(id: vm.items.count) { await vm.loadMore() }
        } else if let e = vm.moreError {
            Button {
                Task { await vm.loadMore(retry: true) }
            } label: {
                Label(e, systemImage: "arrow.clockwise").font(Theme.Font.sub).frame(maxWidth: .infinity, minHeight: 44)
            }
            .tint(Theme.accent)
            .padding(.horizontal, Theme.gutter)
        } else if vm.items.count > 8 {
            Text(tr("Roʻyxat oxiri", "Конец списка", "End of list"))
                .font(Theme.Font.caption).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity).padding(.vertical, 20)
        }
    }

    /// Rasmsiz turlar (an'ana, bayram, maslahat) katakda ikonkali karta bo'lib chiqadi
    private func symbolCard(_ card: Card) -> String? {
        switch spec.type {
        case "tradition": ExCultureSymbols.tradition(card.slug)
        case "holiday": ExCultureSymbols.holiday(card.slug)
        case "guide": SymbolMap.symbol(card.icon)
        default: nil
        }
    }
}

// MARK: - Ro'yxat holati

@MainActor @Observable
final class ExListModel {
    enum Phase: Equatable {
        case loading, loaded, failed(Error)
        static func == (a: Phase, b: Phase) -> Bool {
            switch (a, b) { case (.loading, .loading), (.loaded, .loaded), (.failed, .failed): true; default: false }
        }
    }

    let type: String
    /// venue: stay | eat
    let group: String?
    let district: String?

    var kind: String?
    var region: String?
    var unesco: Bool
    var sortByName = false
    var query = ""

    private(set) var items: [Card] = []
    private(set) var total = 0
    private(set) var chips: [ExKindStat] = []
    private(set) var phase: Phase = .loading
    private(set) var isRefreshing = false
    private(set) var moreError: String?
    private var loadingMore = false
    private var generation = 0
    private var loadedQuery = ""
    private var loadedKey: String?
    private var loadedOnce = false
    private static let pageSize = 40

    init(spec: ListSpec) {
        type = spec.type
        district = spec.district
        if spec.type == "venue", let g = ExKinds.group(of: spec.kind) {
            group = g
            kind = (spec.kind == "stay" || spec.kind == "eat") ? nil : spec.kind
        } else {
            group = nil
            kind = spec.kind
        }
        region = spec.region
        unesco = spec.unesco
    }

    var filterKey: String { "\(kind ?? "-")|\(region ?? "-")|\(unesco)|\(sortByName)|\(query.trimmingCharacters(in: .whitespaces))" }
    var hasFilters: Bool { kind != nil || region != nil || unesco }
    var canLoadMore: Bool { phase == .loaded && !isRefreshing && moreError == nil && items.count < total }

    var defaultSortTitle: String {
        switch type {
        case "person": tr("Tugʻilgan yili boʻyicha", "По году рождения", "By birth year")
        case "route": tr("Kunlar soni boʻyicha", "По числу дней", "By number of days")
        case "place", "venue": tr("Reyting boʻyicha", "По рейтингу", "By rating")
        default: tr("Tavsiya etilgan", "Рекомендуемые", "Recommended")
        }
    }
    var defaultSortSymbol: String {
        switch type { case "person", "route": "calendar"; case "place", "venue": "star"; default: "sparkles" }
    }

    func clearFilters() { kind = nil; region = nil; unesco = false }

    private func params(offset: Int) -> [String: String] {
        var q: [String: String] = ["offset": String(offset), "limit": String(Self.pageSize)]
        if let k = kind ?? group { q["kind"] = k }
        if let region { q["region"] = region }
        if let district { q["district"] = district }
        if unesco { q["unesco"] = "1" }
        if sortByName { q["sort"] = "name" }
        let s = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { q["q"] = String(s.prefix(80)) }
        return q
    }

    /// Filtr o'zgarganda: qidiruv matni o'zgargan bo'lsa — 300 ms kutib (debounce), keyin birinchi sahifa
    func reload(debounced: Bool) async {
        let q = query.trimmingCharacters(in: .whitespaces)
        // Ekranga qaytilganda (.task qayta ishga tushadi) — shu filtr allaqachon yuklangan bo'lsa, sahifalar saqlanib qoladi
        if debounced, phase == .loaded, loadedKey == filterKey { return }
        if debounced, loadedOnce, q != loadedQuery {
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
        }
        generation += 1
        let gen = generation
        let key = filterKey
        moreError = nil
        if items.isEmpty { phase = .loading } else { isRefreshing = true }
        do {
            let page: ListPage = try await API.shared.get("list/\(type)", query: params(offset: 0))
            guard gen == generation else { return }
            let newChips = makeChips(page)
            withAnimation(Motion.spring) {
                items = page.items
                total = page.total
                if !newChips.isEmpty || chips.isEmpty { chips = newChips }
                phase = .loaded
                isRefreshing = false
            }
            loadedQuery = q
            loadedKey = key
            loadedOnce = true
        } catch is CancellationError {
            if gen == generation { isRefreshing = false }
        } catch {
            guard gen == generation else { return }
            isRefreshing = false
            if items.isEmpty { withAnimation { phase = .failed(error) } }
            else { AppModel.shared.show(error.localizedDescription) }
        }
    }

    func loadMore(retry: Bool = false) async {
        if retry { moreError = nil }
        guard phase == .loaded, !loadingMore, !isRefreshing, items.count < total else { return }
        loadingMore = true
        let gen = generation
        defer { loadingMore = false }
        do {
            let page: ListPage = try await API.shared.get("list/\(type)", query: params(offset: items.count))
            guard gen == generation else { return }
            let seen = Set(items.map(\.id))
            let fresh = page.items.filter { !seen.contains($0.id) }
            items.append(contentsOf: fresh)
            total = page.total
            if fresh.isEmpty { total = items.count }          // server boshqa javob bersa — cheksiz aylanish bo'lmasin
        } catch is CancellationError {
        } catch {
            guard gen == generation else { return }
            moreError = tr("Davomini yuklab boʻlmadi — qayta urinish", "Не удалось загрузить — повторить", "Couldn't load more — try again")
        }
    }

    private func makeChips(_ page: ListPage) -> [ExKindStat] {
        guard ExTypes.kindFiltered.contains(type), !page.kinds.isEmpty else { return [] }
        var keys: [String]
        switch type {
        case "place":
            keys = ExKinds.placeOrder.filter { page.kinds[$0] != nil }
            keys += page.kinds.keys.filter { !keys.contains($0) }.sorted()
        case "venue":
            let base = group == "stay" ? ExKinds.stay : group == "eat" ? ExKinds.eat : ExKinds.stay + ExKinds.eat
            keys = base.filter { page.kinds[$0] != nil }
        default:
            keys = page.kinds.keys.sorted { (page.kinds[$0] ?? 0, $1) > (page.kinds[$1] ?? 0, $0) }
        }
        let stats = keys.compactMap { k -> ExKindStat? in
            guard let n = page.kinds[k], n > 0 else { return nil }
            return ExKindStat(key: k, label: ExKinds.label(type, k, server: page.kindLabels[k]), count: n)
        }
        // Tanlangan tur shu hududda bo'lmasa ham chip ko'rinsin (0 bilan)
        if let kind, !stats.contains(where: { $0.key == kind }) {
            return stats + [ExKindStat(key: kind, label: ExKinds.label(type, kind, server: page.kindLabels[kind]), count: 0)]
        }
        return stats.count > 1 || kind != nil ? stats : []
    }
}
