// Sozlamalar: til (model.lang — butun ilova qayta chiziladi), mavzu (ThemeChoice), kesh hajmi va tozalash (tasdiq bilan),
// ko'rilganlar tarixi, maxfiylik siyosati (sayt), ilova versiyasi/build va yangilash taklifi (config.ios).
import SwiftUI

struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @State private var cacheBytes: Int?
    @State private var confirmCache = false
    @State private var confirmRecent = false
    @State private var clearing = false

    var body: some View {
        Form {
            if model.needsUpdate { updateSection }

            Section {
                Picker(selection: langBinding) {
                    ForEach(Lang.allCases) { l in
                        HStack(spacing: 12) {
                            Text(l.rawValue.uppercased()).font(Theme.Font.mono).foregroundStyle(Theme.accent).frame(width: 30, alignment: .leading)
                            Text(l.title).foregroundStyle(Theme.ink)
                        }
                        .tag(l)
                    }
                } label: { EmptyView() }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                SettingsHeader(tr("Til", "Язык", "Language"), symbol: "globe")
            } footer: {
                Text(tr("Kontent ham tanlangan tilda yuklanadi.", "Контент тоже загружается на выбранном языке.", "Content is loaded in the selected language too."))
            }
            .listRowBackground(Theme.card)

            Section {
                Picker(tr("Mavzu", "Тема", "Appearance"), selection: themeBinding) {
                    ForEach(ThemeChoice.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
            } header: {
                SettingsHeader(tr("Mavzu", "Оформление", "Appearance"), symbol: "circle.lefthalf.filled")
            }
            .listRowBackground(Theme.card)

            Section {
                LabeledContent {
                    if let b = cacheBytes {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(b), countStyle: .file))
                            .monospacedDigit().foregroundStyle(Theme.muted)
                            .contentTransition(.numericText())
                    } else {
                        ProgressView().controlSize(.small)
                    }
                } label: {
                    Label { Text(tr("Kesh hajmi", "Размер кэша", "Cache size")).foregroundStyle(Theme.ink) } icon: { MoreIcon(symbol: "internaldrive.fill", color: Theme.teal) }
                }
                Button(role: .destructive) { confirmCache = true } label: {
                    Label { Text(tr("Keshni tozalash", "Очистить кэш", "Clear cache")) } icon: { MoreIcon(symbol: "trash.fill", color: Theme.bad) }
                }
                .disabled(clearing || cacheBytes == 0)
                Button(role: .destructive) { confirmRecent = true } label: {
                    Label { Text(tr("Koʻrilganlar tarixini tozalash", "Очистить историю просмотров", "Clear viewing history")) } icon: {
                        MoreIcon(symbol: "clock.arrow.circlepath", color: Theme.warn)
                    }
                }
                .disabled(model.recent.isEmpty)
            } header: {
                SettingsHeader(tr("Maʼlumotlar", "Данные", "Data"), symbol: "externaldrive")
            } footer: {
                Text(tr("Kesh — oflayn ishlash uchun saqlangan sahifa va rasmlar. Tozalansa, internet orqali qayta yuklanadi. Saqlanganlar oʻchmaydi.",
                        "Кэш — страницы и фото, сохранённые для работы офлайн. После очистки они загрузятся заново. Избранное не удаляется.",
                        "The cache holds pages and photos saved for offline use. After clearing they will be downloaded again. Saved items are kept."))
            }
            .listRowBackground(Theme.card)

            Section {
                Button { model.openWeb(MoreLinks.privacy(model.config)) } label: {
                    SettingsLinkRow(title: tr("Maxfiylik siyosati", "Политика конфиденциальности", "Privacy policy"), symbol: "hand.raised.fill",
                                    color: Theme.accent, external: true)
                }
                NavigationLink(value: Route.about) {
                    SettingsLinkRow(title: tr("Ilova haqida", "О приложении", "About the app"), symbol: "info.circle.fill", color: Theme.teal, external: false)
                }
                LabeledContent {
                    Text(MoreLinks.appVersion).monospacedDigit().foregroundStyle(Theme.muted).textSelection(.enabled)
                } label: {
                    Label { Text(tr("Versiya", "Версия", "Version")).foregroundStyle(Theme.ink) } icon: { MoreIcon(symbol: "app.badge", color: Theme.muted) }
                }
            } header: {
                SettingsHeader(tr("Ilova", "Приложение", "App"), symbol: "app")
            } footer: {
                Text(tr("Ilova kuzatmaydi, reklama koʻrsatmaydi va hisob talab qilmaydi. Saqlanganlar faqat shu telefonda.",
                        "Приложение не следит, не показывает рекламу и не требует учётной записи. Избранное хранится только на этом телефоне.",
                        "No tracking, no ads, no account. Saved items stay on this phone only."))
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .tint(Theme.accent)
        .navigationTitle(tr("Sozlamalar", "Настройки", "Settings"))
        .task { await measure() }
        .confirmationDialog(tr("Kesh tozalansinmi?", "Очистить кэш?", "Clear the cache?"), isPresented: $confirmCache, titleVisibility: .visible) {
            Button(tr("Keshni tozalash", "Очистить кэш", "Clear cache"), role: .destructive) { Task { await clearCache() } }
        } message: {
            Text(tr("Oflayn saqlangan sahifa va rasmlar oʻchadi.", "Сохранённые офлайн страницы и фото будут удалены.", "Pages and photos saved for offline use will be removed."))
        }
        .confirmationDialog(tr("Koʻrilganlar tarixi tozalansinmi?", "Очистить историю просмотров?", "Clear viewing history?"),
                            isPresented: $confirmRecent, titleVisibility: .visible) {
            Button(tr("Tozalash", "Очистить", "Clear"), role: .destructive) {
                model.clearRecent()
                Haptics.success()
                model.show(tr("Tarix tozalandi", "История очищена", "History cleared"))
            }
        }
    }

    @ViewBuilder private var updateSection: some View {
        Section {
            Button { model.openWeb(model.config?.ios?.storeUrl) } label: {
                HStack(spacing: 14) {
                    MoreIcon(symbol: "arrow.down.app.fill", color: Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Yangi versiya mavjud", "Доступна новая версия", "A new version is available")).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                        Text(tr("Ilovani App Store orqali yangilang", "Обновите приложение в App Store", "Update the app in the App Store"))
                            .font(Theme.Font.sub).foregroundStyle(Theme.muted)
                    }
                }
            }
            .disabled(model.config?.ios?.storeUrl == nil)
        }
        .listRowBackground(Theme.card)
    }

    private var langBinding: Binding<Lang> {
        Binding(get: { model.lang }, set: { new in
            guard new != model.lang else { return }
            Haptics.select()
            model.lang = new
        })
    }
    private var themeBinding: Binding<ThemeChoice> {
        Binding(get: { model.theme }, set: { new in Haptics.select(); withAnimation(Motion.gentle) { model.theme = new } })
    }

    private func measure() async {
        let b = await Task.detached(priority: .utility) { API.shared.cacheBytes }.value
        withAnimation(Motion.snappy) { cacheBytes = b }
    }

    private func clearCache() async {
        clearing = true
        await Task.detached(priority: .userInitiated) { API.shared.clearCache() }.value
        clearing = false
        Haptics.success()
        model.show(tr("Kesh tozalandi", "Кэш очищен", "Cache cleared"))
        await measure()
    }
}

private struct SettingsHeader: View {
    let title: String
    let symbol: String
    init(_ title: String, symbol: String) { self.title = title; self.symbol = symbol }
    var body: some View {
        Label(title, systemImage: symbol).font(Theme.Font.kicker).foregroundStyle(Theme.muted)
    }
}

private struct SettingsLinkRow: View {
    let title: String
    let symbol: String
    let color: Color
    let external: Bool
    var body: some View {
        HStack(spacing: 14) {
            MoreIcon(symbol: symbol, color: color)
            Text(title).foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
            if external { Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted) }
        }
        .contentShape(Rectangle())
    }
}
