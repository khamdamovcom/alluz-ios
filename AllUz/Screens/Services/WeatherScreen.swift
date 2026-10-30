// Ob-havo: region == nil — hududlar ro'yxati (hozirgi harorat, holat, dam olish maskanlari) va «Qachon qayerga borish» jadvali;
// region = hudud slug yoki nuqta id (xiva, chimyon) — tafsil: hozirgi holat, 24 soat, 7 kun, iqlim grafigi, eng qulay oylar.
// Ma'lumot: /api/app/v1/weather, /weather/:id (MET Norway + content/climate.json). Ichki navigatsiya: model.open(.weather(slug)).
import SwiftUI

struct WeatherScreen: View {
    let region: String?
    var body: some View {
        if let region, !region.isEmpty { WeatherDetailScreen(id: region) } else { WeatherListScreen() }
    }
}

// MARK: - Ro'yxat
private struct WeatherListScreen: View {
    var body: some View {
        Loadable(load: { try await API.shared.get("weather") as WeatherIndex }) { idx in
            WeatherListContent(idx: idx)
        }
        .background(Theme.paper)
        .navigationTitle(tr("Ob-havo", "Погода", "Weather"))
    }
}

private struct WeatherListContent: View {
    let idx: WeatherIndex
    @Environment(AppModel.self) private var model

    private var mood: WeatherGlyph.Mood {
        let p = idx.regions.first?.mainPoint
        return WeatherGlyph.mood(p?.icon, night: p?.night)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                header
                ForEach(Array(idx.regions.enumerated()), id: \.element.id) { i, r in
                    WeatherRegionCard(region: r).appear(delay: 0.03 * Double(min(i, 8)))
                }
                if idx.regions.contains(where: { $0.cats != nil }) {
                    WeatherMatrix(regions: idx.regions, monthLabels: idx.monthLabels ?? [], current: idx.month, catLabels: idx.catLabels ?? [:])
                        .padding(.top, 14)
                }
                WeatherSourceFooter(source: idx.source, updated: idx.updated, extra: [], web: nil)
                    .padding(.top, 8)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .scrollContentBackground(.hidden)
        .background(alignment: .top) {
            LinearGradient(colors: WeatherGlyph.sky(mood), startPoint: .top, endPoint: .bottom)
                .frame(height: 420).ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Kicker(text: tr("Toshkent vaqti · MET Norway", "Время Ташкента · MET Norway", "Tashkent time · MET Norway"))
            Text(tr("Oʻzbekiston ob-havosi", "Погода в Узбекистане", "Weather in Uzbekistan"))
                .font(Theme.Font.largeTitle).foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(tr("Hozirgi holat va 7 kunlik prognoz — hudud markazlari, sayyohlik shaharlari va dam olish maskanlari.",
                    "Погода сейчас и прогноз на 7 дней — центры регионов, туристические города и курорты.",
                    "Current conditions and a 7-day forecast for regional capitals, tourist towns and resorts."))
                .font(Theme.Font.sub).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
            if let u = WeatherFmt.updated(idx.updated) {
                Label(u, systemImage: "clock").font(Theme.Font.caption).foregroundStyle(Theme.muted)
            }
        }
        .padding(.top, 8).padding(.bottom, 6)
    }
}

/// Hudud kartasi: asosiy nuqta (katta), qolgan nuqtalar — pastda chiplar
private struct WeatherRegionCard: View {
    let region: WeatherRegion
    @Environment(AppModel.self) private var model

