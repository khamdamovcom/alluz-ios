// 14 hudud: katta rasmli kartalar (nom, shior, qisqa tavsif). Bitta so'rov — list/region. Bosilsa → .item(region).
import SwiftUI

struct RegionsScreen: View {
    var body: some View {
        Loadable(load: {
            let page: ListPage = try await API.shared.get("list/region", query: ["limit": "20"])
            await MainActor.run { ExRegionStore.shared.set(page.items) }
            return page.items
        }) { regions in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ExIntro(kicker: tr("Oʻzbekiston", "Узбекистан", "Uzbekistan"),
                            title: tr("\(regions.count) ta hudud", "\(regions.count) \(ExTypes.ruPlural(regions.count, ["регион", "региона", "регионов"]))", "\(regions.count) regions"),
                            text: tr("12 viloyat, Qoraqalpogʻiston Respublikasi va poytaxt Toshkent — har birining oʻz tarixi, taomlari va manzaralari bor.",
                                     "12 областей, Республика Каракалпакстан и столица Ташкент — у каждого региона своя история, кухня и пейзажи.",
                                     "Twelve provinces, the Republic of Karakalpakstan and the capital, Tashkent — each with its own history, food and landscapes."))
                        .padding(.bottom, 4)
                        .appear()
                    ForEach(Array(regions.enumerated()), id: \.element.id) { i, r in
                        ExRegionCard(card: r, index: i + 1)
                            .padding(.horizontal, Theme.gutter)
                            .scrollFade()
                            .appear(delay: 0.04 * Double(min(i, 4)))
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle(tr("Hududlar", "Регионы", "Regions"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Katta hudud kartasi: rasm (ustida tartib raqami va nom), ostida shior va qisqa tavsif
private struct ExRegionCard: View {
    let card: Card
    let index: Int
    @Environment(AppModel.self) private var model
    @Environment(\.zoomNS) private var ns

    var body: some View {
        Button { model.open(card) } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    RemoteImage(img: card.img, region: card.slug, icon: card.icon)
                    LinearGradient(colors: [.black.opacity(0.25), .clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading) {
                        Text(String(format: "%02d", index))
                            .font(Theme.Font.mono).foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .glassBackground(Capsule(), fallback: .ultraThinMaterial)
                        Spacer(minLength: 0)
                        Text(card.name).font(Theme.Font.display(28)).foregroundStyle(.white)
                            .lineLimit(2).minimumScaleFactor(0.75)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                .frame(height: 210)
                .clipped()
                .zoomSource(card.id, in: ns)

                HStack(alignment: .top, spacing: 12) {
                    Capsule().fill(Theme.hue(card.slug)).frame(width: 4)
                    VStack(alignment: .leading, spacing: 6) {
                        if let k = card.kicker, !k.isEmpty {
                            Text(k).font(Theme.Font.title3).foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        }
                        if let s = card.summary, !s.isEmpty {
                            Text(s).font(Theme.Font.sub).foregroundStyle(Theme.ink2).lineLimit(3)
                                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 4) {
                            Text(tr("Hududni ochish", "Открыть регион", "Explore region"))
                            Image(systemName: "arrow.right")
                        }
                        .font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.accent)
                        .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.l))
        }
        .buttonStyle(.press)
        .contextMenu { CardMenu(card: card) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([card.name, card.kicker, card.summary].compactMap { $0 }.joined(separator: ". "))
        .accessibilityAddTraits(.isButton)
    }
}
