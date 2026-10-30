// Pochta indekslari: region=nil — hududlar ro'yxati va indeks qidiruvi (raqamli klaviatura; «ABC» — aholi punkti nomi bilan);
// hudud — aloqa bo'limlari shahar/tuman bo'yicha (indeks katta mono shriftda, nusxa olish), bosilsa — .item(post, slug).
// API: post, post/:region, post-search?q= (docs/API.md «Pochta»).
import SwiftUI
import UIKit

struct PostScreen: View {
    let region: String?
    var body: some View {
        Group {
            if let region {
                Loadable(load: { try await API.shared.get("post/" + region) as PostRegionData }) { data in
                    PostRegionView(data: data)
                }
                .navigationTitle(tr("Pochta indekslari", "Почтовые индексы", "Postcodes"))
            } else {
                Loadable(load: { try await API.shared.get("post") as PostRegionsData }) { data in
                    PostHomeView(data: data)
                }
                .navigationTitle(tr("Pochta indekslari", "Почтовые индексы", "Postcodes"))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.paper)
    }
}

/// Indeks katta mono shriftda (Theme.Font.mono dan kattaroq — SO'ROV: Theme.Font.monoLarge)
private extension Font {
    static let postIndex = Font.system(.title2, design: .monospaced).weight(.bold)
}

// MARK: - Bosh sahifa: qidiruv + hududlar
private struct PostHomeView: View {
    let data: PostRegionsData
    @State private var query = ""
    @State private var textMode = false
    @State private var result: PostSearchData?
    @State private var searching = false
    @State private var searchError: String?
    @FocusState private var focused: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduce

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                header.appear()
                searchField.appear(delay: 0.05)
                if !trimmed.isEmpty {
                    results
                } else {
                    regions
                    if let cc = data.callCenter, let u = GovLinks.tel(cc) {
                        InfoRow(symbol: "phone", title: data.callCenterLabel ?? "", value: cc) { model.openURL(u) }
                            .padding(.horizontal, 14)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
                            .accessibilityHint(tr("Qo'ng'iroq qilish", "Позвонить", "Call"))
                    }
                }
            }
            .padding(Theme.gutter)
            .padding(.bottom, 20)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .scrollDismissesKeyboard(.interactively)
        .task(id: trimmed) { await search() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Kicker(text: tr("Oʻzbekiston pochtasi", "Почта Узбекистана", "Uzbekistan Post"))
            Text(tr("Pochta indeksini toping", "Найдите почтовый индекс", "Find a postcode"))
                .font(Theme.Font.largeTitle).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            Text(tr("\(Fmt.num(data.total)) ta indeks · \(data.regions.count) hudud", "\(Fmt.num(data.total)) индексов · \(data.regions.count) регионов", "\(Fmt.num(data.total)) postcodes · \(data.regions.count) regions"))
                .font(Theme.Font.sub).foregroundStyle(Theme.muted)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
            TextField(textMode ? tr("Aholi punkti yoki manzil", "Населённый пункт или адрес", "Town, village or address") : tr("Indeks, masalan 140100", "Индекс, например 140100", "Postcode, e.g. 140100"), text: $query)
                .keyboardType(textMode ? .default : .numberPad)
                .textContentType(textMode ? nil : .postalCode)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(textMode ? Theme.Font.body : Theme.Font.mono)
                .focused($focused)
                .submitLabel(.search)
                .id(textMode)          // klaviatura turi almashsa — maydon qayta yaratiladi
                .onChange(of: query) { _, v in
                    // Raqamli rejimda faqat raqamlar, 6 tagacha
                    if !textMode { let d = String(v.filter(\.isNumber).prefix(6)); if d != v { query = d } }
                }
            if !query.isEmpty {
                Button { query = ""; Haptics.select() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted) }
                    .accessibilityLabel(tr("Tozalash", "Очистить", "Clear"))
            }
            Button {
                Haptics.select()
                textMode.toggle()
                query = ""
                DispatchQueue.main.async { focused = true }
            } label: {
                Text(textMode ? "123" : "ABC").font(Theme.Font.caption.weight(.bold)).foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Theme.accent.opacity(0.12), in: Capsule())
            }
            .accessibilityLabel(textMode ? tr("Indeks bo'yicha qidirish", "Искать по индексу", "Search by postcode") : tr("Nom bo'yicha qidirish", "Искать по названию", "Search by name"))
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous).strokeBorder(focused ? Theme.accent : Theme.line, lineWidth: focused ? 1.5 : 1))
        .animation(Motion.snappy, value: focused)
    }

    @ViewBuilder private var results: some View {
        if let r = result, r.q == trimmed || r.q == trimmed.filter(\.isNumber) {
            VStack(alignment: .leading, spacing: 10) {
                if let lead = leadText(r) {
                    Text(lead).font(Theme.Font.sub).foregroundStyle(r.mode == "near" ? Theme.warn : Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.numericText())
                }
                if r.items.isEmpty {
                    EmptyState(text: tr("6 xonali indeks yoki aholi punkti nomini yozing.", "Введите 6-значный индекс или название населённого пункта.", "Type a 6-digit postcode or a place name."))
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(r.items.enumerated()), id: \.element.id) { i, p in
                            PostOfficeRow(p: p, showRegion: true).appear(delay: reduce || i > 10 ? 0 : Double(i) * 0.03)
                        }
                    }
                }
            }
        } else if let e = searchError {
            Text(e).font(Theme.Font.sub).foregroundStyle(Theme.bad)
        } else {
            HStack { Spacer(); ProgressView().tint(Theme.accent); Spacer() }.padding(.vertical, 30)
        }
    }

    private func leadText(_ r: PostSearchData) -> String? {
        switch r.mode {
        case "near": tr("\(r.q) indeksi topilmadi — eng yaqinlari:", "Индекс \(r.q) не найден — ближайшие:", "Postcode \(r.q) not found — the nearest ones:")
        case "dup": tr("\(r.q) indeksi bir nechta bo'limda:", "Индекс \(r.q) у нескольких отделений:", "Postcode \(r.q) is shared by several offices:")
        case "prefix": tr("\(r.q) bilan boshlanadigan indekslar: \(r.total)", "Индексы, начинающиеся с \(r.q): \(r.total)", "Postcodes starting with \(r.q): \(r.total)")
        case "text": tr("Topildi: \(r.total)", "Найдено: \(r.total)", "Found: \(r.total)")
        default: nil
        }
    }

    private var regions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("Hududlar", "Регионы", "Regions")).font(Theme.Font.title).foregroundStyle(Theme.ink)
            LazyVStack(spacing: 0) {
                ForEach(Array(data.regions.enumerated()), id: \.element.id) { i, r in
                    Button { model.open(.post(r.slug)) } label: {
                        HStack(spacing: 14) {
                            Text(r.prefix).font(Font.postIndex).foregroundStyle(Theme.accentInk)
                                .frame(width: 56, height: 48)
                                .background(Theme.hue(r.slug), in: RoundedRectangle(cornerRadius: Theme.Radius.s, style: .continuous))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name).font(Theme.Font.headline).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                                Text("\(r.min) – \(r.max)").font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.muted)
                            }
                            Spacer(minLength: 6)
                            Text(Fmt.num(r.count)).font(Theme.Font.sub.weight(.semibold).monospacedDigit()).foregroundStyle(Theme.ink2)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.press)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(r.name), \(tr("indekslar", "индексы", "postcodes")) \(r.min) – \(r.max), \(r.count)")
                    .accessibilityAddTraits(.isButton)
                    .appear(delay: reduce ? 0 : min(Double(i) * 0.03, 0.4))
                    if i < data.regions.count - 1 { Divider().overlay(Theme.line).padding(.leading, 70) }
                }
            }
            .padding(.horizontal, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
        }
    }

    /// 300 ms debounce; 1–2 belgida so'rov yuborilmaydi (raqamli rejimda 1 raqamdan — prefiks)
    private func search() async {
        let q = trimmed
        searchError = nil
        guard !q.isEmpty else { result = nil; return }
        guard textMode ? q.count >= 2 : true else { result = PostSearchData(q: q, mode: "empty", total: 0, items: []); return }
        try? await Task.sleep(for: .milliseconds(300))
        if Task.isCancelled { return }
        searching = true
        defer { searching = false }
        do {
            let r: PostSearchData = try await API.shared.get("post-search", query: ["q": q])
            if Task.isCancelled { return }
            withAnimation(reduce ? nil : Motion.snappy) { result = r }
            if r.mode == "index" || r.mode == "dup" { Haptics.success() }
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled { searchError = error.localizedDescription }
        }
    }
}