    var body: some View {
        let main = region.mainPoint
        let others = region.points.filter { $0.id != main?.id }
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.tap(); model.open(.weather(region.slug))
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Kicker(text: region.name, color: Theme.muted)
                        Text(main?.name ?? region.name).font(Theme.Font.title3).foregroundStyle(Theme.ink)
                        if main?.ok == true {
                            Text(WeatherFmt.capitalized(main?.text)).font(Theme.Font.sub).foregroundStyle(Theme.ink2).lineLimit(2)
                            Text("\(tr("Maks.", "Макс.", "H")) \(WeatherFmt.deg(main?.hi))  ·  \(tr("Min.", "Мин.", "L")) \(WeatherFmt.deg(main?.lo))")
                                .font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.muted)
                        } else {
                            Text(tr("Prognoz hali yuklanmadi", "Прогноз ещё не загружен", "Forecast not loaded yet"))
                                .font(Theme.Font.sub).foregroundStyle(Theme.muted)
                        }
                    }
                    Spacer(minLength: 4)
                    if main?.ok == true {
                        HStack(spacing: 6) {
                            WeatherIcon(icon: main?.icon, size: 30)
                            Text(WeatherFmt.deg(main?.t)).font(Theme.Font.display(40)).foregroundStyle(Theme.ink)
                                .monospacedDigit().lineLimit(1).fixedSize()
                        }
                    }
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.press)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(a11y(main, region: region.name))
            .accessibilityHint(tr("Batafsil prognoz", "Подробный прогноз", "Detailed forecast"))
            .accessibilityAddTraits(.isButton)

            if !others.isEmpty {
                Divider().overlay(Theme.line.opacity(0.6)).padding(.horizontal, 16)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(others) { p in
                            Button { Haptics.tap(); model.open(.weather(p.id)) } label: {
                                HStack(spacing: 6) {
                                    WeatherIcon(icon: p.icon, size: 15)
                                    Text(p.name).font(Theme.Font.sub.weight(.medium)).foregroundStyle(Theme.ink)
                                    if p.ok == true { Text(WeatherFmt.deg(p.t)).font(Theme.Font.sub.monospacedDigit()).foregroundStyle(Theme.ink2) }
                                }
                                .padding(.horizontal, 12).frame(minHeight: 36)
                                .background(Theme.paper2, in: Capsule())
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.press)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(a11y(p, region: p.kindLabel))
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
            }
        }
        .background {
            ZStack {
                Theme.card
                LinearGradient(colors: [WeatherGlyph.sky(WeatherGlyph.mood(main?.icon, night: main?.night))[0].opacity(0.55), .clear],
                               startPoint: .topTrailing, endPoint: .bottomLeading)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
    }

    private func a11y(_ p: WeatherBrief?, region: String?) -> String {
        guard let p else { return region ?? "" }
        var s = [p.name, region].compactMap { $0 }.joined(separator: ", ")
        if p.ok == true {
            s += ". \(WeatherFmt.deg(p.t)), \(p.text ?? ""). \(tr("Eng yuqori", "Максимум", "High")) \(WeatherFmt.deg(p.hi)), \(tr("eng past", "минимум", "low")) \(WeatherFmt.deg(p.lo))"
        }
        return s
    }
}

