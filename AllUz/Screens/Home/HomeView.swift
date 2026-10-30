// Bosh sahifa — ilovaning yuzi: sarlavha (BrandMark), qahramon karusel (parallaks, avtomatik aylanish), qidiruv, tezkor bo'limlar,
// «Oxirgi ko'rilganlar», bo'lim karusellari (Albatta ko'ring, UNESCO, hududlar, marshrutlar, aeroportlar, tadbirlar, oshxona,
// allomalar, sayohatchilarga) va pastda raqamlar bilan yakun. Ma'lumot: API `home` (HomeData), raqamlar — model.config.counts.
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    /// Katta sarlavha yuqoriga ketganda — panelda kichik logotip + nom
    @State private var compactTitle = false

    var body: some View {
        Loadable(load: { try await API.shared.get("home") as HomeData }, skeleton: AnyView(HomeSkeleton())) { home in
            HomeContent(home: home, compactTitle: $compactTitle)
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle("All Uzbekistan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image("BrandMark").resizable().frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text("All Uzbekistan").font(Theme.Font.title3).foregroundStyle(Theme.ink)
                }
                .opacity(compactTitle ? 1 : 0)
                .offset(y: compactTitle ? 0 : 6)
                .animation(Motion.snappy, value: compactTitle)
                .accessibilityAddTraits(.isHeader)
                .accessibilityHidden(!compactTitle)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { Haptics.tap(); model.open(.saved) } label: {
                    Image(systemName: model.saved.isEmpty ? "bookmark" : "bookmark.fill")
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(tr("Saqlanganlar", "Избранное", "Saved"))
            }
        }
    }
}

// MARK: - Kontent

private struct HomeContent: View {
    let home: HomeData
    @Binding var compactTitle: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HomeHeader()
                    .onGeometryChange(for: Bool.self) { $0.frame(in: .scrollView).maxY < 8 } action: { compactTitle = $0 }
                if !home.hero.isEmpty { HomeHero(cards: home.hero) }
                HomeSearchButton().padding(.horizontal, Theme.gutter).appear(delay: 0.08)
                HomeQuickGrid().appear(delay: 0.14)
            }
            .padding(.bottom, 30)

            LazyVStack(alignment: .leading, spacing: 34) {
                if !model.recent.isEmpty { recentRail }
                if !home.top.isEmpty {
                    Rail(title: tr("Albatta koʻring", "Обязательно посмотрите", "Must see"),
                         kicker: tr("Eng mashhur joylar", "Самые известные места", "Uzbekistan’s great sights"),
                         more: { model.open(.list(ListSpec(type: "place"))) }) {
                        ForEach(home.top) { CardTile(card: $0, width: 240, imageHeight: 168).carouselEffect() }
                    }
                }
                if !home.unesco.isEmpty {
                    Rail(title: tr("Jahon merosi", "Всемирное наследие", "World Heritage"), kicker: "UNESCO",
                         more: { model.open(.list(ListSpec(type: "place", unesco: true, title: tr("UNESCO merosi", "Наследие ЮНЕСКО", "UNESCO heritage")))) }) {
                        ForEach(home.unesco) { CardTile(card: $0, width: 220, imageHeight: 150).carouselEffect() }
                    }
                }
                if !home.regions.isEmpty {
                    Rail(title: tr("Oʻn toʻrt hudud", "Четырнадцать регионов", "Fourteen regions"),
                         kicker: tr("Hududlar", "Регионы", "Regions"), more: { model.open(.regions) }) {
                        ForEach(home.regions) { HomeRegionCard(card: $0).carouselEffect() }
                    }
                }
                if !home.routes.isEmpty {
                    Rail(title: tr("Marshrutlar", "Маршруты", "Itineraries"),
                         kicker: tr("Tayyor reja", "Готовые планы", "Ready-made plans"), more: { model.open(.list(ListSpec(type: "route"))) }) {
                        ForEach(home.routes) { CardTile(card: $0, width: 260, imageHeight: 160).carouselEffect() }
                    }
                }
                if !home.airports.isEmpty { HomeAirports(airports: home.airports) }
                if !home.fests.isEmpty {
                    Rail(title: tr("Yaqin tadbirlar", "Ближайшие события", "Upcoming events"),
                         kicker: tr("Tadbirlar", "События", "Events"), more: { model.open(.list(ListSpec(type: "fest"))) }) {
                        ForEach(home.fests) { CardTile(card: $0, width: 240, imageHeight: 150).carouselEffect() }
                    }
                }
                if !home.cuisine.isEmpty {
                    Rail(title: tr("Oshxona", "Кухня", "Cuisine"),
                         kicker: tr("Nima tatib koʻrish kerak", "Что попробовать", "What to taste"), more: { model.open(.culture) }) {
                        ForEach(home.cuisine) { CardTile(card: $0, width: 168, imageHeight: 126).carouselEffect() }
                    }
                }
                if !home.persons.isEmpty {
                    Rail(title: tr("Allomalar", "Великие личности", "Great minds"),
                         kicker: tr("Ilm va madaniyat", "Наука и культура", "Science and culture"), more: { model.open(.list(ListSpec(type: "person"))) }) {
                        ForEach(home.persons) { HomePersonCard(card: $0) }
                    }
                }
                if !home.guides.isEmpty {
                    Rail(title: tr("Sayohatchilarga", "Путешественникам", "Travel tips"),
                         kicker: tr("Bilib qoʻying", "Полезно знать", "Good to know"), more: { model.open(.list(ListSpec(type: "guide"))) }) {
                        ForEach(home.guides) { HomeGuideCard(card: $0).carouselEffect() }
                    }
                }
                HomeFooter()
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.paper)
    }

    private var recentRail: some View {
        Rail(title: tr("Oxirgi koʻrilganlar", "Недавно просмотренные", "Recently viewed"),
             kicker: tr("Davom eting", "Продолжить", "Pick up where you left off"), more: { model.open(.saved) }) {
            ForEach(model.recent.prefix(12)) { CardTile(card: $0, width: 150, imageHeight: 100) }
        }
    }
}