// MARK: - Hudud: bo'limlar guruhlari
private struct PostRegionView: View {
    let data: PostRegionData
    @State private var query = ""
    @State private var group: String?
    @State private var shown: [PostRegionData.Group]
    @State private var keys: [String: String] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduce

    init(data: PostRegionData) {
        self.data = data
        _shown = State(initialValue: data.groups)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                header.padding(.horizontal, Theme.gutter).appear()
                if data.groups.count > 1 {
                    ChipBar(items: data.groups.map { (key: $0.id, label: $0.name, count: $0.count) }, selected: $group)
                }
                if shown.isEmpty {
                    EmptyState(text: query.isEmpty ? nil : tr("Boshqa indeks yoki nom bilan urinib ko'ring.", "Попробуйте другой индекс или название.", "Try another postcode or name."))
                } else {
                    ForEach(shown) { g in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(g.name).font(Theme.Font.title3).foregroundStyle(Theme.ink)
                                Spacer()
                                Text(Fmt.num(g.items.count)).font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.muted)
                            }
                            .accessibilityAddTraits(.isHeader)
                            ForEach(g.items) { p in PostOfficeRow(p: p, showRegion: false) }
                        }
                        .padding(.horizontal, Theme.gutter)
                        .appear(delay: reduce ? 0 : 0.05)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, 20)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .scrollDismissesKeyboard(.immediately)
        .searchable(text: $query, prompt: tr("Indeks yoki aholi punkti", "Индекс или населённый пункт", "Postcode or place"))
        .autocorrectionDisabled()
        .toolbar {
            if let u = GovLinks.https(data.web) {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: u) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel(tr("Ulashish", "Поделиться", "Share"))
                }
            }
        }
        .task(id: "\(query)|\(group ?? "")") { await filter() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Kicker(text: tr("Pochta indekslari", "Почтовые индексы", "Postcodes"))
                Text(data.region.name).font(Theme.Font.largeTitle).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                Text(tr("\(Fmt.num(data.region.count)) ta indeks", "Индексов: \(Fmt.num(data.region.count))", "\(Fmt.num(data.region.count)) postcodes"))
                    .font(Theme.Font.sub).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 6)
            if let p = data.region.prefix {
                VStack(spacing: 0) {
                    Text(p).font(Theme.Font.display(34)).foregroundStyle(Theme.accentInk)
                    Text("····").font(Theme.Font.mono).foregroundStyle(Theme.accentInk.opacity(0.7))
                }
                .frame(width: 84, height: 84)
                .background(Theme.hue(data.region.slug), in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
                .rotationEffect(.degrees(-4))
                .accessibilityHidden(true)
            }
        }
    }

    private func filter() async {
        if keys.isEmpty {
            // Qidiruv kalitlari bir marta hisoblanadi
            var k: [String: String] = [:]
            for g in data.groups { for p in g.items { k[p.slug] = p.searchKey } }
            keys = k
        }
        if !query.isEmpty { try? await Task.sleep(for: .milliseconds(150)) }
        if Task.isCancelled { return }
        let q = query.trimmingCharacters(in: .whitespaces).postFolded
        let words = q.split(separator: " ").map(String.init)
        let base = group.map { gk in data.groups.filter { $0.id == gk } } ?? data.groups
        let out: [PostRegionData.Group] = words.isEmpty ? base : base.compactMap { g in
            let items = g.items.filter { p in let k = keys[p.slug] ?? ""; return words.allSatisfy { k.contains($0) } }
            return items.isEmpty ? nil : PostRegionData.Group(key: g.key, name: g.name, type: g.type, count: items.count, items: items)
        }
        guard out != shown else { return }
        withAnimation(reduce ? nil : Motion.snappy) { shown = out }
    }
}

