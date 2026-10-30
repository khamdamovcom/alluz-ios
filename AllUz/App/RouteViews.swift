// Route → ekran. Ekranlar Screens/<bo'lim>/ papkalarida (har bo'limning egasi alohida). Yangi ekran — avval Route'ga holat qo'shing.
import SwiftUI

extension Route {
    @MainActor @ViewBuilder var destination: some View {
        switch self {
        case .item(let ref): ItemDetailView(ref: ref)
        case .list(let spec): ListScreen(spec: spec)
        case .regions: RegionsScreen()
        case .culture: CultureHub()
        case .history: HistoryScreen()
        case .gallery(let imgs, let i): GalleryScreen(images: imgs, index: i)
        case .map(let ref): MapScreen(focus: ref)
        case .board(let iata): BoardScreen(iata: iata)
        case .railBoard(let st): RailBoardScreen(station: st)
        case .transport: TransportHub()
        case .weather(let r): WeatherScreen(region: r)
        case .currency: CurrencyScreen()
        case .visa(let c): VisaScreen(code: c)
        case .post(let r): PostScreen(region: r)
        case .gov: GovScreen()
        case .distances(let p): DistancesScreen(pair: p)
        case .search: SearchScreen()
        case .saved: SavedScreen()
        case .settings: SettingsScreen()
        case .about: AboutScreen()
        }
    }
}
