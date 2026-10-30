// VAQTINCHA QOLIP — egasi (agent) to'liq ekran bilan almashtiradi.
import SwiftUI

struct MapScreen: View {
    var focus: ItemRef? = nil
    var body: some View { Text("MapScreen").navigationTitle("MapScreen") }
}

struct DistancesScreen: View {
    let pair: String?
    var body: some View { Text("DistancesScreen").navigationTitle("DistancesScreen") }
}

