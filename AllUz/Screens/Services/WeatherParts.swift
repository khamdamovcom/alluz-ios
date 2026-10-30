// Ob-havo tafsil ekrani bo'laklari: katta hozirgi holat, ko'rsatkichlar, soatlik lenta, kunlik ro'yxat (min–max chiziq),
// iqlim grafigi (Swift Charts), «Qachon borish yaxshi», mavsum maslahatlari, manba.
import SwiftUI
import Charts

// MARK: - Hozirgi holat
struct WeatherHero: View {
    let point: WeatherPoint
    let now: WeatherNow
    let regionName: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 6) {
            Kicker(text: [point.kindLabel, point.alt.map { "\(Fmt.num(Int($0))) \(tr("m", "м", "m"))" }].compactMap { $0 }.joined(separator: " · "),
                   color: Theme.ink2)
            Text(point.name).font(Theme.Font.display(30)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: WeatherGlyph.symbol(now.icon))
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 56))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? "" : point.id)
                    .accessibilityHidden(true)
                Text(WeatherFmt.deg(now.t))
                    .font(Theme.Font.display(84))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: WeatherFmt.rounded(now.t)))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            Text(WeatherFmt.capitalized(now.text)).font(Theme.Font.title3).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            HStack(spacing: 14) {
                Label(WeatherFmt.deg(now.hi), systemImage: "arrow.up").labelStyle(.titleAndIcon)
                Label(WeatherFmt.deg(now.lo), systemImage: "arrow.down")
                if let f = now.feels {
                    Text("\(tr("His qilinadi", "Ощущается", "Feels like")) \(WeatherFmt.deg(f))")
                }
            }
            .font(Theme.Font.sub.monospacedDigit())
            .foregroundStyle(Theme.ink2)
            .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(point.name). \(tr("Hozir", "Сейчас", "Now")) \(WeatherFmt.deg(now.t)), \(now.text ?? ""). "
            + "\(tr("Eng yuqori", "Максимум", "High")) \(WeatherFmt.deg(now.hi)), \(tr("eng past", "минимум", "low")) \(WeatherFmt.deg(now.lo)). "
            + (now.feels.map { "\(tr("His qilinadi", "Ощущается как", "Feels like")) \(WeatherFmt.deg($0))" } ?? ""))
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Ko'rsatkichlar
struct WeatherMetrics: View {
    let now: WeatherNow

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            if let f = now.feels {
                tile("thermometer.medium", tr("His qilinadi", "Ощущается", "Feels like"), WeatherFmt.deg(f), sub: feelsHint(f))
            }
            if now.w != nil {
                tile("wind", tr("Shamol", "Ветер", "Wind"), WeatherFmt.wind(now.w), sub: WeatherFmt.windFrom(now.wd), arrow: now.wd)
            }
            if let h = now.h {
                tile("humidity.fill", tr("Namlik", "Влажность", "Humidity"), "\(Int(h))%", sub: nil)
            }
            if let p = now.p {
                tile("gauge.with.dots.needle.33percent", tr("Bosim", "Давление", "Pressure"), "\(Fmt.num(Int(p))) \(tr("hPa", "гПа", "hPa"))", sub: WeatherFmt.mmHg(p))
            }
            if let c = now.c {
                tile("cloud.fill", tr("Bulutlilik", "Облачность", "Cloud cover"), "\(Int(c))%", sub: nil)
            }
            tile("drop.fill", tr("Yogʻin, bugun", "Осадки сегодня", "Rain today"), WeatherFmt.mm(now.pr ?? 0),
                 sub: (now.pr ?? 0) < 0.1 ? tr("Kutilmaydi", "Не ожидаются", "None expected") : nil)
        }
    }

    private func feelsHint(_ f: Double) -> String {
        let t = now.t ?? f
        if f < t - 1.5 { return tr("Shamol tufayli salqinroq", "Прохладнее из-за ветра", "Cooler due to wind") }
        if f > t + 1.5 { return tr("Namlik tufayli issiqroq", "Теплее из-за влажности", "Warmer due to humidity") }
        return tr("Haqiqiy haroratga yaqin", "Близко к фактической", "Close to actual")
    }

    private func tile(_ symbol: String, _ title: String, _ value: String, sub: String?, arrow: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(Theme.Font.kicker).foregroundStyle(Theme.muted).lineLimit(2)
            HStack(spacing: 6) {
                Text(value).font(Theme.Font.title3).foregroundStyle(Theme.ink).monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1).minimumScaleFactor(0.7)
                if let arrow {
                    // MET — «qayerdan»; strelka shamol qayerga esishini ko'rsatadi
                    Image(systemName: "location.north.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accent)
                        .rotationEffect(.degrees(arrow + 180))
                        .accessibilityHidden(true)
                }
            }
            if let sub { Text(sub).font(Theme.Font.caption).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(Theme.card.opacity(0.92), in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, value, sub].compactMap { $0 }.joined(separator: ", "))
    }
}

