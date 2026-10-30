// Valyuta: Markaziy bank (cbu.uz) rasmiy kurslari, konvertor (valyuta ↔ so'm), banklar, «Sayyohlar uchun» maslahatlari.
// Ma'lumot: /api/app/v1/currency (docs/API.md «Valyuta»). Bank bosilsa — .item(bank), «Barcha banklar» — .list(bank).
import SwiftUI
import Charts

// MARK: - Modellar
struct CurrencyRate: Decodable, Hashable, Identifiable, Sendable {
    let code: String
    let name: String
    let nominal: Int
    let rate: Double
    let diff: Double
    let unit: Double
    let top: Bool?
    let trend: [Double]?
    var id: String { code }
    /// 1 birlik uchun o'zgarish
    var unitDiff: Double { nominal > 0 ? diff / Double(nominal) : diff }
}

struct CurrencyBank: Decodable, Hashable, Identifiable, Sendable {
    let card: Card
    let short: String?
    let own: String?
    let ownLabel: String?
    let cards: [String]
    let fx: Bool
    let atm: Bool
    let transfers: Bool
    let phone: String?
    let branches: Int
    var id: String { card.id }

    private enum K: String, CodingKey { case short, own, ownLabel, cards, fx, atm, transfers, phone, branches }
    init(from decoder: Decoder) throws {
        card = try Card(from: decoder)
        let c = try decoder.container(keyedBy: K.self)
        short = try? c.decodeIfPresent(String.self, forKey: .short)
        own = try? c.decodeIfPresent(String.self, forKey: .own)
        ownLabel = try? c.decodeIfPresent(String.self, forKey: .ownLabel)
        cards = (try? c.decodeIfPresent([String].self, forKey: .cards)) ?? []
        fx = (try? c.decodeIfPresent(Bool.self, forKey: .fx)) ?? false
        atm = (try? c.decodeIfPresent(Bool.self, forKey: .atm)) ?? false
        transfers = (try? c.decodeIfPresent(Bool.self, forKey: .transfers)) ?? false
        phone = try? c.decodeIfPresent(String.self, forKey: .phone)
        branches = (try? c.decodeIfPresent(Int.self, forKey: .branches)) ?? 0
    }
}

struct CurrencyTip: Decodable, Hashable, Identifiable, Sendable {
    struct Bank: Decodable, Hashable, Sendable { let slug: String; let name: String }
    let key: String
    let symbol: String?
    let title: String
    let text: String
    let banks: [Bank]?
    let systems: [String]?
    var id: String { key }
}

struct CurrencyData: Decodable, Sendable {
    struct Source: Decodable, Sendable { let name: String; let url: String?; let short: String? }
    struct Stats: Decodable, Sendable { let banks: Int; let branches: Int }
    let date: String?
    let dateLabel: String?
    let updated: Double?
    let stale: Bool?
    let som: String?
    let title: String?
    let note: String?
    let source: Source?
    let main: [String]?
    let rates: [CurrencyRate]
    let stats: Stats?
    let banks: [CurrencyBank]
    let tipsTitle: String?
    let tips: [CurrencyTip]?
}

// MARK: - Yordamchilar
enum CurrencyFmt {
    /// Valyuta kodi → bayroq (ISO 4217 ning birinchi ikki harfi — mamlakat kodi)
    static func flag(_ code: String) -> String {
        switch code {
        case "EUR": return "🇪🇺"
        case "XDR", "XAU", "XAG": return "🌐"
        default:
            let letters = Array(code.uppercased().unicodeScalars.prefix(2))
            guard letters.count == 2, letters.allSatisfy({ (65...90).contains($0.value) }) else { return "🏳️" }
            let s = letters.compactMap { Unicode.Scalar(0x1F1E6 + $0.value - 65) }
            return String(String.UnicodeScalarView(s))
        }
    }
    static func money(_ v: Double) -> String { Fmt.num(v, digits: abs(v) < 10 ? 4 : 2) }
    static func diffColor(_ d: Double) -> Color { d > 0 ? Theme.ok : d < 0 ? Theme.bad : Theme.muted }
    static func parse(_ s: String) -> Double? {
        let t = s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{00A0}", with: "").replacingOccurrences(of: ",", with: ".")
        return t.isEmpty ? nil : Double(t)
    }
}

