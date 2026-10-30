// Viza: «Qaysi davlat fuqarosisiz?» — qidiruvli davlatlar ro'yxati (telefon mintaqasi bo'yicha taklif), tanlangach — natija kartasi
// (vizasiz / e-viza / viza kerak), batafsil qoidalar, e-viza havolasi, ro'yxatdan o'tish, bojxona, murojaat, manbalar.
// Tanlov UserDefaults'da eslab qolinadi; code berilsa — darhol natija. API: visa, visa/:code (docs/API.md «Viza»).
import SwiftUI

struct VisaScreen: View {
    let code: String?

    static let storeKey = "visa.citizenship"
    @State private var selected: String?
    @Environment(AppModel.self) private var model

    init(code: String?) {
        self.code = code
        // code berilsa — darhol natija (va eslab qolinadi); bo'lmasa — oldingi tanlov yoki ro'yxat
        if let c = code?.uppercased(), c.count == 2, c.allSatisfy({ $0.isASCII && $0.isLetter }) {
            UserDefaults.standard.set(c, forKey: Self.storeKey)
            _selected = State(initialValue: c)
        } else {
            _selected = State(initialValue: UserDefaults.standard.string(forKey: Self.storeKey))
        }
    }

    var body: some View {
        Group {
            if let selected {
                VisaResultView(code: selected, change: { withAnimation(Motion.spring) { self.selected = nil } }, pick: { pick($0) })
                    .id(selected)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            } else {
                VisaPickerView(current: UserDefaults.standard.string(forKey: Self.storeKey)) { pick($0) }
                    .transition(.opacity)
            }
        }
        .background(Theme.paper)
        .navigationTitle(tr("Viza", "Виза", "Visa"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pick(_ c: String) {
        Haptics.select()
        UserDefaults.standard.set(c, forKey: Self.storeKey)
        withAnimation(Motion.spring) { selected = c }
    }
}

// MARK: - Davlat tanlash
private struct VisaPickerView: View {
    let current: String?
    let onPick: (String) -> Void
    var body: some View {
        Loadable(load: { try await API.shared.get("visa") as VisaIndex }) { data in
            VisaPickerList(data: data, current: current, onPick: onPick)
        }
    }
}

private struct VisaPickerList: View {
    let data: VisaIndex
    let current: String?
    let onPick: (String) -> Void

    @State private var query = ""
    @State private var mode: String?
    @State private var shown: [VisaCountry]
    @Environment(\.accessibilityReduceMotion) private var reduce

    init(data: VisaIndex, current: String?, onPick: @escaping (String) -> Void) {
        self.data = data; self.current = current; self.onPick = onPick
        _shown = State(initialValue: data.countries)
    }

    /// Telefon mintaqasi (Locale) bo'yicha taklif; oldingi tanlov bo'lsa — u ham
    private var suggestions: [VisaCountry] {
        var codes: [String] = []
        if let c = current { codes.append(c) }
        if let r = Locale.current.region?.identifier, r.count == 2, !codes.contains(r) { codes.append(r) }
        return codes.compactMap { c in data.countries.first { $0.code == c } }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 18)
                if query.isEmpty, mode == nil, !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Kicker(text: tr("Sizga mos", "Подходит вам", "Suggested"))
                        ForEach(suggestions) { c in
                            VisaCountryRow(country: c, highlighted: true) { onPick(c.code) }
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 18)
                    .appear(delay: 0.05)
                }
                ChipBar(items: [VisaMode.visaFree, .evisa, .visaRequired, .special].map { m in
                    (key: m.rawValue, label: data.modes[m.rawValue] ?? m.rawValue, count: data.counts[m.rawValue])
                }, selected: $mode)
                .padding(.bottom, 10)

                if shown.isEmpty {
                    EmptyState(text: tr("Davlat nomini boshqacha yozib ko'ring.", "Попробуйте написать название страны иначе.", "Try spelling the country differently."))
                } else {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { i, c in
                        VisaCountryRow(country: c, highlighted: false) { onPick(c.code) }
                            .padding(.horizontal, Theme.gutter)
                            .appear(delay: reduce || i > 14 ? 0 : Double(i) * 0.02)
                        if i < shown.count - 1 { Divider().overlay(Theme.line).padding(.leading, Theme.gutter + 52) }
                    }
                }
                if let a = data.asofText {
                    Label(tr("Ma'lumot \(a) holatiga tekshirilgan", "Данные проверены на \(a)", "Checked as of \(a)"), systemImage: "checkmark.seal")
                        .font(Theme.Font.caption).foregroundStyle(Theme.muted)
                        .padding(Theme.gutter)
                }
            }
            .padding(.top, 8)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .scrollDismissesKeyboard(.immediately)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: tr("Davlat nomi", "Название страны", "Country name"))
        .autocorrectionDisabled()
        .task(id: "\(query)|\(mode ?? "")") {
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(200)) }
            if Task.isCancelled { return }
            let q = query.trimmingCharacters(in: .whitespaces).postFolded
            let m = mode
            let list = data.countries.filter { c in (m == nil || c.mode == m) && (q.isEmpty || c.key.contains(q)) }
            guard list != shown else { return }
            withAnimation(reduce ? nil : Motion.snappy) { shown = list }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: tr("Oʻzbekistonga kirish", "Въезд в Узбекистан", "Entering Uzbekistan"))
            Text(tr("Qaysi davlat fuqarosisiz?", "Гражданином какой страны вы являетесь?", "What is your citizenship?"))
                .font(Theme.Font.largeTitle).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(tr("Pasportingizni bergan davlatni tanlang — vizasiz muddat, elektron viza yoki elchixona orqali viza va kelgandan keyingi qoidalarni ko'rsatamiz.",
                    "Выберите страну, выдавшую паспорт, — покажем безвизовый срок, электронную визу или визу через посольство и правила после прибытия.",
                    "Pick the country that issued your passport to see your visa-free period, e-visa or embassy visa, and the rules after arrival."))
                .font(Theme.Font.sub).foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .appear()
    }
}

