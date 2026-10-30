// Davlat idoralari: tepada favqulodda raqamlar (bosilsa — tel:), ishonch telefonlari, hudud/tuman filtri, turlar (hokimliklar, IIB,
// soliq …) — plitkalar va chiplar, qidiruv (300 ms debounce), ro'yxat guruhlari (respublika / viloyat / shahar-tuman),
// bosilsa — .item(org, slug). Filtr bo'lmasa — respublika idoralari (vazirliklar, qo'mitalar, agentliklar).
// API: gov?region=&district=&kind=&level=&q=&offset=&limit= (docs/API.md «Davlat idoralari»).
import SwiftUI

struct GovScreen: View {
    @State private var region: String?
    @State private var district: String?
    @State private var kind: String?
    @State private var query = ""
    @State private var data: GovData?
    @State private var error: Error?
    @State private var loading = false
    @State private var loadingMore = false
    @State private var attempt = 0
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduce

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var filterKey: String { "\(region ?? "")|\(district ?? "")|\(kind ?? "")|\(trimmed)|\(attempt)|\(model.reloadToken)" }
    private var filtered: Bool { region != nil || kind != nil || !trimmed.isEmpty }

    var body: some View {
        Group {
            if let data {
                content(data)
            } else if let error {
                ErrorState(error: error) { self.error = nil; attempt += 1 }
            } else {
                SkeletonList()
            }
        }
        .background(Theme.paper)
        .navigationTitle(tr("Davlat idoralari", "Госучреждения", "Government offices"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: tr("Idora nomi yoki manzil", "Название или адрес", "Office name or address"))
        .autocorrectionDisabled()
        .task(id: filterKey) { await load(debounce: !trimmed.isEmpty && data != nil) }
    }

    // MARK: kontent
    private func content(_ d: GovData) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if trimmed.isEmpty {
                    header(d).padding(.horizontal, Theme.gutter).appear()
                    GovEmergencyGrid(phones: d.emergency).padding(.horizontal, Theme.gutter).appear(delay: 0.05)
                    if !d.hotlines.isEmpty { GovHotlineRail(hotlines: d.hotlines).appear(delay: 0.1) }
                }
                filters(d)
                if filtered, let r = d.results {
                    results(r)
                } else {
                    kindGrid(d).padding(.horizontal, Theme.gutter)
                    if !d.rep.isEmpty { repList(d).padding(.horizontal, Theme.gutter) }
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .scrollDismissesKeyboard(.immediately)
        .overlay(alignment: .top) {
            if loading {
                ProgressView().tint(Theme.accent).padding(10).glassBackground(Circle(), fallback: .regularMaterial).padding(.top, 6)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(Motion.snappy, value: loading)
        .refreshable { await load(debounce: false) }
    }

    private func header(_ d: GovData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Kicker(text: tr("Davlat xizmatlari", "Госуслуги", "Public services"))
            Text(tr("Davlat idoralari", "Государственные учреждения", "Government offices"))
                .font(Theme.Font.largeTitle).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            Text(tr("\(Fmt.num(d.total)) idora · \(d.nRegions) hudud · \(d.nDistricts) shahar va tuman",
                    "\(Fmt.num(d.total)) учреждений · \(d.nRegions) регионов · \(d.nDistricts) городов и районов",
                    "\(Fmt.num(d.total)) offices · \(d.nRegions) regions · \(d.nDistricts) cities and districts"))
                .font(Theme.Font.sub).foregroundStyle(Theme.muted)
                .contentTransition(.numericText())
        }
    }

    // Hudud va tuman menyusi + turlar chiplari
    private func filters(_ d: GovData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Menu {
                    Button { setRegion(nil) } label: { Label(tr("Butun mamlakat", "Вся страна", "Whole country"), systemImage: region == nil ? "checkmark" : "globe.asia.australia") }
                    Divider()
                    ForEach(d.regions) { r in
                        Button { setRegion(r.slug) } label: {
                            if region == r.slug { Label("\(r.name) (\(r.count))", systemImage: "checkmark") } else { Text("\(r.name) (\(r.count))") }
                        }
                    }
                } label: {
                    GovFilterLabel(symbol: "map", text: d.regions.first { $0.slug == region }?.name ?? tr("Butun mamlakat", "Вся страна", "Whole country"), on: region != nil)
                }
                .accessibilityLabel(tr("Hudud", "Регион", "Region"))
                if region != nil, !d.districts.isEmpty {
                    Menu {
                        Button { withAnimation(Motion.snappy) { district = nil } } label: { Label(tr("Hamma shahar va tumanlar", "Все города и районы", "All cities and districts"), systemImage: district == nil ? "checkmark" : "square.grid.2x2") }
                        Divider()
                        ForEach(d.districts) { x in
                            Button { Haptics.select(); withAnimation(Motion.snappy) { district = x.slug } } label: {
                                if district == x.slug { Label("\(x.name) (\(x.count))", systemImage: "checkmark") } else { Text("\(x.name) (\(x.count))") }
                            }
                        }
                    } label: {
                        GovFilterLabel(symbol: "building.2", text: d.districts.first { $0.slug == district }?.name ?? tr("Shahar/tuman", "Город/район", "City/district"), on: district != nil)
                    }
                    .accessibilityLabel(tr("Shahar yoki tuman", "Город или район", "City or district"))
                }
                Spacer(minLength: 0)
                if filtered {
                    Button {
                        Haptics.select()
                        withAnimation(Motion.snappy) { region = nil; district = nil; kind = nil; query = "" }
                    } label: { Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(Theme.muted).frame(width: 44, height: 44) }
                    .accessibilityLabel(tr("Filtrni tozalash", "Сбросить фильтр", "Clear filters"))
                }
            }
            .padding(.horizontal, Theme.gutter)
            if filtered {
                ChipBar(items: d.kinds.map { (key: $0.kind, label: $0.label, count: $0.count) }, selected: Binding(get: { kind }, set: { kind = $0 }))
            }
        }
    }

