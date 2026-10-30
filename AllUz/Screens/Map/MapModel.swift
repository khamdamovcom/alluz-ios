// Xarita holati: nuqtalar (API `map?types=place,venue,airport,rail_station`), turkum filtrlari, tanlangan nuqta, qidiruv,
// «Yaqin atrofda», xaritaga buyruqlar (MapCommand — markazlash, butun O'zbekiston, joylashuvim). Xarita o'zi — MapKitView.swift.
import SwiftUI
import MapKit
import CoreLocation

// MARK: - Turkum (filtr chiplari, marker rangi va ikonkasi)
enum MapCategory: String, CaseIterable, Identifiable, Sendable {
    case place, stay, eat, transport
    var id: String { rawValue }

    static let stayKinds: Set<String> = ["hotel", "guesthouse", "hostel", "resort"]

    init(type: String, kind: String?) {
        switch type {
        case "venue": self = MapCategory.stayKinds.contains(kind ?? "") ? .stay : .eat
        case "airport", "rail_station", "bus_station", "metro", "train": self = .transport
        default: self = .place
        }
    }

    var title: String {
        switch self {
        case .place: tr("Joylar", "Места", "Sights")
        case .stay: tr("Mehmonxonalar", "Отели", "Hotels")
        case .eat: tr("Restoranlar", "Рестораны", "Restaurants")
        case .transport: tr("Transport", "Транспорт", "Transport")
        }
    }
    var symbol: String {
        switch self {
        case .place: "building.columns.fill"
        case .stay: "bed.double.fill"
        case .eat: "fork.knife"
        case .transport: "airplane"
        }
    }
    /// Marker rangi: joy — terrakota, mehmonxona — firuza, restoran — oltin, transport — ko'k (tizim rangi, tungi rejimga moslashadi)
    var color: Color {
        switch self {
        case .place: Theme.accent
        case .stay: Theme.teal
        case .eat: Theme.gold
        case .transport: Theme.blue
        }
    }
    var uiColor: UIColor { UIColor(color) }
}

// MARK: - Annotatsiya
final class MapPointAnnotation: NSObject, MKAnnotation {
    let point: MapPoint
    let category: MapCategory
    let coordinate: CLLocationCoordinate2D
    let title: String?
    /// Qidiruv uchun normallashtirilgan nom
    let key: String

    init(point: MapPoint) {
        self.point = point
        category = MapCategory(type: point.type, kind: point.kind)
        coordinate = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon)
        title = point.name
        key = MapText.norm(point.name)
    }

    var location: CLLocation { CLLocation(latitude: point.lat, longitude: point.lon) }

    /// Turga qarab aniqroq ikonka (joy toifasi, aeroport/vokzal)
    var glyph: String {
        switch point.type {
        case "airport": return "airplane"
        case "rail_station": return "tram.fill"
        case "venue":
            switch point.kind {
            case "cafe": return "cup.and.saucer.fill"
            case "choyxona": return "mug.fill"
            case "fastfood": return "takeoutbag.and.cup.and.straw.fill"
            case "hostel": return "bed.double"
            case "resort": return "beach.umbrella.fill"
            default: return category.symbol
            }
        default:
            switch point.kind {
            case "masjid": return "moon.stars.fill"
            case "maqbara", "ziyoratgoh": return "sparkles"
            case "minora": return "building.fill"
            case "qala", "arxeologiya": return "shield.lefthalf.filled"
            case "muzey": return "building.columns"
            case "bog": return "tree.fill"
            case "tabiat", "dam-olish": return "mountain.2.fill"
            case "bozor": return "basket.fill"
            case "madaniyat", "kongilochar": return "theatermasks.fill"
            case "zamonaviy": return "building.2.fill"
            case "ibodatxona": return "building.columns.circle.fill"
            default: return category.symbol
            }
        }
    }

    /// Turning qisqa nomi (karta ostida)
    var typeLabel: String {
        switch point.type {
        case "airport": tr("Aeroport", "Аэропорт", "Airport")
        case "rail_station": tr("Vokzal", "Вокзал", "Railway station")
        case "venue": category == .stay ? tr("Mehmonxona", "Отель", "Hotel") : tr("Restoran va kafe", "Ресторан и кафе", "Restaurant & café")
        default: tr("Diqqatga sazovor joy", "Достопримечательность", "Sight")
        }
    }
}

enum MapText {
    /// Katta-kichik harf, diakritika va tutuq belgilarisiz (ʻ ' ’ `): «Gʻijduvon» = «gijduvon»
    static func norm(_ s: String) -> String {
        let f = s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        return String(f.unicodeScalars.filter { !"ʻʼ'’‘`´".unicodeScalars.contains($0) }.map(Character.init))
    }
}

/// Xaritaga bir martalik buyruq (id bo'yicha bajariladi)
struct MapCommand: Equatable {
    enum Kind { case focus(MapPointAnnotation), deselect, home, user }
    let id = UUID()
    let kind: Kind
    static func == (a: MapCommand, b: MapCommand) -> Bool { a.id == b.id }
}

enum MapGeo {
    /// O'zbekiston chegarasi (taxminan): 37.1–45.6 sh.k., 55.9–73.2 sh.u.
    static let uzbekistan: MKMapRect = {
        let a = MKMapPoint(CLLocationCoordinate2D(latitude: 45.6, longitude: 55.9))
        let b = MKMapPoint(CLLocationCoordinate2D(latitude: 37.1, longitude: 73.2))
        return MKMapRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }()
    static let center = CLLocationCoordinate2D(latitude: 41.3, longitude: 64.6)
    /// Tepada qidiruv+chiplar, pastda tab bar
    static let homePadding = UIEdgeInsets(top: 130, left: 12, bottom: 70, right: 12)
}