/// Davlat qatori: bayroq, nom, rejim belgisi
private struct VisaCountryRow: View {
    let country: VisaCountry
    let highlighted: Bool
    let action: () -> Void
    var body: some View {
        let m = country.visaMode
        Button(action: action) {
            HStack(spacing: 12) {
                Text(country.flag ?? "🏳️").font(.system(size: 30)).frame(width: 40)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(country.name).font(Theme.Font.headline).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Circle().fill(m.color).frame(width: 8, height: 8)
                        Text(country.term).font(Theme.Font.caption).foregroundStyle(Theme.muted)
                    }
                }
                Spacer(minLength: 8)
                VisaModePill(mode: m, text: country.big)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            }
            .padding(.vertical, highlighted ? 12 : 10)
            .padding(.horizontal, highlighted ? 12 : 0)
            .frame(minHeight: 52)
            .background {
                if highlighted {
                    RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous).fill(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous).strokeBorder(m.color.opacity(0.45)))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(country.name), \(country.term)")
        .accessibilityHint(tr("Natijani ochish", "Открыть результат", "Open the result"))
        .accessibilityAddTraits(.isButton)
    }
}

/// Rejim belgisi: rangli kapsula (ikonka + kunlar soni)
private struct VisaModePill: View {
    let mode: VisaMode
    let text: String?
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: mode.symbol).font(.system(size: 11, weight: .bold))
            if let text { Text(text).font(Theme.Font.caption.weight(.bold).monospacedDigit()) }
        }
        .foregroundStyle(mode.color)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(mode.color.opacity(0.13), in: Capsule())
        .accessibilityHidden(true)
    }
}

