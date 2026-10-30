// Birinchi ochilish (fullScreenCover): 1) xush kelibsiz + til tanlash, 2) imkoniyatlar (oflayn, xarita, tablo), 3) maxfiylik.
// Til darhol emas, «Boshlash» bosilganda qo'llanadi (model.lang o'zgarsa butun ilova qayta chiziladi) — shu sababli bu ekran
// matnlari tanlangan til bo'yicha o'zi tarjima qilinadi (OnbText).
import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var page = 0
    @State private var lang: Lang = Lang.current

    private let pages = 3

    var body: some View {
        let t = OnbText(lang: lang)
        ZStack {
            OnbBackdrop(page: page, reduce: reduce)
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < pages - 1 {
                        Button(t("Oʻtkazib yuborish", "Пропустить", "Skip")) { finish() }
                            .font(Theme.Font.sub.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                            .frame(minHeight: 44)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, Theme.gutter + 4)
                .frame(height: 48)

                TabView(selection: $page) {
                    OnbWelcome(t: t, lang: $lang, active: page == 0).tag(0)
                    OnbFeatures(t: t, active: page == 1).tag(1)
                    OnbPrivacy(t: t, active: page == 2).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 18) {
                    HStack(spacing: 7) {
                        ForEach(0..<pages, id: \.self) { i in
                            Capsule().fill(i == page ? Theme.accent : Theme.line)
                                .frame(width: i == page ? 24 : 8, height: 8)
                        }
                    }
                    .accessibilityElement()
                    .accessibilityLabel(t("Sahifa", "Страница", "Page"))
                    .accessibilityValue("\(page + 1) / \(pages)")

                    Button {
                        if page < pages - 1 { Haptics.tap(); withAnimation(Motion.spring) { page += 1 } } else { finish() }
                    } label: {
                        Text(page < pages - 1 ? t("Davom etish", "Далее", "Continue") : t("Boshlash", "Начать", "Get started"))
                            .font(Theme.Font.headline)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .contentTransition(.opacity)
                    }
                    .primaryButton()
                    .controlSize(.large)
                    .tint(Theme.accent)
                    .padding(.horizontal, Theme.gutter + 8)
                }
                .padding(.bottom, 20)
                .animation(Motion.snappy, value: page)
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .environment(\.locale, lang.locale)
        .interactiveDismissDisabled()
    }

    private func finish() {
        Haptics.success()
        let picked = lang
        model.onboarded = true
        // Til o'zgargan bo'lsagina — ilova yangi tilda qayta chiziladi
        if picked != model.lang { model.lang = picked }
    }
}

/// Onboarding matnlari — tanlangan (hali qo'llanmagan) til bo'yicha
private struct OnbText {
    let lang: Lang
    func callAsFunction(_ uz: String, _ ru: String, _ en: String) -> String {
        switch lang { case .uz: uz; case .ru: ru; case .en: en }
    }
}

// MARK: - Fon: sekin suzuvchi rangli dog'lar

private struct OnbBackdrop: View {
    let page: Int
    let reduce: Bool
    @State private var drift = false
    var body: some View {
        GeometryReader { g in
            ZStack {
                Circle().fill(Theme.accent.opacity(0.20))
                    .frame(width: g.size.width * 0.9)
                    .offset(x: -g.size.width * 0.35 + CGFloat(page) * 40, y: -g.size.height * 0.32 + (drift ? 18 : -18))
                Circle().fill(Theme.teal.opacity(0.16))
                    .frame(width: g.size.width * 0.8)
                    .offset(x: g.size.width * 0.4 - CGFloat(page) * 30, y: g.size.height * 0.05 + (drift ? -24 : 24))
                Circle().fill(Theme.gold.opacity(0.16))
                    .frame(width: g.size.width * 0.6)
                    .offset(x: -g.size.width * 0.2 + CGFloat(page) * 60, y: g.size.height * 0.38 + (drift ? 10 : -10))
            }
            .frame(width: g.size.width, height: g.size.height)
            .blur(radius: 60)
        }
        .ignoresSafeArea()
        .animation(Motion.spring, value: page)
        .onAppear {
            guard !reduce else { return }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) { drift = true }
        }
        .accessibilityHidden(true)
    }
}