// MARK: - Soatlik
struct WeatherHourly: View {
    let hours: [WeatherHour]

    var body: some View {
        Panel(padding: 14) {
            WeatherPanelTitle(symbol: "clock", title: tr("Soatlik prognoz", "Почасовой прогноз", "Hourly forecast"),
                              sub: tr("24 soat", "24 часа", "24 hours"))
            Divider().overlay(Theme.line).padding(.vertical, 10)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 2) {
                    ForEach(Array(hours.enumerated()), id: \.element.time) { i, h in
                        VStack(spacing: 8) {
                            Text(h.label ?? WeatherFmt.time(h.time))
                                .font(i == 0 ? Theme.Font.caption.weight(.bold) : Theme.Font.caption)
                                .foregroundStyle(i == 0 ? Theme.accent : Theme.ink2)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            WeatherIcon(icon: h.icon, size: 22).frame(height: 28)
                            Text(WeatherFmt.deg(h.t)).font(Theme.Font.headline.monospacedDigit()).foregroundStyle(Theme.ink)
                            Text((h.pr ?? 0) >= 0.1 ? Fmt.num(h.pr ?? 0, digits: 1) : " ")
                                .font(.caption2.monospacedDigit()).foregroundStyle(Theme.teal)
                        }
                        .frame(width: 54)
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(h.label ?? WeatherFmt.time(h.time)): \(WeatherFmt.deg(h.t)), \(h.text ?? "")"
                            + ((h.pr ?? 0) >= 0.1 ? ", \(WeatherFmt.mm(h.pr ?? 0))" : ""))
                    }
                }
            }
            .frame(height: 104)
        }
    }
}

struct WeatherPanelTitle: View {
    let symbol: String
    let title: String
    var sub: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(Theme.accent)
            Text(title.uppercased()).tracking(0.8)
            if let sub { Text("· \(sub)").foregroundStyle(Theme.muted) }
        }
        .font(Theme.Font.kicker)
        .foregroundStyle(Theme.ink2)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Kunlik (Apple Weather uslubidagi min–max chiziq)
struct WeatherDaily: View {
    let days: [WeatherDay]
    let now: Double?

    var body: some View {
        let lo = days.compactMap(\.lo).min() ?? 0
        let hi = days.compactMap(\.hi).max() ?? 1
        Panel(padding: 14) {
            WeatherPanelTitle(symbol: "calendar", title: tr("\(days.count) kunlik prognoz", "Прогноз на \(days.count) дней", "\(days.count)-day forecast"))
            Divider().overlay(Theme.line).padding(.top, 10)
            ForEach(Array(days.enumerated()), id: \.element.id) { i, d in
                if i > 0 { Divider().overlay(Theme.line.opacity(0.6)) }
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(d.label ?? d.short ?? d.d).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        if let date = d.date { Text(date).font(Theme.Font.caption).foregroundStyle(Theme.muted).lineLimit(1) }
                    }
                    .frame(width: 76, alignment: .leading)
                    VStack(spacing: 1) {
                        WeatherIcon(icon: d.icon, size: 20)
                        if (d.pr ?? 0) >= 0.1 {
                            Text(Fmt.num(d.pr ?? 0, digits: 1)).font(.caption2.monospacedDigit()).foregroundStyle(Theme.teal)
                        }
                    }
                    .frame(width: 40)
                    Text(WeatherFmt.deg(d.lo)).font(Theme.Font.sub.monospacedDigit()).foregroundStyle(Theme.muted)
                        .frame(width: 38, alignment: .trailing)
                    WeatherRangeBar(lo: d.lo ?? lo, hi: d.hi ?? hi, gmin: lo, gmax: hi, now: i == 0 ? now : nil, delay: 0.05 * Double(i))
                    Text(WeatherFmt.deg(d.hi)).font(Theme.Font.sub.monospacedDigit().weight(.semibold)).foregroundStyle(Theme.ink)
                        .frame(width: 38, alignment: .leading)
                }
                .padding(.vertical, 9)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(d.label ?? d.d), \(d.date ?? ""): \(d.text ?? ""). \(tr("Eng past", "Минимум", "Low")) \(WeatherFmt.deg(d.lo)), "
                    + "\(tr("eng yuqori", "максимум", "high")) \(WeatherFmt.deg(d.hi))" + ((d.pr ?? 0) >= 0.1 ? ", \(WeatherFmt.mm(d.pr ?? 0))" : ""))
            }
        }
    }
}