// MARK: - Ekran
struct CurrencyScreen: View {
    var body: some View {
        Loadable(load: { try await API.shared.get("currency") as CurrencyData }) { d in
            CurrencyContent(data: d)
        }
        .background(Theme.paper)
        .navigationTitle(tr("Valyuta va banklar", "Валюта и банки", "Currency & banks"))
    }
}

private struct CurrencyContent: View {
    let data: CurrencyData
    @State private var code: String
    @State private var showAll = false
    @State private var bankFilter: String?
    @Environment(AppModel.self) private var model

    private let topRates: [CurrencyRate]
    private let otherRates: [CurrencyRate]
    private let mainRates: [CurrencyRate]

    init(data: CurrencyData) {
        self.data = data
        let main = data.main ?? ["USD", "EUR", "RUB"]
        mainRates = main.compactMap { c in data.rates.first { $0.code == c } }
        topRates = data.rates.filter { $0.top == true }
        otherRates = data.rates.filter { $0.top != true }
        let saved = UserDefaults.standard.string(forKey: "currency.code") ?? "USD"
        _code = State(initialValue: data.rates.contains { $0.code == saved } ? saved : (data.rates.first?.code ?? "USD"))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    header
                    if data.rates.isEmpty {
                        EmptyState(title: tr("Kurslar hozircha mavjud emas", "Курсы пока недоступны", "Rates are not available right now"),
                                   text: tr("Birozdan soʻng pastga tortib yangilang.", "Потяните вниз чуть позже, чтобы обновить.", "Pull down to refresh in a little while."),
                                   symbol: "banknote")
                    } else {
                        if !mainRates.isEmpty { mainCards }
                        CurrencyConverter(rates: data.rates, som: data.som ?? "UZS", note: data.note, code: $code)
                            .id("converter")
                            .padding(.horizontal, Theme.gutter)
                        ratesList(proxy)
                    }
                    if !data.banks.isEmpty { banksSection }
                    if let tips = data.tips, !tips.isEmpty { tipsSection(tips) }
                    footer
                }
                .padding(.bottom, 32)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .onChange(of: code) { _, c in UserDefaults.standard.set(c, forKey: "currency.code") }
    }

    // MARK: sarlavha
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Kicker(text: tr("Valyuta kurslari", "Курсы валют", "Exchange rates"))
            Text(data.title ?? tr("Markaziy bankning rasmiy kurslari", "Официальные курсы Центрального банка", "Central Bank official rates"))
                .font(Theme.Font.largeTitle).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 10) {
                if let d = data.dateLabel { Label(d, systemImage: "calendar").foregroundStyle(Theme.ink2) }
                Text("cbu.uz").foregroundStyle(Theme.muted)
            }
            .font(Theme.Font.sub)
            if data.stale == true {
                Label(tr("Kurslar vaqtincha yangilanmadi — oxirgi maʼlumot koʻrsatilmoqda",
                         "Курсы временно не обновились — показаны последние данные",
                         "Rates could not be refreshed — showing the latest data"), systemImage: "exclamationmark.circle")
                    .font(Theme.Font.caption.weight(.semibold)).foregroundStyle(Theme.warn)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Theme.warn.opacity(0.12), in: Capsule())
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 8)
    }

    // MARK: asosiy valyutalar (karusel)
    private var mainCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(Array(mainRates.enumerated()), id: \.element.id) { i, r in
                    Button {
                        Haptics.select()
                        withAnimation(Motion.spring) { code = r.code }
                    } label: { CurrencyMainCard(rate: r, som: data.som ?? "", selected: r.code == code) }
                    .buttonStyle(.press)
                    .appear(delay: 0.05 * Double(i))
                    .carouselEffect()
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, Theme.gutter)
        }
        .scrollTargetBehavior(.viewAligned)
    }

    // MARK: kurslar ro'yxati
    private func ratesList(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Kurslar", "Курсы", "Rates"), kicker: data.som.map { tr("1 birlik — \($0)", "за 1 единицу — \($0)", "per 1 unit — \($0)") })
            VStack(spacing: 0) {
                ForEach(Array(topRates.enumerated()), id: \.element.id) { i, r in
                    if i > 0 { Divider().overlay(Theme.line.opacity(0.6)).padding(.leading, 56) }
                    row(r, proxy)
                }
                if showAll {
                    ForEach(otherRates) { r in
                        Divider().overlay(Theme.line.opacity(0.6)).padding(.leading, 56)
                        row(r, proxy)
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
            .padding(.horizontal, Theme.gutter)
            if !otherRates.isEmpty {
                Button {
                    Haptics.select()
                    withAnimation(Motion.spring) { showAll.toggle() }
                } label: {
                    Label(showAll ? tr("Kamroq koʻrsatish", "Свернуть", "Show less")
                                  : tr("Barcha valyutalar (\(data.rates.count))", "Все валюты (\(data.rates.count))", "All currencies (\(data.rates.count))"),
                          systemImage: showAll ? "chevron.up" : "chevron.down")
                        .font(Theme.Font.sub.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .secondaryButton().tint(Theme.accent)
                .padding(.horizontal, Theme.gutter)
            }
        }
    }

    private func row(_ r: CurrencyRate, _ proxy: ScrollViewProxy) -> some View {
        Button {
            Haptics.select()
            withAnimation(Motion.spring) { code = r.code; proxy.scrollTo("converter", anchor: .top) }
        } label: {
            CurrencyRow(rate: r, selected: r.code == code)
        }
        .buttonStyle(.press)
        .accessibilityHint(tr("Konvertorda tanlash", "Выбрать в конвертере", "Select in converter"))
    }

    // MARK: banklar
    private var filteredBanks: [CurrencyBank] {
        switch bankFilter {
        case "fx": data.banks.filter(\.fx)
        case "atm": data.banks.filter(\.atm)
        case "transfers": data.banks.filter(\.transfers)
        default: data.banks
        }
    }

    private var banksSection: some View {
        let list = filteredBanks
        let chips: [(key: String, label: String, count: Int?)] = [
            ("fx", tr("Valyuta ayirboshlash", "Обмен валюты", "Currency exchange"), data.banks.filter(\.fx).count),
            ("atm", tr("Xorijiy karta bankomati", "Банкоматы для иностранных карт", "ATMs for foreign cards"), data.banks.filter(\.atm).count),
            ("transfers", tr("Pul oʻtkazmalari", "Денежные переводы", "Money transfers"), data.banks.filter(\.transfers).count),
        ].filter { ($0.count ?? 0) > 0 }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: tr("Banklar", "Банки", "Banks"),
                          kicker: data.stats.map { tr("\($0.banks) bank · \($0.branches) filial", "\($0.banks) банков · \($0.branches) филиалов", "\($0.banks) banks · \($0.branches) branches") },
                          actionTitle: tr("Hammasi", "Все", "See all")) {
                model.open(.list(ListSpec(type: "bank", title: tr("Banklar", "Банки", "Banks"))))
            }
            if !chips.isEmpty { ChipBar(items: chips, selected: $bankFilter) }
            VStack(spacing: 0) {
                ForEach(Array(list.prefix(8).enumerated()), id: \.element.id) { i, b in
                    if i > 0 { Divider().overlay(Theme.line.opacity(0.6)).padding(.leading, 60) }
                    CurrencyBankRow(bank: b)
                }
            }
            .padding(.horizontal, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
            .padding(.horizontal, Theme.gutter)
            .animation(Motion.snappy, value: bankFilter)
            if list.count > 8 {
                Button {
                    model.open(.list(ListSpec(type: "bank", title: tr("Banklar", "Банки", "Banks"))))
                } label: {
                    Label(tr("Barcha banklar (\(data.banks.count))", "Все банки (\(data.banks.count))", "All banks (\(data.banks.count))"), systemImage: "building.columns")
                        .font(Theme.Font.sub.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                }
                .secondaryButton().tint(Theme.accent)
                .padding(.horizontal, Theme.gutter)
            }
        }
    }

    // MARK: sayyohlar uchun
    private func tipsSection(_ tips: [CurrencyTip]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: data.tipsTitle ?? tr("Sayyohlar uchun", "Путешественникам", "For travellers"),
                          kicker: tr("Pul va kartalar", "Деньги и карты", "Money & cards"))
            VStack(spacing: 12) {
                ForEach(Array(tips.enumerated()), id: \.element.id) { i, tip in
                    CurrencyTipCard(tip: tip).appear(delay: 0.04 * Double(i))
                }
            }
            .padding(.horizontal, Theme.gutter)
        }
    }

    // MARK: manba
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { model.openWeb(data.source?.url) } label: {
                Label(data.source?.name ?? "cbu.uz", systemImage: "building.columns")
                    .font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.accent).multilineTextAlignment(.leading)
                    .frame(minHeight: 32, alignment: .leading)
            }
            .buttonStyle(.plain)
            if let n = data.note { Text(n).font(Theme.Font.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true) }
            if let u = data.updated, u > 0 {
                let d = Date(timeIntervalSince1970: u / 1000)
                Label(tr("Yangilangan: \(Fmt.day(d)), \(Fmt.time(d))", "Обновлено: \(Fmt.day(d)), \(Fmt.time(d))", "Updated \(Fmt.day(d)), \(Fmt.time(d))"), systemImage: "clock")
                    .font(Theme.Font.caption).foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, Theme.gutter)
    }
}