// MARK: - Natija
private struct VisaResultView: View {
    let code: String
    let change: () -> Void
    let pick: (String) -> Void
    var body: some View {
        Loadable(load: { [code] in try await API.shared.get("visa/" + code.lowercased()) as VisaDetail }) { d in
            VisaResultContent(d: d, change: change, pick: pick)
        }
    }
}

private struct VisaResultContent: View {
    let d: VisaDetail
    let change: () -> Void
    let pick: (String) -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VisaHero(d: d, change: change).appear()

                if let note = d.note {
                    Text(note).font(Theme.Font.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true).appear(delay: 0.05)
                }

                mainPanel.appear(delay: 0.08)

                VisaBlockPanel(block: d.after, symbol: "house.fill", tint: Theme.accent, emphasizeFirst: true).appear(delay: 0.1)
                VisaBlockPanel(block: d.customs, symbol: "suitcase.rolling.fill", tint: Theme.teal, emphasizeFirst: false)

                if let vt = d.visaTypes { VisaTypesPanel(types: vt) }

                if !d.rules.isEmpty { rulesPanel }

                if !d.contacts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(d.contactsTitle).font(Theme.Font.title).foregroundStyle(Theme.ink)
                        ForEach(d.contacts) { VisaContactCard(c: $0) }
                    }
                }

                if !d.sources.isEmpty { sourcesPanel }

                if let w = d.warning {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.warn)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.title).font(Theme.Font.sub.weight(.bold)).foregroundStyle(Theme.ink)
                            Text(w.text).font(Theme.Font.sub).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .background(Theme.warn.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
                    .accessibilityElement(children: .combine)
                }

                guideLink

                if !d.same.isEmpty { samePanel }

                if let a = d.asofText {
                    Label(tr("Ma'lumot \(a) holatiga tekshirilgan", "Данные проверены на \(a)", "Checked as of \(a)"), systemImage: "checkmark.seal")
                        .font(Theme.Font.caption).foregroundStyle(Theme.muted)
                }
            }
            .padding(Theme.gutter)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let u = GovLinks.https(d.web) {
                    ShareLink(item: u) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel(tr("Ulashish", "Поделиться", "Share"))
                }
                Button { change() } label: { Image(systemName: "globe") }
                    .accessibilityLabel(tr("Boshqa davlat", "Другая страна", "Another country"))
            }
        }
    }

    // Asosiy natija: tushuntirish, shartlar, qadamlar, e-viza tugmasi, eslatmalar
    private var mainPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(d.lead, id: \.self) { p in
                    Text(p).font(Theme.Font.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                }
                if !d.conditions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(d.conditions, id: \.self) { c in
                            Label { Text(c).fixedSize(horizontal: false, vertical: true) } icon: {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(d.visaMode.color)
                            }
                            .font(Theme.Font.sub).foregroundStyle(Theme.ink2)
                        }
                    }
                }
                if !d.steps.isEmpty {
                    if let t = d.stepsTitle { Text(t).font(Theme.Font.title3).foregroundStyle(Theme.ink).padding(.top, 4) }
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(d.steps.enumerated()), id: \.offset) { i, s in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(i + 1)").font(Theme.Font.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(Theme.accentInk)
                                    .frame(width: 24, height: 24)
                                    .background(d.visaMode.color, in: Circle())
                                    .accessibilityHidden(true)
                                Text(s).font(Theme.Font.sub).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                if let u = GovLinks.https(d.evisaUrl) {
                    Button { Haptics.tap(); model.openURL(u) } label: {
                        Label(d.evisaLabel ?? "e-visa.gov.uz", systemImage: "arrow.up.right.square").frame(maxWidth: .infinity).padding(.vertical, 4)
                    }
                    .primaryButton().tint(Theme.accent)
                    .padding(.top, 4)
                }
                if let u = GovLinks.https(d.embassiesUrl) {
                    Button { model.openURL(u) } label: {
                        Label(d.embassiesLabel ?? tr("Elchixonalar", "Посольства", "Embassies"), systemImage: "globe").frame(maxWidth: .infinity).padding(.vertical, 4)
                    }
                    .primaryButton().tint(Theme.accent)
                    .padding(.top, 4)
                }
                ForEach(d.notes, id: \.self) { n in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill").foregroundStyle(Theme.teal)
                        Text(n).font(Theme.Font.sub).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var rulesPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(d.rulesTitle).font(Theme.Font.title).foregroundStyle(Theme.ink)
            VStack(spacing: 0) {
                ForEach(Array(d.rules.enumerated()), id: \.element.id) { i, s in
                    VisaRuleDisclosure(section: s)
                    if i < d.rules.count - 1 { Divider().overlay(Theme.line) }
                }
            }
            .padding(.horizontal, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
        }
    }

    private var sourcesPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(d.sourcesTitle).font(Theme.Font.title).foregroundStyle(Theme.ink)
            ForEach(d.sources, id: \.self) { s in
                Button { if let u = GovLinks.https(s.url) { model.openURL(u) } } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "scroll").foregroundStyle(Theme.accent).frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            let meta = [s.kind, s.number, s.date.map { $0.split(separator: "-").reversed().joined(separator: ".") }].compactMap { $0 }
                            if !meta.isEmpty { Text(meta.joined(separator: " · ")).font(Theme.Font.caption).foregroundStyle(Theme.muted) }
                            Text(s.title).font(Theme.Font.sub.weight(.medium)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            if let e = s.edition { Text(e).font(Theme.Font.caption).foregroundStyle(Theme.ink2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true) }
                        }
                        Spacer(minLength: 0)
                        if s.url != nil { Image(systemName: "arrow.up.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted) }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.press)
                .disabled(s.url == nil)
            }
        }
    }

    @ViewBuilder private var guideLink: some View {
        let ref = d.guide?.ref ?? ItemRef(type: "guide", slug: "viza-va-kirish")
        Button { model.open(.item(ref)) } label: {
            HStack(spacing: 12) {
                Image(systemName: "book.fill").font(.title3).foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44).background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.s, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Qo'llanma", "Путеводитель", "Guide")).font(Theme.Font.caption).foregroundStyle(Theme.muted)
                    Text(d.guide?.name ?? tr("Viza va kirish", "Визы и въезд", "Visas and entry")).font(Theme.Font.headline).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            }
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityElement(children: .combine)
    }

    private var samePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("Shu rejimdagi davlatlar", "Страны с тем же режимом", "Countries with the same rules")).font(Theme.Font.title3).foregroundStyle(Theme.ink)
            VisaFlow(spacing: 8) {
                ForEach(d.same) { s in
                    Button { pick(s.code) } label: {
                        Text("\(s.flag ?? "") \(s.name)").font(Theme.Font.sub).foregroundStyle(Theme.ink)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Theme.card, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.line))
                    }
                    .buttonStyle(.press)
                }
            }
        }
    }
}

