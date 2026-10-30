// VAQTINCHA QOLIP — egasi (agent) to'liq ekran bilan almashtiradi.
import SwiftUI

struct VisaScreen: View {
    let code: String?
    var body: some View { Text("VisaScreen").navigationTitle("VisaScreen") }
}

struct PostScreen: View {
    let region: String?
    var body: some View { Text("PostScreen").navigationTitle("PostScreen") }
}

struct GovScreen: View {
    var body: some View { Text("GovScreen").navigationTitle("GovScreen") }
}

