// Joylashuv: mini xarita (MapKit, interaktivligi o'chiq — bosilsa Apple Maps'da ochiladi), manzil va «Yo'nalish».
import SwiftUI
import MapKit

struct DetailLocation: View {
    let c: DetailContent
    @Environment(AppModel.self) private var model

    var body: some View {
        DetailSection(title: tr("Joylashuv", "Расположение", "Location"), symbol: "map") {
            VStack(alignment: .leading, spacing: 0) {
                if let lat = c.lat, let lon = c.lon {
                    Button {
                        Haptics.tap()
                        if let u = DetailLink.mapPin(lat: lat, lon: lon, name: c.title) { model.openURL(u) }
                    } label: {
                        DetailMiniMap(lat: lat, lon: lon, span: c.mapSpan, title: c.title, symbol: c.typeSymbol, pin: c.item.type != "region")
                            .frame(height: 190)
                            .overlay(alignment: .bottomTrailing) {
                                Label(tr("Xaritada", "На карте", "Open in Maps"), systemImage: "arrow.up.forward.app")
                                    .font(Theme.Font.caption.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .glassBackground(Capsule(), fallback: .regularMaterial)
                                    .padding(10)
                            }
                    }
                    .buttonStyle(.press)
                    .accessibilityLabel(tr("Xarita: \(c.title)", "Карта: \(c.title)", "Map: \(c.title)"))
                    .accessibilityHint(tr("Apple Xaritalarda ochish", "Открыть в Apple Картах", "Opens Apple Maps"))
                }
                if c.address != nil || (c.hasCoords && c.item.type != "region") {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.accent)
                            .frame(width: 24).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Manzil", "Адрес", "Address")).font(Theme.Font.caption).foregroundStyle(Theme.muted)
                            Text(c.address ?? [c.districtLabel, c.regionLabel].compactMap { $0 }.joined(separator: ", "))
                                .font(Theme.Font.body).foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                        Spacer(minLength: 6)
                        if let lat = c.lat, let lon = c.lon, c.item.type != "region", let u = DetailLink.directions(lat: lat, lon: lon) {
                            Button { Haptics.tap(); model.openURL(u) } label: {
                                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                    .font(.system(size: 18)).foregroundStyle(Theme.accentInk)
                                    .frame(width: 44, height: 44)
                                    .background(Theme.accent, in: Circle())
                            }
                            .buttonStyle(.press)
                            .accessibilityLabel(tr("Yoʻnalish", "Маршрут", "Directions"))
                        }
                    }
                    .padding(14)
                }
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
        }
    }
}

/// Statik ko'rinishdagi kichik xarita (barmoq bilan surilmaydi — sahifa aylantirishga xalaqit bermaydi)
struct DetailMiniMap: View {
    let lat: Double
    let lon: Double
    let span: Double
    let title: String
    let symbol: String
    var pin = true

    var body: some View {
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        Map(initialPosition: .region(MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))),
            interactionModes: []) {
            if pin {
                Marker(title, systemImage: symbol, coordinate: center).tint(Theme.accent)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
