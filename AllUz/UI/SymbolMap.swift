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
    ]
    static func symbol(_ icon: String?) -> String { map[icon ?? ""] ?? "mappin.and.ellipse" }

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
