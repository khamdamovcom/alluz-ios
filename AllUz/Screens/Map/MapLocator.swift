// Joylashuv ruxsati: faqat «Joylashuvim» bosilganda so'raladi (When In Use). Joylashuv faqat telefonda — xaritada nuqta va
// «Yaqin atrofda» masofalari uchun; serverga yuborilmaydi va saqlanmaydi. Nuqtaning o'zini MKMapView (showsUserLocation) ko'rsatadi.
import SwiftUI
import CoreLocation

@MainActor @Observable
final class MapLocator: NSObject, CLLocationManagerDelegate {
    private(set) var status: CLAuthorizationStatus = .notDetermined
    /// Ruxsat berilgach bajariladigan amal (tugma bosilgan edi)
    @ObservationIgnored private var pending: (() -> Void)?
    @ObservationIgnored private lazy var manager: CLLocationManager = {
        let m = CLLocationManager()
        m.delegate = self
        return m
    }()

    var authorized: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }
    var denied: Bool { status == .denied || status == .restricted }

    /// Ilgari ruxsat berilgan bo'lsa — so'ramasdan bilib olish (dialog chiqmaydi)
    func refresh() { status = manager.authorizationStatus }

    /// «Joylashuvim»: ruxsat bo'lsa — darhol, bo'lmasa — so'raladi; rad etilgan bo'lsa false (Sozlamalarga yo'naltirish)
    func request(then action: @escaping () -> Void) -> Bool {
        status = manager.authorizationStatus
        if authorized { action(); return true }
        if denied { return false }
        pending = action
        manager.requestWhenInUseAuthorization()
        return true
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let s = m.authorizationStatus
        Task { @MainActor in
            self.status = s
            if self.authorized, let p = self.pending { self.pending = nil; p() }
            if self.denied { self.pending = nil }
        }
    }
}