// MARK: - Sarlavha

private struct HomeHeader: View {
    private let today = Fmt.day(Date(), weekday: true)
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Kicker(text: today, color: Theme.muted)
                Text("All Uzbekistan")
                    .font(Theme.Font.display(34))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Text(tr("Butun Oʻzbekiston — bir ilovada", "Весь Узбекистан — в одном приложении", "All of Uzbekistan in one app"))
                    .font(Theme.Font.sub).foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image("BrandMark").resizable().frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .shadow(color: Theme.accent.opacity(0.25), radius: 10, y: 4)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 4)
    }
}

// MARK: - Qahramon karusel

private struct HomeHero: View {
    let cards: [Card]
    @State private var current: Int? = 0
    @State private var interacting = false
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.scenePhase) private var phase

    private let height: CGFloat = 430

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(cards.indices, id: \.self) { i in
                        HomeHeroPage(card: cards[i], height: height, parallax: !reduce, index: i, total: cards.count)
                            .containerRelativeFrame(.horizontal)
                            .id(i)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $current)
            .frame(height: height)
            .modifier(HomeScrollPhase(interacting: $interacting))
            .task(id: "\(current ?? 0)-\(interacting)-\(phase == .active)") { await autoAdvance() }

            HStack(alignment: .center) {
                HomeDots(count: cards.count, current: current ?? 0) { i in
                    withAnimation(Motion.spring) { current = i }
                }
                Spacer(minLength: 12)
                if let i = current, cards.indices.contains(i), let img = cards[i].img {
                    CreditLine(img: img).frame(maxWidth: 220, alignment: .trailing)
                        .id(img.u)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Theme.gutter + 4)
            .animation(Motion.gentle, value: current)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(tr("Tanlangan joylar", "Избранные места", "Featured places"))
    }

    /// Har 6 soniyada keyingi sahifa (foydalanuvchi aylantirayotganda, Reduce Motion yoki fon holatida — to'xtaydi)
    private func autoAdvance() async {
        guard !reduce, !interacting, phase == .active, cards.count > 1 else { return }
        try? await Task.sleep(for: .seconds(6))
        guard !Task.isCancelled else { return }
        withAnimation(.smooth(duration: 0.8)) { current = ((current ?? 0) + 1) % cards.count }
    }
}

private struct HomeHeroPage: View {
    let card: Card
    let height: CGFloat
    let parallax: Bool
    let index: Int
    let total: Int
    @Environment(AppModel.self) private var model
    @Environment(\.zoomNS) private var ns