// MARK: - Model
@MainActor @Observable
final class MapScreenModel {
    enum Phase: Equatable { case loading, ready, failed(String) }

    private(set) var all: [MapPointAnnotation] = []
    private(set) var visible: [MapPointAnnotation] = []
    /// Ko'rinadigan to'plam o'zgarganda oshadi (xarita faqat shunda annotatsiyalarni yangilaydi)
    private(set) var version = 0
    private(set) var counts: [MapCategory: Int] = [:]
    var enabled: Set<MapCategory> = Set(MapCategory.allCases) { didSet { if enabled != oldValue { refilter() } } }
    var selected: MapPointAnnotation?
    var command: MapCommand?
    var phase: Phase = .loading
    /// Foydalanuvchi joylashuvi (faqat telefonda; serverga yuborilmaydi)
    var userLocation: CLLocation?
    var showsUser = false
    /// Yuklangan kartalar (rasm, «Tur · Hudud») — tanlanganda
    private(set) var cards: [String: Card] = [:]
    @ObservationIgnored var center = MapGeo.center
    @ObservationIgnored private var loadedOnce = false

    func load(focus: ItemRef?) async {
        if loadedOnce { return }
        phase = .loading
        do {
            let data: MapData = try await API.shared.get("map", query: ["types": "place,venue,airport,rail_station"])
            let pts = await Task.detached(priority: .userInitiated) { data.parsed }.value
            let anns = pts.map(MapPointAnnotation.init(point:))
            all = anns
            counts = Dictionary(grouping: anns, by: \.category).mapValues(\.count)
            refilter()
            loadedOnce = true
            withAnimation(Motion.gentle) { phase = .ready }
            if let focus { await focusOn(focus) }
        } catch is CancellationError {
        } catch {
            withAnimation(Motion.gentle) { phase = .failed(error.localizedDescription) }
        }
    }

    private func refilter() {
        visible = all.filter { enabled.contains($0.category) }
        version += 1
        if let s = selected, !enabled.contains(s.category) { selected = nil }
    }

    func toggle(_ c: MapCategory) {
        Haptics.select()
        if enabled.contains(c) { enabled.remove(c) } else { enabled.insert(c) }
    }

    /// Nuqtani tanlash va xaritada markazlash (filtrda o'chiq bo'lsa — yoqiladi)
    func focus(_ a: MapPointAnnotation) {
        if !enabled.contains(a.category) { enabled.insert(a.category) }
        withAnimation(Motion.spring) { selected = a }
        command = MapCommand(kind: .focus(a))
        Task { await loadCard(a) }
    }

    /// Xaritada bosilganda (xaritaning o'zi markazlamaydi)
    func select(_ a: MapPointAnnotation?) {
        guard a !== selected else { return }
        if a != nil { Haptics.soft() }
        withAnimation(Motion.spring) { selected = a }
        if let a { Task { await loadCard(a) } }
    }

    func closeCard() {
        withAnimation(Motion.spring) { selected = nil }
        command = MapCommand(kind: .deselect)
    }

    func home() { Haptics.tap(); command = MapCommand(kind: .home) }

    func showUser() { showsUser = true; command = MapCommand(kind: .user) }

    /// `focus` — tashqaridan berilgan yozuv: xarita nuqtalari orasida bo'lmasa, yozuvni yuklab koordinatasidan qo'shiladi
    private func focusOn(_ ref: ItemRef) async {
        if let a = all.first(where: { $0.point.ref == ref }) { focus(a); return }
        guard let item: Item = try? await API.shared.get("item/\(ref.type)/\(ref.slug)"), let lat = item.lat, let lon = item.lon else { return }
        let p = MapPoint(type: item.type, slug: item.slug, lat: lat, lon: lon, name: item.name, kind: item.kind, region: item.region,
                         hasImg: item.img != nil, rating: item.rating ?? 0)
        let a = MapPointAnnotation(point: p)
        cards[p.id] = item.card
        all.append(a)
        counts[a.category, default: 0] += 1
        refilter()
        focus(a)
    }

    func loadCard(_ a: MapPointAnnotation) async {
        let id = a.point.id
        guard cards[id] == nil else { return }
        if let item: Item = try? await API.shared.get("item/\(a.point.type)/\(a.point.slug)") {
            withAnimation(Motion.gentle) { cards[id] = item.card }
        }
    }
    func card(_ a: MapPointAnnotation) -> Card? { cards[a.point.id] }

    /// Nom bo'yicha lokal qidiruv: avval boshidan mos kelganlar, keyin reyting
    func search(_ q: String, limit: Int = 30) -> [MapPointAnnotation] {
        let k = MapText.norm(q.trimmingCharacters(in: .whitespacesAndNewlines))
        guard k.count >= 2 else { return [] }
        let hits = all.filter { $0.key.contains(k) }
        return hits.sorted { a, b in
            let pa = a.key.hasPrefix(k), pb = b.key.hasPrefix(k)
            if pa != pb { return pa }
            if a.point.rating != b.point.rating { return a.point.rating > b.point.rating }
            return a.point.name < b.point.name
        }
        .prefix(limit).map { $0 }
    }

    /// Eng yaqin 20 ta (ko'rinadigan turkumlardan), metrda
    func nearby(from origin: CLLocation, limit: Int = 20) -> [(MapPointAnnotation, Double)] {
        visible.map { ($0, $0.location.distance(from: origin)) }.sorted { $0.1 < $1.1 }.prefix(limit).map { $0 }
    }

    func distance(to a: MapPointAnnotation) -> Double? { userLocation.map { a.location.distance(from: $0) } }
}
