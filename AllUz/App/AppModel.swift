// Ilova holati: til, mavzu, tablar va navigatsiya yo'llari, sevimlilar, oxirgi ko'rilganlar, server konfiguratsiyasi.
// Ekranlarda: @Environment(AppModel.self) private var model → model.open(.item(ref)), model.toggleSaved(card), model.isSaved(ref)
import SwiftUI
import Observation

enum ThemeChoice: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self { case .system: tr("Tizim", "Системная", "System"); case .light: tr("Kunduzgi", "Светлая", "Light"); case .dark: tr("Tungi", "Тёмная", "Dark") }
    }
    var scheme: ColorScheme? { switch self { case .system: nil; case .light: .light; case .dark: .dark } }
}

@MainActor @Observable
final class AppModel {
    static let shared = AppModel()

    // Sozlamalar
    var lang: Lang = Lang.current {
        didSet {
            UserDefaults.standard.set(lang.rawValue, forKey: Lang.storeKey)
            // Menyu nomlari tilda — shu tildagi saqlangan config darhol, yangisi RootGate'da so'raladi
            lastConfigAt = .distantPast
            config = nil
            if let c = Self.cachedConfig(lang) { applyConfig(c, fromCache: true) } else { menu = .builtIn }
            reloadToken = UUID()
        }
    }
    var theme: ThemeChoice = ThemeChoice(rawValue: UserDefaults.standard.string(forKey: "app.theme") ?? "") ?? .system {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "app.theme") }
    }
    var onboarded: Bool = UserDefaults.standard.bool(forKey: "app.onboarded") { didSet { UserDefaults.standard.set(onboarded, forKey: "app.onboarded") } }
    /// Til almashsa butun ilova qayta chiziladi va ma'lumotlar yangi tilda yuklanadi
    var reloadToken = UUID()

    // Navigatsiya
    var tab: Tab = .home
    var paths: [Tab: [Route]] = Dictionary(uniqueKeysWithValues: Tab.allCases.map { ($0, []) })
    /// Brauzer oynasi (SFSafariViewController) — tashqi havolalar
    var webURL: IdentifiedURL?
    /// Qisqa xabar (pastda)
    var toast: String?

    // Ma'lumot
    private(set) var saved: [Card] = []
    private(set) var recent: [Card] = []
    private(set) var config: ServerConfig?
    /// Server menyusi (tablar, Bosh sahifa to'ri, «Yana») — config'dan; kelguncha oxirgi saqlangani yoki ichki standart
    private(set) var menu: AppMenu = .builtIn
    /// Kill switch: yopiq bo'lsa ilova faqat xabarni ko'rsatadi. Oxirgi holat diskda — oflayn ham yopiq qoladi.
    private(set) var appState: ServerConfig.AppState = .open
    var isClosed: Bool { appState.closed }
    private var lastConfigAt: Date = .distantPast

    private init() {
        saved = Self.load("saved.json") ?? []
        recent = Self.load("recent.json") ?? []
        appState = Self.load("app-state.json") ?? .open
        if let c = Self.cachedConfig(Lang.current) { applyConfig(c, fromCache: true) }
        if ShotMode.spec == "closed" { appState = Self.shotClosedState }
    }

    // MARK: navigatsiya
    func open(_ route: Route, in tab: Tab? = nil) {
        if let tab, tab != self.tab, menu.visibleTabs.contains(tab) { self.tab = tab }
        paths[self.tab, default: []].append(route)
    }
    /// Tabga o'tish; tab menyudan olib tashlangan bo'lsa — o'sha ekran joriy tabga itariladi
    func go(_ t: Tab) {
        if menu.visibleTabs.contains(t) { if t != tab { Haptics.select() }; tab = t; return }
        switch t {
        case .map: open(.map(nil))
        case .board: open(.board(nil))
        case .explore: open(.explore)
        case .home, .more: tab = t     // doim bor
        }
    }
    /// Menyu bandi bosildi
    func perform(_ a: MenuAction) {
        switch a {
        case .route(let r): open(r)
        case .tab(let t): go(t)
        case .web(let u): openURL(u)
        }
    }
    func open(_ card: Card) {
        if let ref = card.ref { open(.item(ref)) }
        else if let w = card.web, let u = URL(string: w) { openURL(u) }
    }
    /// Sayt havolasi bo'lsa — ilova ichida, aks holda brauzer oynasida
    func openURL(_ url: URL) {
        if url.host == AppConfig.host || url.host == "www." + AppConfig.host, let r = Route(webPath: url.path) { open(r); return }
        guard let scheme = url.scheme?.lowercased() else { return }
        if scheme == "https", url.host == "apps.apple.com" { UIApplication.shared.open(url); return }   // App Store ilovasida
        if scheme == "https" { webURL = IdentifiedURL(url: url) }
        else if scheme == "http", var c = URLComponents(url: url, resolvingAgainstBaseURL: false) {   // Safari oynasida ATS yo'q — https ga
            c.scheme = "https"; if let u = c.url { webURL = IdentifiedURL(url: u) }
        }
        else if ["tel", "mailto", "tg", "maps", "comgooglemaps", "yandexmaps"].contains(scheme) { UIApplication.shared.open(url) }
    }
    func openWeb(_ s: String?) { if let s, let u = URL(string: s) { openURL(u) } }
    /// FAQAT elchixona sayti tugmalari uchun: ba'zi rasmiy saytlar faqat http'da ishlaydi (uzembassy.ru) — ularni o'zgartirmasdan
    /// Safari oynasida ochadi (SFSafariViewController — ilova tarmog'i/ATS emas, cookie ilovaga o'tmaydi). O'z saytimiz — doim openURL (https).
    func openExternalHTTP(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased(), !host.isEmpty else { return }
        if scheme == "http", host != AppConfig.host, !host.hasSuffix("." + AppConfig.host) { webURL = IdentifiedURL(url: url) }
        else { openURL(url) }
    }
    /// Deep link: https://alluzbekistan.com/… yoki alluz://joylar/registon
    func handleDeepLink(_ url: URL) {
        guard !isClosed else { return }                                   // ilova yopiq — havolalar e'tiborsiz
        let path = url.scheme == "alluz" ? "/" + (url.host ?? "") + url.path : url.path
        if let r = Route(webPath: path) { paths[tab] = [r]; return }      // stek cheksiz o'smasin
        // Ilova ichida ekrani yo'q sayt sahifasi — Safari oynasida
        if url.scheme == "https", url.host == AppConfig.host { webURL = IdentifiedURL(url: url) }
    }
    func popToRoot(_ tab: Tab) { paths[tab] = [] }

    // MARK: sevimlilar
    func isSaved(_ ref: ItemRef?) -> Bool { guard let ref else { return false }; return saved.contains { $0.ref == ref } }
    func toggleSaved(_ card: Card) {
        guard let ref = card.ref else { return }
        if let i = saved.firstIndex(where: { $0.ref == ref }) {
            saved.remove(at: i); show(tr("Saqlanganlardan olindi", "Удалено из избранного", "Removed from saved"))
        } else {
            saved.insert(card, at: 0); show(tr("Saqlandi", "Добавлено в избранное", "Saved"))
        }
        Haptics.tap()
        Self.store(saved, "saved.json")
    }
    func removeSaved(at offsets: IndexSet) { saved.remove(atOffsets: offsets); Self.store(saved, "saved.json") }
    /// Ochilgan yozuv (ItemDetailView chaqiradi)
    func visited(_ card: Card) {
        guard card.ref != nil else { return }
        recent.removeAll { $0.ref == card.ref }
        recent.insert(card, at: 0)
        if recent.count > 30 { recent.removeLast(recent.count - 30) }
        Self.store(recent, "recent.json")
    }
    func clearRecent() { recent = []; Self.store(recent, "recent.json") }

    func show(_ text: String) {
        withAnimation(.spring(duration: 0.35)) { toast = text }
        let t = text
        Task { try? await Task.sleep(for: .seconds(2)); if toast == t { withAnimation(.easeOut) { toast = nil } } }
    }

    // MARK: config (menyu, kill switch, yangilash)
    func loadConfig() async { await refreshConfig() }
    /// Config'ni qayta so'rash (ishga tushganda, ilova faollashganda, har 60 s, «Qayta urinish»). minInterval — shu soniyadan
    /// yaqinda so'ralgan bo'lsa o'tkazib yuboriladi. Oflayn — API oxirgi nusxani qaytaradi (yopiq holat saqlanadi).
    func refreshConfig(minInterval: TimeInterval = 0) async {
        guard Date().timeIntervalSince(lastConfigAt) >= minInterval else { return }
        lastConfigAt = Date()
        let l = Lang.current
        guard let data = try? await API.shared.fetch("/api/app/v1/config", lang: l),
              let c = try? JSONDecoder().decode(ServerConfig.self, from: data) else { return }
        guard l == Lang.current else { return }                           // so'rov paytida til almashdi
        try? data.write(to: Self.dir.appendingPathComponent("config-\(l.rawValue).json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        applyConfig(c)
    }
    /// fromCache — diskdagi (tilga xos) nusxa: menyu va counts olinadi, yopiq/ochiq holat esa app-state.json dagi (eng oxirgisi) qoladi
    private func applyConfig(_ c: ServerConfig, fromCache: Bool = false) {
        config = c
        let m = c.menu.map(AppMenu.init) ?? .builtIn
        if m != menu { withAnimation(Motion.gentle) { menu = m } }
        if !m.visibleTabs.contains(tab) { tab = .home }                   // tanlangan tab o'chirildi — Asosiy
        guard !fromCache else { return }
        var st = c.app ?? .open
        if ShotMode.spec == "closed" { st = Self.shotClosedState }
        if st != appState {
            withAnimation(Motion.gentle) { appState = st }
            if !ShotMode.active { Self.store(st, "app-state.json") }      // sinov holati keyingi ishga tushishga o'tmasin
        }
    }
    private static func cachedConfig(_ l: Lang) -> ServerConfig? {
        (try? Data(contentsOf: dir.appendingPathComponent("config-\(l.rawValue).json"))).flatMap { try? JSONDecoder().decode(ServerConfig.self, from: $0) }
    }
    private static var shotClosedState: ServerConfig.AppState {
        .init(closed: true, title: tr("Ilova vaqtincha yopiq", "Приложение временно недоступно", "The app is temporarily unavailable"),
              text: tr("Texnik ishlar olib borilmoqda. Birozdan soʻng qayta urinib koʻring.", "Идут технические работы. Попробуйте позже.",
                       "We are doing maintenance. Please try again later."))
    }

    static var build: Int { Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "") ?? 0 }
    /// Build config.ios.minBuild dan eski — ilova bloklanadi, faqat «Yangilash» (to'liq ekran)
    var updateRequired: Bool {
        if ShotMode.spec == "update" { return true }
        let b = Self.build
        return b > 0 && b < (config?.ios?.minBuild ?? 0)
    }
    /// Yangi build chiqqan (latestBuild) — yopsa bo'ladigan banner
    var updateAvailable: Bool {
        if ShotMode.spec == "update-banner" { return true }
        let b = Self.build
        return b > 0 && b < (config?.ios?.latestBuild ?? 0)
    }
    /// Sozlamalarda «Yangi versiya mavjud»
    var needsUpdate: Bool { updateRequired || updateAvailable }
    /// Banner: yangilanish bor, majburiy emas va shu build uchun yopilmagan
    var showUpdateBanner: Bool {
        updateAvailable && !updateRequired && (ShotMode.spec == "update-banner" || updateBannerDismissed != (config?.ios?.latestBuild ?? 0))
    }
    var updateBannerDismissed: Int = UserDefaults.standard.integer(forKey: "app.updateDismissed") {
        didSet { UserDefaults.standard.set(updateBannerDismissed, forKey: "app.updateDismissed") }
    }
    func dismissUpdateBanner() { withAnimation(Motion.snappy) { updateBannerDismissed = config?.ios?.latestBuild ?? 0 } }
    /// App Store sahifasi (faqat https)
    var storeURL: URL {
        if let s = config?.ios?.storeUrl, let u = URL(string: s), u.scheme == "https", u.host != nil { return u }
        return URL(string: AppConfig.storeURL)!
    }

    // MARK: saqlash (Application Support, faqat shu telefonda)
    private static var dir: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    private static func load<T: Decodable>(_ name: String) -> T? {
        (try? Data(contentsOf: dir.appendingPathComponent(name))).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
    private static func store<T: Encodable>(_ v: T, _ name: String) {
        if let d = try? JSONEncoder().encode(v) { try? d.write(to: dir.appendingPathComponent(name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
    }
}

struct IdentifiedURL: Identifiable, Hashable {
    let url: URL
    var id: String { url.absoluteString }
}
