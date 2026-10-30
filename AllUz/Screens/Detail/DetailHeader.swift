// Bosh qism: to'liq kenglikdagi rasm-galereya (sahifalab), tortganda cho'ziladi, aylantirganda sekinroq siljiydi (parallaks);
// sarlavha bloki (kicker, nom, shior, reyting/UNESCO, hudud va tuman) va tezkor amallar qatori (shisha tugmalar).
import SwiftUI

// MARK: - Rasm-galereya

struct DetailHero: View {
    let images: [Img]
    let region: String?
    let icon: String?
    let unesco: Bool
    let title: String
    var symbol: String = "mappin.and.ellipse"
    @Binding var page: Int?
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let reduce = reduceMotion
        ZStack(alignment: .bottom) {
            if images.isEmpty {
                DetailHeroPlaceholder(region: region, symbol: symbol)
            } else {
                pager
            }
            // Yuqorida yengil «qog'oz tumani» — status bar va navigatsiya tugmalari rasm ustida ham o'qiladi
            LinearGradient(colors: [Theme.paper.opacity(0.6), Theme.paper.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 120)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
            LinearGradient(colors: [.clear, .black.opacity(0.42)], startPoint: .top, endPoint: .bottom)
                .frame(height: 150)
                .allowsHitTesting(false)
            HStack(alignment: .center) {
                if unesco { UnescoBadge(onDark: true) }
                Spacer(minLength: 8)
                if images.count > 1 { DetailPageIndicator(count: images.count, current: page ?? 0) }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 42)
        }
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical) { len, _ in
            images.isEmpty ? min(max(len * 0.34, 230), 300) : min(max(len * 0.54, 320), 520)
        }
        .clipped()
        .visualEffect { content, proxy in
            let y = proxy.frame(in: .scrollView(axis: .vertical)).minY
            let h = max(proxy.size.height, 1)
            return content
                .scaleEffect(y > 0 ? (h + y) / h : 1, anchor: .bottom)          // tortganda kattalashadi
                .offset(y: y < 0 && !reduce ? -y * 0.4 : 0)                       // aylantirganda sekinroq ketadi
        }
    }

    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(images.enumerated()), id: \.offset) { i, img in
                    Button {
                        Haptics.soft()
                        model.open(.gallery(images, i))
                    } label: {
                        RemoteImage(img: img, region: region, icon: icon)
                    }
                    .buttonStyle(.plain)
                    .containerRelativeFrame(.horizontal)
                    .id(i)
                    .accessibilityLabel(img.title ?? title)
                    .accessibilityHint(tr("Rasmni toʻliq ekranda ochish", "Открыть фото на весь экран", "Opens the photo full screen"))
                    .accessibilityAddTraits(.isImage)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $page)
        .scrollDisabled(images.count < 2)
    }
}

