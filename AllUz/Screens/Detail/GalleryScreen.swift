// To'liq ekran galereya: qora fon, sahifalab varaqlash, chimdib kattalashtirish (MagnifyGesture) va ikki marta bosish,
// kattalashganda surish; pastda rasm nomi, muallif/litsenziya (CreditLine) va «n / jami». Bir marta bosish — boshqaruvlarni yashiradi.
import SwiftUI

struct GalleryScreen: View {
    let images: [Img]
    let index: Int

    @State private var page: Int?
    @State private var chrome = true
    @State private var zoomed = false
    @Environment(\.dismiss) private var dismiss

    init(images: [Img], index: Int) {
        self.images = images
        self.index = index
        _page = State(initialValue: images.isEmpty ? nil : min(max(index, 0), images.count - 1))
    }

    private var current: Int { min(max(page ?? index, 0), max(images.count - 1, 0)) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if images.isEmpty {
                EmptyState(title: tr("Rasm yoʻq", "Нет фото", "No photos"), symbol: "photo")
            } else {
                pager
            }
        }
        .overlay(alignment: .bottom) { if chrome && !images.isEmpty { caption.transition(.opacity) } }
        .overlay(alignment: .topLeading) { if chrome { closeButton.transition(.opacity) } }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .statusBarHidden()
        .environment(\.colorScheme, .dark)
        .navigationTitle(tr("Rasmlar", "Фото", "Photos"))
        .animation(.easeInOut(duration: 0.2), value: chrome)
    }

    private var pager: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(images.enumerated()), id: \.offset) { i, img in
                        DetailZoomPage(img: img, isCurrent: i == current, zoomed: $zoomed) {
                            chrome.toggle()
                        }
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(i)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $page)
            .scrollDisabled(zoomed || images.count < 2)
            .ignoresSafeArea()
            .onAppear { proxy.scrollTo(current) }
            .onChange(of: page) { Haptics.select() }
        }
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .glassBackground(Circle(), fallback: .ultraThinMaterial)
        }
        .buttonStyle(.press)
        .padding(.leading, Theme.gutter)
        .padding(.top, 8)
        .accessibilityLabel(tr("Yopish", "Закрыть", "Close"))
    }

    private var caption: some View {
        let img = images[current]
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                if let t = img.title, !t.isEmpty {
                    Text(t).font(Theme.Font.sub).foregroundStyle(.white).lineLimit(3)
                }
                Spacer(minLength: 8)
                Text("\(current + 1) / \(images.count)")
                    .font(Theme.Font.sub.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(current)))
                    .animation(Motion.snappy, value: current)
                    .accessibilityLabel(tr("Rasm \(current + 1), jami \(images.count)", "Фото \(current + 1) из \(images.count)", "Photo \(current + 1) of \(images.count)"))
            }
            CreditLine(img: img)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 40)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }
}

/// Bitta rasm: chimdish, ikki marta bosish (bosilgan joyga kattalashadi), kattalashganda surish
private struct DetailZoomPage: View {
    let img: Img
    let isCurrent: Bool
    @Binding var zoomed: Bool
    let onTap: () -> Void

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduce

    private let maxScale: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            RemoteImage(img: img, mode: .fit, width: 800)
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
                .offset(offset)
                .contentShape(Rectangle())
                .gesture(pan(size), including: scale > 1.01 ? .all : .subviews)
                .simultaneousGesture(magnify(size))
                .gesture(doubleTap(size).exclusively(before: TapGesture().onEnded { onTap() }))
                .accessibilityElement()
                .accessibilityLabel(img.title ?? tr("Rasm", "Фото", "Photo"))
                .accessibilityAddTraits(.isImage)
                .accessibilityAction(named: scale > 1.01 ? tr("Kichraytirish", "Уменьшить", "Zoom out") : tr("Kattalashtirish", "Увеличить", "Zoom in")) {
                    withAnimation(Motion.spring) { if scale > 1.01 { reset() } else { scale = 2.5; baseScale = 2.5; zoomed = true } }
                }
        }
        .clipped()
        .onChange(of: isCurrent) { _, now in if !now { reset() } }
    }

    private func magnify(_ size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { v in
                scale = min(max(baseScale * v.magnification, 0.8), maxScale)
            }
            .onEnded { _ in
                withAnimation(Motion.spring) {
                    if scale <= 1.05 { reset() } else {
                        baseScale = scale
                        offset = clamp(offset, size)
                        baseOffset = offset
                        zoomed = true
                    }
                }
            }
    }

    private func pan(_ size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                offset = CGSize(width: baseOffset.width + v.translation.width, height: baseOffset.height + v.translation.height)
            }
            .onEnded { _ in
                withAnimation(Motion.snappy) { offset = clamp(offset, size) }
                baseOffset = offset
            }
    }

    private func doubleTap(_ size: CGSize) -> some Gesture {
        SpatialTapGesture(count: 2).onEnded { v in
            Haptics.soft()
            withAnimation(reduce ? .easeInOut(duration: 0.2) : Motion.spring) {
                if scale > 1.01 { reset() } else {
                    let s: CGFloat = 2.5
                    scale = s; baseScale = s
                    // bosilgan nuqta markazga yaqinlashsin
                    let dx = (size.width / 2 - v.location.x) * (s - 1)
                    let dy = (size.height / 2 - v.location.y) * (s - 1)
                    offset = clamp(CGSize(width: dx, height: dy), size)
                    baseOffset = offset
                    zoomed = true
                }
            }
        }
    }

    /// Rasm chetlari ekrandan uzoqlashib ketmasin
    private func clamp(_ o: CGSize, _ size: CGSize) -> CGSize {
        let aspect = img.aspect ?? (size.width / max(size.height, 1))
        // .fit — rasmning ekrandagi haqiqiy o'lchami
        let fitW = min(size.width, size.height * aspect), fitH = min(size.height, size.width / aspect)
        let maxX = max(0, (fitW * scale - size.width) / 2), maxY = max(0, (fitH * scale - size.height) / 2)
        return CGSize(width: min(max(o.width, -maxX), maxX), height: min(max(o.height, -maxY), maxY))
    }

    private func reset() {
        scale = 1; baseScale = 1; offset = .zero; baseOffset = .zero
        if isCurrent { zoomed = false }
    }
}
