// Tez rasm: kerakli o'lchamdagi WebP nusxa (Img.url(for:)), ImageIO bilan ekranga mos kichraytirib dekodlash (xotira tejaladi),
// xotira keshi (NSCache) + disk keshi (URLSession URLCache), paydo bo'lishda yumshoq ochilish. Rasm yo'q bo'lsa — hudud rangidagi fon + ikonka.
// Ishlatish: RemoteImage(img: card.img, region: card.region, icon: card.icon).frame(height: 220).clipped()
import SwiftUI
import UIKit
import ImageIO

final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let mem = NSCache<NSURL, UIImage>()
    @MainActor private var tasks: [URL: Task<UIImage?, Never>] = [:]
    init() { mem.totalCostLimit = 120 << 20 }

    func cached(_ url: URL) -> UIImage? { mem.object(forKey: url as NSURL) }
    func clear() { mem.removeAllObjects() }

    /// Bir xil URL bir vaqtda bir marta yuklanadi (vazifalar ro'yxati — asosiy oqimda)
    @MainActor func load(_ url: URL, maxPixel: CGFloat) async -> UIImage? {
        if let i = cached(url) { return i }
        if let t = tasks[url] { return await t.value }
        let t = Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard url.host == AppConfig.host,
                  let (data, resp) = try? await API.shared.session.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return ImageCache.downsample(data, maxPixel: maxPixel)
        }
        tasks[url] = t
        let img = await t.value
        tasks[url] = nil
        if let img { mem.setObject(img, forKey: url as NSURL, cost: Int(img.size.width * img.size.height * img.scale * img.scale * 4)) }
        return img
    }

    static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceShouldCacheImmediately: true,
                                     kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: max(64, maxPixel)]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct RemoteImage: View {
    let img: Img?
    var region: String? = nil
    var icon: String? = nil
    /// .fill — kesib to'ldirish (kartalar), .fit — butun rasm (galereya)
    var mode: ContentMode = .fill
    /// Taxminiy ko'rinish kengligi (pt); nol — GeometryReader o'lchaydi
    var width: CGFloat = 0

    @State private var ui: UIImage?
    @State private var failed = false
    @Environment(\.displayScale) private var scale

    var body: some View {
        GeometryReader { geo in
            let w = width > 0 ? width : geo.size.width
            let px = max(w, geo.size.height * (img?.aspect ?? 1.5)) * scale
            ZStack {
                if let ui {
                    Image(uiImage: ui).resizable().aspectRatio(contentMode: mode)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: alignment)
                        .clipped()
                        .transition(.opacity.animation(.easeOut(duration: 0.35)))
                } else {
                    Placeholder(region: region, icon: icon, loading: img != nil && !failed)
                }
            }
            .task(id: img?.u) {
                guard let img, let url = img.url(for: px) else { ui = nil; return }
                if let c = ImageCache.shared.cached(url) { ui = c; return }
                ui = nil; failed = false
                let r = await ImageCache.shared.load(url, maxPixel: px)
                if Task.isCancelled { return }
                withAnimation(.easeOut(duration: 0.3)) { ui = r; failed = r == nil }
            }
        }
        .accessibilityLabel(img?.title ?? "")
    }

    /// focus: "50% 30%" → kesish markazi
    private var alignment: Alignment {
        guard let f = img?.focus else { return .center }
        let parts = f.split(separator: " ").compactMap { Double($0.replacingOccurrences(of: "%", with: "")) }
        guard parts.count == 2 else { return .center }
        let y = parts[1]
        return y < 35 ? .top : y > 65 ? .bottom : .center
    }
}

/// Rasm yo'q yoki yuklanmoqda: hudud rangidagi gradient + ikonka (+ yuklanayotganda yaltirash)
struct Placeholder: View {
    var region: String? = nil
    var icon: String? = nil
    var loading = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.hue(region).opacity(0.55), Theme.hue(region).opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: SymbolMap.symbol(icon)).font(.system(size: 30, weight: .light)).foregroundStyle(.white.opacity(0.75))
            if loading { Shimmer() }
        }
    }
}

struct Shimmer: View {
    @State private var x: CGFloat = -1
    var body: some View {
        GeometryReader { g in
            LinearGradient(colors: [.clear, .white.opacity(0.22), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: g.size.width * 0.6)
                .offset(x: x * g.size.width * 1.6)
                .onAppear { withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { x = 1 } }
        }
        .allowsHitTesting(false)
        .clipped()
    }
}