// MARK: - Asosiy valyuta kartasi (kurs, o'zgarish, so'nggi 30 kun grafigi)
private struct CurrencyMainCard: View {
    let rate: CurrencyRate
    let som: String
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(CurrencyFmt.flag(rate.code)).font(.title2).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(rate.code).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                    Text(rate.name).font(Theme.Font.caption).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            Text(CurrencyFmt.money(rate.unit)).font(Theme.Font.display(28)).foregroundStyle(Theme.ink)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            HStack(spacing: 6) {
                CurrencyDiff(diff: rate.unitDiff)
                Text(som).font(Theme.Font.caption).foregroundStyle(Theme.muted)
            }
            if let tr0 = rate.trend, tr0.count >= 3 {
                CurrencySpark(values: tr0, color: CurrencyFmt.diffColor((tr0.last ?? 0) - (tr0.first ?? 0)))
                    .frame(height: 40)
            }
        }
        .padding(14)
        .frame(width: 210, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
            .strokeBorder(selected ? Theme.accent : Theme.line.opacity(0.6), lineWidth: selected ? 2 : 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rate.name), \(CurrencyFmt.money(rate.unit)) \(som), \(CurrencyDiff.spoken(rate.unitDiff))")
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

/// So'nggi kunlar grafigi (o'qlarsiz)
private struct CurrencySpark: View {
    let values: [Double]
    let color: Color
    var body: some View {
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        let pad = max((hi - lo) * 0.15, 0.0001)
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                AreaMark(x: .value("Kun", i), yStart: .value("Min", lo - pad), yEnd: .value("Kurs", v))
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.25), color.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Kun", i), y: .value("Kurs", v))
                    .foregroundStyle(color)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartLegend(.hidden)
        .accessibilityHidden(true)
    }
}