/// Katta natija kartasi: bayroq, davlat, rejim, kunlar soni
private struct VisaHero: View {
    let d: VisaDetail
    let change: () -> Void
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        let m = d.visaMode
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(d.flag ?? "🏳️").font(.system(size: 44)).accessibilityHidden(true)
                    Text(d.name).font(Theme.Font.title).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                    Button(action: change) {
                        Label(tr("Boshqa davlat", "Другая страна", "Change country"), systemImage: "arrow.left.arrow.right")
                            .font(Theme.Font.caption.weight(.semibold))
                    }
                    .tint(Theme.accent)
                    .padding(.top, 2)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    if let big = d.big {
                        Text(shown || reduce ? big : "0")
                            .font(Theme.Font.display(56))
                            .foregroundStyle(m.color)
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.6)
                        Text(d.unit).font(Theme.Font.kicker).foregroundStyle(m.color).textCase(.uppercase)
                    } else {
                        Image(systemName: m.symbol).font(.system(size: 44, weight: .semibold)).foregroundStyle(m.color)
                            .symbolEffect(.bounce, value: shown)
                    }
                }
                .accessibilityHidden(true)
            }
            HStack(spacing: 8) {
                Image(systemName: m.symbol)
                Text(d.headline).fixedSize(horizontal: false, vertical: true)
            }
            .font(Theme.Font.headline)
            .foregroundStyle(Theme.accentInk)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(m.color, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
            HStack(spacing: 6) {
                Text(d.modeLabel).font(Theme.Font.sub.weight(.semibold)).foregroundStyle(m.color)
                Text("·").foregroundStyle(Theme.muted)
                Text(d.term).font(Theme.Font.sub).foregroundStyle(Theme.ink2)
            }
            if let s = d.sinceText {
                Label(s, systemImage: "calendar").font(Theme.Font.caption).foregroundStyle(Theme.muted)
            }
            if d.transit && d.visaMode != .visaFree {
                Label(tr("5 kungacha vizasiz tranzit mumkin", "Возможен безвизовый транзит до 5 дней", "Visa-free transit of up to 5 days"), systemImage: "airplane")
                    .font(Theme.Font.caption.weight(.medium)).foregroundStyle(Theme.teal)
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).fill(m.color.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(m.color.opacity(0.5), lineWidth: 1.5))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(d.name): \(d.headline), \(d.term)")
        .onAppear {
            guard !shown else { return }
            withAnimation(reduce ? nil : .spring(response: 0.7, dampingFraction: 0.85).delay(0.15)) { shown = true }
            if d.visaMode == .visaFree { Haptics.success() }
        }
    }
}

