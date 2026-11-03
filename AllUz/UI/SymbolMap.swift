// Sayt ikonkalari (Lucide nomlari, API'dagi `icon`) → SF Symbols. Noma'lumi — «mappin».
import Foundation

enum SymbolMap {
    static let map: [String: String] = [
        "landmark": "building.columns", "library": "books.vertical", "tower-control": "building", "hand-heart": "hands.sparkles",
        "castle": "building.columns.fill", "history": "clock.arrow.circlepath", "church": "building.2", "trees": "tree",
        "sparkles": "sparkles", "drama": "theatermasks", "store": "storefront", "mountain": "mountain.2", "mountain-snow": "mountain.2.fill",
        "building-2": "building.2", "map": "map", "map-pin": "mappin.and.ellipse", "bed-double": "bed.double", "hotel": "bed.double",
        "utensils": "fork.knife", "coffee": "cup.and.saucer", "soup": "takeoutbag.and.cup.and.straw", "plane": "airplane",
        "plane-takeoff": "airplane.departure", "plane-landing": "airplane.arrival", "train-front": "tram", "tram-front": "tram.fill",
        "bus": "bus", "user": "person", "users": "person.2", "calendar-days": "calendar", "calendar": "calendar", "info": "info.circle",
        "route": "point.topleft.down.to.point.bottomright.curvepath", "scroll-text": "scroll", "palette": "paintpalette",
        "credit-card": "creditcard", "mail": "envelope", "passport": "person.text.rectangle", "phone": "phone", "globe": "globe",
        "clock": "clock", "compass": "safari", "shield": "shield", "sun": "sun.max", "cloud-sun": "cloud.sun", "wind": "wind",
        "droplets": "drop", "thermometer-sun": "thermometer.sun", "moon": "moon", "car": "car", "ticket": "ticket", "scale": "scalemass",
        "book-open": "book", "camera": "camera", "briefcase": "briefcase", "smartphone": "iphone", "home": "house", "flag": "flag",
        "coins": "dollarsign.circle", "star": "star", "search": "magnifyingglass", "navigation": "location", "layers": "square.3.layers.3d",
        "door-open": "door.left.hand.open", "siren": "light.beacon.max", "file-text": "doc.text", "send": "paperplane",
        "telegram": "paperplane", "instagram": "camera.circle", "link": "link", "external-link": "arrow.up.right.square",
        "badge-check": "checkmark.seal", "baggage-claim": "suitcase.rolling", "image": "photo", "locate-fixed": "location.fill",
        "layout-grid": "square.grid.2x2", "banknote": "banknote", "milestone": "signpost.right", "bookmark": "bookmark",
        "settings": "gearshape", "train": "tram", "building": "building.2", "flag-triangle-right": "flag",
    ]
    static func symbol(_ icon: String?) -> String { map[icon ?? ""] ?? "mappin.and.ellipse" }

    /// Menyu bandlari (Bosh sahifa to'ri, «Yana» qatorlari) — to'liq (fill) ko'rinish; ro'yxatda yo'g'i — oddiy `symbol`
    static let menuMap: [String: String] = [
        "landmark": "building.columns.fill", "map": "map.fill", "plane": "airplane.departure", "cloud-sun": "cloud.sun.fill",
        "banknote": "banknote.fill", "passport": "person.text.rectangle.fill", "bed-double": "bed.double.fill", "utensils": "fork.knife",
        "map-pin": "mappin.and.ellipse", "scroll-text": "scroll.fill", "user": "person.fill", "users": "person.2.fill",
        "palette": "paintpalette.fill", "calendar": "calendar", "info": "info.circle.fill", "train-front": "tram.fill",
        "milestone": "signpost.right.fill", "mail": "envelope.fill", "building-2": "building.2.fill", "bookmark": "bookmark.fill",
        "settings": "gearshape.fill", "globe": "safari.fill", "home": "house.fill", "compass": "safari.fill",
        "layout-grid": "square.grid.2x2.fill", "search": "magnifyingglass", "bus": "bus.fill", "route": "point.topleft.down.to.point.bottomright.curvepath",
        "phone": "phone.fill", "star": "star.fill", "flag": "flag.fill", "shield": "shield.fill", "sun": "sun.max.fill",
        "camera": "camera.fill", "briefcase": "briefcase.fill", "ticket": "ticket.fill", "car": "car.fill", "book-open": "book.fill",
    ]
    static func menu(_ icon: String?) -> String { menuMap[icon ?? ""] ?? symbol(icon) }

    /// Pastki tab ikonkasi (tab bar o'zi to'ldiradi — oddiy ko'rinish); noma'lumi — tabning o'z belgisi
    static func tab(_ icon: String?, fallback: String) -> String {
        switch icon {
        case "plane": return "airplane.departure"
        case "layout-grid": return "square.grid.2x2"
        case let i? where map[i] != nil: return map[i]!
        default: return fallback
        }
    }

    /// Yozuv turi → SF Symbol (karta ikonkasi bo'lmasa)
    static func forType(_ type: String?) -> String {
        switch type {
        case "region": "map"; case "district": "building.2"; case "place": "building.columns"; case "venue": "bed.double"
        case "org": "building.2.crop.circle"; case "bank": "creditcard"; case "post": "envelope"; case "airport": "airplane"
        case "rail_station", "train": "tram"; case "bus_station", "bus_route": "bus"; case "metro", "city_transport": "tram.fill"
        case "person": "person"; case "era", "hist_event": "scroll"; case "cuisine": "fork.knife"; case "craft": "paintpalette"
        case "tradition": "person.2"; case "holiday", "fest": "calendar"; case "guide": "info.circle"; case "route": "point.topleft.down.to.point.bottomright.curvepath"
        default: "mappin.and.ellipse"
        }
    }
}