/// Sahifa elementi: sahifa faollashganda pastdan ketma-ket chiqadi
private struct OnbReveal: ViewModifier {
    let active: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduce
    func body(content: Content) -> some View {
        content
            .opacity(active || reduce ? 1 : 0)
            .offset(y: active || reduce ? 0 : 22)
            .animation(Motion.spring.delay(active ? delay : 0), value: active)
    }
}
private extension View {
    func onbReveal(_ active: Bool, _ delay: Double = 0) -> some View { modifier(OnbReveal(active: active, delay: delay)) }
}

// MARK: - 1. Xush kelibsiz + til

private struct OnbWelcome: View {
    let t: OnbText
    @Binding var lang: Lang
    let active: Bool
    @State private var spin = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 12)
                Image("BrandMark").resizable().frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: Theme.accent.opacity(0.35), radius: 24, y: 10)
                    .scaleEffect(active || reduce ? 1 : 0.6)
                    .rotationEffect(.degrees(spin || reduce ? 0 : -25))
                    .opacity(active || reduce ? 1 : 0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.62), value: active)
                    .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.6)) { spin = true } }
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(t("Xush kelibsiz", "Добро пожаловать", "Welcome to"))
                        .font(Theme.Font.title3).foregroundStyle(Theme.accent)
                    Text("All Uzbekistan").font(Theme.Font.display(40)).foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                    Text(t("Obidalar va tabiat, mehmonxona va restoranlar, reyslar va poyezdlar — butun Oʻzbekiston bir joyda.",
                           "Памятники и природа, отели и рестораны, рейсы и поезда — весь Узбекистан в одном месте.",
                           "Monuments and nature, hotels and restaurants, flights and trains — all of Uzbekistan in one place."))
                        .font(Theme.Font.body).foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .onbReveal(active, 0.1)

                VStack(alignment: .leading, spacing: 10) {
                    Kicker(text: t("Ilova tili", "Язык приложения", "App language"), color: Theme.muted)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        ForEach(Lang.allCases) { l in
                            Button {
                                Haptics.select()
                                withAnimation(Motion.snappy) { lang = l }
                            } label: {
                                HStack(spacing: 12) {
                                    Text(flagCode(l)).font(Theme.Font.mono).foregroundStyle(Theme.accent).frame(width: 34)
                                    Text(l.title).font(Theme.Font.body.weight(.medium)).foregroundStyle(Theme.ink)
                                    Spacer()
                                    Image(systemName: lang == l ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(lang == l ? Theme.accent : Theme.line)
                                        .contentTransition(.symbolEffect(.replace))
                                }
                                .padding(.horizontal, 16)
                                .frame(minHeight: 52)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.press)
                            .accessibilityAddTraits(lang == l ? .isSelected : [])
                            if l != Lang.allCases.last { Divider().overlay(Theme.line).padding(.leading, 62) }
                        }
                    }
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
                }
                .onbReveal(active, 0.2)
            }
            .padding(.horizontal, Theme.gutter + 8)
            .padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func flagCode(_ l: Lang) -> String { l.rawValue.uppercased() }
}

// MARK: - 2. Imkoniyatlar

private struct OnbFeatures: View {
    let t: OnbText
    let active: Bool

