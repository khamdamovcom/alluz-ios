// Matn: xulosa (lead), maqola (h + p; uzun bo'lsa «Davomini o'qish»), asosiy diqqatga sazovor joylar, eslatmalar, maslahatlar.
import SwiftUI

struct DetailLead: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(Theme.accent).frame(width: 3)
                .accessibilityHidden(true)
            Text(text)
                .font(Theme.Font.title3.weight(.regular))
                .foregroundStyle(Theme.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Theme.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailArticle: View {
    let blocks: [DetailBlock]
    let collapsedCount: Int?
    let readMinutes: Int
    @State private var expanded = false

    var body: some View {
        let collapsed = collapsedCount != nil && !expanded
        let visible = collapsed ? Array(blocks.prefix(collapsedCount ?? blocks.count)) : blocks
        DetailSection(title: tr("Batafsil", "Подробно", "In depth"), symbol: "text.book.closed",
                      trailing: readMinutes > 0 ? tr("~\(readMinutes) daq", "~\(readMinutes) мин", "~\(readMinutes) min") : nil) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(visible) { b in
                    block(b, faded: collapsed && b.id == visible.last?.id)
                        .transition(.opacity.combined(with: .offset(y: 8)))
                }
                if collapsedCount != nil {
                    Button {
                        Haptics.select()
                        withAnimation(Motion.spring) { expanded.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Text(expanded ? tr("Qisqartirish", "Свернуть", "Show less") : tr("Davomini oʻqish", "Читать дальше", "Read more"))
                            Image(systemName: "chevron.down").rotationEffect(.degrees(expanded ? 180 : 0))
                        }
                        .font(Theme.Font.sub.weight(.semibold))
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                    }
                    .secondaryButton()
                    .tint(Theme.accent)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder private func block(_ b: DetailBlock, faded: Bool) -> some View {
        if b.heading {
            Text(b.text)
                .font(Theme.Font.title3)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, b.id == 0 ? 0 : 8)
                .accessibilityAddTraits(.isHeader)
        } else {
            Text(b.text)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .mask {
                    if faded {
                        LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.45), .init(color: .black.opacity(0.08), location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                    } else {
                        Rectangle()
                    }
                }
        }
    }
}

/// «Asosiy» — text.highlights
struct DetailHighlights: View {
    let items: [String]
    var body: some View {
        DetailSection(title: tr("Eng muhimlari", "Главное", "Highlights"), symbol: "star") {
            DetailFlow {
                ForEach(Array(items.enumerated()), id: \.offset) { _, s in
                    DetailChipView(chip: DetailChip(id: s, label: s, symbol: "star.fill"))
                }
            }
        }
    }
}

/// Eslatmalar (qachon o'tkaziladi va h.k.)
struct DetailNotes: View {
    let notes: [DetailFact]
    var body: some View {
        VStack(spacing: 10) {
            ForEach(notes) { n in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: n.symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.teal)
                        .frame(width: 24).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(n.label).font(Theme.Font.caption.weight(.semibold)).foregroundStyle(Theme.teal)
                        Text(n.value).font(Theme.Font.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Theme.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, Theme.gutter)
    }
}

/// Maslahatlar — alohida panel, har biri ikonkali
struct DetailTips: View {
    let tips: [String]
    private static let symbols = ["lightbulb", "clock", "camera", "figure.walk", "ticket", "info.circle", "sun.max", "hand.thumbsup"]
    @State private var bounce = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "lightbulb.max.fill").font(.system(size: 18)).foregroundStyle(Theme.gold)
                    .symbolEffect(.bounce, value: bounce)
                    .onAppear { bounce.toggle() }
                Text(tr("Maslahatlar", "Советы", "Tips")).font(Theme.Font.title).foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(tips.enumerated()), id: \.offset) { i, tip in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: Self.symbols[i % Self.symbols.count])
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                            .frame(width: 30, height: 30)
                            .background(Theme.gold.opacity(0.14), in: Circle())
                            .accessibilityHidden(true)
                        Text(tip).font(Theme.Font.body).foregroundStyle(Theme.ink)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.gold.opacity(0.07), in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.gold.opacity(0.25)))
        .padding(.horizontal, Theme.gutter)
    }
}

/// Venue: ogohlantirish (narx/vaqt o'zgarishi mumkin)
struct DetailDisclaimer: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
