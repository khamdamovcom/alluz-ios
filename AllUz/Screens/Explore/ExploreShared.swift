// «Kashf eting» bo'limining umumiy yordamchilari: tur nomlari (uch tilda), sanoq so'zlari, joy turlari ikonkalari,
// mehmonxona/ovqatlanish guruhlari, hududlar ro'yxati (bir marta yuklanadi) va kichik ko'rinishlar.
import SwiftUI
import Observation

// MARK: - Tur nomlari va sanoq

enum ExTypes {
    /// Ro'yxat sarlavhasi (ko'plikda)
    static func title(_ type: String, group: String? = nil) -> String {
        if type == "venue" {
            switch group {
            case "stay": return tr("Mehmonxonalar", "Где остановиться", "Where to stay")
            case "eat": return tr("Restoranlar", "Где поесть", "Where to eat")
            default: return tr("Mehmonxona va restoranlar", "Отели и рестораны", "Hotels & restaurants")
            }
        }
        switch type {
        case "place": return tr("Diqqatga sazovor joylar", "Достопримечательности", "Places to see")
        case "region": return tr("Hududlar", "Регионы", "Regions")
        case "district": return tr("Tuman va shaharlar", "Районы и города", "Districts & cities")
        case "person": return tr("Allomalar", "Великие люди", "Notable figures")
        case "era": return tr("Tarixiy davrlar", "Исторические эпохи", "Historical eras")
        case "hist_event": return tr("Tarixiy voqealar", "Исторические события", "Historical events")
        case "cuisine": return tr("Milliy taomlar", "Национальная кухня", "Uzbek cuisine")
        case "craft": return tr("Hunarmandchilik", "Ремёсла", "Crafts")
        case "tradition": return tr("Anʼanalar", "Традиции", "Traditions")
        case "holiday": return tr("Bayramlar", "Праздники", "Holidays")
        case "fest": return tr("Festival va tadbirlar", "Фестивали и события", "Festivals & events")
        case "guide": return tr("Sayohatchilarga", "Путешественникам", "Travel tips")
        case "route": return tr("Marshrutlar", "Маршруты", "Itineraries")
        case "org": return tr("Davlat idoralari", "Госучреждения", "Government offices")
        case "bank": return tr("Banklar", "Банки", "Banks")
        case "post": return tr("Pochta boʻlimlari", "Почтовые отделения", "Post offices")
        case "airport": return tr("Aeroportlar", "Аэропорты", "Airports")
        case "rail_station": return tr("Temir yoʻl vokzallari", "Ж/д вокзалы", "Railway stations")
        case "train": return tr("Poyezdlar", "Поезда", "Trains")
        case "bus_station": return tr("Avtovokzallar", "Автовокзалы", "Bus stations")
        case "bus_route": return tr("Avtobus yoʻnalishlari", "Автобусные маршруты", "Bus routes")
        case "city_transport": return tr("Shahar transporti", "Городской транспорт", "City transport")
        case "metro": return tr("Metro", "Метро", "Metro")
        default: return tr("Roʻyxat", "Список", "List")
        }
    }