    var body: some View {
        let k: CGFloat = parallax ? 0.35 : 0
        Button { Haptics.soft(); model.open(card) } label: {
            ZStack(alignment: .bottomLeading) {
                Color.clear
                    .overlay {
                        RemoteImage(img: card.img, region: card.region, icon: card.icon, width: 520)
                            .scaleEffect(parallax ? 1.18 : 1)
                            .visualEffect { c, proxy in
                                c.offset(x: -(proxy.frame(in: .scrollView(axis: .horizontal)).minX - Theme.gutter) * k)
                            }
                    }
                    .clipped()
                LinearGradient(stops: [.init(color: .clear, location: 0.35), .init(color: .black.opacity(0.25), location: 0.6),
                                       .init(color: .black.opacity(0.78), location: 1)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        if card.unesco == true { UnescoBadge(onDark: true) }
                        if let s = card.sub, !s.isEmpty {
                            Text(s).font(Theme.Font.kicker).foregroundStyle(.white)
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .glassBackground(Capsule(), fallback: .ultraThinMaterial)
                                .lineLimit(1)
                        }
                    }
                    Text(card.name)
                        .font(Theme.Font.display(32)).foregroundStyle(.white)
                        .lineLimit(2).minimumScaleFactor(0.75)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                    if let s = card.kicker ?? card.summary, !s.isEmpty {
                        Text(s).font(Theme.Font.callout).foregroundStyle(.white.opacity(0.9)).lineLimit(2)
                    }
                    HStack(spacing: 6) {
                        Text(tr("Batafsil", "Подробнее", "Explore")).font(Theme.Font.sub.weight(.semibold))
                        Image(systemName: "arrow.right").font(.footnote.weight(.bold))
                    }
                    .foregroundStyle(Theme.accentInk)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Theme.accent, in: Capsule())
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            .zoomSource(card.id, in: ns)
            .padding(.horizontal, Theme.gutter)
            .scrollTransition(.interactive, axis: .horizontal) { c, phase in
                c.scaleEffect(phase.isIdentity ? 1 : 0.92).opacity(phase.isIdentity ? 1 : 0.7)
            }
        }
        .buttonStyle(.press)
        .contextMenu { CardMenu(card: card) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([card.name, card.sub, card.kicker].compactMap { $0 }.joined(separator: ", "))
        .accessibilityValue(tr("\(index + 1)-sahifa, jami \(total)", "\(index + 1) из \(total)", "\(index + 1) of \(total)"))
    }
}

/// Sahifa nuqtalari: joriy — cho'zilgan kapsula; bosilsa o'sha sahifa. VoiceOver — yuqoriga/pastga surish bilan almashadi.
private struct HomeDots: View {
    let count: Int
    let current: Int
    let select: (Int) -> Void
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Theme.accent : Theme.line)
                    .frame(width: i == current ? 22 : 7, height: 7)
                    .frame(height: 24)
                    .contentShape(Rectangle())
                    .onTapGesture { Haptics.select(); select(i) }
            }
        }
        .animation(Motion.snappy, value: current)
        .accessibilityElement()
        .accessibilityLabel(tr("Sahifa", "Страница", "Page"))
        .accessibilityValue("\(current + 1) / \(count)")
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: select(min(count - 1, current + 1))
            case .decrement: select(max(0, current - 1))
            @unknown default: break
            }
        }
    }
}

/// iOS 18+: foydalanuvchi karuselni surayotganini bilish (avtomatik aylanish to'xtaydi)
private struct HomeScrollPhase: ViewModifier {
    @Binding var interacting: Bool
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollPhaseChange { _, new in
                let busy = new == .interacting || new == .tracking
                if busy != interacting { interacting = busy }
            }
        } else {
            content
        }
    }
}

// MARK: - Qidiruv tugmasi

private struct HomeSearchButton: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        Button { Haptics.tap(); model.open(.search) } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.body.weight(.semibold)).foregroundStyle(Theme.accent)
                Text(tr("Joy, shahar, mehmonxona yoki taom", "Место, город, отель или блюдо", "Places, cities, hotels, dishes"))
                    .font(Theme.Font.body).foregroundStyle(Theme.muted).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 52)
            .contentShape(Capsule())
            .glassBackground(Capsule(), interactive: true, fallback: .regularMaterial)
            .overlay(Capsule().strokeBorder(Theme.line.opacity(0.7)))
        }
        .buttonStyle(.press)
        .accessibilityLabel(tr("Qidiruv", "Поиск", "Search"))
        .accessibilityHint(tr("Joy, shahar, mehmonxona yoki taomni qidirish", "Поиск мест, городов, отелей и блюд", "Search places, cities, hotels and dishes"))
    }
}

// MARK: - Tezkor bo'limlar (2 qator × 4)

