// Dizayn tizimi: sayt (alluzbekistan.com) ranglari — «sayohat jurnali»: qog'oz fon, siyoh matn, terrakota urg'u, firuza va oltin.
// Kunduzgi/tungi rang avtomatik (tizim yoki Sozlamalardagi tanlov). Shriftlar — tizimniki: sarlavhalar New York (serif), matn SF.
// Qoida: ekranlarda rang qattiq yozilmaydi — faqat Theme.* ; shrift — faqat Theme.Font.* (Dynamic Type bilan o'sadi).
import SwiftUI
import UIKit

enum Theme {
    private static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
    static let paper = dyn(0xF6F1E8, 0x141311)      // asosiy fon
    static let paper2 = dyn(0xEFE7D9, 0x1C1A17)     // ikkinchi fon (bo'limlar)
    static let paper3 = dyn(0xE6DCCB, 0x26231F)
    static let card = dyn(0xFFFDF9, 0x1D1B18)       // karta foni
    static let ink = dyn(0x1C1A17, 0xF2ECE2)        // asosiy matn
    static let ink2 = dyn(0x45403A, 0xD2C9BB)
    static let muted = dyn(0x776F65, 0x9C9285)      // izoh matni
    static let line = dyn(0xDDD2C1, 0x34302A)       // chiziqlar
    static let accent = dyn(0xB2432A, 0xE2805F)     // terrakota — asosiy urg'u, tugmalar
    static let accentInk = dyn(0xFFFFFF, 0x1A0F0A)  // urg'u ustidagi matn
    static let teal = dyn(0x13696D, 0x55B8B3)       // ikkinchi urg'u
    static let gold = dyn(0xA87F32, 0xD6B46B)       // UNESCO, reyting
    static let ok = dyn(0x2E7D4F, 0x6CC58E)
    static let warn = dyn(0xB7791F, 0xE3B261)
    static let bad = dyn(0xB3261E, 0xF2877F)

    /// Hudud rangi (sayt REGION_HUE bilan bir xil) — rasmsiz kartalar foni
    static func hue(_ region: String?) -> Color {
        let h: [String: Double] = ["toshkent-shahri": 12, "toshkent": 28, "samarqand": 200, "buxoro": 38, "xorazm": 24, "qoraqalpogiston": 190,
                                   "fargona": 140, "andijon": 100, "namangan": 160, "navoiy": 45, "qashqadaryo": 18, "surxondaryo": 8,
                                   "jizzax": 60, "sirdaryo": 175]
        return Color(hue: (h[region ?? ""] ?? 30) / 360, saturation: 0.38, brightness: 0.62)
    }

    enum Radius { static let s: CGFloat = 10, m: CGFloat = 16, l: CGFloat = 22, xl: CGFloat = 30 }
    enum Space { static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 24, xxl: CGFloat = 36 }
    /// Ekran chetidan bo'shliq
    static let gutter: CGFloat = 16

    enum Font {
        static func display(_ size: CGFloat = 34) -> SwiftUI.Font { .system(size: size, weight: .bold, design: .serif) }
        static let largeTitle = SwiftUI.Font.system(.largeTitle, design: .serif).weight(.bold)
        static let title = SwiftUI.Font.system(.title2, design: .serif).weight(.bold)
        static let title3 = SwiftUI.Font.system(.title3, design: .serif).weight(.semibold)
        static let headline = SwiftUI.Font.headline
        static let body = SwiftUI.Font.body
        static let callout = SwiftUI.Font.callout
        static let sub = SwiftUI.Font.subheadline
        static let caption = SwiftUI.Font.caption
        static let kicker = SwiftUI.Font.caption.weight(.semibold)
        static let mono = SwiftUI.Font.system(.body, design: .monospaced).weight(.semibold)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// «Kicker» — sarlavha ustidagi kichik yozuv (katta harf, urg'u rangida)
struct Kicker: View {
    let text: String
    var color: Color = Theme.accent
    var body: some View {
        Text(text.uppercased()).font(Theme.Font.kicker).tracking(1.1).foregroundStyle(color).lineLimit(1)
    }
}
