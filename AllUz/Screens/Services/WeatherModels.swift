// Ob-havo: API modellari (/api/app/v1/weather, /weather/:id — docs/API.md «Ob-havo») va yordamchilar (ikonka, rang, format).
// Hamma maydon ixtiyoriy darajada yumshoq: nuqtada ma'lumot hali bo'lmasa ham ekran buziladi emas.
import SwiftUI

// MARK: - Umumiy
struct WeatherSource: Decodable, Hashable, Sendable {
    let name: String
    let url: String?
    let license: String?
    let text: String?
    let note: String?
}

/// Ro'yxat uchun qisqa holat (nuqta: shahar, dam olish maskani)
struct WeatherBrief: Decodable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let kind: String?
    let kindLabel: String?
    let alt: Double?
    let ok: Bool?
    let t: Double?
    let sym: String?
    let icon: String?
    let text: String?
    let night: Bool?
    let hi: Double?
    let lo: Double?
    let w: Double?
    let h: Double?
}

struct WeatherRegion: Decodable, Hashable, Identifiable, Sendable {
    let slug: String
    let name: String
    let main: String?
    let points: [WeatherBrief]
    let cats: [String]?
    let tmax: [Double]?
    let best: String?
    var id: String { slug }
    var mainPoint: WeatherBrief? { points.first { $0.id == main } ?? points.first }
}

struct WeatherIndex: Decodable, Sendable {
    let updated: Double?
    let month: Int?
    let monthLabels: [String]?
    let catLabels: [String: String]?
    let source: WeatherSource?
    let regions: [WeatherRegion]
}

// MARK: - Tafsil
struct WeatherNow: Decodable, Hashable, Sendable {
    let time: Double?
    let t: Double?
    let feels: Double?
    let icon: String?
    let text: String?
    let night: Bool?
    let w: Double?
    let wd: Double?
    let h: Double?
    let c: Double?
    let p: Double?
    let hi: Double?
    let lo: Double?
    let pr: Double?
}

struct WeatherHour: Decodable, Hashable, Sendable {
    let time: Double
    let label: String?
    let t: Double?
    let icon: String?
    let text: String?
    let night: Bool?
    let pr: Double?
    let w: Double?
}

struct WeatherDay: Decodable, Hashable, Identifiable, Sendable {
    let d: String
    let label: String?
    let short: String?
    let date: String?
    let hi: Double?
    let lo: Double?
    let pr: Double?
    let w: Double?
    let icon: String?
    let text: String?
    var id: String { d }
}

struct WeatherPoint: Decodable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let kind: String?
    let kindLabel: String?
    let alt: Double?
    let ok: Bool?
    let at: Double?
    let stale: Bool?
    let now: WeatherNow?
    let hours: [WeatherHour]?
    let days: [WeatherDay]?
}

struct WeatherMonth: Decodable, Hashable, Identifiable, Sendable {
    let m: Int
    let label: String
    let name: String?
    let tmax: Double?
    let tmin: Double?
    let tmean: Double?
    let precip: Double?
    let pdays: Double?
    let sun: Double?
    let cat: String?
    var id: Int { m }
}

struct WeatherTip: Decodable, Hashable, Identifiable, Sendable {
    let season: String
    let title: String
    let months: String?
    let text: String
    var id: String { season }
}

struct WeatherClimate: Decodable, Hashable, Sendable {
    struct Station: Decodable, Hashable, Sendable { let name: String; let alt: Double?; let text: String? }
    struct Comfort: Decodable, Hashable, Sendable { let min: Double; let max: Double }
    struct Source: Decodable, Hashable, Sendable { let name: String; let url: String?; let period: String? }
    struct Mountain: Decodable, Hashable, Sendable { let name: String; let alt: Double?; let months: [WeatherMonth]?; let best: String?; let text: String? }
    let station: Station?
    let months: [WeatherMonth]
    let best: [String]?
    let editorial: String?
    let tips: [WeatherTip]?
    let comfort: Comfort?
    let sources: [Source]?
    let mountain: Mountain?
}

struct WeatherDetail: Decodable, Sendable {
    struct Region: Decodable, Hashable, Sendable { let slug: String; let name: String; let title: String? }
    let region: Region
    let selected: String?
    let updated: Double?
    let month: Int?
    let catLabels: [String: String]?
    let points: [WeatherPoint]
    let climate: WeatherClimate?
    let source: WeatherSource?
    let web: String?
}

