// Animatsiya va sezgi: bir xil prujinalar, bosilganda kichrayish, paydo bo'lish, aylantirganda yumshoq o'zgarish, haptik.
// Ishlatish: Button { } label: { … }.buttonStyle(.press) ; view.appear(delay: 0.05 * Double(i)) ; view.scrollFade()
import SwiftUI
import UIKit

enum Motion {
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.82)
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.86)
    static let gentle = Animation.easeOut(duration: 0.45)
}

@MainActor
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7) }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

/// Bosilganda biroz kichrayadi (kartalar, plitkalar)
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}
extension ButtonStyle where Self == PressStyle {
    static var press: PressStyle { PressStyle() }
}

private struct AppearModifier: ViewModifier {
    let delay: Double
    let offset: CGFloat
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduce
    func body(content: Content) -> some View {
        content
            .opacity(shown || reduce ? 1 : 0)
            .offset(y: shown || reduce ? 0 : offset)
            .onAppear { withAnimation(Motion.spring.delay(min(delay, 0.5))) { shown = true } }
    }
}

extension View {
    /// Birinchi ko'ringanda pastdan yumshoq chiqish (ro'yxatlarda delay = 0.04 * index)
    func appear(delay: Double = 0, offset: CGFloat = 14) -> some View { modifier(AppearModifier(delay: delay, offset: offset)) }

    /// ScrollView ichida: chetga yaqinlashganda biroz xiralashadi va kichrayadi
    func scrollFade() -> some View {
        scrollTransition(.interactive, axis: .vertical) { c, phase in
            c.opacity(phase.isIdentity ? 1 : 0.6).scaleEffect(phase.isIdentity ? 1 : 0.96)
        }
    }
    /// Gorizontal karuselda: chetdagi kartalar kichrayadi
    func carouselEffect() -> some View {
        scrollTransition(.interactive, axis: .horizontal) { c, phase in
            c.scaleEffect(phase.isIdentity ? 1 : 0.93).opacity(phase.isIdentity ? 1 : 0.8)
        }
    }

    /// iOS 18+: kartadan tafsilotga «zoom» o'tish (manba: .zoomSource(id, ns), maqsad: .zoomDestination(id, ns))
    @ViewBuilder func zoomSource(_ id: String, in ns: Namespace.ID?) -> some View {
        if #available(iOS 18.0, *), let ns { matchedTransitionSource(id: id, in: ns) } else { self }
    }
    @ViewBuilder func zoomDestination(_ id: String, in ns: Namespace.ID?) -> some View {
        if #available(iOS 18.0, *), let ns { navigationTransition(.zoom(sourceID: id, in: ns)) } else { self }
    }
}

/// Zoom o'tish uchun umumiy namespace (har tabning NavigationStack'i o'rnatadi)
private struct ZoomNSKey: EnvironmentKey { static let defaultValue: Namespace.ID? = nil }
extension EnvironmentValues {
    var zoomNS: Namespace.ID? {
        get { self[ZoomNSKey.self] }
        set { self[ZoomNSKey.self] = newValue }
    }
}