    // Filtrsiz: turlar plitkalari
    private func kindGrid(_ d: GovData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Idora turlari", "Типы учреждений", "Office types")).font(Theme.Font.title).foregroundStyle(Theme.ink)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(d.kinds.filter { !$0.rep }.enumerated()), id: \.element.id) { i, k in
                    Button { Haptics.select(); withAnimation(Motion.snappy) { kind = k.kind } } label: {
                        HStack(spacing: 10) {
                            Image(systemName: GovSymbol.of(k.icon)).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.accent)
                                .frame(width: 36, height: 36).background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.s, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(k.label).font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(2).multilineTextAlignment(.leading)
                                    .minimumScaleFactor(0.85)
                                Text(Fmt.num(k.count)).font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.muted)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.press)
                    .accessibilityElement(children: .combine)
                    .appear(delay: reduce ? 0 : min(Double(i) * 0.025, 0.4))
                }
            }
        }
    }

    // Filtrsiz: respublika idoralari (vazirliklar, qo'mitalar, agentliklar)
    private func repList(_ d: GovData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderInline(title: tr("Vazirliklar va idoralar", "Министерства и ведомства", "Ministries and agencies"), count: d.rep.count)
            ChipBarInline(kinds: d.kinds.filter(\.rep)) { k in withAnimation(Motion.snappy) { kind = k } }
            LazyVStack(spacing: 0) {
                ForEach(Array(d.rep.prefix(12).enumerated()), id: \.element.id) { i, c in
                    GovOrgRow(card: c)
                    if i < min(d.rep.count, 12) - 1 { Divider().overlay(Theme.line).padding(.leading, 56) }
                }
            }
            .padding(.horizontal, 12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
            if d.rep.count > 12 {
                Button { Haptics.select(); withAnimation(Motion.snappy) { kind = d.kinds.first(where: \.rep)?.kind } } label: {
                    Text(tr("Hammasi", "Все", "See all")).font(Theme.Font.sub.weight(.semibold)).frame(maxWidth: .infinity)
                }
                .secondaryButton().tint(Theme.accent)
            }
        }
    }

    // Filtrlangan ro'yxat
    @ViewBuilder private func results(_ r: GovData.Results) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("Topildi: \(Fmt.num(r.total))", "Найдено: \(Fmt.num(r.total))", "Found: \(Fmt.num(r.total))"))
                .font(Theme.Font.sub).foregroundStyle(Theme.muted)
                .contentTransition(.numericText())
                .padding(.horizontal, Theme.gutter)
            if r.sections.isEmpty {
                EmptyState(text: tr("Boshqa so'z yoki filtr bilan urinib ko'ring.", "Попробуйте другое слово или фильтр.", "Try another word or filter."))
            }
            ForEach(r.sections) { s in
                VStack(alignment: .leading, spacing: 6) {
                    Kicker(text: s.title).padding(.horizontal, 4).accessibilityAddTraits(.isHeader)
                    LazyVStack(spacing: 0) {
                        ForEach(Array(s.items.enumerated()), id: \.element.id) { i, c in
                            GovOrgRow(card: c)
                            if i < s.items.count - 1 { Divider().overlay(Theme.line).padding(.leading, 56) }
                        }
                    }
                    .padding(.horizontal, 12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
                }
                .padding(.horizontal, Theme.gutter)
            }
            let shownCount = r.sections.reduce(0) { $0 + $1.items.count }
            if shownCount < r.total {
                Button { Task { await loadMore(offset: shownCount) } } label: {
                    HStack(spacing: 8) {
                        if loadingMore { ProgressView() }
                        Text(tr("Yana ko'rsatish (\(r.total - shownCount))", "Показать ещё (\(r.total - shownCount))", "Show more (\(r.total - shownCount))"))
                    }
                    .font(Theme.Font.sub.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .secondaryButton().tint(Theme.accent)
                .disabled(loadingMore)
                .padding(.horizontal, Theme.gutter)
            }
        }
    }

    // MARK: amallar
    private func setRegion(_ r: String?) {
        Haptics.select()
        withAnimation(Motion.snappy) { region = r; district = nil }
    }

    private var queryItems: [String: String] {
        var q: [String: String] = [:]
        if let region { q["region"] = region }
        if let district { q["district"] = district }
        if let kind { q["kind"] = kind }
        if !trimmed.isEmpty { q["q"] = trimmed }
        return q
    }

    private func load(debounce: Bool) async {
        if debounce { try? await Task.sleep(for: .milliseconds(300)) }
        if Task.isCancelled { return }
        loading = data != nil
        defer { loading = false }
        do {
            var q = queryItems
            q["limit"] = "60"
            let d: GovData = try await API.shared.get("gov", query: q)
            if Task.isCancelled { return }
            withAnimation(reduce ? nil : Motion.gentle) { data = d; error = nil }
        } catch is CancellationError {
        } catch {
            if Task.isCancelled { return }
            if data == nil { withAnimation { self.error = error } } else { model.show(error.localizedDescription) }
        }
    }

    private func loadMore(offset: Int) async {
        guard !loadingMore, var cur = data, var res = cur.results else { return }
        loadingMore = true
        defer { loadingMore = false }
        do {
            var q = queryItems
            q["offset"] = String(offset)
            q["limit"] = "100"
            let more: GovData = try await API.shared.get("gov", query: q)
            guard let add = more.results?.sections else { return }
            for s in add {
                if let last = res.sections.indices.last, res.sections[last].key == s.key { res.sections[last].items += s.items } else { res.sections.append(s) }
            }
            cur.results = res
            withAnimation(Motion.gentle) { data = cur }
        } catch {
            model.show(error.localizedDescription)
        }
    }
}

