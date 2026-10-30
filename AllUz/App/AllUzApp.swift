// Kirish nuqtasi: 5 tab (har birida NavigationStack + Route), tashqi havola oynasi, xabarlar, deep link, til va mavzu.
// Skrinshot/sinov rejimi: -shot <spec> (ShotMode.swift).
import SwiftUI
import SafariServices

@main
struct AllUzApp: App {
    @State private var model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .id(model.reloadToken)                       // til almashsa — hammasi yangidan
                .preferredColorScheme(model.theme.scheme)
                .tint(Theme.accent)
                .onOpenURL { model.handleDeepLink($0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { a in if let u = a.webpageURL { model.handleDeepLink(u) } }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var zoom

    var body: some View {
        @Bindable var model = model
        TabView(selection: tabBinding) {
            ForEach(Tab.allCases, id: \.self) { tab in
                NavigationStack(path: pathBinding(tab)) {
                    root(tab)
                        .navigationDestination(for: Route.self) { $0.destination.zoomDestination(zoomID($0), in: zoom) }
                }
                .environment(\.zoomNS, zoom)
                .tabItem { Label(tab.title, systemImage: tab.symbol) }
                .tag(tab)
            }
        }
        .minimizingTabBar()
        .overlay(alignment: .bottom) {
            if let t = model.toast { ToastView(text: t).padding(.bottom, 96).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .sheet(item: $model.webURL) { SafariView(url: $0.url).ignoresSafeArea() }
        .fullScreenCover(isPresented: Binding(get: { (!model.onboarded && !ShotMode.active) || ShotMode.spec == "onboarding" }, set: { if !$0 { model.onboarded = true } })) {
            OnboardingView()
        }
        .task {
            await model.loadConfig()
            if let s = ShotMode.spec { ShotMode.apply(s, model: model) }
        }
    }

    @ViewBuilder private func root(_ tab: Tab) -> some View {
        switch tab {
        case .home: HomeView()
        case .explore: ExploreView()
        case .map: MapScreen()
        case .board: BoardScreen(iata: nil)
        case .more: MoreView()
        }
    }

    /// Tab qayta bosilsa — boshiga qaytadi
    private var tabBinding: Binding<Tab> {
        Binding(get: { model.tab }, set: { new in
            if new == model.tab { model.popToRoot(new) } else { Haptics.select() }
            model.tab = new
        })
    }
    private func pathBinding(_ tab: Tab) -> Binding<[Route]> {
        Binding(get: { model.paths[tab] ?? [] }, set: { model.paths[tab] = $0 })
    }
    private func zoomID(_ r: Route) -> String {
        if case .item(let ref) = r { return ref.key }
        return "-"
    }
}

/// Tashqi sayt — ilova ichidagi Safari oynasi (cookie va ma'lumot ilovaga o'tmaydi)
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let c = SFSafariViewController.Configuration()
        c.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: c)
        vc.preferredControlTintColor = UIColor(Theme.accent)
        vc.dismissButtonStyle = .close
        return vc
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
