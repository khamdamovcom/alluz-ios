// MKMapView (UIKit) — ~1300 nuqta uchun tez va silliq: MKClusterAnnotation bilan klasterlash, qayta ishlatiladigan marker ko'rinishlari,
// sokin («muted») xarita stili va tizim POI'larisiz (faqat bizning nuqtalarimiz). Kunduzgi/tungi rejim — tizimniki (trait).
import SwiftUI
import MapKit

struct MapKitView: UIViewRepresentable {
    let model: MapScreenModel
    /// Quyidagilar o'zgarsa SwiftUI updateUIView ni chaqiradi
    let version: Int
    let command: MapCommand?
    let showsUser: Bool
    /// Pastki karta balandligi (markazlashda nuqta karta ostida qolmasin)
    let bottomInset: CGFloat

    func makeCoordinator() -> MapKitCoordinator { MapKitCoordinator(model: model) }

    func makeUIView(context: Context) -> MKMapView {
        let m = MapKitHostView()
        let cfg = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        cfg.pointOfInterestFilter = .excludingAll
        m.preferredConfiguration = cfg
        m.isRotateEnabled = false
        m.isPitchEnabled = false
        m.showsCompass = false
        m.showsScale = false
        m.register(MapPointMarkerView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        m.register(MapClusterMarkerView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        m.delegate = context.coordinator
        m.accessibilityLabel = tr("Oʻzbekiston xaritasi", "Карта Узбекистана", "Map of Uzbekistan")
        return m
    }

    func updateUIView(_ m: MKMapView, context: Context) {
        let c = context.coordinator
        c.bottomInset = bottomInset
        // Tungi/kunduzgi mavzu ilova ichida tanlanadi — xarita plitkalari ham shunga ergashsin
        let style: UIUserInterfaceStyle = context.environment.colorScheme == .dark ? .dark : .light
        if m.overrideUserInterfaceStyle != style { m.overrideUserInterfaceStyle = style }
        if m.showsUserLocation != showsUser { m.showsUserLocation = showsUser }
        if c.appliedVersion != version {
            c.appliedVersion = version
            c.apply(model.visible, to: m)
        }
        if let command, command.id != c.appliedCommand {
            c.appliedCommand = command.id
            c.run(command, on: m)
        }
    }
}

@MainActor
final class MapKitCoordinator: NSObject, MKMapViewDelegate {
    let model: MapScreenModel
    var appliedVersion = -1
    var appliedCommand: UUID?
    var bottomInset: CGFloat = 0
    private var shown = Set<ObjectIdentifier>()
    /// Dastur o'zi tanlaganda/bekor qilganda delegat modelga qayta yozmasin
    private var programmatic = false

    init(model: MapScreenModel) { self.model = model }

    /// Faqat farqni qo'shish/olib tashlash (hammasini qayta chizmaslik)
    func apply(_ anns: [MapPointAnnotation], to m: MKMapView) {
        let want = Set(anns.map(ObjectIdentifier.init))
        let current = m.annotations.compactMap { $0 as? MapPointAnnotation }
        let remove = current.filter { !want.contains(ObjectIdentifier($0)) }
        let add = anns.filter { !shown.contains(ObjectIdentifier($0)) }
        if !remove.isEmpty { m.removeAnnotations(remove) }
        if !add.isEmpty { m.addAnnotations(add) }
        shown = want
    }

    func run(_ cmd: MapCommand, on m: MKMapView) {
        let pad = UIEdgeInsets(top: 150, left: 40, bottom: max(120, bottomInset + 60), right: 40)
        switch cmd.kind {
        case .focus(let a):
            if !shown.contains(ObjectIdentifier(a)) { m.addAnnotation(a); shown.insert(ObjectIdentifier(a)) }
            let size = MKMapSize(width: 9000 * MKMapPointsPerMeterAtLatitude(a.coordinate.latitude), height: 9000 * MKMapPointsPerMeterAtLatitude(a.coordinate.latitude))
            let p = MKMapPoint(a.coordinate)
            let rect = MKMapRect(origin: MKMapPoint(x: p.x - size.width / 2, y: p.y - size.height / 2), size: size)
            m.setVisibleMapRect(rect, edgePadding: pad, animated: true)
            // Klasterdan ajralib chiqqanidan keyin tanlanadi
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self, weak m] in
                guard let self, let m else { return }
                self.programmatic = true
                m.selectAnnotation(a, animated: true)
                self.programmatic = false
            }
        case .deselect:
            programmatic = true
            m.selectedAnnotations.forEach { m.deselectAnnotation($0, animated: true) }
            programmatic = false
        case .home:
            m.setVisibleMapRect(MapGeo.uzbekistan, edgePadding: MapGeo.homePadding, animated: true)
        case .user:
            if let loc = m.userLocation.location, CLLocationCoordinate2DIsValid(loc.coordinate) {
                m.setRegion(MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 4000, longitudinalMeters: 4000), animated: true)
            } else {
                m.setUserTrackingMode(.follow, animated: true)
            }
        }
    }

    // MARK: delegat
    func mapView(_ m: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }     // tizim nuqtasi
        if annotation is MKClusterAnnotation {
            return m.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier, for: annotation)
        }
        return m.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier, for: annotation)
    }

    func mapView(_ m: MKMapView, didSelect view: MKAnnotationView) {
        if let cluster = view.annotation as? MKClusterAnnotation {
            Haptics.tap()
            m.deselectAnnotation(cluster, animated: false)
            m.showAnnotations(cluster.memberAnnotations, animated: true)
            return
        }
        guard !programmatic, let a = view.annotation as? MapPointAnnotation else { return }
        model.select(a)
    }

    func mapView(_ m: MKMapView, didDeselect view: MKAnnotationView) {
        guard !programmatic, let a = view.annotation as? MapPointAnnotation else { return }
        // Boshqa nuqta tanlanganda avval «deselect» keladi — keyingi tanlov uchun qisqa kutish
        DispatchQueue.main.async { [weak self] in
            guard let self, m.selectedAnnotations.isEmpty, self.model.selected === a else { return }
            self.model.select(nil)
        }
    }

    func mapView(_ m: MKMapView, regionDidChangeAnimated animated: Bool) {
        model.center = m.centerCoordinate
    }

    func mapView(_ m: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard let loc = userLocation.location, loc.horizontalAccuracy >= 0 else { return }
        if let old = model.userLocation, old.distance(from: loc) < 50 { return }   // keraksiz qayta chizishsiz
        model.userLocation = loc
    }
}

