// VAQTINCHA QOLIP — egasi (agent) to'liq ekran bilan almashtiradi.
import SwiftUI

struct BoardScreen: View {
    let iata: String?
    var body: some View { Text("BoardScreen").navigationTitle("BoardScreen") }
}

struct RailBoardScreen: View {
    let station: String?
    var body: some View { Text("RailBoardScreen").navigationTitle("RailBoardScreen") }
}

struct TransportHub: View {
    var body: some View { Text("TransportHub").navigationTitle("TransportHub") }
}