/// Aloqa bo'limi qatori: katta indeks + nusxa olish, nom, manzil, holat
private struct PostOfficeRow: View {
    let p: PostOffice
    let showRegion: Bool
    @Environment(AppModel.self) private var model
    @State private var copied = 0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { model.open(.item(p.ref)) } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(p.index).font(Font.postIndex).foregroundStyle(p.isArchive ? Theme.muted : Theme.ink)
                                .tracking(1.5)
                            if p.isMain {
                                Image(systemName: "building.columns.fill").font(.caption).foregroundStyle(Theme.accent)
                                    .accessibilityHidden(true)
                            }
                            if let s = p.statusLabel {
                                Text(s).font(Theme.Font.caption.weight(.semibold)).foregroundStyle(p.isArchive ? Theme.muted : Theme.warn)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background((p.isArchive ? Theme.muted : Theme.warn).opacity(0.12), in: Capsule())
                            }
                        }
                        Text(p.settlement ?? p.name).font(Theme.Font.headline).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                        Text([p.kindLabel, showRegion ? (p.districtName ?? p.regionName) : nil].compactMap { $0 }.joined(separator: " · "))
                            .font(Theme.Font.caption).foregroundStyle(Theme.accent)
                        if let a = p.address {
                            Text(a).font(Theme.Font.sub).foregroundStyle(Theme.ink2).multilineTextAlignment(.leading).lineLimit(3)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.press)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: tr("Nusxa olish", "Копировать", "Copy")) { copy() }

            Button(action: copy) {
                Image(systemName: copied > 0 ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(copied > 0 ? Theme.ok : Theme.accent)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
                    .background(Theme.accent.opacity(0.1), in: Circle())
            }
            .buttonStyle(.press)
            .accessibilityLabel(tr("Indeksni nusxalash: \(p.index)", "Скопировать индекс: \(p.index)", "Copy postcode: \(p.index)"))
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
        .contextMenu {
            Button(action: copy) { Label(tr("Indeksni nusxalash", "Скопировать индекс", "Copy postcode"), systemImage: "doc.on.doc") }
            if let a = p.address {
                Button { UIPasteboard.general.string = "\(a), \(p.index)"; model.show(tr("Manzil nusxalandi", "Адрес скопирован", "Address copied")) } label: {
                    Label(tr("Manzilni nusxalash", "Скопировать адрес", "Copy address"), systemImage: "envelope")
                }
            }
            CardMenu(card: p.card)
        }
    }

    private var accLabel: String {
        let digits = p.index.map(String.init).joined(separator: " ")
        return [tr("Indeks", "Индекс", "Postcode") + " " + digits, p.settlement ?? p.name, p.kindLabel, p.statusLabel, p.address].compactMap { $0 }.joined(separator: ", ")
    }

    private func copy() {
        UIPasteboard.general.string = p.index
        Haptics.success()
        model.show(tr("Nusxa olindi: \(p.index)", "Скопировано: \(p.index)", "Copied: \(p.index)"))
        withAnimation(Motion.snappy) { copied += 1 }
        let n = copied
        Task { try? await Task.sleep(for: .seconds(1.6)); if copied == n { withAnimation(Motion.snappy) { copied = 0 } } }
    }
}