private struct HomeQuickItem: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let color: Color
    let action: @MainActor (AppModel) -> Void
}

private struct HomeQuickGrid: View {
    @Environment(AppModel.self) private var model
    private let items: [HomeQuickItem] = [
        .init(id: "places", title: tr("Joylar", "Места", "Places"), symbol: "building.columns.fill", color: Theme.accent) {
            $0.open(.list(ListSpec(type: "place")))
        },
        .init(id: "regions", title: tr("Hududlar", "Регионы", "Regions"), symbol: "map.fill", color: Theme.teal) { $0.open(.regions) },
        .init(id: "board", title: tr("Tablo", "Табло", "Flights"), symbol: "airplane.departure", color: Theme.ink2) { m in
            Haptics.select(); m.tab = .board
        },
        .init(id: "weather", title: tr("Ob-havo", "Погода", "Weather"), symbol: "cloud.sun.fill", color: Theme.warn) { $0.open(.weather(nil)) },
        .init(id: "currency", title: tr("Valyuta", "Валюта", "Currency"), symbol: "dollarsign.arrow.circlepath", color: Theme.ok) { $0.open(.currency) },
        .init(id: "visa", title: tr("Viza", "Виза", "Visa"), symbol: "person.text.rectangle.fill", color: Theme.bad) { $0.open(.visa(nil)) },
        .init(id: "stay", title: tr("Mehmonxonalar", "Отели", "Hotels"), symbol: "bed.double.fill", color: Theme.gold) {
            $0.open(.list(ListSpec(type: "venue", kind: "stay", title: tr("Mehmonxonalar", "Отели", "Hotels"))))
        },
        .init(id: "eat", title: tr("Restoranlar", "Рестораны", "Restaurants"), symbol: "fork.knife", color: Theme.accent) {
            $0.open(.list(ListSpec(type: "venue", kind: "eat", title: tr("Restoranlar", "Рестораны", "Restaurants"))))
        },
    ]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items) { item in
                Button { Haptics.tap(); item.action(model) } label: {
                    VStack(spacing: 7) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(item.color)
                            .frame(width: 50, height: 50)
                            .background(item.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        Text(item.title)
                            .font(Theme.Font.caption.weight(.medium)).foregroundStyle(Theme.ink)
                            .lineLimit(2).minimumScaleFactor(0.75)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .top)
                    .padding(.vertical, 8)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
                    .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
                }
                .buttonStyle(.press)
                .accessibilityLabel(item.title)
            }
        }
        .padding(.horizontal, Theme.gutter)
    }
}

// MARK: - Maxsus kartalar

/// Hudud: tik karta, rasm ustida nom va shior
private struct HomeRegionCard: View {
    let card: Card
    @Environment(AppModel.self) private var model
    @Environment(\.zoomNS) private var ns
    var body: some View {
        Button { model.open(card) } label: {
            ZStack(alignment: .bottomLeading) {
                RemoteImage(img: card.img, region: card.slug, icon: card.icon, width: 170)
                LinearGradient(colors: [.clear, Theme.hue(card.slug).opacity(0.35), .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.name).font(Theme.Font.title3).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.8)
                    if let k = card.kicker, !k.isEmpty {
                        Text(k).font(Theme.Font.caption).foregroundStyle(.white.opacity(0.85)).lineLimit(2)
                    }
                }
                .padding(12)
            }
            .frame(width: 170, height: 230)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.l))
            .zoomSource(card.id, in: ns)
        }
        .buttonStyle(.press)
        .contextMenu { CardMenu(card: card) }
        .accessibilityElement(children: .combine)
    }
}

/// Alloma: yumaloq portret, ism va soha
private struct HomePersonCard: View {
    let card: Card
    @Environment(AppModel.self) private var model
    @Environment(\.zoomNS) private var ns
    var body: some View {
        Button { model.open(card) } label: {
            VStack(spacing: 8) {
                RemoteImage(img: card.img, region: card.region, icon: card.icon ?? "user", width: 108)
                    .frame(width: 108, height: 108)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Theme.gold.opacity(0.55), lineWidth: 2).padding(-4))
                    .padding(4)
                    .zoomSource(card.id, in: ns)
                Text(card.name).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center).lineLimit(2)
                if let k = card.kicker, !k.isEmpty {
                    Text(k).font(Theme.Font.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.center).lineLimit(2)
                }
            }
            .frame(width: 136)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .contextMenu { CardMenu(card: card) }
        .accessibilityElement(children: .combine)
    }
}

