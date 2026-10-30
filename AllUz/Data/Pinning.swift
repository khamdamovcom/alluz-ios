// TLS himoyasi: alluzbekistan.com ga ulanishda sertifikat zanjirida Let's Encrypt (ISRG) ildiz kalitlaridan biri bo'lishi SHART
// (SPKI SHA-256 «pin»). Tizim tekshiruvidan o'tgan, lekin boshqa CA bergan sertifikat (korporativ proksi, soxta CA) rad etiladi.
// Pinlar ildizlarga qo'yilgan — sayt sertifikati har 60–90 kunda yangilansa ham ilova ishlayveradi (ildizlar 2035–2045 gacha).
// Pinlarni qayta hisoblash: openssl x509 -in root.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64
import Foundation
import CryptoKit
import Security

enum Pinning {
    static let pins: Set<String> = [
        "C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=",   // ISRG Root X1 (RSA 4096, 2035)
        "diGVwiVYbubAI3RW4hB9xU8e/CH2GnkuvVFZE8zmgzI=",   // ISRG Root X2 (EC P-384, 2040)
        "fk6IOKit1ild5647BH06ujSIq5XbCgqlbYl6ANhhi88=",   // ISRG Root YR (RSA 4096, 2045) — hozirgi zanjir
        "sCkq5UWXjg+7mKu9lMhhYF5bGLsy7VI/UNW3tccdR7w=",   // ISRG Root YE (EC P-384, 2045)
    ]

    /// SPKI DER sarlavhalari (kalit turi va o'lchami bo'yicha)
    private static let rsa4096 = Data([0x30, 0x82, 0x02, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x02, 0x0f, 0x00])
    private static let rsa2048 = Data([0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00])
    private static let ec384 = Data([0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x05, 0x2b, 0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00])
    private static let ec256 = Data([0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00])

    static func spkiHash(_ cert: SecCertificate) -> String? {
        guard let key = SecCertificateCopyKey(cert), let raw = SecKeyCopyExternalRepresentation(key, nil) as Data?,
              let attrs = SecKeyCopyAttributes(key) as? [CFString: Any],
              let type = attrs[kSecAttrKeyType] as? String, let bits = attrs[kSecAttrKeySizeInBits] as? Int else { return nil }
        let rsa = type == (kSecAttrKeyTypeRSA as String), ec = type == (kSecAttrKeyTypeECSECPrimeRandom as String)
        let header: Data
        switch (rsa, ec, bits) {
        case (true, _, 4096): header = rsa4096
        case (true, _, 2048): header = rsa2048
        case (_, true, 384): header = ec384
        case (_, true, 256): header = ec256
        default: return nil
        }
        return Data(SHA256.hash(data: header + raw)).base64EncodedString()
    }

    /// Tizim tekshiruvi + zanjirda pin bormi
    static func validate(_ trust: SecTrust, host: String) -> Bool {
        SecTrustSetPolicies(trust, SecPolicyCreateSSL(true, host as CFString))
        guard SecTrustEvaluateWithError(trust, nil) else { return false }
        let chain = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
        return chain.contains { spkiHash($0).map(pins.contains) ?? false }
    }
}

/// URLSession delegati: faqat alluzbekistan.com ga pin bilan; boshqa xostlarga ilova umuman so'rov yubormaydi (API.swift tekshiradi)
final class PinningDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil); return
        }
        let host = challenge.protectionSpace.host
        if host == AppConfig.host, Pinning.validate(trust, host: host) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