// MARK: - Favqulodda raqamlar
private struct GovEmergencyGrid: View {
    let phones: [GovData.Phone]
    @Environment(AppModel.self) private var model
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "light.beacon.max.fill").foregroundStyle(Theme.bad)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduce)
                Text(tr("Favqulodda raqamlar", "Экстренные номера", "Emergency numbers")).font(Theme.Font.title).foregroundStyle(Theme.ink)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Text(tr("Bepul, kecha-kunduz. Bosing — qo'ng'iroq qilinadi.", "Бесплатно, круглосуточно. Нажмите, чтобы позвонить.", "Free, 24/7. Tap to call."))
                .font(Theme.Font.caption).foregroundStyle(Theme.muted)
            if let first = phones.first {
                button(first, wide: true)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(phones.dropFirst()) { p in button(p, wide: false) }
            }
        }
    }

    private func button(_ p: GovData.Phone, wide: Bool) -> some View {
        Button {
            Haptics.tap()
            if let u = GovLinks.tel(p.tel) { model.openURL(u) }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.num).font(Theme.Font.display(wide ? 40 : 30)).foregroundStyle(wide ? Theme.accentInk : Theme.bad)
                        .monospacedDigit()
                    Text(p.label).font(wide ? Theme.Font.headline : Theme.Font.caption.weight(.semibold))
                        .foregroundStyle(wide ? Theme.accentInk : Theme.ink)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    if wide, let s = p.sub {
                        Text(s).font(Theme.Font.caption).foregroundStyle(Theme.accentInk.opacity(0.85)).multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: wide ? "phone.fill" : GovSymbol.of(p.icon))
                    .font(.system(size: wide ? 24 : 18, weight: .semibold))
                    .foregroundStyle(wide ? Theme.bad : Theme.bad)
                    .frame(width: wide ? 54 : 36, height: wide ? 54 : 36)
                    .background(wide ? AnyShapeStyle(Theme.accentInk) : AnyShapeStyle(Theme.bad.opacity(0.12)), in: Circle())
            }
            .padding(wide ? 16 : 12)
            .frame(maxWidth: .infinity, minHeight: wide ? 0 : 92, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                    .fill(wide ? AnyShapeStyle(Theme.bad) : AnyShapeStyle(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(wide ? Color.clear : Theme.bad.opacity(0.25)))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(p.num), \(p.label)")
        .accessibilityHint(tr("Qo'ng'iroq qilish", "Позвонить", "Call"))
        .accessibilityAddTraits(.isButton)
    }
}