/// Sayohatchilarga maslahat (odatda rasmsiz): ikonka, sarlavha, qisqa matn
private struct HomeGuideCard: View {
    let card: Card
    @Environment(AppModel.self) private var model
    var body: some View {
        Button { model.open(card) } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: card.icon.map(SymbolMap.symbol) ?? SymbolMap.forType(card.type))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.teal)
                    .frame(width: 40, height: 40)
                    .background(Theme.teal.opacity(0.13), in: Circle())
                Text(card.name).font(Theme.Font.title3).foregroundStyle(Theme.ink).lineLimit(2).multilineTextAlignment(.leading)
                if let s = card.summary, !s.isEmpty {
                    Text(s).font(Theme.Font.sub).foregroundStyle(Theme.ink2).lineLimit(3).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(width: 260, height: 196, alignment: .topLeading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.l))
        }
        .buttonStyle(.press)
        .contextMenu { CardMenu(card: card) }
        .accessibilityElement(children: .combine)
    }
}

/// Aeroportlar: IATA chiplari → o'sha aeroport tablosi
private struct HomeAirports: View {
    let airports: [HomeAirport]
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: tr("Reyslar tablosi", "Табло рейсов", "Flight boards"), kicker: tr("Aeroportlar", "Аэропорты", "Airports"),
                          actionTitle: tr("Tablo", "Табло", "Board")) { model.tab = .board }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(airports, id: \.iata) { a in
                        Button { Haptics.tap(); model.open(.board(a.iata)) } label: {
                            HStack(spacing: 10) {
                                Text(a.iata).font(Theme.Font.mono).foregroundStyle(Theme.accent)
                                Text(a.city ?? a.name).font(Theme.Font.sub.weight(.medium)).foregroundStyle(Theme.ink).lineLimit(1)
                            }
                            .padding(.horizontal, 14).frame(minHeight: 44)
                            .background(Theme.card, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.line))
                        }
                        .buttonStyle(.press)
                        .accessibilityLabel("\(a.name), \(a.iata)")
                        .accessibilityHint(tr("Tabloni ochish", "Открыть табло", "Open the board"))
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 1)
            }
        }
    }
}

/// Yakun: raqamlar (config.counts) va manbalar haqida
private struct HomeFooter: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let c = model.config?.counts ?? [:]
        let stats: [(Int, String)] = [
            (c["place"] ?? 0, tr("diqqatga sazovor joy", "достопримечательностей", "sights")),
            (c["district"] ?? 0, tr("shahar va tuman", "городов и районов", "cities & districts")),
            (c["venue"] ?? 0, tr("mehmonxona va restoran", "отелей и ресторанов", "hotels & restaurants")),
            (c["org"] ?? 0, tr("davlat idorasi", "госучреждений", "public offices")),
        ].filter { $0.0 > 0 }
        VStack(alignment: .leading, spacing: 14) {
            Kicker(text: tr("Bir mamlakat — ming hikoya", "Одна страна — тысяча историй", "One country, a thousand stories"))
            if !stats.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)], spacing: 14) {
                    ForEach(stats, id: \.1) { n, label in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Fmt.num(n)).font(Theme.Font.display(28)).foregroundStyle(Theme.ink)
                                .contentTransition(.numericText())
                            Text(label).font(Theme.Font.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            Text(tr("Maʼlumotlar ochiq va rasmiy manbalardan; ish vaqti va narxlar oʻzgarishi mumkin.",
                    "Данные из открытых и официальных источников; часы работы и цены могут меняться.",
                    "Data from open and official sources; hours and prices may change."))
                .font(Theme.Font.sub).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
            Button { model.open(.about) } label: {
                Label(tr("Ilova haqida", "О приложении", "About the app"), systemImage: "info.circle")
                    .font(Theme.Font.sub.weight(.semibold))
            }
            .tint(Theme.accent)
            .frame(minHeight: 44)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper2, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
        .padding(.horizontal, Theme.gutter)
    }
}

// MARK: - Yuklanayotganda

private struct HomeSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HomeHeader()
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous).fill(Theme.paper3)
                .frame(height: 430).overlay(Shimmer()).clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
                .padding(.horizontal, Theme.gutter)
            Capsule().fill(Theme.paper3).frame(height: 52).padding(.horizontal, Theme.gutter)
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous).fill(Theme.paper3).frame(height: 88)
                }
            }
            .padding(.horizontal, Theme.gutter)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("Yuklanmoqda", "Загрузка", "Loading"))
    }
}