    /// «61 ta joy» / «61 место» / «61 places»
    static func count(_ n: Int, _ type: String, group: String? = nil) -> String {
        let w: (uz: String, ru: [String], en: [String])?
        switch (type, group) {
        case ("venue", "stay"): w = ("mehmonxona", ["вариант жилья", "варианта жилья", "вариантов жилья"], ["place to stay", "places to stay"])
        case ("venue", "eat"): w = ("ovqatlanish joyi", ["заведение", "заведения", "заведений"], ["place to eat", "places to eat"])
        case ("venue", _): w = ("maskan", ["заведение", "заведения", "заведений"], ["venue", "venues"])
        case ("place", _): w = ("joy", ["место", "места", "мест"], ["place", "places"])
        case ("region", _): w = ("hudud", ["регион", "региона", "регионов"], ["region", "regions"])
        case ("person", _): w = ("alloma", ["личность", "личности", "личностей"], ["figure", "figures"])
        case ("era", _): w = ("davr", ["эпоха", "эпохи", "эпох"], ["era", "eras"])
        case ("hist_event", _): w = ("voqea", ["событие", "события", "событий"], ["event", "events"])
        case ("cuisine", _): w = ("taom", ["блюдо", "блюда", "блюд"], ["dish", "dishes"])
        case ("craft", _): w = ("hunar", ["ремесло", "ремесла", "ремёсел"], ["craft", "crafts"])
        case ("tradition", _): w = ("anʼana", ["традиция", "традиции", "традиций"], ["tradition", "traditions"])
        case ("holiday", _): w = ("bayram", ["праздник", "праздника", "праздников"], ["holiday", "holidays"])
        case ("fest", _): w = ("tadbir", ["событие", "события", "событий"], ["event", "events"])
        case ("guide", _): w = ("maslahat", ["статья", "статьи", "статей"], ["guide", "guides"])
        case ("route", _): w = ("marshrut", ["маршрут", "маршрута", "маршрутов"], ["itinerary", "itineraries"])
        case ("org", _): w = ("idora", ["учреждение", "учреждения", "учреждений"], ["office", "offices"])
        case ("bank", _): w = ("bank", ["банк", "банка", "банков"], ["bank", "banks"])
        case ("post", _): w = ("indeks", ["индекс", "индекса", "индексов"], ["postcode", "postcodes"])
        case ("airport", _): w = ("aeroport", ["аэропорт", "аэропорта", "аэропортов"], ["airport", "airports"])
        case ("rail_station", _): w = ("vokzal", ["вокзал", "вокзала", "вокзалов"], ["station", "stations"])
        case ("bus_station", _): w = ("avtovokzal", ["автовокзал", "автовокзала", "автовокзалов"], ["bus station", "bus stations"])
        case ("train", _): w = ("poyezd", ["поезд", "поезда", "поездов"], ["train", "trains"])
        case ("district", _): w = ("tuman va shahar", ["район и город", "района и города", "районов и городов"], ["district", "districts"])
        default: w = nil
        }
        let num = Fmt.num(n)
        guard let w else { return tr("\(num) ta natija", "Найдено: \(num)", "\(num) results") }
        switch Lang.current {
        case .uz: return "\(num) ta \(w.uz)"
        case .ru: return "\(num) \(ruPlural(n, w.ru))"
        case .en: return "\(num) \(n == 1 ? w.en[0] : w.en[1])"
        }
    }

    /// Rus tilida sonning shakli: 1 место, 3 места, 5 мест
    static func ruPlural(_ n: Int, _ forms: [String]) -> String {
        guard forms.count == 3 else { return forms.first ?? "" }
        let a = abs(n) % 100, b = a % 10
        if a > 10 && a < 20 { return forms[2] }
        if b == 1 { return forms[0] }
        if b >= 2 && b <= 4 { return forms[1] }
        return forms[2]
    }

    /// Hudud filtri qaysi turlar uchun mantiqli
    static let regionFiltered: Set<String> = ["place", "venue", "district", "person", "fest", "route", "org", "airport", "rail_station", "bus_station", "post"]
    /// Tur chiplari qaysi turlar uchun
    static let kindFiltered: Set<String> = ["place", "venue", "person", "district"]
}

// MARK: - Turlar (kind)

enum ExKinds {
    /// Joy turlari — sayt tartibida
    static let placeOrder = ["ansambl", "madrasa", "masjid", "maqbara", "minora", "ziyoratgoh", "qala", "arxeologiya", "muzey", "ibodatxona",
                             "bog", "kongilochar", "madaniyat", "bozor", "tabiat", "dam-olish", "zamonaviy"]
    static let stay = ["hotel", "guesthouse", "hostel", "resort"]
    static let eat = ["restaurant", "cafe", "choyxona", "osh", "fastfood"]

    /// Mehmonxona/ovqatlanish guruhi (venue kind'idan)
    static func group(of kind: String?) -> String? {
        guard let kind else { return nil }
        if kind == "stay" || stay.contains(kind) { return "stay" }
        if kind == "eat" || eat.contains(kind) { return "eat" }
        return nil
    }