/// ↑ 12,5 / ↓ 3,1 — rangli o'zgarish
private struct CurrencyDiff: View {
    let diff: Double
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: diff > 0 ? "arrowtriangle.up.fill" : diff < 0 ? "arrowtriangle.down.fill" : "equal")
                .font(.system(size: 8, weight: .bold))
            Text(CurrencyFmt.money(abs(diff))).monospacedDigit()
        }
        .font(Theme.Font.caption.weight(.semibold))
        .foregroundStyle(CurrencyFmt.diffColor(diff))
    }
    static func spoken(_ d: Double) -> String {
        if d > 0 { return tr("oshdi: \(CurrencyFmt.money(d))", "вырос на \(CurrencyFmt.money(d))", "up \(CurrencyFmt.money(d))") }
        if d < 0 { return tr("tushdi: \(CurrencyFmt.money(-d))", "снизился на \(CurrencyFmt.money(-d))", "down \(CurrencyFmt.money(-d))") }
        return tr("oʻzgarmadi", "без изменений", "unchanged")
    }
}

private struct CurrencyRow: View {
    let rate: CurrencyRate
    let selected: Bool
    var body: some View {
        HStack(spacing: 12) {
            Text(CurrencyFmt.flag(rate.code)).font(.title2).frame(width: 32).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(rate.code).font(Theme.Font.headline).foregroundStyle(selected ? Theme.accent : Theme.ink)
                Text(rate.name).font(Theme.Font.caption).foregroundStyle(Theme.muted).lineLimit(2)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFmt.money(rate.unit)).font(Theme.Font.body.weight(.semibold).monospacedDigit()).foregroundStyle(Theme.ink)
                CurrencyDiff(diff: rate.unitDiff)
            }
        }
        .padding(.vertical, 10)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rate.name) (\(rate.code)): \(CurrencyFmt.money(rate.unit)), \(CurrencyDiff.spoken(rate.unitDiff))")
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Konvertor
private struct CurrencyConverter: View {
    let rates: [CurrencyRate]
    let som: String
    let note: String?
    @Binding var code: String
    @State private var amountText = "100"
    @State private var toUZS = true
    @State private var spin = 0.0
    @FocusState private var focused: Bool
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rate: CurrencyRate? { rates.first { $0.code == code } }
    private var amount: Double { CurrencyFmt.parse(amountText) ?? 0 }
    private var result: Double {
        guard let r = rate, r.unit > 0 else { return 0 }
        return toUZS ? amount * r.unit : amount / r.unit
    }

