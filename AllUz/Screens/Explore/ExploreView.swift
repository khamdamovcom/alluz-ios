// «Kashf eting» tabi — butun kontentga kirish eshigi: qidiruv, joy turlari, UNESCO, hududlar, barcha bo'limlar (soni bilan).
// So'rovlar (parallel, 3 ta kichik): list/place?unesco=1&limit=6 (kinds + UNESCO rasmlari), list/venue?limit=1 (mehmonxona/restoran soni),
// list/region (14 hudud). Sonlar — model.config.counts (bo'lmasa config so'raladi).
import SwiftUI

struct ExploreView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Loadable(load: { try await ExExploreData.load() }, skeleton: AnyView(ExExploreSkeleton())) { data in
            ExExploreContent(data: data)
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle(Tab.explore.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Haptics.tap(); model.open(.search) } label: { Image(systemName: "magnifyingglass") }
                    .accessibilityLabel(tr("Qidiruv", "Поиск", "Search"))
            }
        }
    }
}

// MARK: - Ma'lumot

struct ExExploreData: Sendable {
    let placeKinds: [ExKindStat]
    let placeTotal: Int
    let unescoTotal: Int
    let unesco: [Card]
    let regions: [Card]
    let counts: [String: Int]
    let stay: Int
    let eat: Int

    static func load() async throws -> ExExploreData {
        async let unescoPage: ListPage = API.shared.get("list/place", query: ["unesco": "1", "limit": "6"])
        async let venuePage: ListPage = API.shared.get("list/venue", query: ["limit": "1"])
        async let regionPage: ListPage = API.shared.get("list/region", query: ["limit": "20"])
        var counts = await MainActor.run { AppModel.shared.config?.counts } ?? [:]
        if counts.isEmpty, let cfg: ServerConfig = try? await API.shared.get("config") { counts = cfg.counts }
        let (u, v, r) = try await (unescoPage, venuePage, regionPage)

        var order = ExKinds.placeOrder
        order += u.kinds.keys.filter { !order.contains($0) }.sorted()
        let kinds = order.compactMap { k -> ExKindStat? in
            guard let n = u.kinds[k], n > 0 else { return nil }
            return ExKindStat(key: k, label: ExKinds.label("place", k, server: u.kindLabels[k]), count: n)
        }
        let stay = ExKinds.stay.reduce(0) { $0 + (v.kinds[$1] ?? 0) }
        let eat = ExKinds.eat.reduce(0) { $0 + (v.kinds[$1] ?? 0) }
        await MainActor.run { ExRegionStore.shared.set(r.items) }
        return ExExploreData(placeKinds: kinds, placeTotal: counts["place"] ?? kinds.reduce(0) { $0 + $1.count },
                             unescoTotal: u.total, unesco: u.items, regions: r.items, counts: counts, stay: stay, eat: eat)
    }
}

// MARK: - Kontent

