// Umumiy komponentlar — barcha ekranlar shulardan foydalanadi (bir xil ko'rinish uchun). Yangi umumiy komponent kerak bo'lsa —
// o'z faylingizda private qiling yoki koordinatorga ayting.
//
//  Loadable(load: { try await API.shared.get("home") as HomeData }) { home in … }   — yuklash/xato/qayta urinish/tortib yangilash
//  CardLarge(card) / CardTile(card) / CardRow(card) — kartalar (bosilsa — model.open(card))
//  Rail(title:, more:) { ForEach … CardTile }            — gorizontal karusel bo'limi
//  SectionHeader(title, kicker:, action:)                 — bo'lim sarlavhasi
//  ChipBar(items:, selected:)                             — filtr chiplari
//  InfoRow(symbol:, title:, value:, action:)              — ma'lumot qatori (manzil, telefon …)
//  SaveButton(card) / ShareLinkButton(url)                — sevimli va ulashish
//  EmptyState / ErrorState / SkeletonList                 — bo'sh, xato, yuklanmoqda
import SwiftUI

// MARK: - Yuklash
struct Loadable<T: Sendable, Content: View>: View {
    let load: @Sendable () async throws -> T
    @ViewBuilder let content: (T) -> Content
    var skeleton: AnyView = AnyView(SkeletonList())

    init(load: @escaping @Sendable () async throws -> T, skeleton: AnyView = AnyView(SkeletonList()), @ViewBuilder content: @escaping (T) -> Content) {
        self.load = load; self.content = content; self.skeleton = skeleton
    }

    @State private var value: T?
    @State private var error: Error?
    @State private var attempt = 0
    /// Qaysi kalit bilan yuklangan — ekranga qaytilganda qayta so'ralmaydi (faqat til almashsa yoki «qayta urinish»da)
    @State private var loadedKey: String?
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let value {
                content(value).transition(.opacity)
            } else if let error {
                ErrorState(error: error) { self.error = nil; attempt += 1 }
            } else {
                skeleton.transition(.opacity)
            }
        }
        .animation(Motion.gentle, value: value == nil)
        .task(id: "\(attempt)-\(model.reloadToken)") {
            let key = "\(attempt)-\(model.reloadToken)"
            if value != nil, loadedKey == key { return }
            await run()
            if value != nil { loadedKey = key }
        }
        .refreshable { await run() }
    }

    private func run() async {
        do {
            let v = try await load()
            withAnimation(Motion.gentle) { value = v; error = nil }
        } catch is CancellationError {
        } catch {
            if value == nil { withAnimation { self.error = error } } else { model.show(error.localizedDescription) }
        }
    }
}

struct ErrorState: View {
    let error: Error
    let retry: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label(tr("Yuklab bo'lmadi", "Не удалось загрузить", "Couldn't load"), systemImage: (error as? APIError) == .offline ? "wifi.slash" : "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button(tr("Qayta urinish", "Повторить", "Try again"), action: retry).primaryButton().tint(Theme.accent)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }
}

struct EmptyState: View {
    var title: String = tr("Hech narsa topilmadi", "Ничего не найдено", "Nothing found")
    var text: String? = nil
    var symbol: String = "magnifyingglass"
    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: text.map(Text.init))
            .frame(maxWidth: .infinity, minHeight: 280)
    }
}

/// Yuklanayotganda kartalar o'rnida kulrang qoliplar
struct SkeletonList: View {
    var rows = 6
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: Theme.Radius.l).fill(Theme.paper3).frame(height: 220).overlay(Shimmer())
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.paper3).frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(Theme.paper3).frame(width: 180, height: 14)
                        Capsule().fill(Theme.paper3).frame(width: 120, height: 10)
                        Capsule().fill(Theme.paper3).frame(width: 220, height: 10)
                    }
                }
            }
        }
        .padding(Theme.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .redacted(reason: .placeholder)
        .accessibilityLabel(tr("Yuklanmoqda", "Загрузка", "Loading"))
    }
}