/// Rasmsiz yozuv: hudud rangidagi gradient, katta tur ikonkasi va yumshoq doiralar (bezak)
struct DetailHeroPlaceholder: View {
    let region: String?
    let symbol: String
    var body: some View {
        let hue = Theme.hue(region)
        ZStack {
            LinearGradient(colors: [hue.opacity(0.85), hue.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.08)).frame(width: 320).offset(x: 150, y: -40)
            Circle().fill(.white.opacity(0.06)).frame(width: 220).offset(x: -160, y: 70)
            Image(systemName: symbol)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.white.opacity(0.85))
                .offset(y: 6)
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

/// Sahifa ko'rsatkichi: kam rasmda nuqtalar, ko'pida «3 / 12»
struct DetailPageIndicator: View {
    let count: Int
    let current: Int
    var body: some View {
        Group {
            if count <= 7 {
                HStack(spacing: 5) {
                    ForEach(0..<count, id: \.self) { i in
                        Capsule().fill(.white.opacity(i == current ? 1 : 0.5))
                            .frame(width: i == current ? 16 : 6, height: 6)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "photo.on.rectangle").font(.system(size: 11, weight: .semibold))
                    Text("\(current + 1) / \(count)").font(Theme.Font.caption.monospacedDigit().weight(.semibold))
                        .contentTransition(.numericText(value: Double(current)))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 6)
            }
        }
        .background(.black.opacity(0.28), in: Capsule())
        .animation(Motion.snappy, value: current)
        .accessibilityElement()
        .accessibilityLabel(tr("Rasm \(current + 1), jami \(count)", "Фото \(current + 1) из \(count)", "Photo \(current + 1) of \(count)"))
    }
}

// MARK: - Sarlavha bloki

struct DetailTitleBlock: View {
    let c: DetailContent
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: c.kicker)
            Text(c.title)
                .font(Theme.Font.display(c.title.count > 48 ? 26 : 32))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let t = c.tagline {
                Text(t).font(Theme.Font.title3.weight(.regular)).italic().foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            meta
        }
        .padding(.horizontal, Theme.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var meta: some View {
        let rating = c.item.rating ?? 0
        let hasMeta = rating > 0 || c.item.unesco == true || c.readMinutes > 0 || c.districtLabel != nil || c.regionLabel != nil
        if hasMeta {
            DetailFlow(spacing: 8, lineSpacing: 8) {
                if rating > 0 {
                    RatingView(rating: min(rating, 5))
                        .padding(.horizontal, 10).frame(height: 30)
                        .background(Theme.gold.opacity(0.1), in: Capsule())
                }
                if c.item.unesco == true { UnescoBadge().frame(height: 30) }
                if let d = c.districtLabel, d != c.title { place(d, card: c.districtCard, symbol: "mappin") }
                if let r = c.regionLabel, r != c.title { place(r, card: c.regionCard, symbol: "map") }
                if c.readMinutes > 0 {
                    Label(tr("\(c.readMinutes) daq oʻqish", "\(c.readMinutes) мин чтения", "\(c.readMinutes) min read"), systemImage: "book")
                        .font(Theme.Font.caption.weight(.medium)).foregroundStyle(Theme.muted)
                        .frame(height: 30)
                }
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder private func place(_ text: String, card: Card?, symbol: String) -> some View {
        let label = Label(text, systemImage: symbol)
            .font(Theme.Font.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10).frame(minHeight: 30)
        if let card, card.ref != nil {
            Button { Haptics.tap(); model.open(card) } label: {
                label.foregroundStyle(Theme.accent).background(Theme.accent.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.press)
            .accessibilityHint(tr("Hudud sahifasini ochish", "Открыть страницу", "Opens this area"))
        } else {
            label.foregroundStyle(Theme.ink2).background(Theme.paper2, in: Capsule())
        }
    }
}

// MARK: - Tezkor amallar

struct DetailQuickActions: View {
    let c: DetailContent
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 6) {
                ForEach(Array(c.quick.enumerated()), id: \.element.id) { i, q in
                    button(q, primary: i == 0)
                }
                if let w = DetailLink.web(c.item.web) {
                    ShareLink(item: w, subject: Text(c.title)) {
                        DetailQuickLabel(symbol: "square.and.arrow.up", title: tr("Ulashish", "Поделиться", "Share"))
                    }
                    .buttonStyle(.press)
                }
                let saved = model.isSaved(c.item.ref)
                Button { model.toggleSaved(c.item.card) } label: {
                    DetailQuickLabel(symbol: saved ? "bookmark.fill" : "bookmark",
                                     title: saved ? tr("Saqlangan", "В избранном", "Saved") : tr("Saqlash", "Сохранить", "Save"),
                                     active: saved)
                }
                .buttonStyle(.press)
                .sensoryFeedback(.selection, trigger: saved)
            }
            .padding(.horizontal, Theme.gutter - 4)
            .glassGroup(spacing: 6)
        }
    }

    private func button(_ q: DetailQuick, primary: Bool) -> some View {
        let (symbol, title, url): (String, String, URL?) = switch q {
        case .directions(let u): ("arrow.triangle.turn.up.right.diamond", tr("Yoʻnalish", "Маршрут", "Directions"), u)
        case .call(let u): ("phone", tr("Qoʻngʻiroq", "Позвонить", "Call"), u)
        case .web(let u): ("safari", tr("Sayt", "Сайт", "Website"), u)
        case .telegram(let u): ("paperplane", "Telegram", u)
        case .instagram(let u): ("camera", "Instagram", u)
        case .mail(let u): ("envelope", "Email", u)
        case .board: ("airplane.departure", tr("Tablo", "Табло", "Flights"), nil)
        case .railBoard: ("tram", tr("Tablo", "Табло", "Timetable"), nil)
        }
        return Button {
            Haptics.tap()
            switch q {
            case .board(let iata): model.open(.board(iata))
            case .railBoard(let st): model.open(.railBoard(st))
            default: if let url { model.openURL(url) }
            }
        } label: {
            DetailQuickLabel(symbol: symbol, title: title, primary: primary)
        }
        .buttonStyle(.press)
    }
}

/// Shisha doira ichida ikonka + ostida yozuv (≥ 44 pt)
struct DetailQuickLabel: View {
    let symbol: String
    let title: String
    var primary = false
    var active = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(primary ? Theme.accentInk : Theme.accent)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 54, height: 54)
                .background {
                    if primary { Circle().fill(Theme.accent) }
                    else if active { Circle().fill(Theme.accent.opacity(0.14)) }
                }
                .glassBackground(Circle(), tint: primary ? Theme.accent : nil, interactive: true)
            Text(title)
                .font(Theme.Font.caption.weight(.medium))
                .foregroundStyle(Theme.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 74)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}
