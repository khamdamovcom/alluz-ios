// «Xarita» tabi: butun O'zbekiston — joylar, mehmonxonalar, restoranlar, aeroport va vokzallar (klasterli MKMapView).
// Tepada: qidiruv (nom bo'yicha, lokal) va shisha filtr chiplari; o'ngda: joylashuvim, yaqin atrofda, butun mamlakat;
// pastda: tanlangan nuqta kartasi (rasm, tur · hudud, masofa, «Batafsil», «Yo'nalish»). focus — shu yozuvga yaqinlashib tanlaydi.
import SwiftUI
import MapKit
import CoreLocation

struct MapScreen: View {
    var focus: ItemRef? = nil

    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = MapScreenModel()
    @State private var locator = MapLocator()
    @State private var query = ""
    @State private var results: [MapPointAnnotation] = []
    @FocusState private var searching: Bool
    @State private var showNearby = false
    @State private var showDenied = false
    @State private var cardHeight: CGFloat = 0

    var body: some View {
        MapKitView(model: model, version: model.version, command: model.command, showsUser: model.showsUser,
                   bottomInset: model.selected == nil ? 0 : cardHeight)
            .ignoresSafeArea()
            .overlay(alignment: .top) { topBar }
            .overlay(alignment: .bottomTrailing) { controls }
            .overlay(alignment: .bottom) { bottom }
            .background(Theme.paper)
            .navigationTitle(focus == nil ? Tab.map.title : tr("Xaritada", "На карте", "On the map"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(focus == nil ? .hidden : .visible, for: .navigationBar)
            .task { locator.refresh(); if locator.authorized { model.showsUser = true }; await model.load(focus: focus) }
            .task(id: query) {
                let q = query
                if q.trimmingCharacters(in: .whitespaces).count < 2 { results = []; return }
                try? await Task.sleep(for: .milliseconds(300))
                if Task.isCancelled { return }
                withAnimation(Motion.snappy) { results = model.search(q) }
            }
            .sheet(isPresented: $showNearby) {
                MapNearbySheet(model: model, origin: nearbyOrigin) { a in
                    showNearby = false
                    model.focus(a)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .alert(tr("Joylashuvga ruxsat yoʻq", "Нет доступа к геопозиции", "Location access is off"), isPresented: $showDenied) {
                Button(tr("Sozlamalar", "Настройки", "Settings")) {
                    if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                }
                Button(tr("Bekor qilish", "Отмена", "Cancel"), role: .cancel) {}
            } message: {
                Text(tr("Yaqin atrofdagi joylarni koʻrish uchun Sozlamalarda joylashuvga ruxsat bering. Joylashuv faqat telefoningizda ishlatiladi.",
                        "Чтобы видеть места рядом, разрешите доступ к геопозиции в Настройках. Она используется только на телефоне.",
                        "To see places nearby, allow location access in Settings. Your location stays on this phone."))
            }
    }

    // MARK: tepa — qidiruv va chiplar
    private var searchActive: Bool { searching && query.trimmingCharacters(in: .whitespaces).count >= 2 }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted).accessibilityHidden(true)
                TextField(tr("Joy, mehmonxona, restoran…", "Место, отель, ресторан…", "Sight, hotel, restaurant…"), text: $query)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.ink)
                    .focused($searching)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { if let f = results.first { pick(f) } }
                if !query.isEmpty {
                    Button { withAnimation(Motion.snappy) { query = ""; results = [] } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 28, minHeight: 28)
                    .accessibilityLabel(tr("Tozalash", "Очистить", "Clear"))
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .glassBackground(Capsule(), interactive: true, fallback: .regularMaterial)
            .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
            .padding(.horizontal, Theme.gutter)

            if searchActive {
                resultsPanel.padding(.horizontal, Theme.gutter)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            } else {
                chips.transition(.opacity)
            }
        }
        .padding(.top, 8)
        .animation(Motion.snappy, value: searchActive)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MapCategory.allCases) { c in
                    let on = model.enabled.contains(c)
                    Button { withAnimation(Motion.snappy) { model.toggle(c) } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: c.symbol)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(on ? Theme.accentInk : c.color)
                                .frame(width: 22, height: 22)
                                .background(on ? c.color : c.color.opacity(0.15), in: Circle())
                                .contentTransition(.symbolEffect(.replace))
                            Text(c.title).font(Theme.Font.sub.weight(.semibold)).foregroundStyle(on ? Theme.ink : Theme.muted)
                            if let n = model.counts[c], n > 0 {
                                Text(Fmt.num(n)).font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.muted)
                                    .contentTransition(.numericText())
                            }
                        }
                        .padding(.leading, 6).padding(.trailing, 12)
                        .frame(minHeight: 40)
                        .glassBackground(Capsule(), tint: on ? c.color.opacity(0.18) : nil, interactive: true, fallback: .regularMaterial)
                        .opacity(on ? 1 : 0.85)
                    }
                    .buttonStyle(.press)
                    .accessibilityLabel(c.title)
                    .accessibilityValue(on ? tr("Koʻrsatilmoqda", "Показаны", "Shown") : tr("Yashirilgan", "Скрыты", "Hidden"))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 2)
            .glassGroup(spacing: 8)
        }
    }

    private var resultsPanel: some View {
        VStack(spacing: 0) {
            if results.isEmpty {
                Text(tr("Hech narsa topilmadi", "Ничего не найдено", "Nothing found"))
                    .font(Theme.Font.sub).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 56)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results, id: \.point.id) { a in
                            Button { pick(a) } label: { MapPointRow(annotation: a, meters: model.distance(to: a)) }
                                .buttonStyle(.press)
                            if a !== results.last { Divider().overlay(Theme.line).padding(.leading, 56) }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollDismissesKeyboard(.immediately)
                .frame(maxHeight: 340)
            }
        }
        .glassBackground(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous), fallback: .regularMaterial)
        .shadow(color: .black.opacity(0.1), radius: 14, y: 4)
    }

    private func pick(_ a: MapPointAnnotation) {
        searching = false
        Haptics.select()
        model.focus(a)
    }

    // MARK: o'ng — boshqaruv tugmalari
    private var controls: some View {
        VStack(spacing: 10) {
            roundButton("location.fill", tr("Joylashuvim", "Моё местоположение", "My location"), active: model.showsUser) { locate() }
            roundButton("list.bullet", tr("Yaqin atrofda", "Рядом", "Nearby"), active: false) {
                Haptics.tap(); searching = false; showNearby = true
            }
            .disabled(model.phase != .ready)
            roundButton("globe.asia.australia", tr("Butun Oʻzbekiston", "Весь Узбекистан", "All of Uzbekistan"), active: false) { model.home() }
        }
        .glassGroup(spacing: 10)
        .padding(.trailing, Theme.gutter)
        .padding(.bottom, (model.selected == nil ? 24 : cardHeight + 24))
        .opacity(searchActive ? 0 : 1)
        .animation(Motion.spring, value: model.selected == nil)
        .animation(Motion.spring, value: cardHeight)
    }

    private func roundButton(_ symbol: String, _ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(active ? Theme.accent : Theme.ink)
                .symbolEffect(.bounce, value: active)
                .frame(width: 48, height: 48)
                .glassBackground(Circle(), interactive: true, fallback: .regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        }
        .buttonStyle(.press)
        .accessibilityLabel(label)
    }

    private func locate() {
        Haptics.tap()
        let ok = locator.request { model.showUser() }
        if !ok { showDenied = true }
    }

    /// «Yaqin atrofda» — joylashuv bo'lsa undan, aks holda xarita markazidan
    private var nearbyOrigin: CLLocation {
        model.userLocation ?? CLLocation(latitude: model.center.latitude, longitude: model.center.longitude)
    }

    // MARK: pastki karta / holat
    @ViewBuilder private var bottom: some View {
        Group {
            if let a = model.selected {
                MapPointCard(annotation: a, card: model.card(a), meters: model.distance(to: a), onClose: { model.closeCard() })
                    .id(a.point.id)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeight = $0 }
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            } else {
                switch model.phase {
                case .loading:
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(tr("Nuqtalar yuklanmoqda…", "Загрузка точек…", "Loading places…")).font(Theme.Font.sub).foregroundStyle(Theme.ink2)
                    }
                    .padding(.horizontal, 18).frame(minHeight: 44)
                    .glassBackground(Capsule(), fallback: .regularMaterial)
                    .transition(.opacity)
                case .failed(let msg):
                    HStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark").foregroundStyle(Theme.bad)
                        Text(msg).font(Theme.Font.sub).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                        Button(tr("Qayta", "Повторить", "Retry")) { Task { await model.load(focus: focus) } }
                            .primaryButton().tint(Theme.accent)
                    }
                    .padding(14)
                    .glassBackground(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous), fallback: .regularMaterial)
                    .transition(.opacity)
                case .ready:
                    EmptyView()
                }
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 12)
        .animation(Motion.spring, value: model.selected?.point.id)
        .animation(Motion.gentle, value: model.phase)
    }
}