/// Boshlang'ich ko'rinish (butun O'zbekiston) — o'lchami ma'lum bo'lgach bir marta
final class MapKitHostView: MKMapView {
    private var fitted = false
    override func layoutSubviews() {
        super.layoutSubviews()
        guard !fitted, bounds.width > 0, bounds.height > 0 else { return }
        fitted = true
        setVisibleMapRect(MapGeo.uzbekistan, edgePadding: MapGeo.homePadding, animated: false)
    }
}

// MARK: - Marker ko'rinishlari
final class MapPointMarkerView: MKMarkerAnnotationView {
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "alluz"
        collisionMode = .circle
        subtitleVisibility = .hidden
        animatesWhenAdded = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        clusteringIdentifier = "alluz"
        guard let a = annotation as? MapPointAnnotation else { return }
        markerTintColor = a.category.uiColor
        glyphImage = UIImage(systemName: a.glyph)
        glyphTintColor = .white
        // Muhim joylar zich hududda ham ko'rinib tursin
        displayPriority = a.point.rating >= 5 ? .defaultHigh : a.point.rating >= 4 ? MKFeatureDisplayPriority(rawValue: 600) : .defaultLow
        titleVisibility = .adaptive
        isAccessibilityElement = true
        accessibilityLabel = "\(a.point.name), \(a.typeLabel)"
        accessibilityTraits = .button
    }
}

final class MapClusterMarkerView: MKMarkerAnnotationView {
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .circle
        displayPriority = .defaultHigh
        titleVisibility = .hidden
        subtitleVisibility = .hidden
    }
    required init?(coder: NSCoder) { fatalError() }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        guard let c = annotation as? MKClusterAnnotation else { return }
        let members = c.memberAnnotations.compactMap { $0 as? MapPointAnnotation }
        // Klaster rangi — undagi eng ko'p turkum
        var tally: [MapCategory: Int] = [:]
        for m in members { tally[m.category, default: 0] += 1 }
        let top = tally.max { $0.value < $1.value }?.key ?? .place
        markerTintColor = top.uiColor
        glyphText = members.count > 999 ? "999+" : "\(c.memberAnnotations.count)"
        glyphTintColor = .white
        isAccessibilityElement = true
        accessibilityLabel = tr("\(c.memberAnnotations.count) ta nuqta — yaqinlashtirish", "Точек: \(c.memberAnnotations.count) — приблизить",
                                "\(c.memberAnnotations.count) places — zoom in")
        accessibilityTraits = .button
    }
}