    var body: some View {
        let rows: [(String, Color, String, String)] = [
            ("wifi.slash", Theme.teal, t("Oflayn ishlaydi", "Работает офлайн", "Works offline"),
             t("Ochilgan sahifalar internet boʻlmaganda ham koʻrinadi — togʻda ham, poyezdda ham.",
               "Открытые страницы доступны и без интернета — в горах и в поезде.",
               "Pages you’ve opened stay available without internet — in the mountains or on a train.")),
            ("map.fill", Theme.accent, t("Xarita", "Карта", "Map"),
             t("Obidalar, mehmonxona va restoranlar xaritada. Joylashuvingiz faqat telefonda ishlatiladi.",
               "Достопримечательности, отели и рестораны на карте. Геопозиция используется только на телефоне.",
               "Sights, hotels and restaurants on a map. Your location is used only on your phone.")),
            ("airplane.departure", Theme.gold, t("Jonli tablo", "Живое табло", "Live flight board"),
             t("Aeroportlar reyslari, poyezdlar va avtovokzallar — bir necha bosishda.",
               "Рейсы аэропортов, поезда и автовокзалы — в пару касаний.",
               "Airport flights, trains and bus stations — just a couple of taps away.")),
            ("cloud.sun.fill", Theme.warn, t("Foydali xizmatlar", "Полезные сервисы", "Handy services"),
             t("Ob-havo, valyuta kurslari, viza, pochta indekslari va davlat idoralari.",
               "Погода, курсы валют, визы, почтовые индексы и госучреждения.",
               "Weather, exchange rates, visas, postal codes and government offices.")),
        ]
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Spacer(minLength: 8)
                VStack(alignment: .leading, spacing: 8) {
                    Kicker(text: t("Imkoniyatlar", "Возможности", "Features"))
                    Text(t("Sayohatda kerak boʻlgan hamma narsa", "Всё, что нужно в поездке", "Everything you need on the road"))
                        .font(Theme.Font.display(30)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                .onbReveal(active, 0.05)
                ForEach(rows.indices, id: \.self) { i in
                    let r = rows[i]
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: r.0)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(r.1)
                            .frame(width: 52, height: 52)
                            .background(r.1.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .symbolEffect(.bounce, value: active)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(r.2).font(Theme.Font.headline).foregroundStyle(Theme.ink)
                            Text(r.3).font(Theme.Font.sub).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .onbReveal(active, 0.12 + Double(i) * 0.08)
                }
            }
            .padding(.horizontal, Theme.gutter + 8)
            .padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - 3. Maxfiylik

private struct OnbPrivacy: View {
    let t: OnbText
    let active: Bool

    var body: some View {
        let points: [(String, String)] = [
            ("eye.slash", t("Kuzatuv yoʻq", "Без слежки", "No tracking")),
            ("megaphone", t("Reklama yoʻq", "Без рекламы", "No ads")),
            ("person.crop.circle.badge.xmark", t("Roʻyxatdan oʻtish shart emas", "Без регистрации", "No account needed")),
            ("iphone", t("Saqlanganlar faqat telefoningizda", "Избранное хранится только на телефоне", "Saved items stay on your phone")),
        ]
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 16)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(Theme.teal)
                    .frame(width: 128, height: 128)
                    .background(Theme.teal.opacity(0.13), in: Circle())
                    .symbolEffect(.bounce, value: active)
                    .onbReveal(active, 0)
                    .accessibilityHidden(true)
                VStack(spacing: 10) {
                    Text(t("Maxfiyligingiz — birinchi oʻrinda", "Ваша приватность — прежде всего", "Your privacy comes first"))
                        .font(Theme.Font.display(28)).foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(t("Ilova sizdan hech qanday shaxsiy maʼlumot soʻramaydi va hech kimga yubormaydi.",
                           "Приложение не запрашивает личных данных и никому их не передаёт.",
                           "The app never asks for personal data and never shares any."))
                        .font(Theme.Font.body).foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .onbReveal(active, 0.08)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(points.indices, id: \.self) { i in
                        HStack(spacing: 14) {
                            Image(systemName: points[i].0).font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.ok).frame(width: 28)
                            Text(points[i].1).font(Theme.Font.body).foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(Theme.ok)
                        }
                        .padding(.vertical, 12)
                        .accessibilityElement(children: .combine)
                        if i < points.count - 1 { Divider().overlay(Theme.line) }
                    }
                }
                .padding(.horizontal, 16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous).strokeBorder(Theme.line.opacity(0.6)))
                .onbReveal(active, 0.16)
            }
            .padding(.horizontal, Theme.gutter + 8)
            .padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