// MARK: - Natija / yaqin atrofdagi qator
private struct MapPointRow: View {
    let annotation: MapPointAnnotation
    var meters: Double? = nil
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: annotation.glyph)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(annotation.category.color, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(annotation.point.name).font(Theme.Font.headline).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                Text(annotation.typeLabel).font(Theme.Font.caption).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            if let meters {
                Text(Fmt.km(meters / 1000)).font(Theme.Font.caption.monospacedDigit().weight(.semibold)).foregroundStyle(Theme.ink2)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tanlangan nuqta kartasi
private struct MapPointCard: View {
    let annotation: MapPointAnnotation
    let card: Card?
    let meters: Double?
    let onClose: () -> Void
    @Environment(AppModel.self) private var app

    private var point: MapPoint { annotation.point }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Button { open() } label: {
                    RemoteImage(img: card?.img, region: point.region, icon: card?.icon, width: 84)
                        .frame(width: 84, height: 84)
                        .overlay {
                            if card == nil && point.hasImg { Shimmer() }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
                }
                .buttonStyle(.press)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Kicker(text: annotation.typeLabel, color: annotation.category.color)
                    Text(point.name).font(Theme.Font.title3).foregroundStyle(Theme.ink)
                        .lineLimit(3).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    if let sub = card?.sub, !sub.isEmpty {
                        Text(sub).font(Theme.Font.caption).foregroundStyle(Theme.muted).lineLimit(2).transition(.opacity)
                    }
                    HStack(spacing: 8) {
                        if point.rating > 0 && point.type == "place" { RatingView(rating: point.rating) }
                        if let meters {
                            Label(Fmt.km(meters / 1000), systemImage: "location.fill")
                                .font(Theme.Font.caption.monospacedDigit().weight(.semibold)).foregroundStyle(Theme.ink2)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink2)
                        .frame(width: 30, height: 30)
                        .background(Theme.ink.opacity(0.08), in: Circle())
                        .frame(width: 44, height: 44, alignment: .topTrailing)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("Yopish", "Закрыть", "Close"))
            }

            HStack(spacing: 10) {
                Button { open() } label: {
                    Label(tr("Batafsil", "Подробнее", "Details"), systemImage: "info.circle")
                        .font(Theme.Font.sub.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 30)
                }
                .primaryButton().tint(Theme.accent)
                Button { directions() } label: {
                    Label(tr("Yoʻnalish", "Маршрут", "Directions"), systemImage: "arrow.triangle.turn.up.right.diamond")
                        .font(Theme.Font.sub.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 30)
                }
                .secondaryButton().tint(Theme.ink)
                if let card { SaveButton(card: card).font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44).tint(Theme.accent) }
            }
        }
        .padding(14)
        .glassBackground(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous), fallback: .regularMaterial)
        .shadow(color: .black.opacity(0.14), radius: 18, y: 6)
        .accessibilityElement(children: .contain)
    }

    private func open() { Haptics.tap(); app.open(.item(point.ref)) }

    /// Apple Xaritalar (tizim ilovasi) — faqat manzil koordinatasi beriladi
    private func directions() {
        Haptics.tap()
        var c = URLComponents()
        c.scheme = "maps"; c.host = ""
        c.queryItems = [URLQueryItem(name: "daddr", value: "\(point.lat),\(point.lon)"), URLQueryItem(name: "q", value: point.name)]
        if let u = c.url { app.openURL(u) }
    }
}