// MARK: - Kartalar
/// Katta karta: to'liq rasm, ustida sarlavha (bosh sahifa, tanlanganlar)
struct CardLarge: View {
    let card: Card
    var height: CGFloat = 300
    @Environment(AppModel.self) private var model
    @Environment(\.zoomNS) private var ns
    var body: some View {
        Button { model.open(card) } label: {
            ZStack(alignment: .bottomLeading) {
                RemoteImage(img: card.img, region: card.region, icon: card.icon)
                LinearGradient(colors: [.clear, .black.opacity(0.15), .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if card.unesco == true { UnescoBadge(onDark: true) }
                        if let k = card.sub, !k.isEmpty { Text(k).font(Theme.Font.kicker).foregroundStyle(.white.opacity(0.9)).lineLimit(1) }
                    }
                    Text(card.name).font(Theme.Font.display(28)).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.8)
                    if let s = card.kicker ?? card.summary, !s.isEmpty {
                        Text(s).font(Theme.Font.sub).foregroundStyle(.white.opacity(0.88)).lineLimit(2)
                    }
                }
                .padding(18)
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.l))
            .zoomSource(card.id, in: ns)
        }
        .buttonStyle(.press)
        .contextMenu { CardMenu(card: card) }
        .accessibilityElement(children: .combine)
    }
}

/// O'rta karta: rasm tepada, matn pastda (karusellar, katak)
struct CardTile: View {
    let card: Card
    var width: CGFloat? = 220
    var imageHeight: CGFloat = 150
    @Environment(AppModel.self) private var model
    @Environment(\.zoomNS) private var ns
    var body: some View {
        Button { model.open(card) } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    RemoteImage(img: card.img, region: card.region, icon: card.icon, width: width ?? 0)
                        .frame(height: imageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
                    if card.unesco == true { UnescoBadge(onDark: true).padding(8) }
                }
                .zoomSource(card.id, in: ns)
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.name).font(Theme.Font.headline).foregroundStyle(Theme.ink).lineLimit(2).multilineTextAlignment(.leading)
                    if let s = card.sub, !s.isEmpty { Text(s).font(Theme.Font.caption).foregroundStyle(Theme.muted).lineLimit(1) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .contextMenu { CardMenu(card: card) }
    }
}

/// Qator karta: chapda kichik rasm (ro'yxatlar)
struct CardRow: View {
    let card: Card
    var showSummary = true
    var trailing: String? = nil
    @Environment(AppModel.self) private var model
    var body: some View {
        Button { model.open(card) } label: {
            HStack(alignment: .top, spacing: 12) {
                RemoteImage(img: card.img, region: card.region, icon: card.icon, width: 84)
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(card.name).font(Theme.Font.headline).foregroundStyle(Theme.ink).lineLimit(2).multilineTextAlignment(.leading)
                        if card.unesco == true { UnescoBadge() }
                    }
                    if let s = card.sub, !s.isEmpty { Text(s).font(Theme.Font.caption).foregroundStyle(Theme.accent).lineLimit(1) }
                    if showSummary, let s = card.summary, !s.isEmpty {
                        Text(s).font(Theme.Font.sub).foregroundStyle(Theme.ink2).lineLimit(2).multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                if let trailing { Text(trailing).font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.muted) }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .contextMenu { CardMenu(card: card) }
    }
}

/// Uzoq bosilganda: saqlash, ulashish, saytda ochish
struct CardMenu: View {
    let card: Card
    @Environment(AppModel.self) private var model
    var body: some View {
        if card.ref != nil {
            Button { model.toggleSaved(card) } label: {
                model.isSaved(card.ref) ? Label(tr("Saqlanganlardan olish", "Убрать из избранного", "Remove from saved"), systemImage: "bookmark.slash")
                                        : Label(tr("Saqlash", "В избранное", "Save"), systemImage: "bookmark")
            }
        }
        if let w = card.web, let u = URL(string: w) {
            ShareLink(item: u) { Label(tr("Ulashish", "Поделиться", "Share"), systemImage: "square.and.arrow.up") }
        }
    }
}

struct UnescoBadge: View {
    var onDark = false
    var body: some View {
        Text("UNESCO").font(.system(size: 10, weight: .heavy)).tracking(0.6)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .foregroundStyle(onDark ? .white : Theme.gold)
            .background(onDark ? AnyShapeStyle(Theme.gold.opacity(0.9)) : AnyShapeStyle(Theme.gold.opacity(0.14)), in: Capsule())
            .accessibilityLabel(tr("YUNESKO merosi", "Наследие ЮНЕСКО", "UNESCO heritage"))
    }
}

// MARK: - Bo'limlar
struct SectionHeader: View {
    let title: String
    var kicker: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if let kicker { Kicker(text: kicker) }
                Text(title).font(Theme.Font.title).foregroundStyle(Theme.ink)
            }
            Spacer()
            if let action {
                Button(actionTitle ?? tr("Hammasi", "Все", "See all")) { Haptics.select(); action() }
                    .font(Theme.Font.sub.weight(.semibold)).tint(Theme.accent)
            }
        }
        .padding(.horizontal, Theme.gutter)
    }
}