// MARK: - Ikonka, kayfiyat (fon), rang
enum WeatherGlyph {
    /// Sayt ikonka turi (API `icon`) → SF Symbol (multicolor bilan chiziladi)
    static func symbol(_ icon: String?) -> String {
        switch icon {
        case "sun": "sun.max.fill"
        case "moon": "moon.stars.fill"
        case "cloud-sun", "pc-day": "cloud.sun.fill"
        case "cloud-moon", "pc-night": "cloud.moon.fill"
        case "cloud": "cloud.fill"
        case "fog": "cloud.fog.fill"
        case "drizzle": "cloud.drizzle.fill"
        case "rain": "cloud.rain.fill"
        case "rain-heavy": "cloud.heavyrain.fill"
        case "sun-rain": "cloud.sun.rain.fill"
        case "moon-rain": "cloud.moon.rain.fill"
        case "sleet": "cloud.sleet.fill"
        case "snow": "cloud.snow.fill"
        case "thunder": "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }

    enum Mood { case clear, partly, cloudy, wet, snow, night }
    static func mood(_ icon: String?, night: Bool?) -> Mood {
        switch icon {
        case "moon", "cloud-moon", "pc-night": return .night
        case "sun": return night == true ? .night : .clear
        case "cloud-sun", "pc-day": return .partly
        case "drizzle", "rain", "rain-heavy", "sun-rain", "moon-rain", "thunder": return .wet
        case "snow", "sleet", "fog": return .snow
        default: return night == true ? .night : .cloudy
        }
    }
    /// Fon gradienti (yuqoridan pastga) — faqat Theme ranglaridan, kunduzgi/tungi rejimga mos
    static func sky(_ m: Mood) -> [Color] {
        switch m {
        case .clear: [Theme.gold.opacity(0.38), Theme.accent.opacity(0.10), Theme.paper]
        case .partly: [Theme.gold.opacity(0.22), Theme.teal.opacity(0.14), Theme.paper]
        case .cloudy: [Theme.muted.opacity(0.32), Theme.line.opacity(0.35), Theme.paper]
        case .wet: [Theme.teal.opacity(0.36), Theme.muted.opacity(0.18), Theme.paper]
        case .snow: [Theme.line.opacity(0.95), Theme.teal.opacity(0.10), Theme.paper]
        case .night: [Theme.ink.opacity(0.30), Theme.teal.opacity(0.22), Theme.paper]
        }
    }

    /// Harorat → rang (kunlik chiziq bar): sovuq — firuza, mo'tadil — yashil/oltin, issiq — terrakota
    static func tempColor(_ t: Double) -> Color {
        switch t {
        case ..<0: Theme.teal
        case ..<12: Theme.teal.opacity(0.7)
        case ..<20: Theme.ok
        case ..<28: Theme.gold
        case ..<34: Theme.accent
        default: Theme.bad
        }
    }

    /// Oy toifasi (iqlim) → rang
    static func catColor(_ cat: String?) -> Color {
        switch cat {
        case "best": Theme.ok
        case "okRain": Theme.ok.opacity(0.5)
        case "warm": Theme.gold
        case "hot": Theme.accent
        case "cool": Theme.teal.opacity(0.5)
        case "cold": Theme.teal
        default: Theme.line
        }
    }
    static let catOrder = ["best", "okRain", "warm", "hot", "cool", "cold"]
}

enum WeatherFmt {
    /// −3° (haqiqiy minus belgisi)
    static func deg(_ v: Double?) -> String {
        guard let v else { return "—" }
        let n = Int(v.rounded())
        return (n < 0 ? "−\(-n)" : "\(n)") + "°"
    }
    static func rounded(_ v: Double?) -> Double { (v ?? 0).rounded() }
    static func time(_ ms: Double) -> String { Fmt.time(Date(timeIntervalSince1970: ms / 1000)) }
    static func mm(_ v: Double) -> String { "\(Fmt.num(v, digits: 1)) \(tr("mm", "мм", "mm"))" }
    static func wind(_ v: Double?) -> String { "\(Fmt.num(v ?? 0, digits: 1)) \(tr("m/s", "м/с", "m/s"))" }
    /// Shamol qayerdan esadi (MET: «qayerdan», gradus) → nom
    static func windFrom(_ deg: Double?) -> String? {
        guard let deg else { return nil }
        let i = Int(((deg.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) + 22.5) / 45) % 8
        let uz = ["shimoldan", "shimoli-sharqdan", "sharqdan", "janubi-sharqdan", "janubdan", "janubi-gʻarbdan", "gʻarbdan", "shimoli-gʻarbdan"]
        let ru = ["северный", "северо-восточный", "восточный", "юго-восточный", "южный", "юго-западный", "западный", "северо-западный"]
        let en = ["from the N", "from the NE", "from the E", "from the SE", "from the S", "from the SW", "from the W", "from the NW"]
        return tr(uz[i], ru[i], en[i])
    }
    /// hPa → mm simob ustuni
    static func mmHg(_ hpa: Double) -> String { "\(Int((hpa * 0.750062).rounded())) \(tr("mm sim. ust.", "мм рт. ст.", "mmHg"))" }
    static func updated(_ ms: Double?) -> String? {
        guard let ms, ms > 0 else { return nil }
        let d = Date(timeIntervalSince1970: ms / 1000)
        let t = Calendar.current.isDateInToday(d) ? Fmt.time(d) : "\(Fmt.day(d)), \(Fmt.time(d))"
        return tr("Yangilangan: \(t)", "Обновлено: \(t)", "Updated \(t)")
    }
    static func capitalized(_ s: String?) -> String {
        guard let s, let f = s.first else { return "" }
        return f.uppercased() + s.dropFirst()
    }
}

/// Ob-havo ikonkasi (SF Symbol, multicolor)
struct WeatherIcon: View {
    let icon: String?
    var size: CGFloat = 22
    var body: some View {
        Image(systemName: WeatherGlyph.symbol(icon))
            .symbolRenderingMode(.multicolor)
            .font(.system(size: size))
            .frame(minWidth: size * 1.25, minHeight: size)
            .accessibilityHidden(true)
    }
}
