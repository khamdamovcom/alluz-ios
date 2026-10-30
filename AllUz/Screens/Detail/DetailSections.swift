// Turga xos bo'limlar: marshrut (mavsum + kun-baykun yo'l chizig'i), davr (vaqt chizig'i), poyezd bekatlari, metro liniyalari,
// bank filiallari, karusellar (refs/sections), tumanlar katagi, joylashuv kartalari, manbalar.
import SwiftUI

// MARK: - Eng yaxshi mavsum (12 oy chizig'i)

struct DetailSeason: View {
    let months: Set<Int>

    var body: some View {
        let names = (1...12).filter { months.contains($0) }.map { Fmt.month($0) }.joined(separator: ", ")
        DetailSection(title: tr("Eng yaxshi mavsum", "Лучший сезон", "Best season"), symbol: "sun.max") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 3) {
                    ForEach(1...12, id: \.self) { m in
                        let on = months.contains(m)
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(on ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.paper3))
                                .frame(height: on ? 26 : 14)
                                .frame(height: 26, alignment: .bottom)
                            Text(DetailLabels.monthShort(m))
                                .font(.caption2.weight(on ? .bold : .regular))
                                .foregroundStyle(on ? Theme.accent : Theme.muted)
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityHidden(true)
                Text(names.prefix(1).uppercased() + names.dropFirst())
                    .font(Theme.Font.sub).foregroundStyle(Theme.ink2)
            }
            .detailCard()
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Marshrut: kun-baykun

struct DetailItinerary: View {
    let days: [DetailDay]
    @Environment(AppModel.self) private var model

    var body: some View {
        DetailSection(title: tr("Kun-baykun", "По дням", "Day by day"), symbol: "point.topleft.down.to.point.bottomright.curvepath") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element.id) { i, day in
                    dayView(day, last: i == days.count - 1)
                }
            }
        }
    }

    private func dayView(_ day: DetailDay, last: Bool) -> some View {
        let n = day.id % 1000
        return HStack(alignment: .top, spacing: 14) {
            Text(n > 0 ? "\(n)" : "•")
                .font(Theme.Font.headline.monospacedDigit())
                .foregroundStyle(Theme.accentInk)
                .frame(width: 34, height: 34)
                .background(Theme.accent, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                if n > 0 {
                    Text(tr("\(n)-kun", "День \(n)", "Day \(n)"))
                        .font(Theme.Font.title3).foregroundStyle(Theme.ink)
                        .frame(minHeight: 34)
                        .accessibilityAddTraits(.isHeader)
                }
                ForEach(day.stops) { s in stop(s) }
            }
            .padding(.bottom, last ? 0 : 22)
        }
        .background(alignment: .topLeading) {
            if !last {
                Rectangle().fill(Theme.accent.opacity(0.3)).frame(width: 2).padding(.leading, 16).padding(.top, 36)
            }
        }
    }

    private func stop(_ s: DetailStop) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let r = s.regionName {
                HStack(spacing: 6) {
                    Circle().fill(Theme.hue(s.region)).frame(width: 8, height: 8)
                    Text(r).font(Theme.Font.caption.weight(.semibold)).foregroundStyle(Theme.ink2)
                }
            }
            Text(s.text).font(Theme.Font.body).foregroundStyle(Theme.ink).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if let p = s.place { CardRow(card: p, showSummary: false) }
        }
    }
}

// MARK: - Davr: vaqt chizig'i

struct DetailTimeline: View {
    let events: [DetailEvent]
    @State private var expanded = false

    var body: some View {
        let limit = 6
        let list = expanded ? events : Array(events.prefix(limit))
        DetailSection(title: tr("Davr voqealari", "События эпохи", "Key events"), symbol: "calendar.day.timeline.left") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, e in
                    DetailEventRow(event: e, last: i == list.count - 1)
                        .transition(.opacity)
                }
                if events.count > limit { DetailExpandButton(expanded: $expanded, more: events.count - limit) }
            }
        }
    }
}

