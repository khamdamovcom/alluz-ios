// Darvoza ekranlari: ilova yopiq (admin → Ilova → «Yopish», config.app.closed), majburiy yangilash (build < config.ios.minBuild)
// va yopsa bo'ladigan «yangi versiya» banneri (build < config.ios.latestBuild). Sinov: -shot closed | update | update-banner.
import SwiftUI

/// Kill switch: faqat logotip, sarlavha, matn, «Qayta urinish» va sayt havolasi — tablar, kontent va deep link yo'q
struct AppClosedView: View {
    @Environment(AppModel.self) private var model
    @State private var checking = false
    @State private var shake = 0

    var body: some View {
        AppGateLayout(symbol: "wrench.and.screwdriver.fill",
                      title: model.appState.title ?? tr("Ilova vaqtincha yopiq", "Приложение временно недоступно", "The app is temporarily unavailable"),
                      text: model.appState.text ?? tr("Texnik ishlar olib borilmoqda. Birozdan soʻng qayta urinib koʻring.",
                                                     "Идут технические работы. Попробуйте позже.", "We are doing maintenance. Please try again later.")) {
            Button {
                guard !checking else { return }
                Haptics.tap()
                checking = true
                Task {
                    await model.refreshConfig()
                    checking = false
                    if model.isClosed { UINotificationFeedbackGenerator().notificationOccurred(.warning); withAnimation(Motion.snappy) { shake += 1 } }
                }
            } label: {
                HStack(spacing: 8) {
                    if checking { ProgressView().tint(Theme.accentInk) } else { Image(systemName: "arrow.clockwise") }
                    Text(tr("Qayta urinish", "Повторить", "Try again"))
                }
                .frame(maxWidth: .infinity, minHeight: 30)
            }
            .primaryButton().tint(Theme.accent)
            .disabled(checking)
            .modifier(AppGateShake(trigger: shake))

            Button {
                Haptics.tap()
                // Saytga to'g'ridan-to'g'ri (openURL sayt havolasini ilova ichidagi ekranga aylantiradi — yopiq holatda kerak emas)
                if let u = URL(string: MoreLinks.site) { model.webURL = IdentifiedURL(url: u) }
            } label: {
                Label(tr("Saytni ochish", "Открыть сайт", "Open the website"), systemImage: "safari").frame(maxWidth: .infinity, minHeight: 30)
            }
            .secondaryButton()
        }
    }
}

/// Majburiy yangilash: build serverdagi minBuild'dan eski — faqat App Store tugmasi
struct AppUpdateRequiredView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        AppGateLayout(symbol: "arrow.down.app.fill",
                      title: tr("Ilovani yangilang", "Обновите приложение", "Please update the app"),
                      text: tr("Bu versiya endi qoʻllab-quvvatlanmaydi. Davom etish uchun All Uzbekistan’ning yangi versiyasini App Store’dan oʻrnating.",
                               "Эта версия больше не поддерживается. Чтобы продолжить, установите новую версию All Uzbekistan из App Store.",
                               "This version is no longer supported. To continue, install the latest version of All Uzbekistan from the App Store.")) {
            Button { Haptics.tap(); model.openURL(model.storeURL) } label: {
                Label(tr("App Store’da yangilash", "Обновить в App Store", "Update on the App Store"), systemImage: "arrow.down.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .primaryButton().tint(Theme.accent)

            Button { Haptics.tap(); Task { await model.refreshConfig() } } label: {
                Label(tr("Qayta tekshirish", "Проверить снова", "Check again"), systemImage: "arrow.clockwise").frame(maxWidth: .infinity, minHeight: 30)
            }
            .secondaryButton()
        }
    }
}

/// Yangi versiya bor (majburiy emas) — pastda, yopsa bo'ladi (shu build uchun boshqa chiqmaydi)
struct AppUpdateBanner: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.app.fill").font(.title2).foregroundStyle(Theme.accent).accessibilityHidden(true)
            Button { Haptics.tap(); model.openURL(model.storeURL) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Yangi versiya mavjud", "Доступна новая версия", "A new version is available"))
                        .font(Theme.Font.sub.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(tr("App Store’da yangilash", "Обновить в App Store", "Update on the App Store"))
                        .font(Theme.Font.caption).foregroundStyle(Theme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.press)
            Button { Haptics.select(); model.dismissUpdateBanner() } label: {
                Image(systemName: "xmark").font(.footnote.weight(.bold)).foregroundStyle(Theme.muted)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel(tr("Yopish", "Закрыть", "Dismiss"))
        }
        .padding(.leading, 16).padding(.trailing, 4).padding(.vertical, 6)
        .glassBackground(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous), fallback: .regularMaterial)
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

/// Umumiy joylashuv: logotip, belgi, sarlavha, matn, tugmalar
private struct AppGateLayout<Actions: View>: View {
    let symbol: String
    let title: String
    let text: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 40)
                ZStack(alignment: .bottomTrailing) {
                    Image("BrandMark").resizable().frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.accentInk)
                        .frame(width: 38, height: 38)
                        .background(Theme.accent, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.paper, lineWidth: 3))
                        .offset(x: 10, y: 10)
                        .symbolEffect(.pulse, options: .repeating)
                }
                .accessibilityHidden(true)
                .appear()

                VStack(spacing: 10) {
                    Text("All Uzbekistan").font(Theme.Font.kicker).foregroundStyle(Theme.muted)
                    Text(title).font(Theme.Font.display(30)).foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(text).font(Theme.Font.body).foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }
                .appear(delay: 0.06)

                VStack(spacing: 12) { actions() }
                    .padding(.top, 8)
                    .appear(delay: 0.12)
                Spacer(minLength: 24)
            }
            .padding(.horizontal, Theme.gutter + 12)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollContentBackground(.hidden)
        .background(Theme.paper.ignoresSafeArea())
    }
}

/// «Hali yopiq» — tugma yengil chayqaladi
private struct AppGateShake: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduce
    func body(content: Content) -> some View {
        if reduce { content } else {
            content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { v, x in v.offset(x: x) } keyframes: { _ in
                KeyframeTrack { CubicKeyframe(-8, duration: 0.07); CubicKeyframe(8, duration: 0.07); CubicKeyframe(-5, duration: 0.07); CubicKeyframe(0, duration: 0.07) }
            }
        }
    }
}
