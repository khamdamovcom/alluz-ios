// Ixtiyoriy JSON qiymati — yozuvning turga xos maydonlari (`data`) va matn bloklari (`text`) uchun.
// Ishlatish: item.data["phones"]?.strings, item.data["hours"]?.string, item.text["body"]?.array
import Foundation

enum JSONValue: Codable, Hashable, Sendable {
    case string(String), number(Double), bool(Bool), array([JSONValue]), object([String: JSONValue]), null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        case .null: try c.encodeNil()
        }
    }

    subscript(key: String) -> JSONValue? { if case .object(let o) = self { return o[key] } else { return nil } }
    subscript(index: Int) -> JSONValue? { if case .array(let a) = self, a.indices.contains(index) { return a[index] } else { return nil } }

    /// Matn ko'rinishi: son ham matnga aylanadi (butun bo'lsa — kasrsiz)
    var string: String? {
        switch self {
        case .string(let s): return s.isEmpty ? nil : s
        case .number(let n): return n.rounded() == n && abs(n) < 1e15 ? String(Int64(n)) : String(n)
        case .bool(let b): return b ? "✓" : nil
        default: return nil
        }
    }
    var double: Double? { if case .number(let n) = self { return n }; if case .string(let s) = self { return Double(s) }; return nil }
    var int: Int? { double.map { Int($0) } }
    var bool: Bool? { if case .bool(let b) = self { return b }; return nil }
    var array: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    var object: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
    /// Matnlar massivi (bitta matn bo'lsa — bitta elementli)
    var strings: [String] {
        switch self {
        case .array(let a): return a.compactMap(\.string)
        case .string(let s): return s.isEmpty ? [] : [s]
        default: return []
        }
    }
    var isNull: Bool { if case .null = self { return true }; return false }

    /// JSONValue → Decodable model (masalan, data["stops"] → [Stop])
    func decode<T: Decodable>(_ type: T.Type) -> T? {
        guard let d = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }
}
