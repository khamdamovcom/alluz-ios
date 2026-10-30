// Tarmoq: faqat https://alluzbekistan.com (TLS pin — Pinning.swift), faqat GET, faqat o'qish; login, kuzatuv, reklama yo'q.
// Til — yo'l prefiksi: uz → /api/app/v1/…, ru → /ru/api/app/v1/…, en → /en/api/app/v1/…
// Oflayn: har muvaffaqiyatli javob diskka (Caches/api) yoziladi; tarmoq bo'lmasa oxirgi nusxa qaytadi (fresh=false).
// Ishlatish: let home: HomeData = try await API.shared.get("home")
//            let page: ListPage = try await API.shared.get("list/place", query: ["region": "samarqand"])
//            Boshqa (ilova bo'lmagan) API: try await API.shared.getRaw("/api/board", query: [...]) — yo'l «/» bilan boshlanadi
import Foundation
import CryptoKit

enum APIError: LocalizedError, Equatable {
    case offline, notFound, server(Int), decoding, blocked

    var errorDescription: String? {
        switch self {
        case .offline: return tr("Internet yoʻq. Ulanishni tekshiring.", "Нет интернета. Проверьте подключение.", "No internet connection.")
        case .notFound: return tr("Topilmadi.", "Не найдено.", "Not found.")
        case .server(let c): return tr("Server xatosi (\(c)). Birozdan keyin urinib koʻring.", "Ошибка сервера (\(c)). Попробуйте позже.", "Server error (\(c)). Please try again later.")
        case .decoding: return tr("Maʼlumotni oʻqib boʻlmadi. Ilovani yangilang.", "Не удалось прочитать данные. Обновите приложение.", "Could not read data. Please update the app.")
        case .blocked: return tr("Xavfsiz ulanib boʻlmadi.", "Не удалось установить безопасное соединение.", "Secure connection failed.")
        }
    }
}

final class API: @unchecked Sendable {
    static let shared = API()

    let session: URLSession
    private let decoder = JSONDecoder()
    private let cacheDir: URL

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 60
        cfg.waitsForConnectivity = false
        cfg.httpCookieAcceptPolicy = .never
        cfg.httpShouldSetCookies = false
        cfg.httpCookieStorage = nil
        cfg.urlCredentialStorage = nil
        cfg.httpAdditionalHeaders = ["Accept": "application/json", "User-Agent": API.userAgent]
        // Rasmlar uchun katta disk kesh (server Cache-Control bo'yicha)
        cfg.urlCache = URLCache(memoryCapacity: 48 << 20, diskCapacity: 400 << 20)
        cfg.requestCachePolicy = .useProtocolCachePolicy
        cfg.tlsMinimumSupportedProtocolVersion = .TLSv12
        session = URLSession(configuration: cfg, delegate: PinningDelegate(), delegateQueue: nil)
        cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("api", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    static var userAgent: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "AllUzbekistan-iOS/\(v) (\(b))"
    }

    private static func langPrefix(_ lang: Lang) -> String { lang == .uz ? "" : "/\(lang.rawValue)" }

    /// Ilova API: "home", "list/place", "item/place/registon", "search", "map", "config", "weather" …
    func get<T: Decodable>(_ path: String, query: [String: String] = [:], lang: Lang = Lang.current) async throws -> T {
        try await getRaw("/api/app/v1/" + path, query: query, lang: lang)
    }

    /// Istalgan sayt API'si (masalan /api/board) — tilga prefiks qo'shiladi
    func getRaw<T: Decodable>(_ path: String, query: [String: String] = [:], lang: Lang = Lang.current) async throws -> T {
        let data = try await fetch(path, query: query, lang: lang)
        do { return try decoder.decode(T.self, from: data) } catch {
            #if DEBUG
            print("[API] decode \(path): \(error)")
            #endif
            throw APIError.decoding
        }
    }

    /// Xom javob (keshdan yoki tarmoqdan)
    func fetch(_ path: String, query: [String: String] = [:], lang: Lang = Lang.current) async throws -> Data {
        // Yo'l faqat oddiy belgilardan: «..», «%», «?», «#» — so'rovni boshqa yo'lga burish urinishi
        guard path.hasPrefix("/"), !path.contains(".."), path.range(of: #"^/[A-Za-z0-9/_.\-]{1,300}$"#, options: .regularExpression) != nil
        else { throw APIError.notFound }
        var c = URLComponents(string: AppConfig.site + API.langPrefix(lang) + path)
        let q = query.filter { !$0.value.isEmpty }.sorted { $0.key < $1.key }
        if !q.isEmpty { c?.queryItems = q.map { URLQueryItem(name: $0.key, value: $0.value) } }
        guard let url = c?.url, url.host == AppConfig.host, url.scheme == "https" else { throw APIError.notFound }
        let key = cacheKey(url)
        do {
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalCacheData    // JSON — doim yangisi; oflayn nusxa o'zimizda
            let (data, resp) = try await session.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            switch code {
            case 200 where (resp.mimeType ?? "").contains("json"): try? data.write(to: cacheDir.appendingPathComponent(key), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]); return data
            case 200: return data
            case 404: throw APIError.notFound
            default: throw APIError.server(code)
            }
        } catch let e as APIError {
            if case .server = e, let d = cached(key) { return d }
            throw e
        } catch let e as URLError {
            if Task.isCancelled { throw CancellationError() }      // ekran yopildi — xato ko'rsatilmaydi
            if let d = cached(key) { return d }
            switch e.code {
            // pin mos kelmasa delegat ulanishni bekor qiladi → .cancelled
            case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid,
                 .secureConnectionFailed, .cancelled:
                throw APIError.blocked
            default: throw APIError.offline
            }
        }
    }

    private func cacheKey(_ url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined().prefix(40) + ".json"
    }
    private func cached(_ key: String) -> Data? { try? Data(contentsOf: cacheDir.appendingPathComponent(key)) }

    /// Sozlamalar → «Keshni tozalash»
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        session.configuration.urlCache?.removeAllCachedResponses()
        ImageCache.shared.clear()
    }
    var cacheBytes: Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        let json = files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        return json + (session.configuration.urlCache?.currentDiskUsage ?? 0)
    }
}
