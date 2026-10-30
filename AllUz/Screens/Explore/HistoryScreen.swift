// Tarix: tosh davridan mustaqillikkacha — vertikal vaqt chizig'i (chiziq pastga «chiziladi», nuqtalar paydo bo'ladi).
// So'rovlar (parallel, 3 ta): list/era (server tartibi = xronologiya), list/hist_event (davr — web havolasidan: /tarix/<davr>#…),
// list/person?limit=8 («Allomalar» kirishi uchun rasmlar). Davr kartasi → .item(era), voqea → .item(hist_event).
import SwiftUI

struct HistoryScreen: View {
    var body: some View {
        Loadable(load: { try await ExHistoryData.load() }) { data in
            ExHistoryContent(data: data)
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle(tr("Tarix", "История", "History"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ExHistoryData: Sendable {
    let eras: [Card]
    let eventsByEra: [String: [Card]]
    let eventTotal: Int
    let persons: [Card]
    let personTotal: Int

    static func load() async throws -> ExHistoryData {
        async let e: ListPage = API.shared.get("list/era", query: ["limit": "50"])
        async let h: ListPage = API.shared.get("list/hist_event", query: ["limit": "200"])
        async let p: ListPage = API.shared.get("list/person", query: ["limit": "8"])
        let eras = try await e
        // Voqealar va allomalar — qo'shimcha: xato bo'lsa ham davrlar ko'rinadi
        let events = try? await h
        let persons = try? await p
        var by: [String: [Card]] = [:]
        for ev in events?.items ?? [] {
            if let era = eraSlug(ev.web) { by[era, default: []].append(ev) }
        }
        return ExHistoryData(eras: eras.items, eventsByEra: by, eventTotal: events?.total ?? 0,
                             persons: persons?.items ?? [], personTotal: persons?.total ?? 0)
    }

    /// https://alluzbekistan.com/en/tarix/temuriylar#… → "temuriylar"
    static func eraSlug(_ web: String?) -> String? {
        guard let web, let url = URL(string: web) else { return nil }
        let parts = url.pathComponents
        guard let i = parts.firstIndex(of: "tarix"), i + 1 < parts.count else { return nil }
        return parts[i + 1]
    }
}

private struct ExHistoryContent: View {
    let data: ExHistoryData
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ExIntro(kicker: tr("Tarix", "История", "History"),
                        title: tr("Oʻzbekiston tarixi", "История Узбекистана", "A history of Uzbekistan"),
                        text: introText)
                    .padding(.bottom, 20)
                    .appear()

                if data.personTotal > 0 {
                    personsEntry
                        .padding(.horizontal, Theme.gutter)
                        .padding(.bottom, 28)
                        .appear(delay: 0.06)
                }

                SectionHeader(title: tr("Davrlar", "Эпохи", "Eras"), kicker: tr("Vaqt chizigʻi", "Хронология", "Timeline"))
                    .padding(.bottom, 16)

                ForEach(Array(data.eras.enumerated()), id: \.element.id) { i, era in
                    ExTimelineRow(era: era, index: i, isFirst: i == 0, isLast: i == data.eras.count - 1,
                                  events: data.eventsByEra[era.slug ?? ""] ?? [])
                        .padding(.horizontal, Theme.gutter)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
    }

    private var introText: String {
        let e = data.eras.count, v = data.eventTotal
        if v > 0 {
            return tr("Tosh davri gʻorlaridan mustaqil davlatgacha: \(e) ta davr va \(v) ta muhim voqea — bir vaqt chizigʻida.",
                      "От пещер каменного века до независимого государства: \(e) \(ExTypes.ruPlural(e, ["эпоха", "эпохи", "эпох"])) и \(v) \(ExTypes.ruPlural(v, ["событие", "события", "событий"])) на одной ленте времени.",
                      "From Stone Age caves to an independent state: \(e) eras and \(v) key events on a single timeline.")
        }
        return tr("Tosh davri gʻorlaridan mustaqil davlatgacha — Oʻzbekiston zaminidagi \(e) ta davr.",
                  "От пещер каменного века до независимого государства — \(e) \(ExTypes.ruPlural(e, ["эпоха", "эпохи", "эпох"])) истории Узбекистана.",
                  "From Stone Age caves to an independent state — \(e) eras of Uzbek history.")
    }

    /// «Allomalar» kirishi: rasmlar to'plami + soni
    private var personsEntry: some View {
        Button { Haptics.tap(); model.open(.list(ListSpec(type: "person"))) } label: {
            HStack(spacing: 14) {
                HStack(spacing: -14) {
                    ForEach(data.persons.filter { $0.img != nil }.prefix(4)) { p in
                        RemoteImage(img: p.img, region: p.region, icon: p.icon, width: 48)
                            .frame(width: 48, height: 48).clipShape(Circle())
                            .overlay(Circle().strokeBorder(Theme.card, lineWidth: 3))
                    }
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Allomalar", "Великие люди", "Notable figures")).font(Theme.Font.title3).foregroundStyle(Theme.ink)
                    Text(tr("\(data.personTotal) ta olim, shoir va hukmdor", "\(data.personTotal) учёных, поэтов и правителей", "\(data.personTotal) scholars, poets and rulers"))
                        .font(Theme.Font.caption).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.l))
        }
        .buttonStyle(.press)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Vaqt chizig'i qatori

private struct ExTimelineRow: View {
    let era: Card
    let index: Int
    let isFirst: Bool
    let isLast: Bool
    let events: [Card]

    @State private var drawn = false
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.zoomNS) private var ns

    private static let rail: CGFloat = 34
    private static let node: CGFloat = 34

    var body: some View {
        content
            .padding(.leading, Self.rail + 14)
            .padding(.bottom, isLast ? 0 : 26)
            .overlay(alignment: .topLeading) { railView }
            .onAppear {
                guard !drawn else { return }
                if reduce { drawn = true } else { withAnimation(.easeOut(duration: 0.8).delay(0.08)) { drawn = true } }
            }
    }

    // Chap tomondagi chiziq va nuqta
    private var railView: some View {
        ZStack(alignment: .top) {
            if !isLast {
                // fon chizig'i va ustidan «chiziladigan» rangli chiziq
                Capsule().fill(Theme.line).frame(width: 3)
                    .padding(.top, isFirst ? Self.node / 2 : 0)
                Capsule()
                    .fill(LinearGradient(colors: [Theme.accent, Theme.gold], startPoint: .top, endPoint: .bottom))
                    .frame(width: 3)
                    .scaleEffect(x: 1, y: drawn ? 1 : 0, anchor: .top)
                    .padding(.top, isFirst ? Self.node / 2 : 0)
            } else if !isFirst {
                Capsule().fill(Theme.line).frame(width: 3, height: Self.node / 2)
            }
            Text("\(index + 1)")
                .font(.system(.subheadline, design: .serif).weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.accentInk)
                .frame(width: Self.node, height: Self.node)
                .background(Theme.accent, in: Circle())
                .overlay(Circle().strokeBorder(Theme.paper, lineWidth: 3))
                .scaleEffect(drawn ? 1 : 0.4)
                .opacity(drawn ? 1 : 0)
                .animation(reduce ? nil : .spring(response: 0.45, dampingFraction: 0.6), value: drawn)
                .accessibilityHidden(true)
        }
        .frame(width: Self.rail)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { model.open(era) } label: {
                VStack(alignment: .leading, spacing: 0) {
                    RemoteImage(img: era.img, region: nil, icon: era.icon)
                        .frame(height: 150)
                        .clipped()
                        .zoomSource(era.id, in: ns)
                    VStack(alignment: .leading, spacing: 6) {
                        Kicker(text: era.kicker.flatMap { $0.isEmpty ? nil : $0 }
                               ?? tr("\(index + 1)-davr", "Эпоха \(index + 1)", "Era \(index + 1)"))
                        Text(era.name).font(Theme.Font.title3).foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        if let s = era.summary, !s.isEmpty {
                            Text(s).font(Theme.Font.sub).foregroundStyle(Theme.ink2).lineLimit(3)
                                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.press)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(tr("\(index + 1)-davr: \(era.name)", "Эпоха \(index + 1): \(era.name)", "Era \(index + 1): \(era.name)"))
            .accessibilityHint(era.summary ?? "")

            if !events.isEmpty { eventsList }
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
        .contextMenu { CardMenu(card: era) }
        .opacity(drawn ? 1 : 0)
        .offset(x: drawn ? 0 : 18)
        .animation(reduce ? nil : Motion.spring.delay(0.1), value: drawn)
    }

    // Davr voqealari (dastlabki 3 tasi) — kichik nuqtalar bilan
    private var eventsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(Theme.line.opacity(0.6))
            ForEach(events.prefix(3)) { ev in
                Button { model.open(ev) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Circle().fill(Theme.gold).frame(width: 7, height: 7).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                        Text(ev.name).font(Theme.Font.sub).foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption2.weight(.bold)).foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.press)
            }
            if events.count > 3 {
                Button { model.open(era) } label: {
                    Text(tr("Yana \(events.count - 3) ta voqea", "Ещё \(events.count - 3) \(ExTypes.ruPlural(events.count - 3, ["событие", "события", "событий"]))",
                            "\(events.count - 3) more \(events.count - 3 == 1 ? "event" : "events")"))
                        .font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.accent)
                        .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.press)
            }
        }
        .padding(.bottom, 4)
    }
}
