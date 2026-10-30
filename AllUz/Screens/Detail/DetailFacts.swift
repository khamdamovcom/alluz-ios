// Faktlar: 2 ustunli ikonkali katak (qisqa qiymatlar), uzun qiymatlar qatori (ish vaqti, chipta …), «Qisqacha» (text.facts),
// sonlar (hudud ichidagi joylar), chip guruhlari (qulayliklar, kartalar, xizmatlar …), tablo kartasi, aloqa.
import SwiftUI

// MARK: - Faktlar katagi

struct DetailFactsView: View {
    let facts: [DetailFact]
    let rows: [DetailFact]
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !facts.isEmpty {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    ForEach(Array(stride(from: 0, to: facts.count, by: 2)), id: \.self) { i in
                        GridRow {
                            DetailFactTile(fact: facts[i])
                            if i + 1 < facts.count { DetailFactTile(fact: facts[i + 1]) } else { Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]) }
                        }
                    }
                }
            }
            if !rows.isEmpty {
                Panel(padding: 6) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, f in
                        if i > 0 { Divider().overlay(Theme.line).padding(.leading, 46) }
                        InfoRow(symbol: f.symbol, title: f.label, value: f.value, action: f.tap.map { t in { DetailNav.perform(t, model) } })
                            .padding(.horizontal, 10)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.gutter)
    }
}

struct DetailFactTile: View {
    let fact: DetailFact
    @Environment(AppModel.self) private var model

    var body: some View {
        if let tap = fact.tap {
            Button { DetailNav.perform(tap, model) } label: { tile }
                .buttonStyle(.press)
                .accessibilityHint(tr("Ochish", "Открыть", "Opens"))
        } else {
            tile
        }
    }

    private var tile: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: fact.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 30, height: 30)
                    .background(Theme.accent.opacity(0.12), in: Circle())
                Spacer(minLength: 0)
                if fact.tap != nil {
                    Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(fact.label).font(Theme.Font.caption).foregroundStyle(Theme.muted)
                Text(fact.value)
                    .font(fact.mono ? Theme.Font.mono : Theme.Font.headline)
                    .foregroundStyle(fact.tap == nil ? Theme.ink : Theme.accent)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .detailCard()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Qisqacha (text.facts)

struct DetailInfoView: View {
    let pairs: [DetailPair]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        DetailSection(title: tr("Qisqacha", "Коротко", "At a glance"), symbol: "list.bullet.rectangle") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(pairs) { p in
                    if p.id != pairs.first?.id { Divider().overlay(Theme.line) }
                    row(p)
                        .padding(.vertical, 11)
                        .accessibilityElement(children: .combine)
                }
            }
            .detailCard(radius: Theme.Radius.l, padding: 14)
        }
    }

    @ViewBuilder private func row(_ p: DetailPair) -> some View {
        let label = Text(p.label).font(Theme.Font.sub).foregroundStyle(Theme.muted)
        let value = Text(p.value).font(Theme.Font.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 3) { label; value }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                label.frame(width: 108, alignment: .leading)
                value
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Sonlar (hudud/tuman)

struct DetailCountsView: View {
    let counts: [DetailCount]
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var shown = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(counts) { c in
                Button { Haptics.tap(); model.open(.list(c.spec)) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: c.symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.teal)
                        Text(Fmt.num(shown || reduce ? c.value : 0))
                            .font(Theme.Font.display(26)).foregroundStyle(Theme.ink)
                            .contentTransition(.numericText(value: Double(shown ? c.value : 0)))
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text(c.label).font(Theme.Font.caption).foregroundStyle(Theme.muted).lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .detailCard(padding: 12)
                }
                .buttonStyle(.press)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(c.label): \(c.value)")
                .accessibilityAddTraits(.isButton)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Theme.gutter)
        .onAppear { withAnimation(.easeOut(duration: 0.9).delay(0.15)) { shown = true } }
    }
}

// MARK: - Chip guruhlari

struct DetailChipsView: View {
    let groups: [DetailChipGroup]
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(groups) { g in
                VStack(alignment: .leading, spacing: 10) {
                    Label(g.title, systemImage: g.symbol)
                        .font(Theme.Font.headline)
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    DetailFlow {
                        ForEach(g.chips) { DetailChipView(chip: $0) }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tablo (aeroport / vokzal)

struct DetailBoardCard: View {
    let c: DetailContent
    @Environment(AppModel.self) private var model

    var body: some View {
        let isAir = c.boardIATA != nil
        Button {
            Haptics.tap()
            if let iata = c.boardIATA { model.open(.board(iata)) } else if let st = c.railStation { model.open(.railBoard(st)) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isAir ? "airplane.departure" : "tram.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.accentInk)
                    .frame(width: 50, height: 50)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .symbolEffect(.pulse, options: .repeat(2))
                VStack(alignment: .leading, spacing: 3) {
                    Text(isAir ? tr("Jonli tablo", "Онлайн-табло", "Live flight board") : tr("Poyezdlar jadvali", "Расписание поездов", "Train timetable"))
                        .font(Theme.Font.headline).foregroundStyle(Theme.ink)
                    Text(isAir ? tr("Uchish va qoʻnish — real vaqtda", "Вылеты и прилёты в реальном времени", "Departures and arrivals in real time")
                               : tr("Joʻnash va kelish vaqtlari", "Отправление и прибытие", "Departures and arrivals"))
                        .font(Theme.Font.sub).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if let iata = c.boardIATA {
                    Text(iata).font(Theme.Font.mono).foregroundStyle(Theme.accent)
                }
                Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted)
            }
            .detailCard(radius: Theme.Radius.l, padding: 14)
        }
        .buttonStyle(.press)
        .padding(.horizontal, Theme.gutter)
    }
}

// MARK: - Aloqa

struct DetailContactsView: View {
    let contacts: [DetailFact]
    @Environment(AppModel.self) private var model

    var body: some View {
        DetailSection(title: tr("Aloqa", "Контакты", "Contacts"), symbol: "phone.bubble") {
            Panel(padding: 6) {
                ForEach(Array(contacts.enumerated()), id: \.element.id) { i, f in
                    if i > 0 { Divider().overlay(Theme.line).padding(.leading, 46) }
                    InfoRow(symbol: f.symbol, title: f.label, value: f.value, action: f.tap.map { t in { DetailNav.perform(t, model) } })
                        .padding(.horizontal, 10)
                }
            }
        }
    }
}

// MARK: - Mobil ilovalar (bank)

struct DetailAppsView: View {
    let apps: [DetailApp]
    @Environment(AppModel.self) private var model

    var body: some View {
        let list = apps.filter { $0.ios != nil }
        if !list.isEmpty {
            DetailSection(title: tr("Mobil ilovalar", "Мобильные приложения", "Mobile apps"), symbol: "iphone") {
                VStack(spacing: 10) {
                    ForEach(list) { a in
                        HStack(spacing: 12) {
                            Image(systemName: "app.badge")
                                .font(.system(size: 18, weight: .medium)).foregroundStyle(Theme.teal)
                                .frame(width: 40, height: 40)
                                .background(Theme.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text(a.name).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 6)
                            if let u = a.ios {
                                Button { Haptics.tap(); model.openURL(u) } label: {
                                    Label("App Store", systemImage: "arrow.down.app").font(Theme.Font.sub.weight(.semibold))
                                }
                                .secondaryButton()
                                .tint(Theme.accent)
                                .accessibilityLabel("\(a.name) — App Store")
                            }
                        }
                        .detailCard(padding: 12)
                    }
                }
            }
        }
    }
}