/// Kun harorati oralig'i: hafta min–max shkalasida rangli bo'lak; bugun — hozirgi harorat nuqtasi
struct WeatherRangeBar: View {
    let lo: Double
    let hi: Double
    let gmin: Double
    let gmax: Double
    var now: Double? = nil
    var delay: Double = 0
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { g in
            let span = max(1, gmax - gmin)
            let w = g.size.width
            let a = min(max((lo - gmin) / span, 0), 1), b = min(max((hi - gmin) / span, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line.opacity(0.7))
                Capsule()
                    .fill(LinearGradient(colors: [WeatherGlyph.tempColor(lo), WeatherGlyph.tempColor(hi)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, (b - a) * w))
                    .scaleEffect(x: shown || reduceMotion ? 1 : 0.05, anchor: .leading)
                    .offset(x: a * w)
                if let now {
                    let x = min(max((now - gmin) / span, 0), 1) * w
                    Circle().fill(Theme.ink).overlay(Circle().strokeBorder(Theme.card, lineWidth: 1.5))
                        .frame(width: 8, height: 8)
                        .offset(x: min(max(x - 4, 0), w - 8))
                        .opacity(shown || reduceMotion ? 1 : 0)
                }
            }
        }
        .frame(height: 6)
        .frame(minWidth: 40)
        .onAppear { withAnimation(Motion.spring.delay(delay)) { shown = true } }
        .accessibilityHidden(true)
    }
}

