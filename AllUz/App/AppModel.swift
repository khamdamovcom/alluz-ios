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
    var lang: Lang = Lang.current { didSet { UserDefaults.standard.set(lang.rawValue, forKey: Lang.storeKey); reloadToken = UUID() } }
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
    var config: ServerConfig?

    private init() {
        saved = Self.load("saved.json") ?? []
        recent = Self.load("recent.json") ?? []
    }

    // MARK: navigatsiya
    func open(_ route: Route, in tab: Tab? = nil) {
        if let tab, tab != self.tab { self.tab = tab }
        paths[self.tab, default: []].append(route)
    }
    func open(_ card: Card) {
        if let ref = card.ref { open(.item(ref)) }
        else if let w = card.web, let u = URL(string: w) { openURL(u) }
    }
    /// Sayt havolasi bo'lsa — ilova ichida, aks holda brauzer oynasida
    func openURL(_ url: URL) {
        if url.host == AppConfig.host || url.host == "www." + AppConfig.host, let r = Route(webPath: url.path) { open(r); return }
        guard let scheme = url.scheme?.lowercased() else { return }
        if scheme == "https" || scheme == "http" { webURL = IdentifiedURL(url: url) }
        else if ["tel", "mailto", "tg", "maps", "comgooglemaps", "yandexmaps"].contains(scheme) { UIApplication.shared.open(url) }
    }
    func openWeb(_ s: String?) { if let s, let u = URL(string: s) { openURL(u) } }
    /// Deep link: https://alluzbekistan.com/… yoki alluz://joylar/registon
    func handleDeepLink(_ url: URL) {
        let path = url.scheme == "alluz" ? "/" + (url.host ?? "") + url.path : url.path
        if let r = Route(webPath: path) { open(r) }
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

    func loadConfig() async {
        config = try? await API.shared.get("config")
    }
    /// Server talab qilgan minimal build'dan eski bo'lsa — yangilash taklifi
    var needsUpdate: Bool {
        let b = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "") ?? 0
        return b > 0 && b < (config?.ios?.minBuild ?? 0)
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
