// Har qanday yozuv tafsiloti — `item/:type/:slug` (joy, hudud, tuman, mehmonxona, alloma, davr, marshrut, aeroport, bank, idora …).
// Ma'lumot yuklash paytida DetailContent'ga tayyorlanadi (DetailContent.swift), bu yerda faqat bo'limlar tartib bilan chiziladi.
// Bosh rasm navigatsiya paneli ostida: panel rasm ustida shaffof, aylantirganda odatiy ko'rinishga o'tadi.
import SwiftUI

struct ItemDetailView: View {
    let ref: ItemRef

    var body: some View {
        Loadable(load: { [ref] in try await DetailContent.load(ref) },
                 skeleton: AnyView(DetailSkeleton(title: DetailLabels.type(ref.type)))) { content in
            DetailPage(c: content)
        }
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sahifa

private struct DetailPage: View {
    let c: DetailContent
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page: Int? = 0
    @State private var barSolid = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                DetailHero(images: c.images, region: c.item.type == "region" ? c.item.slug : (c.item.region ?? c.regionCard?.slug), icon: c.item.icon,
                           unesco: c.item.unesco == true, title: c.title, symbol: c.typeSymbol, page: $page)
                    .onGeometryChange(for: Bool.self) { proxy in
                        proxy.frame(in: .scrollView(axis: .vertical)).maxY < 130
                    } action: { solid in
                        withAnimation(.easeInOut(duration: 0.22)) { barSolid = solid }
                    }
                sheet
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(Theme.paper)
        .navigationTitle(c.title)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(c.title)
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .opacity(barSolid ? 1 : 0)
                    .accessibilityHidden(!barSolid)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let w = DetailLink.web(c.item.web) {
                    ShareLink(item: w, subject: Text(c.title)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .modifier(DetailBarIcon(onImage: !barSolid))
                    .accessibilityLabel(tr("Ulashish", "Поделиться", "Share"))
                }
                SaveButton(card: c.item.card)
                    .modifier(DetailBarIcon(onImage: !barSolid))
            }
        }
        .modifier(DetailBarChrome(solid: barSolid))
        .onAppear { model.visited(c.item.card) }
    }

    /// Rasm ustiga chiqib turgan qog'oz «varaq» — barcha bo'limlar
    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let img = c.images.indices.contains(page ?? 0) ? c.images[page ?? 0] : c.images.first, img.creditLine != nil {
                CreditLine(img: img)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 10)
                    .animation(nil, value: page)
            }
            LazyVStack(alignment: .leading, spacing: 30) {
                ForEach(Array(c.parts.enumerated()), id: \.element) { i, part in
                    section(part)
                        .appear(delay: i < 6 ? Double(i) * 0.05 : 0, offset: reduceMotion ? 0 : 14)
                }
            }
            .padding(.bottom, 40)
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.xl, topTrailingRadius: Theme.Radius.xl, style: .continuous))
        .padding(.top, -Theme.Radius.xl)
    }

    @ViewBuilder private func section(_ part: DetailPart) -> some View {
        switch part {
        case .title: DetailTitleBlock(c: c)
        case .actions: DetailQuickActions(c: c).padding(.top, -10)
        case .lead: if let l = c.lead { DetailLead(text: l) }
        case .facts: DetailFactsView(facts: c.facts, rows: c.rows)
        case .board: DetailBoardCard(c: c)
        case .counts: DetailCountsView(counts: c.counts)
        case .info: DetailInfoView(pairs: c.info)
        case .chips: DetailChipsView(groups: c.chips)
        case .body: DetailArticle(blocks: c.blocks, collapsedCount: c.collapsedCount, readMinutes: c.readMinutes)
        case .highlights: DetailHighlights(items: c.highlights)
        case .notes: DetailNotes(notes: c.notes)
        case .tips: DetailTips(tips: c.tips)
        case .season: DetailSeason(months: c.season)
        case .itinerary: DetailItinerary(days: c.days)
        case .timeline: DetailTimeline(events: c.events)
        case .train: DetailTrainStops(stops: c.trainStops)
        case .metro: DetailMetroLines(lines: c.metroLines)
        case .branches: DetailBranches(branches: c.branches)
        case .apps: DetailAppsView(apps: c.apps)
        case .contacts: DetailContactsView(contacts: c.contacts)
        case .location: DetailLocation(c: c)
        case .rail(let i): if c.rails.indices.contains(i) { DetailRailView(rail: c.rails[i]) }
        case .districts: DetailDistricts(cards: c.districts)
        case .places: DetailLocationCards(cards: c.locationCards)
        case .disclaimer: if let d = c.disclaimer { DetailDisclaimer(text: d) }
        case .sources: DetailSources(sources: c.sources)
        }
    }
}

// MARK: - Navigatsiya paneli: rasm ustida shaffof, aylantirganda odatiy

private struct DetailBarChrome: ViewModifier {
    let solid: Bool
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // Liquid Glass: panel o'zi shaffof; rasm ustida xiralash (edge effect) o'chiriladi
            content.scrollEdgeEffectHidden(!solid, for: .top)
        } else {
            content
                .toolbarBackground(solid ? .visible : .hidden, for: .navigationBar)
                .toolbarBackground(Theme.paper, for: .navigationBar)
        }
    }
}

/// iOS 17–18: rasm ustidagi panel tugmalari xira doira ichida (iOS 26 da shisha o'zi bor)
private struct DetailBarIcon: ViewModifier {
    let onImage: Bool
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial.opacity(onImage ? 1 : 0), in: Circle())
        }
    }
}

// MARK: - Yuklanayotganda

private struct DetailSkeleton: View {
    let title: String
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Rectangle().fill(Theme.paper3)
                    .containerRelativeFrame(.vertical) { len, _ in min(max(len * 0.5, 300), 480) }
                    .overlay(Shimmer())
                VStack(alignment: .leading, spacing: 12) {
                    Capsule().fill(Theme.paper3).frame(width: 110, height: 10)
                    Capsule().fill(Theme.paper3).frame(height: 26).padding(.trailing, 60)
                    Capsule().fill(Theme.paper3).frame(width: 200, height: 14)
                    HStack(spacing: 10) {
                        ForEach(0..<4, id: \.self) { _ in Circle().fill(Theme.paper3).frame(width: 54, height: 54) }
                    }
                    .padding(.vertical, 8)
                    ForEach(0..<5, id: \.self) { _ in Capsule().fill(Theme.paper3).frame(height: 12) }
                }
                .padding(.horizontal, Theme.gutter)
            }
        }
        .scrollDisabled(true)
        .ignoresSafeArea(edges: .top)
        .background(Theme.paper)
        .navigationTitle(title)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("Yuklanmoqda", "Загрузка", "Loading"))
    }
}