/// «Kelgandan keyin» / «Bojxona» — sarlavha, punktlar, manbalar
private struct VisaBlockPanel: View {
    let block: VisaBlock
    let symbol: String
    let tint: Color
    let emphasizeFirst: Bool
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                Label { Text(block.title).font(Theme.Font.title3).foregroundStyle(Theme.ink) } icon: { Image(systemName: symbol).foregroundStyle(tint) }
                ForEach(Array(block.items.enumerated()), id: \.offset) { i, s in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: emphasizeFirst && i == 0 ? "exclamationmark.circle.fill" : "circle.fill")
                            .font(.system(size: emphasizeFirst && i == 0 ? 16 : 6))
                            .foregroundStyle(emphasizeFirst && i == 0 ? Theme.warn : Theme.muted)
                            .frame(width: 18, height: 20)
                        Text(s).font(emphasizeFirst && i == 0 ? Theme.Font.sub.weight(.semibold) : Theme.Font.sub)
                            .foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
                VisaSourceChips(sources: block.sources)
            }
        }
    }
}

/// Manba yorliqlari (bosilsa — rasmiy hujjat)
private struct VisaSourceChips: View {
    let sources: [VisaSource]
    @Environment(AppModel.self) private var model
    var body: some View {
        if !sources.isEmpty {
            VisaFlow(spacing: 6) {
                ForEach(sources, id: \.self) { s in
                    Button { if let u = GovLinks.https(s.url) { model.openURL(u) } } label: {
                        Label(s.label, systemImage: "scroll").font(Theme.Font.caption.weight(.medium)).foregroundStyle(Theme.accent)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(Theme.accent.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.press)
                    .accessibilityLabel(tr("Manba: ", "Источник: ", "Source: ") + s.label)
                }
            }
        }
    }
}

private struct VisaRuleDisclosure: View {
    let section: VisaRuleSection
    @State private var open = false
    var body: some View {
        DisclosureGroup(isExpanded: $open.animation(Motion.snappy)) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(section.items.enumerated()), id: \.offset) { _, it in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(it.text).font(Theme.Font.sub).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
                        VisaSourceChips(sources: it.sources)
                    }
                }
            }
            .padding(.bottom, 12)
            .padding(.top, 4)
        } label: {
            Label { Text(section.title).font(Theme.Font.headline).foregroundStyle(Theme.ink).multilineTextAlignment(.leading) } icon: {
                Image(systemName: GovSymbol.of(section.icon)).foregroundStyle(Theme.accent)
            }
            .padding(.vertical, 12)
        }
        .tint(Theme.muted)
    }
}