/// «Qachon qayerga borish» — hududlar × 12 oy, rang — oy toifasi (sayt jadvali kabi)
private struct WeatherMatrix: View {
    let regions: [WeatherRegion]
    let monthLabels: [String]
    let current: Int?
    let catLabels: [String: String]
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Kicker(text: tr("Qachon borish yaxshi", "Когда лучше ехать", "Best time to visit"))
                Text(tr("Qachon qayerga borish", "Куда и когда ехать", "Where to go and when")).font(Theme.Font.title).foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            Panel(padding: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 2) {
                        Color.clear.frame(width: 92, height: 1)
                        ForEach(0..<12, id: \.self) { m in
                            Text(String((monthLabels.weatherAt(m) ?? "").prefix(1)))
                                .font(.caption2.weight(m + 1 == current ? .bold : .regular))
                                .foregroundStyle(m + 1 == current ? Theme.accent : Theme.muted)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .accessibilityHidden(true)
                    ForEach(regions.filter { $0.cats != nil }) { r in
                        Button { Haptics.tap(); model.open(.weather(r.slug)) } label: {
                            HStack(spacing: 2) {
                                Text(r.name).font(Theme.Font.caption).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.8)
                                    .frame(width: 92, alignment: .leading)
                                ForEach(0..<12, id: \.self) { m in
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(WeatherGlyph.catColor(r.cats?.weatherAt(m)))
                                        .frame(maxWidth: .infinity).frame(height: 20)
                                        .overlay {
                                            if m + 1 == current { RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.ink, lineWidth: 1.5) }
                                        }
                                }
                            }
                            .frame(minHeight: 28)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.press)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(r.name). \(r.best ?? "")")
                        .accessibilityAddTraits(.isButton)
                    }
                    WeatherCatLegend(labels: catLabels).padding(.top, 8)
                }
            }
            Text(tr("Eng qulay oy — oʻrtacha kunduzgi harorat 15–28 °C. Iqlim — koʻp yillik oʻrtacha qiymatlar.",
                    "Лучший месяц — средняя дневная температура 15–28 °C. Климат — многолетние средние значения.",
                    "Best month: average daytime high of 15–28 °C. Climate figures are long-term averages."))
                .font(Theme.Font.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Oy toifalari izohi
struct WeatherCatLegend: View {
    let labels: [String: String]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach(WeatherGlyph.catOrder, id: \.self) { k in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(WeatherGlyph.catColor(k)).frame(width: 14, height: 14)
                    Text(labels[k] ?? k).font(Theme.Font.caption).foregroundStyle(Theme.ink2).lineLimit(2)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tafsil
private struct WeatherDetailScreen: View {
    let id: String
    @State private var title: String?
    var body: some View {
        Loadable(load: { [id] in try await API.shared.get("weather/\(id)") as WeatherDetail }) { d in
            WeatherDetailContent(detail: d).onAppear { title = d.region.name }
        }
        .background(Theme.paper)
        .navigationTitle(title ?? tr("Ob-havo", "Погода", "Weather"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WeatherDetailContent: View {
    let detail: WeatherDetail
    @State private var sel: String
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(detail: WeatherDetail) {
        self.detail = detail
        _sel = State(initialValue: detail.selected ?? detail.points.first?.id ?? "")
    }

    private var point: WeatherPoint? { detail.points.first { $0.id == sel } ?? detail.points.first }
    private var mood: WeatherGlyph.Mood { WeatherGlyph.mood(point?.now?.icon, night: point?.now?.night) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if detail.points.count > 1 { picker }
                if let p = point, let now = p.now {
                    WeatherHero(point: p, now: now, regionName: detail.region.name)
                    WeatherMetrics(now: now)
                    if let hs = p.hours, !hs.isEmpty { WeatherHourly(hours: hs) }
                    if let ds = p.days, !ds.isEmpty { WeatherDaily(days: ds, now: now.t) }
                    if p.stale == true {
                        Label(tr("Prognoz bir necha soatdan beri yangilanmadi — oxirgi maʼlumot koʻrsatilmoqda.",
                                 "Прогноз не обновлялся несколько часов — показаны последние данные.",
                                 "The forecast hasn't refreshed for a few hours — showing the latest data."), systemImage: "exclamationmark.circle")
                            .font(Theme.Font.caption).foregroundStyle(Theme.warn)
                    }
                } else {
                    EmptyState(title: tr("Prognoz hali yuklanmadi", "Прогноз ещё не загружен", "Forecast not loaded yet"),
                               text: tr("Birozdan soʻng pastga tortib yangilang.", "Потяните вниз чуть позже, чтобы обновить.", "Pull down to refresh in a little while."),
                               symbol: "cloud.sun")
                }
                if let c = detail.climate {
                    WeatherClimateSection(climate: c, current: detail.month, catLabels: detail.catLabels ?? [:])
                }
                WeatherSourceFooter(source: detail.source, updated: detail.updated,
                                    extra: detail.climate?.sources ?? [], web: detail.web)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollContentBackground(.hidden)
        .background(alignment: .top) {
            LinearGradient(colors: WeatherGlyph.sky(mood), startPoint: .top, endPoint: .bottom)
                .frame(height: 560)
                .ignoresSafeArea()
                .animation(reduceMotion ? nil : Motion.gentle, value: mood)
        }
    }

    /// Hududdagi nuqtalar (shahar, dam olish maskani)
    private var picker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(detail.points) { p in
                    let on = p.id == sel
                    Button {
                        Haptics.select()
                        withAnimation(reduceMotion ? nil : Motion.spring) { sel = p.id }
                    } label: {
                        HStack(spacing: 6) {
                            WeatherIcon(icon: p.now?.icon, size: 15)
                            Text(p.name).font(Theme.Font.sub.weight(.semibold))
                            if let t = p.now?.t { Text(WeatherFmt.deg(t)).font(Theme.Font.sub.monospacedDigit()).opacity(0.85) }
                        }
                        .padding(.horizontal, 14).frame(minHeight: 40)
                        .foregroundStyle(on ? Theme.accentInk : Theme.ink)
                        .background(on ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.card.opacity(0.85)), in: Capsule())
                        .overlay(Capsule().strokeBorder(on ? .clear : Theme.line))
                    }
                    .buttonStyle(.press)
                    .accessibilityLabel("\(p.name), \(p.kindLabel ?? ""), \(WeatherFmt.deg(p.now?.t))")
                    .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }
}

extension Array {
    /// Chegaradan chiqsa nil
    func weatherAt(_ i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
