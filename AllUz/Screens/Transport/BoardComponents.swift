// Tablo bo'limining umumiy kichik ko'rinishlari: holat pill'i, «jonli» nuqta, shisha segment, ma'lumot yorlig'i, yangilanish belgisi.
import SwiftUI

/// Rangli holat yorlig'i (o'z vaqtida — yashil, kechikadi — sariq, bekor — qizil, uchdi/qo'ndi — kulrang)
struct BoardStatusPill: View {
    let label: String
    let tone: BoardTone
    var large = false

    var body: some View {
        HStack(spacing: large ? 7 : 5) {
            BoardLiveDot(color: tone.color, size: large ? 8 : 6, pulsing: tone == .boarding)
            Text(label)
                .font(large ? Theme.Font.sub.weight(.semibold) : Theme.Font.caption.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .contentTransition(.interpolate)
        }
        .padding(.horizontal, large ? 12 : 8)
        .padding(.vertical, large ? 7 : 4)
        .foregroundStyle(tone == .done || tone == .neutral ? Theme.ink2 : tone.color)
        .background(tone.color.opacity(tone == .done || tone == .neutral ? 0.12 : 0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(tone.color.opacity(0.22), lineWidth: 0.5))
        .animation(Motion.spring, value: label)
        .animation(Motion.spring, value: tone)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

/// Kichik doira; pulsing — sekin «nafas oladi» (Reduce Motion'da harakatsiz)
struct BoardLiveDot: View {
    var color: Color = Theme.ok
    var size: CGFloat = 7
    var pulsing = true
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
            .background {
                if pulsing && !reduce {
                    Circle().fill(color.opacity(0.35)).frame(width: size, height: size)
                        .phaseAnimator([false, true]) { c, on in
                            c.scaleEffect(on ? 2.4 : 1).opacity(on ? 0 : 0.9)
                        } animation: { on in on ? .easeOut(duration: 1.4) : .linear(duration: 0.01) }
                }
            }
            .accessibilityHidden(true)
    }
}

/// Shisha segment (Jo'nash/Kelish, Kecha/Bugun/Ertaga) — tanlangan bo'lak sirpanib o'tadi
struct BoardSegment<T: Hashable & Identifiable>: View {
    let items: [T]
    @Binding var selection: T
    let title: (T) -> String
    var symbol: ((T) -> String)? = nil
    var compact = false
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { it in
                let on = it == selection
                Button {
                    guard !on else { return }
                    Haptics.select()
                    withAnimation(Motion.snappy) { selection = it }
                } label: {
                    HStack(spacing: 6) {
                        if let symbol { Image(systemName: symbol(it)).font(.footnote.weight(.semibold)) }
                        Text(title(it)).lineLimit(1).minimumScaleFactor(0.75)
                    }
                    .font(compact ? Theme.Font.caption.weight(.semibold) : Theme.Font.sub.weight(.semibold))
                    .foregroundStyle(on ? Theme.accentInk : Theme.ink)
                    .padding(.horizontal, compact ? 10 : 12)
                    .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 32 : 40)
                    .background {
                        if on { Capsule().fill(Theme.accent).matchedGeometryEffect(id: "seg", in: ns) }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(3)
        .glassBackground(Capsule(), fallback: .regularMaterial)
        .overlay(Capsule().strokeBorder(Theme.line.opacity(0.5), lineWidth: 0.5))
    }
}

/// Terminal / chiqish / stoyka / lenta yorlig'i
struct BoardBitTag: View {
    let bit: BoardInfoBit
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: bit.symbol).font(.caption2.weight(.semibold)).foregroundStyle(Theme.muted)
            Text(bit.label).foregroundStyle(Theme.muted)
            Text(bit.value).font(Theme.Font.boardCode).foregroundStyle(Theme.ink)
        }
        .font(Theme.Font.caption)
        .lineLimit(1)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Theme.paper2, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// «Yangilandi 14:05» — yangilanayotganda aylanadigan belgi; eskirgan bo'lsa sariq
struct BoardUpdatedBadge: View {
    let updated: Date?
    let refreshing: Bool
    let stale: Bool

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                if refreshing {
                    ProgressView().controlSize(.mini).transition(.scale.combined(with: .opacity))
                } else {
                    BoardLiveDot(color: stale ? Theme.warn : Theme.ok, size: 7, pulsing: !stale).transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 14, height: 14)
            if let updated {
                // Tor ekranda (375 pt, katta shrift) — faqat vaqt
                ViewThatFits(in: .horizontal) {
                    Text("\(tr("Yangilandi", "Обновлено", "Updated")) \(BoardTime.time(updated))")
                    Text(BoardTime.time(updated))
                }
                .font(Theme.Font.caption.monospacedDigit())
                .foregroundStyle(stale ? Theme.warn : Theme.muted)
                .contentTransition(.numericText())
                .lineLimit(1)
            }
        }
        .animation(Motion.snappy, value: refreshing)
        .animation(Motion.gentle, value: updated)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(updated.map { "\(tr("Yangilandi", "Обновлено", "Updated")) \(BoardTime.time($0))" } ?? tr("Yuklanmoqda", "Загрузка", "Loading"))
    }
}

/// Ogohlantirish / izoh qatori (eskirgan ma'lumot, kechagi ro'yxat …)
struct BoardNote: View {
    let text: String
    var symbol = "info.circle"
    var tint: Color = Theme.teal
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).font(.subheadline.weight(.semibold)).foregroundStyle(tint)
            Text(text).font(Theme.Font.sub).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Tablo yuklanayotganda — qator qoliplari
struct BoardSkeleton: View {
    var rows = 8
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 6).fill(Theme.paper3).frame(width: 58, height: 22)
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(Theme.paper3).frame(width: 150, height: 14)
                        Capsule().fill(Theme.paper3).frame(width: 110, height: 10)
                        Capsule().fill(Theme.paper3).frame(width: 84, height: 18)
                    }
                    Spacer()
                }
                .padding(.vertical, 14)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.line.opacity(0.5)).frame(height: 0.5) }
            }
        }
        .overlay(Shimmer())
        .padding(.horizontal, Theme.gutter)
        .accessibilityLabel(tr("Yuklanmoqda", "Загрузка", "Loading"))
    }
}