    var body: some View {
        Panel(padding: 16) {
            HStack {
                Label(tr("Konvertor", "Конвертер", "Converter"), systemImage: "arrow.left.arrow.right")
                    .font(Theme.Font.kicker).foregroundStyle(Theme.accent)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if focused {
                    Button(tr("Tayyor", "Готово", "Done")) { focused = false }
                        .font(Theme.Font.sub.weight(.semibold)).tint(Theme.accent)
                        .frame(minHeight: 32)
                }
            }
            VStack(spacing: 0) {
                if toUZS {
                    inputRow(isCurrency: true)
                    swapButton
                    outputRow(isCurrency: false)
                } else {
                    inputRow(isCurrency: false)
                    swapButton
                    outputRow(isCurrency: true)
                }
            }
            .padding(.top, 12)
            if let r = rate {
                Text("1 \(r.code) = \(CurrencyFmt.money(r.unit)) \(som)")
                    .font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.ink2)
                    .padding(.top, 10)
                    .contentTransition(.numericText())
            }
            if let note { Text(note).font(Theme.Font.caption).foregroundStyle(Theme.muted).padding(.top, 4).fixedSize(horizontal: false, vertical: true) }
        }
    }

    // Yuqori qator — summa kiritiladi
    private func inputRow(isCurrency: Bool) -> some View {
        HStack(spacing: 10) {
            badge(isCurrency: isCurrency)
            TextField("0", text: $amountText)
                .keyboardType(.decimalPad)
                .focused($focused)
                .multilineTextAlignment(.trailing)
                .font(Theme.Font.display(28).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .onChange(of: amountText) { _, v in if v.count > 15 { amountText = String(v.prefix(15)) } }
                .accessibilityLabel(tr("Miqdor", "Сумма", "Amount") + ", " + (isCurrency ? code : som))
        }
        .padding(12)
        .background(Theme.paper2, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
        .matchedGeometryEffect(id: isCurrency ? "ccy" : "uzs", in: ns)
    }

    // Pastki qator — natija
    private func outputRow(isCurrency: Bool) -> some View {
        HStack(spacing: 10) {
            badge(isCurrency: isCurrency)
            Spacer(minLength: 4)
            Text(CurrencyFmt.money(result))
                .font(Theme.Font.display(28).monospacedDigit())
                .foregroundStyle(Theme.accent)
                .lineLimit(1).minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: result))
                .animation(reduceMotion ? nil : Motion.snappy, value: result)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(Theme.paper2.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
        .matchedGeometryEffect(id: isCurrency ? "ccy" : "uzs", in: ns)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("Natija", "Результат", "Result") + ": \(CurrencyFmt.money(result)) \(isCurrency ? code : som)")
    }

    @ViewBuilder
    private func badge(isCurrency: Bool) -> some View {
        if isCurrency {
            Menu {
                Picker(tr("Valyuta", "Валюта", "Currency"), selection: $code) {
                    ForEach(rates) { r in Text("\(CurrencyFmt.flag(r.code)) \(r.code) — \(r.name)").tag(r.code) }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(CurrencyFmt.flag(code)).font(.title3)
                    Text(code).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.semibold)).foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 10).frame(minHeight: 44)
                .background(Theme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.line))
            }
            .accessibilityLabel(tr("Valyuta", "Валюта", "Currency") + ": \(rate?.name ?? code)")
        } else {
            HStack(spacing: 6) {
                Text("🇺🇿").font(.title3)
                Text("UZS").font(Theme.Font.headline).foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 10).frame(minHeight: 44)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(som)
        }
    }

    private var swapButton: some View {
        Button {
            Haptics.tap()
            // natija yangi summa bo'ladi — almashtirilganda qiymat saqlanadi
            let r = result
            withAnimation(reduceMotion ? nil : Motion.spring) {
                toUZS.toggle()
                spin += 180
                if amount > 0 { amountText = Fmt.num(r, digits: 2).replacingOccurrences(of: " ", with: "") }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.accentInk)
                .frame(width: 44, height: 44)
                .background(Theme.accent, in: Circle())
                .rotationEffect(.degrees(spin))
                .shadow(color: Theme.accent.opacity(0.3), radius: 6, y: 2)
        }
        .buttonStyle(.press)
        .padding(.vertical, -10)
        .zIndex(1)
        .accessibilityLabel(tr("Yoʻnalishni almashtirish", "Поменять направление", "Swap direction"))
    }
}

