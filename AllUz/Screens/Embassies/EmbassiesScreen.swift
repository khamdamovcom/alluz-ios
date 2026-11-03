// Elchixonalar: «Oʻzbekistonda / Xorijda» (segment), qidiruv (davlat, shahar, manzil — server `key` bo'yicha, 300 ms debounce),
// davlatlar bo'yicha guruhlangan (bayroq bilan) ro'yxat: tur belgisi, shahar, manzil, telefon. API: embassies (bir so'rov — ikkala yo'nalish).
import SwiftUI

struct EmbassiesScreen: View {
    let dir: String?

    @State private var selected: String
    @State private var query = ""
    @State private var q = ""

    init(dir: String?) {
        self.dir = dir
        _selected = State(initialValue: dir == "out" ? "out" : "in")
    }

    var body: some View {
        Loadable(load: { try await API.shared.get("embassies") as EmbassyList }) { list in
            EmbassiesContent(list: list, dir: $selected, q: q)
        }
        .background(Theme.paper)
        .navigationTitle(tr("Elchixonalar", "Посольства", "Embassies"))
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: tr("Davlat, shahar yoki manzil…", "Страна, город или адрес…", "Country, city or address…"))
        .task(id: query) {
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
            if !Task.isCancelled { withAnimation(Motion.snappy) { q = query } }
        }
    }
}

private struct EmbassiesContent: View {
    let list: EmbassyList
    @Binding var dir: String
    let q: String
    @Environment(AppModel.self) private var model

    var body: some View {
        let tokens = EmbassyStyle.tokens(q)
        let groups = filter(list.countries(dir), tokens)
        let found = groups.reduce(0) { $0 + $1.items.count }
        let other = dir == "in" ? "out" : "in"
        let otherFound = tokens.isEmpty ? 0 : filter(list.countries(other), tokens).reduce(0) { $0 + $1.items.count }

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                header(found: found, filtering: !tokens.isEmpty)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 8)

                if groups.isEmpty {
                    EmptyState(text: tr("Soʻrov boʻyicha vakolatxona topilmadi. Davlat nomini boshqacha yozib koʻring.",
                                        "По запросу ничего не найдено. Попробуйте написать название страны иначе.",
                                        "No mission matches your search. Try spelling the country differently."))
                    if otherFound > 0 { switchButton(other, otherFound).padding(.horizontal, Theme.gutter) }
                } else {
                    ForEach(groups) { c in
                        Section {
                            VStack(spacing: 0) {
                                ForEach(Array(c.items.enumerated()), id: \.element.id) { i, r in
                                    EmbassyRowView(row: r)
                                    if i < c.items.count - 1 { Divider().overlay(Theme.line) }
                                }
                            }
                            .padding(.horizontal, 14)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
                            .padding(.horizontal, Theme.gutter)
                            .padding(.bottom, 14)
                        } header: {
                            countryHeader(c)
                        }
                    }
                    if otherFound > 0 { switchButton(other, otherFound).padding(.horizontal, Theme.gutter).padding(.top, 4) }
                }

                if let w = list.web, let u = URL(string: w), u.scheme == "https", u.host == AppConfig.host {
                    // To'g'ridan-to'g'ri Safari oynasida (openURL sayt havolasini shu ekranga qaytarardi)
                    Button { Haptics.tap(); model.webURL = IdentifiedURL(url: u) } label: {
                        Label(tr("Saytda ochish", "Открыть на сайте", "Open on the website"), systemImage: "safari")
                            .font(Theme.Font.sub.weight(.semibold)).frame(maxWidth: .infinity)
                    }
                    .secondaryButton()
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 18)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.paper)
        .sensoryFeedback(.selection, trigger: dir)
    }

    private func header(found: Int, filtering: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(tr("Yoʻnalish", "Раздел", "Section"), selection: $dir.animation(Motion.snappy)) {
                Text(EmbassyStyle.dirTitle("in")).tag("in")
                Text(EmbassyStyle.dirTitle("out")).tag("out")
            }
            .pickerStyle(.segmented)

            Group {
                if filtering {
                    Text(tr("Topildi: \(found)", "Найдено: \(found)", "Found: \(found)"))
                } else {
                    let n = list.counts?[dir] ?? 0, c = list.counts?[dir + "C"] ?? 0
                    Text(dir == "in"
                         ? tr("\(n) ta xorijiy vakolatxona · \(c) davlat", "\(n) иностранных представительств · \(c) стран", "\(n) foreign missions · \(c) countries")
                         : tr("Oʻzbekistonning \(n) ta vakolatxonasi · \(c) davlatda", "\(n) представительств Узбекистана · \(c) стран", "\(n) Uzbek missions · \(c) countries"))
                }
            }
            .font(Theme.Font.sub).foregroundStyle(Theme.muted)
            .contentTransition(.numericText())
        }
        .appear()
    }

    private func countryHeader(_ c: EmbassyCountry) -> some View {
        HStack(spacing: 10) {
            Text(c.flag ?? "🏳️").font(.system(size: 24)).accessibilityHidden(true)
            Text(c.name).font(Theme.Font.title3).foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            if c.items.count > 1 {
                Text("\(c.items.count)").font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func switchButton(_ other: String, _ n: Int) -> some View {
        Button { withAnimation(Motion.snappy) { dir = other } } label: {
            HStack {
                Text("\(EmbassyStyle.dirTitle(other)): " + tr("yana \(n) ta topildi", "найдено ещё \(n)", "\(n) more found"))
                Spacer(minLength: 6)
                Image(systemName: "arrow.right")
            }
            .font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.accent)
            .padding(14)
            .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
        }
        .buttonStyle(.press)
    }

    /// Har bir so'z kalitda (yoki davlat nomida) bo'lishi kerak
    private func filter(_ countries: [EmbassyCountry], _ tokens: [String]) -> [EmbassyCountry] {
        guard !tokens.isEmpty else { return countries }
        return countries.compactMap { c in
            let cname = EmbassyStyle.tokens(c.name).joined(separator: " ") + " " + c.code.lowercased()
            let items = c.items.filter { r in
                let hay = (r.key ?? r.name.lowercased()) + " " + cname
                return tokens.allSatisfy { hay.contains($0) }
            }
            return items.isEmpty ? nil : EmbassyCountry(code: c.code, name: c.name, flag: c.flag, items: items)
        }
    }
}
