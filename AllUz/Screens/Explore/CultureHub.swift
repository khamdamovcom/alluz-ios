// Madaniyat: oshxona, hunarmandchilik, an'analar, bayramlar, festivallar. 5 ta parallel so'rov (list/<tur>).
// An'ana va bayramlarda rasm yo'q — ular ikonka + rangli kartalar bilan chiqadi.
import SwiftUI

struct CultureHub: View {
    var body: some View {
        Loadable(load: { try await ExCultureData.load() }) { data in
            ExCultureContent(data: data)
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle(tr("Madaniyat", "Культура", "Culture"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ExCultureData: Sendable {
    let cuisine: ListPage
    let craft: ListPage
    let tradition: ListPage
    let holiday: ListPage
    let fest: ListPage

    static func load() async throws -> ExCultureData {
        @Sendable func page(_ t: String, _ n: Int) async throws -> ListPage { try await API.shared.get("list/\(t)", query: ["limit": String(n)]) }
        async let a = page("cuisine", 12)
        async let b = page("craft", 12)
        async let c = page("tradition", 10)
        async let d = page("holiday", 12)
        async let e = page("fest", 10)
        return try await ExCultureData(cuisine: a, craft: b, tradition: c, holiday: d, fest: e)
    }
}

private struct ExCultureContent: View {
    let data: ExCultureData
    @Environment(AppModel.self) private var model

    private struct Anchor: Identifiable { let id: String; let title: String; let symbol: String; let count: Int }
    private var anchors: [Anchor] {
        [Anchor(id: "cuisine", title: tr("Oshxona", "Кухня", "Cuisine"), symbol: "fork.knife", count: data.cuisine.total),
         Anchor(id: "craft", title: tr("Hunarlar", "Ремёсла", "Crafts"), symbol: "paintpalette.fill", count: data.craft.total),
         Anchor(id: "tradition", title: tr("Anʼanalar", "Традиции", "Traditions"), symbol: "person.2.fill", count: data.tradition.total),
         Anchor(id: "holiday", title: tr("Bayramlar", "Праздники", "Holidays"), symbol: "gift.fill", count: data.holiday.total),
         Anchor(id: "fest", title: tr("Festivallar", "Фестивали", "Festivals"), symbol: "music.note", count: data.fest.total)]
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 16) {
                        ExIntro(kicker: tr("Madaniyat", "Культура", "Culture"),
                                title: tr("Oʻzbekiston madaniyati", "Культура Узбекистана", "The culture of Uzbekistan"),
                                text: tr("Dasturxondagi osh va choy, ustalar qoʻlidan chiqqan kulolchilik va atlas, mahalla va toʻy anʼanalari, Navroʻz va festivallar — xalqning tirik merosi.",
                                         "Плов и чай на дастархане, керамика и атлас из рук мастеров, традиции махалли и свадеб, Навруз и фестивали — живое наследие народа.",
                                         "Plov and tea on the dastarkhan, ceramics and silk from master artisans, mahalla and wedding traditions, Navruz and festivals — a living heritage."))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(anchors) { a in
                                    Button {
                                        Haptics.select()
                                        withAnimation(Motion.spring) { proxy.scrollTo(a.id, anchor: .top) }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: a.symbol).foregroundStyle(Theme.accent)
                                            Text(a.title).foregroundStyle(Theme.ink)
                                            Text("\(a.count)").foregroundStyle(Theme.muted)
                                        }
                                        .font(Theme.Font.sub.weight(.medium))
                                        .padding(.horizontal, 14).frame(minHeight: 40)
                                        .background(Theme.card, in: Capsule())
                                        .overlay(Capsule().strokeBorder(Theme.line))
                                    }
                                    .buttonStyle(.press)
                                    .accessibilityLabel("\(a.title), \(a.count)")
                                }
                            }
                            .padding(.horizontal, Theme.gutter)
                        }
                    }
                    .appear()

                    rail("cuisine", data.cuisine, title: tr("Milliy taomlar", "Национальная кухня", "Uzbek cuisine"),
                         kicker: tr("Oshxona", "Кухня", "Cuisine"))
                    rail("craft", data.craft, title: tr("Hunarmandchilik", "Ремёсла", "Crafts"),
                         kicker: tr("Ustalar merosi", "Наследие мастеров", "Master artisans"))
                    traditions
                    holidays
                    rail("fest", data.fest, title: tr("Festivallar", "Фестивали", "Festivals"),
                         kicker: tr("Tadbirlar", "События", "Events"))
                }
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
        }
    }

    private func openAll(_ type: String) { model.open(.list(ListSpec(type: type))) }

    @ViewBuilder
    private func rail(_ type: String, _ page: ListPage, title: String, kicker: String) -> some View {
        if !page.items.isEmpty {
            Rail(title: title, kicker: "\(kicker) · \(page.total)", more: { openAll(type) }) {
                ForEach(page.items) { c in
                    CardTile(card: c, width: 200, imageHeight: 140).carouselEffect()
                }
            }
            .id(type)
        }
    }

    // An'analar — rangli ikonka kartalari (gorizontal)
    @ViewBuilder private var traditions: some View {
        if !data.tradition.items.isEmpty {
            Rail(title: tr("Anʼanalar", "Традиции", "Traditions"),
                 kicker: "\(tr("Urf-odatlar", "Обычаи", "Customs")) · \(data.tradition.total)",
                 more: { openAll("tradition") }) {
                ForEach(Array(data.tradition.items.enumerated()), id: \.element.id) { i, c in
                    ExSymbolCard(card: c, symbol: ExCultureSymbols.tradition(c.slug), tint: ExKinds.tint(i))
                        .frame(width: 236)
                        .carouselEffect()
                }
            }
            .id("tradition")
        }
    }

    // Bayramlar — kalendar varag'i uslubida vertikal ro'yxat
    @ViewBuilder private var holidays: some View {
        if !data.holiday.items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: tr("Bayramlar", "Праздники", "Holidays"),
                              kicker: "\(tr("Yil davomida", "Круглый год", "All year round")) · \(data.holiday.total)",
                              action: { openAll("holiday") })
                VStack(spacing: 10) {
                    ForEach(Array(data.holiday.items.prefix(6).enumerated()), id: \.element.id) { i, c in
                        ExHolidayRow(card: c, symbol: ExCultureSymbols.holiday(c.slug), tint: ExKinds.tint(i + 2))
                            .appear(delay: 0.03 * Double(i))
                    }
                }
                .padding(.horizontal, Theme.gutter)
            }
            .id("holiday")
        }
    }
}