private struct DetailEventRow: View {
    let event: DetailEvent
    let last: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle().strokeBorder(Theme.accent, lineWidth: 3).background(Circle().fill(Theme.paper))
                .frame(width: 16, height: 16).padding(.top, 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                if !event.when.isEmpty {
                    Text(event.when).font(Theme.Font.caption.weight(.bold).monospacedDigit()).foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.1), in: Capsule())
                }
                Text(event.title).font(Theme.Font.headline).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                if let t = event.text {
                    Text(t).font(Theme.Font.sub).foregroundStyle(Theme.ink2).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                }
                if !event.cards.isEmpty {
                    DetailFlow {
                        ForEach(event.cards) { c in
                            DetailChipView(chip: DetailChip(id: c.id, label: c.name, symbol: SymbolMap.symbol(c.icon), tap: c.ref != nil ? .card(c) : nil))
                        }
                    }
                }
            }
            .padding(.bottom, last ? 4 : 22)
        }
        .background(alignment: .topLeading) {
            if !last { Rectangle().fill(Theme.line).frame(width: 2).padding(.leading, 7).padding(.top, 20) }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Poyezd bekatlari

struct DetailTrainStops: View {
    let stops: [DetailTrainStop]

    var body: some View {
        DetailSection(title: tr("Bekatlar", "Остановки", "Stops"), symbol: "tram", trailing: tr("\(stops.count) ta", "\(stops.count)", "\(stops.count)")) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(stops.enumerated()), id: \.element.id) { i, s in
                    let edge = i == 0 || i == stops.count - 1
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .trailing, spacing: 2) {
                            if let a = s.arr { Text(a).font(Theme.Font.sub.monospacedDigit().weight(.semibold)).foregroundStyle(Theme.ink) }
                            if let d = s.dep, d != s.arr {
                                Text(d).font((s.arr == nil ? Theme.Font.sub.weight(.semibold) : Theme.Font.caption).monospacedDigit())
                                    .foregroundStyle(s.arr == nil ? Theme.ink : Theme.muted)
                            }
                        }
                        .frame(width: 52, alignment: .trailing)
                        Circle().fill(edge ? Theme.accent : Theme.card)
                            .overlay(Circle().strokeBorder(Theme.accent, lineWidth: 2))
                            .frame(width: edge ? 14 : 10, height: edge ? 14 : 10)
                            .frame(width: 14).padding(.top, 4)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(s.name).font(edge ? Theme.Font.headline : Theme.Font.body).foregroundStyle(Theme.ink)
                            if s.dayOffset > 0 {
                                Text("+\(s.dayOffset)").font(Theme.Font.caption.weight(.bold)).foregroundStyle(Theme.warn)
                                    .accessibilityLabel(tr("\(s.dayOffset) kundan keyin", "через \(s.dayOffset) дн.", "+\(s.dayOffset) day"))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 14)
                    .background(alignment: .topLeading) {
                        if i < stops.count - 1 { Rectangle().fill(Theme.accent.opacity(0.3)).frame(width: 2).padding(.leading, 64 + 6).padding(.top, 14) }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .detailCard()
        }
    }
}

// MARK: - Metro liniyalari

struct DetailMetroLines: View {
    let lines: [DetailMetroLine]
    var body: some View {
        DetailSection(title: tr("Liniyalar", "Линии", "Lines"), symbol: "tram.fill.tunnel") {
            VStack(spacing: 10) {
                ForEach(lines) { DetailMetroLineCard(line: $0) }
            }
        }
    }
}

private struct DetailMetroLineCard: View {
    let line: DetailMetroLine
    @State private var open = false

    var body: some View {
        let color = line.color.map { Color(uiColor: UIColor(hex: $0)) } ?? Theme.accent
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Haptics.select()
                withAnimation(Motion.spring) { open.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Capsule().fill(color).frame(width: 6, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.name).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                        Text([line.stations.isEmpty ? nil : tr("\(line.stations.count) bekat", "станций: \(line.stations.count)", "\(line.stations.count) stations"),
                              line.opened.map { tr("\($0)-yildan", "с \($0) г.", "since \($0)") }].compactMap { $0 }.joined(separator: " · "))
                            .font(Theme.Font.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                    if !line.stations.isEmpty {
                        Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                            .rotationEffect(.degrees(open ? 180 : 0))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(line.stations.isEmpty)
            if let n = line.note { Text(n).font(Theme.Font.sub).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true) }
            if open {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(line.stations.enumerated()), id: \.offset) { i, s in
                        HStack(spacing: 10) {
                            Circle().fill(Theme.card).overlay(Circle().strokeBorder(color, lineWidth: 2.5)).frame(width: 11, height: 11)
                            Text(s).font(Theme.Font.sub).foregroundStyle(Theme.ink)
                        }
                        .frame(minHeight: 28)
                        .background(alignment: .leading) {
                            if i < line.stations.count - 1 { Rectangle().fill(color).frame(width: 3).padding(.leading, 4).offset(y: 14) }
                        }
                    }
                }
                .padding(.leading, 18)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .detailCard()
        .clipped()
    }
}

// MARK: - Bank filiallari

struct DetailBranches: View {
    let branches: [DetailBranch]
    @State private var expanded = false
    @Environment(AppModel.self) private var model

