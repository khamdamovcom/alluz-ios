// Kirish nuqtasi: RootGate (kill switch / majburiy yangilash / oddiy ilova) → RootView: server menyusidagi tablar (har birida
// NavigationStack + Route), tashqi havola oynasi, xabarlar, deep link, til va mavzu. Config: ishga tushganda, faollashganda, har 60 s.
// Skrinshot/sinov rejimi: -shot <spec> (ShotMode.swift).
import SwiftUI
import SafariServices

@main
struct AllUzApp: App {
    @State private var model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            RootGate()
                .environment(model)
                .id(model.reloadToken)                       // til almashsa — hammasi yangidan
                .preferredColorScheme(model.theme.scheme)
                .tint(Theme.accent)
                .onOpenURL { model.handleDeepLink($0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { a in if let u = a.webpageURL { model.handleDeepLink(u) } }
        }
    }
}

/// Ilova darvozasi: yopiq (kill switch) → faqat xabar; build juda eski → faqat «Yangilash»; aks holda — tablar.
/// Config shu yerda yangilanadi: ilova faollashganda (scenePhase → .active) va faol turganda har 60 s.
struct RootGate: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var shotApplied = false

    var body: some View {
        @Bindable var model = model
        ZStack {
            if model.isClosed {
                AppClosedView().transition(.opacity)
            } else if model.updateRequired {
                AppUpdateRequiredView().transition(.opacity)
            } else {
                RootView().transition(.opacity)
            }
        }
        .animation(Motion.gentle, value: model.isClosed)
        .animation(Motion.gentle, value: model.updateRequired)
        .overlay(alignment: .bottom) {
            if let t = model.toast { ToastView(text: t).padding(.bottom, 96).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .sheet(item: $model.webURL) { SafariView(url: $0.url).ignoresSafeArea() }
        .task(id: scenePhase == .active) {
            guard scenePhase == .active else { return }
            await model.refreshConfig(minInterval: 5)
            if !shotApplied, let s = ShotMode.spec { shotApplied = true; ShotMode.apply(s, model: model) }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                if Task.isCancelled { break }
                await model.refreshConfig(minInterval: 50)
            }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var zoom

    var body: some View {
        TabView(selection: tabBinding) {
            ForEach(model.menu.tabs) { item in
                let tab = item.tab
                NavigationStack(path: pathBinding(tab)) {
                    root(tab)
                        .navigationDestination(for: Route.self) { $0.destination.zoomDestination(zoomID($0), in: zoom) }
                }
                .environment(\.zoomNS, zoom)
                .tabItem { Label(item.title, systemImage: item.symbol) }
                .tag(tab)
            }
        }
        .minimizingTabBar()
        .overlay(alignment: .bottom) {
            if model.showUpdateBanner {
                AppUpdateBanner().padding(.horizontal, Theme.gutter).padding(.bottom, 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: Binding(get: { (!model.onboarded && !ShotMode.active) || ShotMode.spec == "onboarding" }, set: { if !$0 { model.onboarded = true } })) {
            OnboardingView()
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
            guard model.menu.visibleTabs.contains(new) else { return }
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
