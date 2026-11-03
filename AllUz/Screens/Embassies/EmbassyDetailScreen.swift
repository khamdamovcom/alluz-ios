// Bitta vakolatxona: sarlavha (bayroq, tur, nom), tezkor tugmalar (qo'ng'iroq, sayt, yo'nalish), aloqa (telefonlar, konsullik va
// shoshilinch liniyalar, e-mail, Telegram), manzil + xarita, ish vaqti, xizmatlar, qo'shimcha akkreditatsiya, bog'liq vakolatxonalar,
// shu davlatning boshqalari, viza qoidalari, manbalar, tekshirilgan sana, saytda ochish. API: embassies/:slug.
// Elchixona sayti http bo'lishi mumkin (uzembassy.ru faqat http) — faqat shu tugmalar model.openExternalHTTP orqali.
import SwiftUI

struct EmbassyDetailScreen: View {
    let slug: String

    var body: some View {
        Loadable(load: { [slug] in try await API.shared.get("embassies/" + slug) as EmbassyDetail }) { d in
            EmbassyDetailContent(d: d)
        }
        .background(Theme.paper)
        .navigationTitle(tr("Vakolatxona", "Представительство", "Mission"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EmbassyDetailContent: View {
    let d: EmbassyDetail
    @Environment(AppModel.self) private var model

    private var r: EmbassyRow { d.row }
    private var countryName: String { d.countryInfo?.name ?? r.country }
    private var flag: String { d.countryInfo?.flag ?? "🏳️" }
    private var website: URL? { EmbassyStyle.web(r.website) }
    private var firstPhone: EmbassyPhone? { d.phones.first ?? r.phone }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerView.appear()
                actions.appear(delay: 0.05)
                contacts.appear(delay: 0.08)
                location
                hoursPanel
                if let s = d.services, !s.isEmpty { servicesPanel(s) }
                if !d.coversInfo.isEmpty { coversPanel }
                relatedPanel
                if !d.same.isEmpty {
                    rowsPanel(r.isIn ? tr("Shu davlatning boshqa vakolatxonalari", "Другие представительства этой страны", "Other missions of this country")
                                     : tr("Oʻzbekistonning shu davlatdagi boshqa vakolatxonalari", "Другие представительства Узбекистана в этой стране", "Other Uzbek missions in this country"),
                              kicker: "\(flag) \(countryName)", rows: d.same)
                }
                if !d.sources.isEmpty { sourcesPanel }
                footer
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let w = d.web, let u = URL(string: w), u.scheme == "https", u.host == AppConfig.host {
                    ShareLink(item: u) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel(tr("Ulashish", "Поделиться", "Share"))
                }
            }
        }
    }

    // MARK: sarlavha
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(flag).font(.system(size: 52)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    EmbassyKindBadge(kind: r.kind, label: r.kindLabel)
                    Text(EmbassyStyle.dirLong(r.dir)).font(Theme.Font.caption).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(r.name).font(Theme.Font.display(26)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            let sub = [r.city, countryName].compactMap { $0 }.filter { !$0.isEmpty }
            if !sub.isEmpty {
                Label(sub.joined(separator: " · "), systemImage: "mappin.and.ellipse")
                    .font(Theme.Font.sub).foregroundStyle(Theme.ink2)
            }
        }
    }

    // MARK: tezkor tugmalar
    private var actions: some View {
        HStack(spacing: 10) {
            if let p = firstPhone, let u = EmbassyStyle.tel(p) {
                actionButton(tr("Qoʻngʻiroq", "Позвонить", "Call"), "phone.fill", primary: true) { model.openURL(u) }
            }
            if let u = website {
                actionButton(tr("Sayt", "Сайт", "Website"), "globe", primary: firstPhone == nil) { model.openExternalHTTP(u) }
            }
            if let lat = r.lat, let lon = r.lon, let u = URL(string: "maps://?daddr=\(lat),\(lon)&dirflg=d") {
                actionButton(tr("Yoʻnalish", "Маршрут", "Directions"), "arrow.triangle.turn.up.right.diamond.fill", primary: false) { model.openURL(u) }
            }
        }
        .glassGroup()
    }

    private func actionButton(_ title: String, _ symbol: String, primary: Bool, _ action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                Text(title).font(Theme.Font.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(primary ? Theme.accentInk : Theme.accent)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(primary ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.accent.opacity(0.12)),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
        }
        .buttonStyle(.press)
        .accessibilityLabel(title)
    }

    // MARK: aloqa
    @ViewBuilder private var contacts: some View {
        let hasAny = !d.phones.isEmpty || !d.consularPhones.isEmpty || !d.emergencyPhones.isEmpty || d.email != nil || d.telegram != nil || website != nil
        EmbassyBlock(title: tr("Aloqa", "Контакты", "Contacts"), symbol: "phone") {
            if !hasAny {
                Text(tr("Telefon raqami rasmiy manbada koʻrsatilmagan.", "Телефон в официальном источнике не указан.", "No phone number is given in the official source."))
                    .font(Theme.Font.sub).foregroundStyle(Theme.muted).padding(.vertical, 10)
            }
            ForEach(d.phones, id: \.self) { p in phoneRow(p, tr("Telefon", "Телефон", "Phone"), "phone") }
            ForEach(d.consularPhones, id: \.self) { p in phoneRow(p, tr("Konsullik boʻlimi", "Консульский отдел", "Consular section"), "person.text.rectangle") }
            ForEach(d.emergencyPhones, id: \.self) { p in
                phoneRow(p, tr("Fuqarolar uchun shoshilinch liniya", "Экстренная линия для граждан", "Emergency line for nationals"), "light.beacon.max")
            }
            if let e = d.email, e.contains("@"), !e.contains(" "), !e.contains("?"), let u = URL(string: "mailto:" + e) {
                InfoRow(symbol: "envelope", title: "E-mail", value: e) { model.openURL(u) }
            }
            if let t = d.telegram, let u = URL(string: t), u.scheme == "https", u.host == "t.me" {
                InfoRow(symbol: "paperplane", title: "Telegram", value: "@" + u.lastPathComponent) { model.openURL(u) }
            }
            if let u = website {
                InfoRow(symbol: "globe", title: tr("Rasmiy sayt", "Официальный сайт", "Official website"), value: EmbassyStyle.domain(u)) { model.openExternalHTTP(u) }
            }
        }
    }

    private func phoneRow(_ p: EmbassyPhone, _ title: String, _ symbol: String) -> some View {
        let action: (() -> Void)? = EmbassyStyle.tel(p).map { u in { model.openURL(u) } }
        return InfoRow(symbol: symbol, title: title, value: p.value, action: action)
            .accessibilityHint(tr("Qoʻngʻiroq qilish", "Позвонить", "Call"))
    }

    // MARK: manzil + xarita
    @ViewBuilder private var location: some View {
        if r.address != nil || (r.lat != nil && r.lon != nil) {
            EmbassyBlock(title: tr("Manzil", "Адрес", "Address"), symbol: "map", padded: false) {
                if let lat = r.lat, let lon = r.lon {
                    Button {
                        Haptics.tap()
                        let q = r.name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
                        if let u = URL(string: "maps://?ll=\(lat),\(lon)&q=\(q)") { model.openURL(u) }
                    } label: {
                        DetailMiniMap(lat: lat, lon: lon, span: 0.01, title: r.name, symbol: EmbassyStyle.symbol(r.kind))
                            .frame(height: 180)
                            .overlay(alignment: .bottomTrailing) {
                                Label(tr("Xaritada", "На карте", "Open in Maps"), systemImage: "arrow.up.forward.app")
                                    .font(Theme.Font.caption.weight(.semibold)).foregroundStyle(Theme.ink)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .glassBackground(Capsule(), fallback: .regularMaterial)
                                    .padding(10)
                            }
                    }
                    .buttonStyle(.press)
                    .accessibilityLabel(tr("Xarita: \(r.name)", "Карта: \(r.name)", "Map: \(r.name)"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.address ?? [r.city, countryName].compactMap { $0 }.joined(separator: ", "))
                        .font(Theme.Font.body).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    if r.lat == nil {
                        Text(tr("Koordinata tasdiqlanmagan — manzil boʻyicha qidiring.", "Координаты не подтверждены — ищите по адресу.", "Location not verified — search by the address."))
                            .font(Theme.Font.caption).foregroundStyle(Theme.muted)
                    }
                }
                .padding(14)
            }
        }
    }

    // MARK: ish vaqti, xizmatlar, akkreditatsiya
    @ViewBuilder private var hoursPanel: some View {
        if d.hours != nil || d.consularHours != nil {
            EmbassyBlock(title: tr("Ish vaqti", "Часы работы", "Opening hours"), symbol: "clock") {
                if let h = d.hours { InfoRow(symbol: "clock", title: tr("Ish vaqti", "Часы работы", "Opening hours"), value: h) }
                if let h = d.consularHours { InfoRow(symbol: "person.text.rectangle", title: tr("Konsullik qabuli", "Консульский приём", "Consular reception"), value: h) }
            }
        }
    }

    private func servicesPanel(_ s: String) -> some View {
        EmbassyBlock(title: tr("Xizmatlar va qamrov", "Услуги и округ", "Services and coverage"), symbol: "list.bullet.rectangle") {
            Text(s).font(Theme.Font.body).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .padding(.vertical, 10)
        }
    }

    private var coversPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("Shuningdek akkreditatsiyalangan", "Также аккредитовано", "Also accredited to")).font(Theme.Font.title3).foregroundStyle(Theme.ink)
            DetailFlow(spacing: 8) {
                ForEach(d.coversInfo, id: \.code) { c in
                    Text("\(c.flag ?? "") \(c.name)").font(Theme.Font.sub).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Theme.card, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.line))
                }
            }
        }
    }

    // MARK: bog'liq vakolatxonalar va viza
    private var relatedPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if d.related.isEmpty {
                Text(r.isIn ? tr("Oʻzbekistonning bu davlatdagi vakolatxonasi haqida tekshirilgan maʼlumot hali yoʻq.", "Проверенных данных о представительстве Узбекистана в этой стране пока нет.", "No verified data yet on an Uzbek mission in this country.")
                            : tr("Bu davlatning Oʻzbekistondagi vakolatxonasi haqida tekshirilgan maʼlumot hali yoʻq.", "Проверенных данных о представительстве этой страны в Узбекистане пока нет.", "No verified data yet on this country’s mission in Uzbekistan."))
                    .font(Theme.Font.sub).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            } else {
                rowsPanel(r.isIn ? tr("Oʻzbekistonning shu davlatdagi vakolatxonasi", "Представительство Узбекистана в этой стране", "Uzbekistan’s mission in this country")
                                 : tr("Shu davlatning Oʻzbekistondagi vakolatxonasi", "Представительство этой страны в Узбекистане", "This country’s mission in Uzbekistan"),
                          kicker: tr("Bogʻliq vakolatxonalar", "Связанные представительства", "Related missions"), rows: d.related)
            }
            if r.country.count == 2, r.country != "UZ" {
                Button { Haptics.tap(); model.open(.visa(r.country)) } label: {
                    HStack(spacing: 12) {
                        Text(flag).font(.system(size: 26)).accessibilityHidden(true)
                        Text(tr("\(countryName) fuqarolari uchun viza qoidalari", "Визовые правила для граждан страны: \(countryName)", "Visa rules for citizens of \(countryName)"))
                            .font(Theme.Font.headline).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                    }
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.press)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func rowsPanel(_ title: String, kicker: String, rows: [EmbassyRow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Kicker(text: kicker)
                Text(title).font(Theme.Font.title3).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                    EmbassyRowView(row: row)
                    if i < rows.count - 1 { Divider().overlay(Theme.line) }
                }
            }
            .padding(.horizontal, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
        }
    }

    // MARK: manbalar va pastki qism
    private var sourcesPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("Manbalar", "Источники", "Sources")).font(Theme.Font.title3).foregroundStyle(Theme.ink)
            DetailFlow(spacing: 8) {
                ForEach(d.sources, id: \.self) { s in
                    if let u = EmbassyStyle.web(s) {
                        Button { model.openURL(u) } label: {
                            Label(EmbassyStyle.domain(u), systemImage: "link").font(Theme.Font.caption.weight(.medium)).foregroundStyle(Theme.accent)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(Theme.accent.opacity(0.1), in: Capsule())
                        }
                        .buttonStyle(.press)
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let c = d.checked {
                Label(tr("Tekshirilgan: \(EmbassyStyle.date(c))", "Проверено: \(EmbassyStyle.date(c))", "Checked: \(EmbassyStyle.date(c))"), systemImage: "checkmark.seal")
                    .font(Theme.Font.caption).foregroundStyle(Theme.muted)
            }
            if let w = d.web, let u = URL(string: w), u.scheme == "https", u.host == AppConfig.host {
                Button { Haptics.tap(); model.webURL = IdentifiedURL(url: u) } label: {
                    Label(tr("Saytda ochish", "Открыть на сайте", "Open on the website"), systemImage: "safari")
                        .font(Theme.Font.sub.weight(.semibold)).frame(maxWidth: .infinity)
                }
                .secondaryButton()
            }
        }
    }
}

/// Sarlavhali oq panel (ichida InfoRow'lar)
private struct EmbassyBlock<Content: View>: View {
    let title: String
    let symbol: String
    var padded = true
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label { Text(title).font(Theme.Font.title3).foregroundStyle(Theme.ink) } icon: {
                Image(systemName: symbol).foregroundStyle(Theme.accent)
            }
            .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) { content() }
                .padding(.horizontal, padded ? 14 : 0)
                .padding(.vertical, padded ? 4 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
        }
    }
}