private struct ExExploreContent: View {
    let data: ExExploreData
    @Environment(AppModel.self) private var model
    @State private var allKinds = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    private var sections: [ExSection] { ExSection.all(data) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                searchField.appear()
                kindsBlock.appear(delay: 0.05)
                unescoBanner.appear(delay: 0.1)
                regionsRail
                sectionsGrid
                Color.clear.frame(height: 8)
            }
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
    }

    // Qidiruv
    private var searchField: some View {
        Button { Haptics.tap(); model.open(.search) } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.body.weight(.semibold)).foregroundStyle(Theme.accent)
                Text(tr("Joy, shahar, mehmonxona…", "Место, город, отель…", "Places, cities, hotels…"))
                    .font(Theme.Font.body).foregroundStyle(Theme.muted).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).frame(minHeight: 50)
            .background(Theme.card, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.line))
            .contentShape(Capsule())
        }
        .buttonStyle(.press)
        .padding(.horizontal, Theme.gutter)
        .accessibilityLabel(tr("Qidiruv", "Поиск", "Search"))
        .accessibilityHint(tr("Butun sayt boʻyicha qidirish", "Поиск по всему сайту", "Search everything"))
    }

    // Joy turlari
    private var kindsBlock: some View {
        let shown = allKinds ? data.placeKinds : Array(data.placeKinds.prefix(9))
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: tr("Joy turlari", "Что посмотреть", "What to see"),
                          kicker: ExTypes.count(data.placeTotal, "place"),
                          actionTitle: tr("Hammasi", "Все", "See all")) {
                model.open(.list(ListSpec(type: "place")))
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(Array(shown.enumerated()), id: \.element.key) { i, k in
                    ExKindTile(stat: k, tint: ExKinds.tint(i)) {
                        model.open(.list(ListSpec(type: "place", kind: k.key)))
                    }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .padding(.horizontal, Theme.gutter)
            if data.placeKinds.count > 9 {
                Button {
                    Haptics.select()
                    withAnimation(reduce ? nil : Motion.spring) { allKinds.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text(allKinds ? tr("Kamroq", "Свернуть", "Show less")
                                      : tr("Yana \(data.placeKinds.count - 9) ta tur", "Ещё \(data.placeKinds.count - 9)", "\(data.placeKinds.count - 9) more"))
                        Image(systemName: "chevron.down").rotationEffect(.degrees(allKinds ? 180 : 0))
                    }
                    .font(Theme.Font.sub.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.press)
                .padding(.horizontal, Theme.gutter)
            }
        }
    }

    // UNESCO
    @ViewBuilder private var unescoBanner: some View {
        let cover = data.unesco.first { $0.img != nil }
        Button {
            Haptics.tap()
            model.open(.list(ListSpec(type: "place", unesco: true, title: tr("UNESCO merosi", "Наследие ЮНЕСКО", "UNESCO heritage"))))
        } label: {
            ZStack(alignment: .bottomLeading) {
                RemoteImage(img: cover?.img, region: cover?.region, icon: cover?.icon)
                LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.25), .black.opacity(0.78)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 8) {
                    UnescoBadge(onDark: true)
                    Text(tr("UNESCO merosi", "Наследие ЮНЕСКО", "UNESCO heritage"))
                        .font(Theme.Font.display(30)).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(tr("Jahon merosi roʻyxatidagi shaharlar va yodgorliklar — \(Fmt.num(data.unescoTotal)) ta obyekt",
                            "Города и памятники из Списка всемирного наследия — объектов: \(Fmt.num(data.unescoTotal))",
                            "World Heritage cities and monuments — \(Fmt.num(data.unescoTotal)) sites"))
                        .font(Theme.Font.sub).foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: -10) {
                        ForEach(data.unesco.dropFirst().filter { $0.img != nil }.prefix(4)) { c in
                            RemoteImage(img: c.img, region: c.region, icon: c.icon, width: 36)
                                .frame(width: 36, height: 36).clipShape(Circle())
                                .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2))
                        }
                        Spacer()
                        Image(systemName: "arrow.right").font(.headline).foregroundStyle(Theme.ink)
                            .frame(width: 40, height: 40).background(.white.opacity(0.92), in: Circle())
                    }
                    .padding(.top, 4)
                    .accessibilityHidden(true)
                }
                .padding(18)
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.gold.opacity(0.6), lineWidth: 1.5))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.l))
        }
        .buttonStyle(.press)
        .padding(.horizontal, Theme.gutter)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    // Hududlar
    private var regionsRail: some View {
        Rail(title: tr("Hududlar", "Регионы", "Regions"), kicker: ExTypes.count(data.regions.count, "region"), more: { model.open(.regions) }) {
            ForEach(data.regions) { r in
                ExRegionTile(card: r).carouselEffect()
            }
        }
    }

    // Bo'limlar
    private var sectionsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: tr("Boʻlimlar", "Разделы", "Sections"), kicker: tr("Hammasi bir joyda", "Всё в одном месте", "Everything in one place"))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { i, s in
                    ExSectionTile(section: s, tint: ExKinds.tint(i)) { model.open(s.route) }
                        .appear(delay: 0.03 * Double(i))
                }
            }
            .padding(.horizontal, Theme.gutter)
        }
    }
}

// MARK: - Bo'limlar ro'yxati

private struct ExSection: Identifiable {
    let id: String
    let title: String
    let detail: String?
    let symbol: String
    let route: Route