// MARK: - Bank qatori
private struct CurrencyBankRow: View {
    let bank: CurrencyBank
    @Environment(AppModel.self) private var model

    private var initials: String {
        let name = bank.short ?? bank.card.name
        let words = name.replacingOccurrences(of: "«", with: "").replacingOccurrences(of: "»", with: "").split(separator: " ").filter { $0.first?.isLetter == true }
        if words.count >= 2, let a = words[0].first, let b = words[1].first { return String([a, b]).uppercased() }
        let w = words.first.map(String.init) ?? name
        if w.count <= 4, w == w.uppercased() { return String(w.prefix(3)) }
        return String(w.prefix(2)).uppercased()
    }
    private var tint: Color {
        let palette = [Theme.accent, Theme.teal, Theme.gold, Theme.ok]
        let h = (bank.card.slug ?? bank.card.name).unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 9973 }
        return palette[h % palette.count]
    }

    var body: some View {
        Button { model.open(bank.card) } label: {
            HStack(spacing: 12) {
                Text(initials)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(bank.short ?? bank.card.name).font(Theme.Font.headline).foregroundStyle(Theme.ink).lineLimit(2)
                    if let o = bank.ownLabel { Text(o).font(Theme.Font.caption).foregroundStyle(Theme.muted).lineLimit(1) }
                    HStack(spacing: 6) {
                        ForEach(bank.cards.filter { ["Visa", "Mastercard", "UnionPay"].contains($0) }, id: \.self) { c in
                            Text(c).font(.caption2.weight(.semibold)).foregroundStyle(Theme.ink2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.paper2, in: Capsule())
                        }
                        if bank.atm {
                            Image(systemName: "creditcard.and.123").font(.caption2).foregroundStyle(Theme.teal)
                                .accessibilityLabel(tr("Xorijiy karta bankomati", "Банкоматы для иностранных карт", "ATMs for foreign cards"))
                        }
                    }
                }
                Spacer(minLength: 4)
                if bank.branches > 0 {
                    Text("\(bank.branches)").font(Theme.Font.caption.monospacedDigit()).foregroundStyle(Theme.muted)
                        .accessibilityLabel(tr("\(bank.branches) filial", "\(bank.branches) филиалов", "\(bank.branches) branches"))
                }
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .contextMenu { CardMenu(card: bank.card) }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sayyohlar uchun maslahat
private struct CurrencyTipCard: View {
    let tip: CurrencyTip
    @Environment(AppModel.self) private var model

    var body: some View {
        Panel(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: tip.symbol ?? "info.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40)
                    .background(Theme.accent.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.title).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                    Text(tip.text).font(Theme.Font.sub).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
                    if let s = tip.systems, !s.isEmpty {
                        Text(s.joined(separator: " · ")).font(Theme.Font.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            if let banks = tip.banks, !banks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(banks.prefix(10), id: \.slug) { b in
                            Button { model.open(.item(ItemRef(type: "bank", slug: b.slug))) } label: {
                                Text(b.name).font(Theme.Font.caption.weight(.semibold)).foregroundStyle(Theme.ink)
                                    .padding(.horizontal, 10).frame(minHeight: 32)
                                    .background(Theme.paper2, in: Capsule())
                            }
                            .buttonStyle(.press)
                        }
                        if banks.count > 10 {
                            Text("+\(banks.count - 10)").font(Theme.Font.caption).foregroundStyle(Theme.muted).padding(.horizontal, 6)
                        }
                    }
                }
                .padding(.top, 10)
                .scrollClipDisabled()
            }
        }
    }
}
