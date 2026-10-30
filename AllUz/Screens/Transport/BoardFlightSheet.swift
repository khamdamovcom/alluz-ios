// Reys tafsiloti (tablodagi reys bosilganda, sheet): marshrut katta (TAS → IST), holat, vaqtlar jadvali, aeroportda
// (terminal / stoyka / chiqish / lenta), reys (aviakompaniya, kodsheyrlar, samolyot), Flightradar24, ulashish, manba.
import SwiftUI

struct BoardFlightSheet: View {
    let item: BoardItem
    let dir: BoardDir
    let day: BoardDay
    let airport: BoardAirport
    let source: String?
    let updatedAt: Date?

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var f: BoardFlight { item.f }
    private var dep: Bool { dir == .dep }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    route
                    if f.removedFromSource {
                        BoardNote(text: tr("Oxirgi maʼlum holat (reys tablodan olib tashlangan).", "Последний известный статус (рейс убран с табло).",
                                           "Last known status (the flight was removed from the board)."), symbol: "clock.arrow.circlepath", tint: Theme.muted)
                    }
                    times
                    atAirport
                    flightInfo
                    actions
                    sourceLine
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .background(Theme.paper)
            .navigationTitle(f.flight)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: shareText) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel(tr("Ulashish", "Поделиться", "Share"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(tr("Yopish", "Закрыть", "Close"))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.paper)
        .presentationCornerRadius(Theme.Radius.xl)
    }

    // MARK: Sarlavha

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: [item.airline, dir.title, item.sched.map { Fmt.day($0) }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
            Text(f.flight).font(Theme.Font.display(32)).monospaced().foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            BoardStatusPill(label: item.label, tone: item.tone, large: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Marshrut — TAS → IST

    private var route: some View {
        let here = (code: airport.iata, city: airport.city)
        let there = (code: item.otherIata ?? "—", city: item.city)
        let from = dep ? here : there, to = dep ? there : here
        return Panel(padding: 18) {
            HStack(alignment: .top, spacing: 8) {
                endpoint(code: from.code, city: from.city, time: dep ? hereTime : nil, align: .leading)
                VStack(spacing: 6) {
                    BoardRouteArc(progress: progress, tone: item.tone)
                        .frame(height: 34)
                    Text(dir.title).font(Theme.Font.caption).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                endpoint(code: to.code, city: to.city, time: dep ? nil : hereTime, align: .trailing)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(from.city) \(from.code) → \(to.city) \(to.code). \(hereTime.main)")
    }

    private struct EndTime { let main: String; let was: String?; let label: String }
    private var hereTime: EndTime {
        EndTime(main: item.newTimeText ?? item.timeText, was: item.newTimeText != nil ? item.timeText : nil,
                label: item.newTimeText != nil ? tr("yangi vaqt", "новое время", "new time") : tr("jadval boʻyicha", "по расписанию", "scheduled"))
    }

    private func endpoint(code: String, city: String, time: EndTime?, align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 2) {
            Text(code).font(Theme.Font.display(34)).monospaced().foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
            Text(city).font(Theme.Font.sub.weight(.medium)).foregroundStyle(Theme.ink2)
                .multilineTextAlignment(align == .leading ? .leading : .trailing).lineLimit(2)
            if let time {
                Text(time.main).font(Theme.Font.boardTime)
                    .foregroundStyle(time.was != nil ? (item.early ? Theme.ok : Theme.warn) : Theme.ink)
                    .padding(.top, 6)
                HStack(spacing: 4) {
                    Text(time.label)
                    if let w = time.was { Text(w).strikethrough() }
                }
                .font(Theme.Font.caption).foregroundStyle(Theme.muted)
            } else {
                Text("—").font(Theme.Font.boardTime).foregroundStyle(Theme.line).padding(.top, 6)
                    .accessibilityHidden(true)
            }
        }
        .frame(minWidth: 84, alignment: align == .leading ? .leading : .trailing)
    }

    /// Uchdi/qo'ndi — to'liq; bekor — yo'q; boshqasi — noma'lum (nil)
    private var progress: Double? {
        switch f.status {
        case "arrived": 1
        case "departed": dep ? 0.5 : nil
        default: nil
        }
    }

    // MARK: Vaqtlar

    private var times: some View {
        section(tr("Vaqtlar", "Время", "Times")) {
            if let s = item.sched {
                row("clock", dep ? tr("Uchish · jadval boʻyicha", "Вылет · по расписанию", "Departure · scheduled")
                                 : tr("Qoʻnish · jadval boʻyicha", "Прилёт · по расписанию", "Arrival · scheduled"),
                    "\(BoardTime.time(s)) · \(BoardTime.dayMonth(s))")
            }
            if let e = BoardTime.parse(f.estimated), let s = item.sched, e != s {
                row("clock.badge.exclamationmark", dep ? tr("Uchish · yangi vaqt", "Вылет · новое время", "Departure · new time")
                                                     : tr("Qoʻnish · yangi vaqt", "Прилёт · новое время", "Arrival · new time"),
                    BoardTime.time(e) + plusDay(s, e), tint: e < s ? Theme.ok : Theme.warn)
            }
            if let a = BoardTime.parse(f.actual) {
                row(dep ? "airplane.departure" : "airplane.arrival", dep ? tr("Uchdi", "Вылетел", "Departed") : tr("Qoʻndi", "Приземлился", "Landed"),
                    BoardTime.time(a) + (item.sched.map { plusDay($0, a) } ?? ""), tint: Theme.ok)
            }
            if let s = item.sched, let e = item.eff, item.newTimeText != nil {
                let m = Int((e.timeIntervalSince(s) / 60).rounded())
                if m > 0 { row("hourglass", tr("Kechikish", "Задержка", "Delay"), Fmt.duration(minutes: m), tint: Theme.warn) }
            }
            if let st = f.statusText, st != item.label {
                row("text.bubble", tr("Tablodagi yozuv", "Надпись на табло", "Board says"), "«\(st)»")
            }
        }
    }

    private func plusDay(_ a: Date, _ b: Date) -> String {
        let d = BoardTime.dayShift(a, b)
        guard d != 0 else { return "" }
        return " (\(BoardTime.dayMonth(b)))"
    }

    // MARK: Aeroportda

    @ViewBuilder private var atAirport: some View {
        let bits = tiles
        section("\(tr("Aeroportda", "В аэропорту", "At the airport")) · \(airport.city)") {
            if bits.isEmpty {
                Text(hint).font(Theme.Font.sub).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 6)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(bits, id: \.self) { b in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(b.label, systemImage: b.symbol).font(Theme.Font.caption).foregroundStyle(Theme.muted).lineLimit(2)
                            Text(b.value).font(Theme.Font.display(26)).monospaced().foregroundStyle(Theme.ink)
                                .lineLimit(1).minimumScaleFactor(0.5)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.paper2, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var tiles: [BoardInfoBit] {
        var b: [BoardInfoBit] = []
        if let t = f.terminal { b.append(.init(symbol: "building.2", label: tr("Terminal", "Терминал", "Terminal"), value: t)) }
        if dep {
            if let d = f.desks { b.append(.init(symbol: "person.badge.clock", label: tr("Roʻyxatdan oʻtish stoykalari", "Стойки регистрации", "Check-in desks"), value: d)) }
            if let g = f.gate { b.append(.init(symbol: "door.left.hand.open", label: tr("Chiqish (gate)", "Выход на посадку", "Gate"), value: g)) }
        } else if let l = f.belt {
            b.append(.init(symbol: "suitcase.rolling", label: tr("Bagaj lentasi", "Багажная лента", "Baggage belt"), value: l))
        }
        return b
    }

    private var hint: String {
        let done = ["departed", "arrived", "cancelled", "diverted"].contains(f.status ?? "") || f.removedFromSource
        if done { return tr("Tabloda terminal va chiqish haqida maʼlumot boʻlmagan.", "На табло не было данных о терминале и выходе.", "The board did not list a terminal or gate.") }
        return dep
            ? tr("Terminal, stoykalar va chiqish odatda uchishdan 2–3 soat oldin eʼlon qilinadi.", "Терминал, стойки регистрации и выход обычно объявляют за 2–3 часа до вылета.",
                 "Terminal, check-in desks and gate are usually announced 2–3 hours before departure.")
            : tr("Bagaj lentasi samolyot qoʻngach eʼlon qilinadi.", "Багажную ленту объявляют после посадки самолёта.", "The baggage belt is announced after landing.")
    }

    // MARK: Reys

    private var flightInfo: some View {
        section(tr("Reys", "Рейс", "Flight")) {
            row("airplane", tr("Aviakompaniya", "Авиакомпания", "Airline"), item.airline.isEmpty ? "—" : item.airline)
            row("number", tr("Reys raqami", "Номер рейса", "Flight number"), f.flight, mono: true)
            if !f.codeshares.isEmpty {
                row("link", tr("Hamkor reyslar (codeshare)", "Совместные рейсы (codeshare)", "Codeshare flights"), f.codeshares.joined(separator: ", "), mono: true)
            }
            if let a = f.aircraft { row("airplane.circle", tr("Samolyot", "Самолёт", "Aircraft"), a) }
        }
    }

    // MARK: Amallar

    private var actions: some View {
        VStack(spacing: 10) {
            ShareLink(item: shareText) {
                Label(tr("Ulashish", "Поделиться", "Share"), systemImage: "square.and.arrow.up")
                    .font(Theme.Font.headline).frame(maxWidth: .infinity, minHeight: 44)
            }
            .primaryButton().tint(Theme.accent)
            if let url = radarURL {
                Button { openWeb(url) } label: {
                    Label(tr("Flightradar24 da kuzatish", "Следить на Flightradar24", "Track on Flightradar24"), systemImage: "location.viewfinder")
                        .font(Theme.Font.sub.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                }
                .secondaryButton().tint(Theme.accent)
            }
        }
    }

    /// Flightradar24: C6 va 2U reyslari radarda raqamsiz ko'rinadi (sayt NO_RADAR); bekor qilingan — yo'q
    private var radarURL: String? {
        let n = f.flight.uppercased().replacingOccurrences(of: " ", with: "")
        guard n.count >= 3, f.status != "cancelled", !["C6", "2U"].contains(String(n.prefix(2))),
              let q = n.lowercased().addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        return "https://www.flightradar24.com/data/flights/\(q)"
    }

    private var webLink: String {
        let prefix = Lang.current == .uz ? "" : "/\(Lang.current.rawValue)"
        var q: [String] = []
        if dir == .arr { q.append("dir=arr") }
        if day != .today { q.append("day=\(day.rawValue)") }
        let qs = q.isEmpty ? "" : "?" + q.joined(separator: "&")
        return "\(AppConfig.site)\(prefix)/tablo/\(airport.iata.lowercased())\(qs)#reys-\(airport.iata.lowercased())-\(dir.rawValue)-\(f.key)"
    }

    private var shareText: String {
        let here = "\(airport.city) (\(airport.iata))", there = "\(item.city)\(item.otherIata.map { " (\($0))" } ?? "")"
        var lines = ["\(f.flight)\(item.airline.isEmpty ? "" : " · \(item.airline)")", dep ? "\(here) → \(there)" : "\(there) → \(here)"]
        if let s = item.sched {
            var t = "\(dep ? tr("Uchish", "Вылет", "Departure") : tr("Qoʻnish", "Прилёт", "Arrival")): \(Fmt.day(s)), \(BoardTime.time(s))"
            if let n = item.newTimeText { t += " → \(n)" }
            lines.append(t + " (\(tr("Toshkent vaqti", "ташкентское время", "Tashkent time")))")
        }
        lines.append("\(tr("Holat", "Статус", "Status")): \(item.label)")
        let b = tiles.map { "\($0.label): \($0.value)" }
        if !b.isEmpty { lines.append(b.joined(separator: " · ")) }
        lines.append(webLink)
        return lines.joined(separator: "\n")
    }

    // MARK: Manba

    @ViewBuilder private var sourceLine: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let s = source, let host = BoardSource.host(s) {
                Button { openWeb(BoardSource.home(s)) } label: {
                    Label("\(tr("Manba", "Источник", "Source")): \(host)\(updatedAt.map { " · \(tr("yangilangan", "обновлено", "updated")) \(BoardTime.time($0))" } ?? "")",
                          systemImage: "link")
                        .font(Theme.Font.caption.weight(.medium)).foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
            Text(tr("Vaqtlar oʻzgarishi mumkin — aniq maʼlumotni aviakompaniyangizdan oling.", "Время может меняться — уточняйте у своей авиакомпании.",
                    "Times may change — always check with your airline."))
                .font(Theme.Font.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Yordamchilar

    /// Tashqi havola: avval oyna yopiladi (ildizdagi Safari oynasi sheet ustida ochilmaydi), keyin model.openWeb
    private func openWeb(_ s: String?) {
        guard let s else { return }
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            model.openWeb(s)
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: @escaping () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Theme.Font.title3).foregroundStyle(Theme.ink)
            Panel(padding: 14) { content() }
        }
    }

    private func row(_ symbol: String, _ title: String, _ value: String, tint: Color? = nil, mono: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol).font(.subheadline).foregroundStyle(tint ?? Theme.accent).frame(width: 22)
            Text(title).font(Theme.Font.sub).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(value).font(mono ? Theme.Font.mono : Theme.Font.body.weight(.semibold)).foregroundStyle(tint ?? Theme.ink)
                .multilineTextAlignment(.trailing).textSelection(.enabled)
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
    }
}

/// Ikki aeroport orasidagi yoy va samolyot (uchdi — o'rtada, qo'ndi — oxirida, noma'lum — chiziq uzuq)
struct BoardRouteArc: View {
    let progress: Double?
    let tone: BoardTone
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let p0 = CGPoint(x: 4, y: h - 4), p2 = CGPoint(x: w - 4, y: h - 4), c = CGPoint(x: w / 2, y: -h * 0.6)
            let t = CGFloat(shown || reduce ? (progress ?? 0.5) : 0)
            let pt = quad(p0, c, p2, t)
            let ang = atan2(deriv(p0, c, p2, t).y, deriv(p0, c, p2, t).x)
            ZStack {
                Path { $0.move(to: p0); $0.addQuadCurve(to: p2, control: c) }
                    .stroke(Theme.line, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4]))
                if let progress {
                    Path { $0.move(to: p0); $0.addQuadCurve(to: p2, control: c) }
                        .trim(from: 0, to: shown || reduce ? progress : 0)
                        .stroke(tone == .bad ? Theme.bad : Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                Circle().fill(Theme.muted).frame(width: 5, height: 5).position(p0)
                Circle().fill(Theme.muted).frame(width: 5, height: 5).position(p2)
                Image(systemName: "airplane")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(progress == nil ? Theme.muted : Theme.accent)
                    .rotationEffect(.radians(Double(ang)))
                    .position(pt)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.9).delay(0.15)) { shown = true } }
        .accessibilityHidden(true)
    }

    private func quad(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x, y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
    }
    private func deriv(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: 2 * (1 - t) * (c.x - a.x) + 2 * t * (b.x - c.x), y: 2 * (1 - t) * (c.y - a.y) + 2 * t * (b.y - c.y))
    }
}
