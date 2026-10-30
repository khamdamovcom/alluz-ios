// VAQTINCHA QOLIP — egasi (agent) to'liq ekran bilan almashtiradi.
import SwiftUI

struct ItemDetailView: View {
    let ref: ItemRef
    var body: some View { Text("ItemDetailView").navigationTitle("ItemDetailView") }
}

struct GalleryScreen: View {
    let images: [Img]
    let index: Int
    var body: some View { Text("GalleryScreen").navigationTitle("GalleryScreen") }
}

