// Til: uz / ru / en — ilova ichida almashtiriladi (Sozlamalar), standart — telefon tili (o'zbek/rus, aks holda ingliz).
// Matnlar kodda uch tilda: tr("Oʻzbekcha", "Русский", "English"). Til almashsa ildiz ko'rinish qayta chiziladi (.id(lang)).
import Foundation

enum Lang: String, CaseIterable, Identifiable, Codable, Sendable {
    case uz, ru, en
    var id: String { rawValue }
    var title: String { switch self { case .uz: "Oʻzbekcha"; case .ru: "Русский"; case .en: "English" } }
    var locale: Locale { Locale(identifier: self == .uz ? "uz_Latn_UZ" : self == .ru ? "ru_RU" : "en_US") }

    static let storeKey = "app.lang"
    /// Joriy til (UserDefaults; AppModel o'zgartiradi)
    static var current: Lang {
        if let s = UserDefaults.standard.string(forKey: storeKey), let l = Lang(rawValue: s) { return l }
        return deviceDefault
    }
    static var deviceDefault: Lang {
        let code = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
        return code == "uz" ? .uz : code == "ru" ? .ru : .en
    }
}

/// Uch tildagi matndan joriysini tanlash
func tr(_ uz: String, _ ru: String, _ en: String) -> String {
    switch Lang.current { case .uz: uz; case .ru: ru; case .en: en }
}

enum Fmt {
    /// 1 234 567
    static func num(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = " "; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }
    static func num(_ n: Double, digits: Int = 2) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = " "; f.decimalSeparator = Lang.current == .en ? "." : ","
        f.maximumFractionDigits = digits; f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }
    /// ISO sana/vaqt → Date
    static func date(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withFullDate]
        return f.date(from: s)
    }
    /// 14:05 (O'zbekiston vaqti)
    static func time(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(identifier: "Asia/Tashkent"); return f.string(from: d)
    }
    /// 30-oktabr / 30 октября / 30 October
    static func day(_ d: Date, weekday: Bool = false) -> String {
        let f = DateFormatter(); f.locale = Lang.current.locale; f.timeZone = TimeZone(identifier: "Asia/Tashkent")
        f.setLocalizedDateFormatFromTemplate(weekday ? "EEEEdMMMM" : "dMMMM")
        return f.string(from: d)
    }
    static func month(_ m: Int) -> String {
        let names: [String] = switch Lang.current {
        case .uz: ["yanvar", "fevral", "mart", "aprel", "may", "iyun", "iyul", "avgust", "sentabr", "oktabr", "noyabr", "dekabr"]
        case .ru: ["январь", "февраль", "март", "апрель", "май", "июнь", "июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"]
        case .en: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        }
        return (1...12).contains(m) ? names[m - 1] : ""
    }
    /// 90 → «1 soat 30 daq»
    static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        let hs = tr("soat", "ч", "h"), ms = tr("daq", "мин", "min")
        if h == 0 { return "\(m) \(ms)" }
        return m == 0 ? "\(h) \(hs)" : "\(h) \(hs) \(m) \(ms)"
    }
    static func km(_ km: Double) -> String { km < 10 ? "\(Fmt.num(km, digits: 1)) \(tr("km", "км", "km"))" : "\(Fmt.num(Int(km.rounded()))) \(tr("km", "км", "km"))" }
}