    static func symbol(_ type: String, _ kind: String) -> String {
        switch (type, kind) {
        case ("place", "ansambl"): "building.2.fill"
        case ("place", "madrasa"): "books.vertical.fill"
        case ("place", "masjid"): "moon.stars.fill"
        case ("place", "maqbara"): "crown.fill"
        case ("place", "minora"): "light.beacon.max.fill"
        case ("place", "ziyoratgoh"): "hands.sparkles.fill"
        case ("place", "qala"): "shield.lefthalf.filled"
        case ("place", "arxeologiya"): "hourglass.bottomhalf.filled"
        case ("place", "muzey"): "building.columns.fill"
        case ("place", "ibodatxona"): "bell.fill"
        case ("place", "bog"): "leaf.fill"
        case ("place", "kongilochar"): "balloon.2.fill"
        case ("place", "madaniyat"): "theatermasks.fill"
        case ("place", "bozor"): "basket.fill"
        case ("place", "tabiat"): "mountain.2.fill"
        case ("place", "dam-olish"): "beach.umbrella.fill"
        case ("place", "zamonaviy"): "building.fill"
        case ("venue", "hotel"): "bed.double.fill"
        case ("venue", "guesthouse"): "house.fill"
        case ("venue", "hostel"): "person.3.fill"
        case ("venue", "resort"): "sun.horizon.fill"
        case ("venue", "restaurant"): "fork.knife"
        case ("venue", "cafe"): "cup.and.saucer.fill"
        case ("venue", "choyxona"): "mug.fill"
        case ("venue", "osh"): "flame.fill"
        case ("venue", "fastfood"): "takeoutbag.and.cup.and.straw.fill"
        default: SymbolMap.forType(type)
        }
    }

    /// Server yorlig'i tarjima qilinmagan turlar uchun (alloma sohasi, tuman turi)
    static func label(_ type: String, _ kind: String, server: String?) -> String {
        switch (type, kind) {
        case ("person", "olim"): return tr("Olimlar", "Учёные", "Scholars")
        case ("person", "din"): return tr("Din allomalari", "Богословы", "Theologians")
        case ("person", "hukmdor"): return tr("Hukmdorlar", "Правители", "Rulers")
        case ("person", "shoir"): return tr("Shoirlar", "Поэты", "Poets")
        case ("person", "sanat"): return tr("Sanʼatkorlar", "Деятели искусства", "Artists")
        case ("person", "zamonaviy"): return tr("Zamondoshlar", "Современники", "Modern era")
        case ("district", "tuman"): return tr("Tumanlar", "Районы", "Districts")
        case ("district", "shahar"): return tr("Shaharlar", "Города", "Cities")
        default:
            if let s = server, !s.isEmpty, s != kind { return s }
            return kind.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

    /// Plitkalar uchun rang (faqat Theme ranglari)
    static func tint(_ i: Int) -> Color {
        let all = [Theme.accent, Theme.teal, Theme.gold, Theme.ok, Theme.warn]
        return all[((i % all.count) + all.count) % all.count]
    }
}

/// Chip/plitka uchun tur statistikasi
struct ExKindStat: Hashable, Sendable, Identifiable {
    let key: String
    let label: String
    let count: Int
    var id: String { key }
}

// MARK: - Hududlar (bir marta yuklanadi — filtr menyusi va «Kashf eting» uchun)

@MainActor @Observable
final class ExRegionStore {
    static let shared = ExRegionStore()
    private(set) var items: [Card] = []
    private var lang: Lang?
    private var loading = false

    func set(_ cards: [Card]) { items = cards; lang = Lang.current }

    func load() async {
        if lang == Lang.current, !items.isEmpty { return }
        guard !loading else { return }
        loading = true
        defer { loading = false }
        if let page: ListPage = try? await API.shared.get("list/region", query: ["limit": "20"]) { set(page.items) }
    }

    func name(_ slug: String?) -> String? {
        guard let slug else { return nil }
        return items.first { $0.slug == slug }?.name
    }
}

// MARK: - Kichik ko'rinishlar

/// Rangli doiradagi ikonka
struct ExIconBadge: View {
    let symbol: String
    var tint: Color = Theme.accent
    var size: CGFloat = 44
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Bo'lim sarlavhasi ostidagi kirish matni
struct ExIntro: View {
    let kicker: String
    let title: String
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: kicker)
            Text(title).font(Theme.Font.display(30)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            Text(text).font(Theme.Font.body).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.gutter)
        .accessibilityElement(children: .combine)
    }
}