private struct VisaTypesPanel: View {
    let types: VisaTypes
    @State private var open = false
    var body: some View {
        Panel {
            DisclosureGroup(isExpanded: $open.animation(Motion.snappy)) {
                VStack(alignment: .leading, spacing: 10) {
                    if let l = types.lead { Text(l).font(Theme.Font.sub).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true) }
                    ForEach(types.items, id: \.self) { r in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(r.code).font(Theme.Font.mono).foregroundStyle(Theme.accent).frame(minWidth: 44, alignment: .leading)
                            Text(r.name).font(Theme.Font.sub).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 6)
                            Text(r.term).font(Theme.Font.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.trailing)
                        }
                        .accessibilityElement(children: .combine)
                        Divider().overlay(Theme.line)
                    }
                    if let n = types.note { Text(n).font(Theme.Font.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true) }
                    VisaSourceChips(sources: types.sources)
                }
                .padding(.top, 10)
            } label: {
                Label { Text(types.title).font(Theme.Font.title3).foregroundStyle(Theme.ink) } icon: { Image(systemName: "list.bullet.rectangle").foregroundStyle(Theme.accent) }
            }
            .tint(Theme.muted)
        }
    }
}

/// Murojaat uchun idora: telefonlar (tel:), e-mail, Telegram, sayt
private struct VisaContactCard: View {
    let c: VisaContact
    @Environment(AppModel.self) private var model
    var body: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Label { Text(c.name).font(Theme.Font.headline).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true) } icon: {
                    Image(systemName: GovSymbol.of(c.icon)).foregroundStyle(Theme.accent)
                }
                if let r = c.role { Text(r).font(Theme.Font.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true) }
                ForEach(c.phones, id: \.self) { p in
                    InfoRow(symbol: "phone", title: p.label ?? tr("Telefon", "Телефон", "Phone"), value: p.value) {
                        if let u = GovLinks.tel(p.tel) { model.openURL(u) }
                    }
                    .accessibilityHint(tr("Qo'ng'iroq qilish", "Позвонить", "Call"))
                }
                ForEach(c.emails, id: \.self) { e in
                    InfoRow(symbol: "envelope", title: "E-mail", value: e) { if let u = GovLinks.mail(e) { model.openURL(u) } }
                }
                if let t = c.telegram, let u = GovLinks.https(t) {
                    InfoRow(symbol: "paperplane", title: "Telegram", value: "@" + (u.lastPathComponent)) { model.openURL(u) }
                }
                ForEach(c.links, id: \.self) { l in
                    if let u = GovLinks.https(l.url) { InfoRow(symbol: "list.bullet", title: tr("Havola", "Ссылка", "Link"), value: l.label) { model.openURL(u) } }
                }
                if let w = c.website, let u = GovLinks.https(w) {
                    InfoRow(symbol: "globe", title: tr("Sayt", "Сайт", "Website"), value: (u.host ?? w).replacingOccurrences(of: "www.", with: "") + (u.path.count > 1 ? u.path : "")) { model.openURL(u) }
                }
                if let a = c.address { InfoRow(symbol: "mappin.and.ellipse", title: tr("Manzil", "Адрес", "Address"), value: a) }
                if let n = c.note { Text(n).font(Theme.Font.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true).padding(.top, 4) }
            }
        }
    }
}

/// Oddiy oqim joylashuvi (chiplar qatorga sig'masa — keyingi qatorga)
struct VisaFlow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, width: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.init(width: maxW, height: nil))
            if x > 0, x + sz.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = max(rowH, sz.height); width = max(width, x - spacing)
        }
        return CGSize(width: proposal.width ?? width, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.init(width: bounds.width, height: nil))
            if x > bounds.minX, x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(sz.width, bounds.width), height: sz.height))
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
    }
}
