// Saqlanganlar: model.saved (surib o'chirish → model.removeSaved, tahrirlash rejimi) va «Oxirgi ko'rilganlar» (model.recent, tozalash).
// Hammasi faqat shu telefonda saqlanadi (AppModel → Application Support).
import SwiftUI

struct SavedScreen: View {
    @Environment(AppModel.self) private var model
    @State private var confirmClear = false

    var body: some View {
        Group {
            if model.saved.isEmpty && model.recent.isEmpty {
                ScrollView { SavedEmpty(full: true).padding(.top, 40) }
            } else {
                list
            }
        }
        .background(Theme.paper)
        .navigationTitle(tr("Saqlanganlar", "Избранное", "Saved"))
        .toolbar {
            if !model.saved.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { EditButton().tint(Theme.accent) }
            }
        }
        .confirmationDialog(tr("Koʻrilganlar tarixi tozalansinmi?", "Очистить историю просмотров?", "Clear viewing history?"),
                            isPresented: $confirmClear, titleVisibility: .visible) {
            Button(tr("Tozalash", "Очистить", "Clear"), role: .destructive) {
                Haptics.success()
                withAnimation(Motion.spring) { model.clearRecent() }
            }
        }
    }

    private var list: some View {
        List {
            Section {
                if model.saved.isEmpty {
                    SavedEmpty(full: false)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(model.saved) { card in
                        CardRow(card: card)
                            .listRowBackground(Theme.paper)
                            .listRowSeparatorTint(Theme.line)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { remove(card) } label: {
                                    Label(tr("Oʻchirish", "Удалить", "Remove"), systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { offsets in withAnimation(Motion.spring) { model.removeSaved(at: offsets) } }
                }
            } header: {
                SavedHeader(title: tr("Saqlanganlar", "Избранное", "Saved"), count: model.saved.count, symbol: "bookmark.fill")
            }

            if !model.recent.isEmpty {
                Section {
                    ForEach(model.recent) { card in
                        CardRow(card: card, showSummary: false)
                            .listRowBackground(Theme.paper)
                            .listRowSeparatorTint(Theme.line)
                    }
                } header: {
                    HStack(alignment: .lastTextBaseline) {
                        SavedHeader(title: tr("Oxirgi koʻrilganlar", "Недавно просмотренные", "Recently viewed"), count: model.recent.count,
                                    symbol: "clock.arrow.circlepath")
                        Spacer()
                        Button(tr("Tozalash", "Очистить", "Clear")) { confirmClear = true }
                            .font(Theme.Font.sub.weight(.semibold)).tint(Theme.accent)
                            .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(Motion.spring, value: model.saved.count)
        .animation(Motion.spring, value: model.recent.count)
    }

    private func remove(_ card: Card) {
        guard let i = model.saved.firstIndex(where: { $0.id == card.id }) else { return }
        Haptics.tap()
        withAnimation(Motion.spring) { model.removeSaved(at: IndexSet(integer: i)) }
    }
}

private struct SavedHeader: View {
    let title: String
    let count: Int
    let symbol: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.footnote.weight(.semibold)).foregroundStyle(Theme.accent)
            Text(title).font(Theme.Font.title3).foregroundStyle(Theme.ink)
            if count > 0 {
                Text("\(count)").font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.muted)
                    .contentTransition(.numericText())
            }
        }
        .textCase(nil)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Bo'sh holat: hali hech narsa saqlanmagan
private struct SavedEmpty: View {
    let full: Bool
    @Environment(AppModel.self) private var model
    @State private var bounce = false

    var body: some View {
        VStack(spacing: full ? 18 : 12) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.10)).frame(width: full ? 132 : 84, height: full ? 132 : 84)
                Circle().strokeBorder(Theme.accent.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
                    .frame(width: full ? 164 : 104, height: full ? 164 : 104)
                Image(systemName: "bookmark.fill")
                    .font(.system(size: full ? 50 : 32, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .symbolEffect(.bounce, value: bounce)
            }
            .onAppear { bounce.toggle() }
            .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text(tr("Hali hech narsa saqlanmagan", "Пока ничего не сохранено", "Nothing saved yet"))
                    .font(full ? Theme.Font.title : Theme.Font.title3).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                let mark = Image(systemName: "bookmark")
                Text("\(Text(tr("Yoqqan joy, mehmonxona yoki marshrutdagi ", "Нажмите ", "Tap ")))\(mark)\(Text(tr(" belgisini bosing — ular shu yerda, internet boʻlmasa ham turadi.", " на понравившемся месте, отеле или маршруте — они появятся здесь и будут доступны даже без интернета.", " on any place, hotel or itinerary you like — it will wait for you here, even offline.")))")
                    .font(Theme.Font.sub).foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if full {
                Button { model.open(.list(ListSpec(type: "place"))) } label: {
                    Label(tr("Joylarni koʻrish", "Смотреть места", "Browse places"), systemImage: "building.columns")
                        .font(Theme.Font.headline)
                        .padding(.horizontal, 8)
                }
                .primaryButton()
                .controlSize(.large)
                .tint(Theme.accent)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.gutter + 8)
        .padding(.vertical, full ? 20 : 16)
        .appear()
    }
}