    static func all(_ d: ExExploreData) -> [ExSection] {
        let c = d.counts
        func n(_ t: String) -> Int { c[t] ?? 0 }
        func cnt(_ t: String, _ v: Int? = nil, group: String? = nil) -> String? {
            let v = v ?? n(t); return v > 0 ? ExTypes.count(v, t, group: group) : nil
        }
        let culture = ["cuisine", "craft", "tradition", "holiday"].reduce(0) { $0 + n($1) }
        let hist: String? = n("era") > 0
            ? [cnt("era"), cnt("hist_event")].compactMap { $0 }.joined(separator: " · ") : nil
        let transport: String? = n("airport") + n("rail_station") > 0
            ? [cnt("airport"), cnt("rail_station")].compactMap { $0 }.joined(separator: " · ") : nil
        return [
            ExSection(id: "stay", title: tr("Mehmonxonalar", "Отели", "Hotels"), detail: cnt("venue", d.stay, group: "stay"),
                      symbol: "bed.double.fill", route: .list(ListSpec(type: "venue", kind: "stay"))),
            ExSection(id: "eat", title: tr("Restoranlar", "Рестораны", "Restaurants"), detail: cnt("venue", d.eat, group: "eat"),
                      symbol: "fork.knife", route: .list(ListSpec(type: "venue", kind: "eat"))),
            ExSection(id: "history", title: tr("Tarix", "История", "History"), detail: hist, symbol: "scroll.fill", route: .history),
            ExSection(id: "person", title: tr("Allomalar", "Великие люди", "Notable figures"), detail: cnt("person"),
                      symbol: "person.2.fill", route: .list(ListSpec(type: "person"))),
            ExSection(id: "culture", title: tr("Madaniyat", "Культура", "Culture"),
                      detail: culture > 0 ? tr("\(culture) ta maqola", "Статей: \(culture)", "\(culture) articles") : nil,
                      symbol: "theatermasks.fill", route: .culture),
            ExSection(id: "fest", title: tr("Tadbirlar", "События", "Events"), detail: cnt("fest"),
                      symbol: "calendar", route: .list(ListSpec(type: "fest"))),
            ExSection(id: "route", title: tr("Marshrutlar", "Маршруты", "Itineraries"), detail: cnt("route"),
                      symbol: "point.topleft.down.to.point.bottomright.curvepath.fill", route: .list(ListSpec(type: "route"))),
            ExSection(id: "guide", title: tr("Sayohatchilarga", "Путешественникам", "Travel tips"), detail: cnt("guide"),
                      symbol: "suitcase.fill", route: .list(ListSpec(type: "guide"))),
            ExSection(id: "transport", title: tr("Transport", "Транспорт", "Transport"), detail: transport,
                      symbol: "tram.fill", route: .transport),
            ExSection(id: "gov", title: tr("Davlat idoralari", "Госучреждения", "Government"), detail: cnt("org"),
                      symbol: "building.columns.fill", route: .gov),
            ExSection(id: "bank", title: tr("Banklar", "Банки", "Banks"),
                      detail: n("bank") > 0 ? tr("\(n("bank")) ta bank · kurslar", "\(n("bank")) \(ExTypes.ruPlural(n("bank"), ["банк", "банка", "банков"])) · курсы", "\(n("bank")) banks · rates") : nil,
                      symbol: "banknote.fill", route: .currency),
            ExSection(id: "post", title: tr("Pochta", "Почта", "Post"), detail: cnt("post"),
                      symbol: "envelope.fill", route: .post(nil)),
        ]
    }
}

// MARK: - Plitkalar

private struct ExKindTile: View {
    let stat: ExKindStat
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button { Haptics.tap(); action() } label: {
            VStack(spacing: 8) {
                ExIconBadge(symbol: ExKinds.symbol("place", stat.key), tint: tint, size: 42)
                Text(stat.label).font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Fmt.num(stat.count)).font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.muted)
            }
            .padding(.vertical, 14).padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 116)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous).strokeBorder(Theme.line.opacity(0.7)))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
        }
        .buttonStyle(.press)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.label), \(ExTypes.count(stat.count, "place"))")
        .accessibilityAddTraits(.isButton)
    }
}

private struct ExSectionTile: View {
    let section: ExSection
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button { Haptics.tap(); action() } label: {
            HStack(alignment: .center, spacing: 12) {
                ExIconBadge(symbol: section.symbol, tint: tint, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    if let d = section.detail {
                        Text(d).font(Theme.Font.caption).foregroundStyle(Theme.muted).lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous).strokeBorder(Theme.line.opacity(0.7)))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
        }
        .buttonStyle(.press)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Hudud plitkasi (gorizontal karusel)
struct ExRegionTile: View {
    let card: Card
    var width: CGFloat = 150
    var height: CGFloat = 200
    @Environment(AppModel.self) private var model
    @Environment(\.zoomNS) private var ns
    var body: some View {
        Button { model.open(card) } label: {
            ZStack(alignment: .bottomLeading) {
                RemoteImage(img: card.img, region: card.slug, icon: card.icon, width: width)
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                Text(card.name).font(Theme.Font.title3).foregroundStyle(.white)
                    .lineLimit(3).minimumScaleFactor(0.8)
                    .padding(12)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
            .zoomSource(card.id, in: ns)
        }
        .buttonStyle(.press)
        .contextMenu { CardMenu(card: card) }
        .accessibilityLabel(card.name)
        .accessibilityHint(card.kicker ?? "")
    }
}

// MARK: - Yuklanayotgan holat

private struct ExExploreSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule().fill(Theme.paper3).frame(height: 50)
            Capsule().fill(Theme.paper3).frame(width: 160, height: 18)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.paper3).frame(height: 116)
                }
            }
            RoundedRectangle(cornerRadius: Theme.Radius.l).fill(Theme.paper3).frame(height: 240).overlay(Shimmer())
        }
        .padding(Theme.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("Yuklanmoqda", "Загрузка", "Loading"))
    }
}