/// Ishonch telefonlari — gorizontal karusel
private struct GovHotlineRail: View {
    let hotlines: [GovData.Hotline]
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Ishonch telefonlari", "Телефоны доверия", "Hotlines"), kicker: tr("Bitta raqam — butun mamlakat", "Один номер — по всей стране", "One number, nationwide"))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(hotlines) { h in
                        Button { Haptics.tap(); if let u = GovLinks.tel(h.tel) { model.openURL(u) } } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(h.num).font(Theme.Font.display(26)).foregroundStyle(Theme.accent).monospacedDigit()
                                    Spacer(minLength: 4)
                                    Image(systemName: GovSymbol.of(h.icon)).foregroundStyle(Theme.accent.opacity(0.8))
                                }
                                Text(h.label).font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(2).multilineTextAlignment(.leading)
                                if let s = h.sub { Text(s).font(Theme.Font.caption).foregroundStyle(Theme.muted).lineLimit(1) }
                            }
                            .padding(12)
                            .frame(width: 190, alignment: .leading)
                            .frame(minHeight: 112, alignment: .top)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
                        }
                        .buttonStyle(.press)
                        .carouselEffect()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(h.num), \(h.label)")
                        .accessibilityHint(tr("Qo'ng'iroq qilish", "Позвонить", "Call"))
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, Theme.gutter)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

/// Idora qatori: tur belgisi, nom, «Tur · joy»; bosilsa — .item(org, slug)
private struct GovOrgRow: View {
    let card: Card
    @Environment(AppModel.self) private var model
    var body: some View {
        Button { model.open(card) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: GovSymbol.of(card.icon)).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.s, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.name).font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let s = card.sub, !s.isEmpty { Text(s).font(Theme.Font.caption).foregroundStyle(Theme.muted).lineLimit(2) }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted).padding(.top, 10)
            }
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .contextMenu { CardMenu(card: card) }
        .accessibilityElement(children: .combine)
    }
}

private struct GovFilterLabel: View {
    let symbol: String
    let text: String
    let on: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(text).lineLimit(1)
            Image(systemName: "chevron.down").font(.caption2.weight(.bold))
        }
        .font(Theme.Font.sub.weight(.medium))
        .foregroundStyle(on ? Theme.accentInk : Theme.ink)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(on ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.card), in: Capsule())
        .overlay(Capsule().strokeBorder(on ? .clear : Theme.line))
        .frame(minHeight: 44)
    }
}

private struct SectionHeaderInline: View {
    let title: String
    let count: Int
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Theme.Font.title).foregroundStyle(Theme.ink)
            Spacer()
            Text(Fmt.num(count)).font(Theme.Font.sub.monospacedDigit()).foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Respublika turlari (vazirliklar, qo'mitalar …) — bosilsa shu tur filtri
private struct ChipBarInline: View {
    let kinds: [GovData.Kind]
    let pick: (String) -> Void
    var body: some View {
        VisaFlow(spacing: 8) {
            ForEach(kinds) { k in
                Button { Haptics.select(); pick(k.kind) } label: {
                    HStack(spacing: 5) {
                        Text(k.label)
                        Text("\(k.count)").foregroundStyle(Theme.muted)
                    }
                    .font(Theme.Font.sub.weight(.medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Theme.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.line))
                }
                .buttonStyle(.press)
            }
        }
    }
}
