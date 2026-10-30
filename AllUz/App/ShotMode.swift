// Skrinshot va sinov rejimi (CI simulyatori): ilova `-shot <spec> [-theme dark] [-lang en]` bilan ochiladi.
// spec: "tab:home|explore|map|board|more" yoki Route(spec:) — "item:place:registon", "list:venue:stay", "board:TAS", "weather:samarqand" …
// Bir nechta qadam «,» bilan: "tab:explore,regions,item:region:xorazm". Bu rejimda onboarding chiqmaydi.
import SwiftUI

@MainActor
enum ShotMode {
    private static var args: [String] { ProcessInfo.processInfo.arguments }
    private static func arg(_ name: String) -> String? {
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    static var spec: String? { arg("-shot") }
    static var active: Bool { spec != nil }

    static func apply(_ spec: String, model: AppModel) {
        if let t = arg("-theme"), let th = ThemeChoice(rawValue: t) { model.theme = th }
        for step in spec.split(separator: ",").map(String.init) {
            if step.hasPrefix("tab:"), let t = Tab(rawValue: String(step.dropFirst(4))) { model.tab = t; continue }
            if let r = Route(spec: step) { model.paths[model.tab, default: []].append(r) }
        }
    }

    // Til: simctl launch … -app.lang en (UserDefaults argument domeni — Lang.current shuni o'qiydi)
}
