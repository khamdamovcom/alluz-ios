// Tafsilot sahifasining kichik qurilish bloklari: chiplar uchun oqim (flow) joylashuvi, bo'lim o'rami, bosish amali, chip.
import SwiftUI

/// DetailTap → amal (tashqi havola faqat model.openURL orqali)
@MainActor
enum DetailNav {
    static func perform(_ t: DetailTap, _ model: AppModel) {
        Haptics.tap()
        switch t {
        case .url(let u): model.openURL(u)
        case .route(let r): model.open(r)
        case .card(let c): model.open(c)
        }
    }
}

/// Qatorga sig'maganini keyingi qatorga o'tkazuvchi joylashuv (chiplar, teglar)
struct DetailFlow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0, x + sz.width > width { x = 0; y += lineH + lineSpacing; lineH = 0 }
            x += sz.width + spacing
            maxX = max(maxX, x - spacing)
            lineH = max(lineH, sz.height)
        }
        return CGSize(width: width.isFinite ? width : maxX, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX, x + sz.width > bounds.maxX { x = bounds.minX; y += lineH + lineSpacing; lineH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(sz.width, bounds.width), height: sz.height))
            x += sz.width + spacing
            lineH = max(lineH, sz.height)
        }
    }
}

/// Bo'lim: sarlavha (ixtiyoriy belgi bilan) + mazmun, chetlardan Theme.gutter
struct DetailSection<Content: View>: View {
    let title: String
    var symbol: String? = nil
    var trailing: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                }
                Text(title).font(Theme.Font.title).foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if let trailing { Text(trailing).font(Theme.Font.caption).foregroundStyle(Theme.muted) }
            }
            content()
        }
        .padding(.horizontal, Theme.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Bitta chip (ikonka + matn); bosiladigan bo'lsa — urg'u rangida
struct DetailChipView: View {
    let chip: DetailChip
    @Environment(AppModel.self) private var model

    var body: some View {
        if let tap = chip.tap {
            Button { DetailNav.perform(tap, model) } label: { label(on: true) }.buttonStyle(.press)
        } else {
            label(on: false)
        }
    }

    private func label(on: Bool) -> some View {
        HStack(spacing: 6) {
            if let s = chip.symbol {
                Image(systemName: s).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accent).accessibilityHidden(true)
            }
            Text(chip.label).font(Theme.Font.sub).foregroundStyle(on ? Theme.accent : Theme.ink)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(minHeight: 34)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().strokeBorder(on ? Theme.accent.opacity(0.4) : Theme.line))
    }
}

/// Karta foni (Panel'dan yengilroq — ichki bo'laklar uchun)
extension View {
    func detailCard(radius: CGFloat = Theme.Radius.m, padding: CGFloat = 14) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
    }
}

/// Ochiladigan ro'yxat tugmasi: «Hammasini ko'rsatish (12)» / «Yig'ish»
struct DetailExpandButton: View {
    @Binding var expanded: Bool
    let more: Int
    var body: some View {
        Button {
            Haptics.select()
            withAnimation(Motion.spring) { expanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(expanded ? tr("Yigʻish", "Свернуть", "Show less") : tr("Yana \(more) ta", "Ещё \(more)", "\(more) more"))
                Image(systemName: "chevron.down").rotationEffect(.degrees(expanded ? 180 : 0))
            }
            .font(Theme.Font.sub.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