    var body: some View {
        let limit = 3
        let list = expanded ? branches : Array(branches.prefix(limit))
        DetailSection(title: tr("Filiallar", "Филиалы", "Branches"), symbol: "building.2", trailing: "\(branches.count)") {
            VStack(spacing: 10) {
                ForEach(list) { b in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(b.name).font(Theme.Font.headline).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                            if let a = b.address { Text(a).font(Theme.Font.sub).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true) }
                            if let h = b.hours { Label(h, systemImage: "clock").font(Theme.Font.caption).foregroundStyle(Theme.muted) }
                        }
                        Spacer(minLength: 4)
                        if let u = b.phoneURL {
                            iconButton("phone", tr("Qoʻngʻiroq", "Позвонить", "Call") + " " + (b.phone ?? "")) { model.openURL(u) }
                        }
                        if let u = b.directions {
                            iconButton("arrow.triangle.turn.up.right.diamond", tr("Yoʻnalish", "Маршрут", "Directions")) { model.openURL(u) }
                        }
                    }
                    .detailCard(padding: 12)
                    .transition(.opacity)
                }
                if branches.count > limit { DetailExpandButton(expanded: $expanded, more: branches.count - limit) }
            }
        }
    }

    private func iconButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            Image(systemName: symbol).font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Theme.accent.opacity(0.1), in: Circle())
        }
        .buttonStyle(.press)
        .accessibilityLabel(label)
    }
}

// MARK: - Karusel (refs / sections)

struct DetailRailView: View {
    let rail: DetailRail
    @Environment(AppModel.self) private var model

    var body: some View {
        Rail(title: rail.title, kicker: rail.kicker, more: rail.more.map { spec in { model.open(.list(spec)) } }) {
            ForEach(rail.cards) { c in
                (rail.portrait ? CardTile(card: c, width: 150, imageHeight: 190) : CardTile(card: c))
                    .carouselEffect()
            }
        }
    }
}

// MARK: - Tumanlar katagi (hudud)

struct DetailDistricts: View {
    let cards: [Card]
    @Environment(AppModel.self) private var model

    var body: some View {
        DetailSection(title: tr("Shahar va tumanlar", "Города и районы", "Cities & districts"), symbol: "square.grid.2x2", trailing: "\(cards.count)") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(cards) { c in
                    Button { Haptics.tap(); model.open(c) } label: {
                        HStack(spacing: 10) {
                            RemoteImage(img: c.img, region: c.region, icon: c.icon, width: 46)
                                .frame(width: 46, height: 46)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name).font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.ink)
                                    .lineLimit(2).multilineTextAlignment(.leading)
                                if let k = c.kind { Text(DetailLabels.districtType(k)).font(Theme.Font.caption).foregroundStyle(Theme.muted) }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
                    }
                    .buttonStyle(.press)
                    .contextMenu { CardMenu(card: c) }
                }
            }
        }
    }
}

// MARK: - Joylashuv kartalari (tuman, hudud)

struct DetailLocationCards: View {
    let cards: [Card]
    var body: some View {
        DetailSection(title: tr("Qayerda joylashgan", "Где находится", "Where it is"), symbol: "mappin.and.ellipse") {
            VStack(spacing: 4) {
                ForEach(cards) { CardRow(card: $0, showSummary: true) }
            }
        }
    }
}

// MARK: - Manbalar

struct DetailSources: View {
    let sources: [DetailSource]
    @State private var expanded = false
    @Environment(AppModel.self) private var model

    var body: some View {
        let limit = 4
        let list = expanded ? sources : Array(sources.prefix(limit))
        DetailSection(title: tr("Manbalar", "Источники", "Sources"), symbol: "books.vertical", trailing: "\(sources.count)") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, s in
                    if i > 0 { Divider().overlay(Theme.line) }
                    Button { Haptics.tap(); model.openURL(s.url) } label: {
                        HStack(spacing: 12) {
                            Text("\(i + 1)").font(Theme.Font.caption.weight(.bold).monospacedDigit()).foregroundStyle(Theme.muted)
                                .frame(width: 22, height: 22).background(Theme.paper2, in: Circle())
                            VStack(alignment: .leading, spacing: 1) {
                                Text(s.domain).font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                                if !s.path.isEmpty { Text(s.path).font(Theme.Font.caption).foregroundStyle(Theme.muted).lineLimit(1) }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                        }
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(s.domain)
                    .accessibilityHint(tr("Manbani brauzerda ochish", "Открыть источник", "Opens the source"))
                    .transition(.opacity)
                }
                if sources.count > limit { DetailExpandButton(expanded: $expanded, more: sources.count - limit) }
            }
            .detailCard(padding: 12)
        }
    }
}
