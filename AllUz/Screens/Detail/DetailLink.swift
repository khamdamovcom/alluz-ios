// Serverdan kelgan havola/telefon/email'ni xavfsiz URL'ga aylantirish. Faqat https/http (Safari oynasi), tel:, mailto:, maps:.
// javascript:, data:, file: va boshqa sxemalar — hech qachon. Ochish faqat model.openURL / model.openWeb orqali.
import Foundation

enum DetailLink {
    /// https/http havola (host majburiy, login/parol bo'lmasin)
    static func web(_ raw: String?) -> URL? {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty, s.count < 2000 else { return nil }
        if s.hasPrefix("//") { s = "https:" + s }
        if !s.contains("://") {
            // "example.uz/path" — sxemasiz domen
            guard s.range(of: #"^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+(/.*)?$"#, options: .regularExpression) != nil else { return nil }
            s = "https://" + s
        }
        guard let u = URL(string: s), let scheme = u.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = u.host, !host.isEmpty, u.user == nil, u.password == nil else { return nil }
        return u
    }

    /// Telefon → tel: (faqat raqamlar va boshidagi +). Qisqa raqamlar (1005, 1256) ham bo'ladi.
    static func tel(_ raw: String?) -> URL? {
        guard let raw else { return nil }
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 3, digits.count <= 16 else { return nil }
        let plus = raw.trimmingCharacters(in: .whitespaces).hasPrefix("+") ? "+" : ""
        return URL(string: "tel:" + plus + digits)
    }

    static func mail(_ raw: String?) -> URL? {
        guard let s = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              s.range(of: #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil else { return nil }
        return URL(string: "mailto:" + s)
    }

    /// Telegram: "https://t.me/name", "@name" yoki "name" → https://t.me/name
    static func telegram(_ raw: String?) -> URL? {
        guard let s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        if s.contains("/") {
            guard let u = web(s), let h = u.host?.lowercased(), ["t.me", "telegram.me", "www.t.me"].contains(h) else { return nil }
            return u
        }
        let name = s.hasPrefix("@") ? String(s.dropFirst()) : s
        guard name.range(of: #"^[A-Za-z0-9_]{3,32}$"#, options: .regularExpression) != nil else { return nil }
        return URL(string: "https://t.me/" + name)
    }

    static func instagram(_ raw: String?) -> URL? {
        guard let s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        if s.contains("/") {
            guard let u = web(s), let h = u.host?.lowercased(), (h == "instagram.com" || h.hasSuffix(".instagram.com")) else { return nil }
            return u
        }
        let name = s.hasPrefix("@") ? String(s.dropFirst()) : s
        guard name.range(of: #"^[A-Za-z0-9_.]{1,30}$"#, options: .regularExpression) != nil else { return nil }
        return URL(string: "https://www.instagram.com/" + name)
    }

    /// App Store havolasi (faqat apps.apple.com)
    static func appStore(_ raw: String?) -> URL? {
        guard let u = web(raw), u.host?.lowercased() == "apps.apple.com" else { return nil }
        return u
    }

    /// Apple Maps: yo'nalish (daddr) yoki nuqta (ll + q)
    static func directions(lat: Double, lon: Double) -> URL? {
        URL(string: "maps://?daddr=\(lat),\(lon)&dirflg=d")
    }
    static func mapPin(lat: Double, lon: Double, name: String) -> URL? {
        let q = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return URL(string: "maps://?ll=\(lat),\(lon)&q=\(q)")
    }

    /// Havola uchun qisqa yozuv: "whc.unesco.org" (www. siz)
    static func domain(_ u: URL) -> String {
        var h = u.host ?? u.absoluteString
        if h.hasPrefix("www.") { h.removeFirst(4) }
        return h
    }
    /// Telefon raqamini chiroyli ko'rsatish (serverdagi ko'rinish saqlanadi, faqat ortiqcha bo'shliqlar olinadi)
    static func phoneText(_ s: String) -> String {
        s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