// MARK: - Iqlim
struct WeatherClimateSection: View {
    let climate: WeatherClimate
    let current: Int?
    let catLabels: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Kicker(text: tr("Iqlim", "Климат", "Climate"))
                Text(tr("Oylar boʻyicha iqlim", "Климат по месяцам", "Climate by month")).font(Theme.Font.title).foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                if let s = climate.station?.text {
                    Text(s).font(Theme.Font.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 10)
            Panel(padding: 14) {
                WeatherClimateChart(months: climate.months, current: current, comfort: climate.comfort)
            }
            .appear()
            WeatherBestTime(climate: climate, current: current, catLabels: catLabels)
                .appear()
            if let tips = climate.tips, !tips.isEmpty { WeatherSeasonTips(tips: tips) }
            if let m = climate.mountain, let text = m.text {
                Panel(padding: 14) {
                    WeatherPanelTitle(symbol: "mountain.2.fill", title: tr("Togʻlarda", "В горах", "In the mountains"), sub: m.name)
                    Text(text).font(Theme.Font.body).foregroundStyle(Theme.ink).padding(.top, 8).fixedSize(horizontal: false, vertical: true)
                    if let best = m.best {
                        Text(best).font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.ok).padding(.top, 6).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

/// Oylik harorat (kunduzgi/tungi o'rtacha, qulay zona) va yog'in (mm) — ikki grafik bir x o'qida
struct WeatherClimateChart: View {
    let months: [WeatherMonth]
    let current: Int?
    let comfort: WeatherClimate.Comfort?
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var temps: [WeatherMonth] { months.filter { $0.tmax != nil && $0.tmin != nil } }
    private var curLabel: String? { months.first { $0.m == current }?.label }

    var body: some View {
        let grow = shown || reduceMotion
        VStack(alignment: .leading, spacing: 10) {
            WeatherPanelTitle(symbol: "thermometer.sun", title: tr("Harorat", "Температура", "Temperature"), sub: "°C")
            Chart {
                if let c = comfort {
                    BarMark(yStart: .value("Min", c.min), yEnd: .value("Max", c.max))
                        .foregroundStyle(Theme.ok.opacity(0.10))
                }
                if let curLabel {
                    RuleMark(x: .value("Oy", curLabel))
                        .foregroundStyle(Theme.ink.opacity(0.22))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                ForEach(temps) { m in
                    AreaMark(x: .value("Oy", m.label), yStart: .value("Min", m.tmin ?? 0), yEnd: .value("Max", m.tmax ?? 0))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.22), Theme.teal.opacity(0.14)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(temps) { m in
                    LineMark(x: .value("Oy", m.label), y: .value("Max", m.tmax ?? 0), series: .value("S", "max"))
                        .foregroundStyle(Theme.accent)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        .symbol { Circle().fill(Theme.accent).frame(width: m.m == current ? 9 : 5) }
                        .accessibilityLabel(m.name ?? m.label)
                        .accessibilityValue("\(tr("kunduzi", "днём", "day")) \(WeatherFmt.deg(m.tmax)), \(tr("tunda", "ночью", "night")) \(WeatherFmt.deg(m.tmin))")
                }
                ForEach(temps) { m in
                    LineMark(x: .value("Oy", m.label), y: .value("Min", m.tmin ?? 0), series: .value("S", "min"))
                        .foregroundStyle(Theme.teal)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        .symbol { Circle().fill(Theme.teal).frame(width: m.m == current ? 9 : 5) }
                        .accessibilityHidden(true)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .stride(by: 10)) { v in
                    AxisGridLine().foregroundStyle(Theme.line)
                    AxisValueLabel { if let d = v.as(Double.self) { Text(WeatherFmt.deg(d)).foregroundStyle(Theme.muted) } }
                }
            }
            .frame(height: 180)
            .opacity(grow ? 1 : 0)
            .scaleEffect(y: grow ? 1 : 0.6, anchor: .bottom)

            HStack(spacing: 14) {
                legend(Theme.accent, tr("Kunduzi", "Днём", "Day"))
                legend(Theme.teal, tr("Tunda", "Ночью", "Night"))
                if let c = comfort {
                    legend(Theme.ok.opacity(0.35), tr("Qulay \(Int(c.min))–\(Int(c.max))°", "Комфорт \(Int(c.min))–\(Int(c.max))°", "Comfort \(Int(c.min))–\(Int(c.max))°"))
                }
            }
            .font(Theme.Font.caption).foregroundStyle(Theme.ink2)
            .accessibilityElement(children: .combine)

            Divider().overlay(Theme.line).padding(.vertical, 4)
            WeatherPanelTitle(symbol: "cloud.rain", title: tr("Yogʻin", "Осадки", "Precipitation"), sub: tr("mm/oy", "мм/мес", "mm/month"))
            Chart {
                ForEach(months) { m in
                    BarMark(x: .value("Oy", m.label), y: .value("mm", grow ? (m.precip ?? 0) : 0), width: .ratio(0.55))
                        .foregroundStyle(m.m == current ? Theme.teal : Theme.teal.opacity(0.45))
                        .cornerRadius(3)
                        .accessibilityLabel(m.name ?? m.label)
                        .accessibilityValue("\(WeatherFmt.mm(m.precip ?? 0)), \(Int(m.pdays ?? 0)) \(tr("kun", "дн.", "days"))")
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                    AxisGridLine().foregroundStyle(Theme.line)
                    AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))").foregroundStyle(Theme.muted) } }
                }
            }
            .chartXAxis {
                AxisMarks { v in
                    AxisValueLabel {
                        if let s = v.as(String.self) {
                            Text(s).font(.caption2.weight(s == curLabel ? .bold : .regular))
                                .foregroundStyle(s == curLabel ? Theme.accent : Theme.muted)
                        }
                    }
                }
            }
            .frame(height: 110)
        }
        .onAppear { withAnimation(Motion.spring.delay(0.1)) { shown = true } }
    }

    private func legend(_ c: Color, _ s: String) -> some View {
        HStack(spacing: 5) { Capsule().fill(c).frame(width: 14, height: 4); Text(s).lineLimit(1) }
    }
}

/// «Qachon borish yaxshi»: 12 oylik rangli chiziq, izoh, matn, muharrir maslahati
struct WeatherBestTime: View {
    let climate: WeatherClimate
    let current: Int?
    let catLabels: [String: String]

    var body: some View {
        Panel(padding: 14) {
            WeatherPanelTitle(symbol: "calendar.badge.checkmark", title: tr("Qachon borish yaxshi", "Когда лучше ехать", "Best time to visit"))
            HStack(spacing: 3) {
                ForEach(climate.months) { m in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(WeatherGlyph.catColor(m.cat))
                            .frame(height: 30)
                            .overlay {
                                if m.m == current { RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.ink, lineWidth: 2) }
                            }
                            .overlay {
                                Text(m.tmax.map { "\(Int($0.rounded()))" } ?? "")
                                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(Theme.accentInk)
                                    .minimumScaleFactor(0.6)
                            }
                        Text(String(m.label.prefix(1))).font(.caption2.weight(m.m == current ? .bold : .regular))
                            .foregroundStyle(m.m == current ? Theme.accent : Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(m.name ?? m.label): \(catLabels[m.cat ?? ""] ?? ""), \(WeatherFmt.deg(m.tmax))")
                }
            }
            .padding(.top, 12)
            WeatherCatLegend(labels: catLabels).padding(.top, 10)
            if let best = climate.best, let first = best.first {
                Text(first).font(Theme.Font.headline).foregroundStyle(Theme.ink).padding(.top, 12).fixedSize(horizontal: false, vertical: true)
                ForEach(best.dropFirst(), id: \.self) { s in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(Theme.accent).frame(width: 5, height: 5).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                        Text(s).font(Theme.Font.sub).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 6)
                    .accessibilityElement(children: .combine)
                }
            }
            if let e = climate.editorial, !e.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Muharrir maslahati", "Совет редакции", "Editor’s note")).font(Theme.Font.kicker).foregroundStyle(Theme.accent)
                    Text(e).font(Theme.Font.sub).italic().foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.paper2, in: RoundedRectangle(cornerRadius: Theme.Radius.s, style: .continuous))
                .padding(.top, 12)
            }
        }
    }
}