// MARK: - «Yaqin atrofda»
private struct MapNearbySheet: View {
    let model: MapScreenModel
    let origin: CLLocation
    let onPick: (MapPointAnnotation) -> Void
    @State private var items: [(MapPointAnnotation, Double)] = []

    private var fromUser: Bool { model.userLocation != nil }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    EmptyState(title: tr("Yaqin atrofda hech narsa yoʻq", "Рядом ничего нет", "Nothing nearby"),
                               text: tr("Filtrlarni yoqib koʻring.", "Попробуйте включить фильтры.", "Try turning filters on."), symbol: "mappin.slash")
                } else {
                    List {
                        Section {
                            ForEach(Array(items.enumerated()), id: \.element.0.point.id) { i, pair in
                                Button { onPick(pair.0) } label: { MapPointRow(annotation: pair.0, meters: pair.1) }
                                    .buttonStyle(.press)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                                    .listRowBackground(Theme.card)
                                    .appear(delay: 0.025 * Double(i), offset: 8)
                            }
                        } header: {
                            Label(fromUser ? tr("Joylashuvingizdan", "От вашего местоположения", "From your location")
                                           : tr("Xarita markazidan", "От центра карты", "From the map centre"),
                                  systemImage: fromUser ? "location.fill" : "scope")
                                .font(Theme.Font.caption).foregroundStyle(Theme.muted)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.paper)
            .navigationTitle(tr("Yaqin atrofda", "Рядом", "Nearby"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { items = model.nearby(from: origin) }
    }
}