// MARK: - Ikonkalar (sayt bu turlarga bitta umumiy ikonka beradi — ilovada har biriga mosini tanlaymiz)

enum ExCultureSymbols {
    static func tradition(_ slug: String?) -> String {
        switch slug {
        case "mehmondorchilik": "hands.sparkles.fill"
        case "choy-madaniyati": "cup.and.saucer.fill"
        case "ozbek-toyi": "heart.fill"
        case "beshik-toyi": "moon.zzz.fill"
        case "mahalla": "house.and.flag.fill"
        case "hashar": "hammer.fill"
        case "navroz-urf-odatlari": "leaf.fill"
        case "shashmaqom", "katta-ashula": "music.quarternote.3"
        case "baxshichilik": "guitars.fill"
        case "lazgi": "figure.dance"
        case "askiya", "nasriddin-afandi-latifalari": "face.smiling.inverse"
        case "kurash": "figure.wrestling"
        case "kopkari": "figure.equestrian.sports"
        case "milliy-libos": "tshirt.fill"
        case "ramazon-va-iftor": "moon.stars.fill"
        case "boysun-urf-odatlari": "mountain.2.fill"
        default: "sparkles"
        }
    }
    static func holiday(_ slug: String?) -> String {
        switch slug {
        case "yangi-yil": "snowflake"
        case "vatan-himoyachilari-kuni": "shield.fill"
        case "xotin-qizlar-kuni": "camera.macro"
        case "navroz-bayrami": "sun.max.fill"
        case "ramazon-hayiti", "qurbon-hayiti": "moon.stars.fill"
        case "xotira-va-qadrlash-kuni": "flame.fill"
        case "mustaqillik-kuni": "flag.fill"
        case "oqituvchi-va-murabbiylar-kuni": "graduationcap.fill"
        case "konstitutsiya-kuni": "book.closed.fill"
        default: "calendar"
        }
    }
}

/// Rasmsiz kontent uchun karta: rangli gradient, katta ikonka, nom va qisqa tavsif
struct ExSymbolCard: View {
    let card: Card
    let symbol: String
    let tint: Color
    var height: CGFloat = 190
    @Environment(AppModel.self) private var model

    var body: some View {
        Button { model.open(card) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: symbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 52, height: 52)
                        .background(tint.opacity(0.16), in: Circle())
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 2)
                Text(card.name).font(Theme.Font.title3).foregroundStyle(Theme.ink)
                    .lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                if let s = card.summary, !s.isEmpty {
                    Text(s).font(Theme.Font.caption).foregroundStyle(Theme.ink2)
                        .lineLimit(3).multilineTextAlignment(.leading)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
            .background {
                ZStack(alignment: .bottomTrailing) {
                    LinearGradient(colors: [tint.opacity(0.14), Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: symbol)
                        .font(.system(size: 96, weight: .bold))
                        .foregroundStyle(tint.opacity(0.07))
                        .offset(x: 18, y: 18)
                        .accessibilityHidden(true)
                }
                .background(Theme.card)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(tint.opacity(0.25)))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.l))
        }
        .buttonStyle(.press)
        .contextMenu { CardMenu(card: card) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([card.name, card.summary].compactMap { $0 }.joined(separator: ". "))
        .accessibilityAddTraits(.isButton)
    }
}

/// Bayram qatori: chapda rangli «kalendar varag'i» ikonka, o'ngda nom va tavsif (sana tavsif boshida)
private struct ExHolidayRow: View {
    let card: Card
    let symbol: String
    let tint: Color
    @Environment(AppModel.self) private var model
    var body: some View {
        Button { model.open(card) } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    Rectangle().fill(tint).frame(height: 10)
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(tint.opacity(0.1))
                }
                .frame(width: 56, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(tint.opacity(0.3)))
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    if let s = card.summary, !s.isEmpty {
                        Text(s).font(Theme.Font.sub).foregroundStyle(Theme.ink2).lineLimit(2).multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
        }
        .buttonStyle(.press)
        .contextMenu { CardMenu(card: card) }
        .accessibilityElement(children: .combine)
    }
}
