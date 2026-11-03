// «Yana» tab: barcha bo'limlar guruhlab — server menyusidan (model.menu.more, admin → Ilova; AppMenu.swift), Sozlamalar uslubidagi
// rangli ikonkali qatorlar. Qatorlar yonida bo'limdagi yozuvlar soni (model.config.counts). Bo'limlar: Route orqali; «tab:…» — o'z tabiga o'tadi.
import SwiftUI

struct MoreView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                MoreHeader()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            ForEach(groups) { g in
                Section {
                    ForEach(g.rows) { row in MoreRowView(row: row) }
                } header: {
                    Text(g.title).font(Theme.Font.kicker).foregroundStyle(Theme.muted)
                }
                .listRowBackground(Theme.card)
                .listRowSeparatorTint(Theme.line)
            }

            Section {
                Text(tr("Mustaqil maʼlumot loyihasi · kuzatuv va reklamasiz", "Независимый справочный проект · без слежки и рекламы",
                        "An independent guide · no tracking, no ads"))
                    .font(Theme.Font.caption).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle(tr("Yana", "Ещё", "More"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.open(.search) } label: { Image(systemName: "magnifyingglass") }
                    .accessibilityLabel(tr("Qidiruv", "Поиск", "Search"))
            }
        }
    }

    /// Server menyusidan (AppMenu) — tartib va ko'rinish admin paneldan; son — config.counts dan route turi bo'yicha
    private var groups: [MoreGroup] {
        model.menu.more.map { g in
            MoreGroup(id: g.id, title: g.title, rows: g.items.map { e in
                MoreRow(id: e.id, title: e.title, symbol: e.symbol, color: e.color(), count: count(e), action: e.action)
            })
        }
    }

    private func count(_ e: MenuEntry) -> Int? {
        let c = model.config?.counts ?? [:]
        func n(_ k: String...) -> Int? { let s = k.compactMap { c[$0] }.reduce(0, +); return s > 0 ? s : nil }
        switch e.action {
        case .route(let r):
            switch r {
            case .list(let l): return l.kind == nil && l.region == nil && !l.unesco ? n(l.type) : nil
            case .regions: return n("region")
            case .history: return n("era")
            case .culture: return n("cuisine", "craft", "tradition", "holiday")
            case .post(nil): return n("post")
            case .gov: return n("org")
            case .saved: return model.saved.isEmpty ? nil : model.saved.count
            default: return nil
            }
        default: return nil
        }
    }
}

// MARK: - Umumiy (More papkasi ichida)

/// Sayt havolalari joriy til prefiksi bilan
enum MoreLinks {
    static var langPrefix: String { Lang.current == .uz ? "" : "/" + Lang.current.rawValue }
    static var site: String { AppConfig.site + langPrefix }
    static func privacy(_ config: ServerConfig?) -> String { config?.links?.privacy ?? AppConfig.site + langPrefix + "/maxfiylik" }
    static func photos(_ config: ServerConfig?) -> String { config?.links?.photos ?? AppConfig.site + langPrefix + "/rasmlar" }
    static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

/// Sozlamalar uslubidagi rangli ikonka
struct MoreIcon: View {
    let symbol: String
    let color: Color
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.card)
            .frame(width: 30, height: 30)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct MoreGroup: Identifiable {
    let id: String
    let title: String
    let rows: [MoreRow]
}

private struct MoreRow: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let color: Color
    let count: Int?
    let action: MenuAction
}

private struct MoreRowView: View {
    let row: MoreRow
    @Environment(AppModel.self) private var model

    var body: some View {
        switch row.action {
        case .route(let r):
            NavigationLink(value: r) { label }
        case .tab(let t) where model.menu.visibleTabs.contains(t):
            Button { Haptics.select(); model.go(t) } label: { label.overlay(alignment: .trailing) { trailingIcon("arrow.turn.up.right") } }
                .accessibilityHint(tr("Boshqa tabga oʻtadi", "Переход на другую вкладку", "Switches tab"))
        case .tab(let t):      // tab menyuda yo'q — ekran shu stekka itariladi
            Button { model.go(t) } label: { label.overlay(alignment: .trailing) { trailingIcon("chevron.right") } }
        case .web(let u):
            Button { model.openURL(u) } label: { label.overlay(alignment: .trailing) { trailingIcon("arrow.up.right") } }
        }
    }

    private var label: some View {
        HStack(spacing: 14) {
            MoreIcon(symbol: row.symbol, color: row.color)
            Text(row.title).font(Theme.Font.body).foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            if let c = row.count {
                Text(Fmt.num(c)).font(Theme.Font.sub.monospacedDigit()).foregroundStyle(Theme.muted)
                    .contentTransition(.numericText())
                    .padding(.trailing, isLink ? 0 : 20)
            }
        }
        .frame(minHeight: 36)
        .contentShape(Rectangle())
    }

    private var isLink: Bool { if case .route = row.action { return true }; return false }

    private func trailingIcon(_ s: String) -> some View {
        Image(systemName: s).font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted).accessibilityHidden(true)
    }
}

/// Tepada: logotip, nom, qidiruv tugmasi
private struct MoreHeader: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image("BrandMark").resizable().frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("All Uzbekistan").font(Theme.Font.title).foregroundStyle(Theme.ink)
                    Text(tr("Barcha boʻlimlar", "Все разделы", "All sections")).font(Theme.Font.sub).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            Button { Haptics.tap(); model.open(.search) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.accent)
                    Text(tr("Qidiruv", "Поиск", "Search")).foregroundStyle(Theme.muted)
                    Spacer(minLength: 0)
                }
                .font(Theme.Font.body)
                .padding(.horizontal, 16)
                .frame(minHeight: 46)
                .contentShape(Capsule())
                .glassBackground(Capsule(), interactive: true, fallback: .regularMaterial)
                .overlay(Capsule().strokeBorder(Theme.line.opacity(0.7)))
            }
            .buttonStyle(.press)
            .accessibilityLabel(tr("Qidiruv", "Поиск", "Search"))
        }
        .padding(.vertical, 6)
        .appear()
    }
}