/// Gorizontal karusel bo'limi
struct Rail<Content: View>: View {
    let title: String
    var kicker: String? = nil
    var more: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, kicker: kicker, action: more)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) { content() }
                    .scrollTargetLayout()
                    .padding(.horizontal, Theme.gutter)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

/// Filtr chiplari (tanlangan — urg'u rangida); nil — «Hammasi»
struct ChipBar: View {
    let items: [(key: String, label: String, count: Int?)]
    @Binding var selected: String?
    var allTitle: String = tr("Hammasi", "Все", "All")
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(nil, allTitle, nil).id("__all")
                    ForEach(items, id: \.key) { chip($0.key, $0.label, $0.count).id($0.key) }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 2)
            }
            .onAppear { if let s = selected { DispatchQueue.main.async { proxy.scrollTo(s, anchor: .center) } } }
            .onChange(of: selected) { _, s in withAnimation(Motion.snappy) { proxy.scrollTo(s ?? "__all", anchor: .center) } }
        }
    }
    private func chip(_ key: String?, _ label: String, _ count: Int?) -> some View {
        let on = selected == key
        return Button {
            Haptics.select()
            withAnimation(Motion.snappy) { selected = key }
        } label: {
            HStack(spacing: 5) {
                Text(label)
                if let count { Text("\(count)").foregroundStyle(on ? Theme.accentInk.opacity(0.8) : Theme.muted) }
            }
            .font(Theme.Font.sub.weight(.medium))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .foregroundStyle(on ? Theme.accentInk : Theme.ink)
            .background(on ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.card), in: Capsule())
            .overlay(Capsule().strokeBorder(on ? .clear : Theme.line))
        }
        .buttonStyle(.press)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Ma'lumot qatori: ikonka, sarlavha, qiymat; amal bo'lsa — bosiladi
struct InfoRow: View {
    let symbol: String
    let title: String
    let value: String
    var action: (() -> Void)? = nil
    var body: some View {
        let row = HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.accent).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Font.caption).foregroundStyle(Theme.muted)
                Text(value).font(Theme.Font.body).foregroundStyle(action == nil ? Theme.ink : Theme.accent).multilineTextAlignment(.leading)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
            if action != nil { Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted) }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        if let action { Button(action: action) { row }.buttonStyle(.press) } else { row }
    }
}

/// Oq/qora fondagi yumaloq karta konteyner
struct Panel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
    }
}

struct SaveButton: View {
    let card: Card
    @Environment(AppModel.self) private var model
    var body: some View {
        let on = model.isSaved(card.ref)
        Button { model.toggleSaved(card) } label: {
            Image(systemName: on ? "bookmark.fill" : "bookmark").contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(on ? tr("Saqlanganlardan olish", "Убрать из избранного", "Remove from saved") : tr("Saqlash", "В избранное", "Save"))
    }
}

/// Reyting: 1–5 yulduz (sayt reytingi — «qanchalik ko'rishga arziydi»)
struct RatingView: View {
    let rating: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < rating ? "star.fill" : "star").font(.system(size: 11)).foregroundStyle(i < rating ? Theme.gold : Theme.line)
            }
        }
        .accessibilityLabel("\(rating) / 5")
    }
}

/// Rasm muallifi va litsenziyasi (CC talabi) — bosilsa manba ochiladi
struct CreditLine: View {
    let img: Img?
    @Environment(AppModel.self) private var model
    var body: some View {
        if let img, let line = img.creditLine {
            Button { model.openWeb(img.source ?? img.licenseUrl) } label: {
                Label(line, systemImage: "camera").font(.caption2).foregroundStyle(Theme.muted).lineLimit(2).multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
        }
    }
}

/// Pastdagi qisqa xabar (model.show(...))
struct ToastView: View {
    let text: String
    var body: some View {
        Text(text).font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.ink)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .glassBackground(Capsule(), fallback: .regularMaterial)
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}