/// Mavsum maslahatlari — gorizontal karusel
struct WeatherSeasonTips: View {
    let tips: [WeatherTip]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WeatherPanelTitle(symbol: "leaf", title: tr("Mavsum maslahatlari", "Советы по сезонам", "Seasonal tips"))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(tips) { tip in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: symbol(tip.season)).symbolRenderingMode(.multicolor).font(.system(size: 20))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(tip.title).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                                    if let m = tip.months { Text(m).font(Theme.Font.caption).foregroundStyle(Theme.muted) }
                                }
                            }
                            Text(tip.text).font(Theme.Font.sub).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .frame(width: 270, alignment: .topLeading)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
                        .accessibilityElement(children: .combine)
                        .carouselEffect()
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }
    private func symbol(_ s: String) -> String {
        switch s { case "spring": "camera.macro"; case "summer": "sun.max.fill"; case "autumn": "leaf.fill"; default: "snowflake" }
    }
}

// MARK: - Manba
struct WeatherSourceFooter: View {
    let source: WeatherSource?
    let updated: Double?
    let extra: [WeatherClimate.Source]
    let web: String?
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WeatherPanelTitle(symbol: "info.circle", title: tr("Manbalar", "Источники", "Sources"))
            if let s = source {
                Button { model.openWeb(s.url) } label: {
                    Label("\(s.name)\(s.license.map { " · \($0)" } ?? "")", systemImage: "cloud.sun")
                        .font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.accent)
                        .frame(minHeight: 32, alignment: .leading)
                }
                .buttonStyle(.plain)
                if let t = s.text { Text(t).font(Theme.Font.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true) }
            }
            ForEach(extra, id: \.self) { e in
                Button { model.openWeb(e.url) } label: {
                    Label(e.name + (e.period.map { " · \($0)" } ?? ""), systemImage: "chart.line.uptrend.xyaxis")
                        .font(Theme.Font.caption).foregroundStyle(Theme.accent).multilineTextAlignment(.leading)
                        .frame(minHeight: 32, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            if let n = source?.note { Text(n).font(Theme.Font.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true) }
            if let u = WeatherFmt.updated(updated) {
                Label(u, systemImage: "clock").font(Theme.Font.caption).foregroundStyle(Theme.muted)
            }
            if let web {
                Button { model.openWeb(web) } label: {
                    Label(tr("Saytda ochish", "Открыть на сайте", "Open on the website"), systemImage: "safari")
                        .font(Theme.Font.sub.weight(.semibold))
                }
                .secondaryButton().tint(Theme.accent)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
