// Tafsilot sahifasi uchun uch tildagi yorliqlar: tur nomlari, kategoriyalar, qulayliklar, bank xizmatlari, transport turlari …
// Sayt lug'atlari bilan bir xil (/opt/alluz/src/i18n/*.js). Noma'lum kalit — kalitning o'zi chiroyli ko'rinishda (hech qachon bo'sh emas).
import Foundation

enum DetailLabels {
    /// Yozuv turi (birlik)
    static func type(_ t: String) -> String {
        switch t {
        case "region": tr("Hudud", "Регион", "Region")
        case "district": tr("Shahar va tuman", "Город и район", "City & district")
        case "place": tr("Diqqatga sazovor joy", "Достопримечательность", "Sight")
        case "venue": tr("Joy", "Заведение", "Venue")
        case "org": tr("Davlat idorasi", "Госучреждение", "Public office")
        case "bank": tr("Bank", "Банк", "Bank")
        case "post": tr("Pochta boʻlimi", "Почтовое отделение", "Post office")
        case "airport": tr("Aeroport", "Аэропорт", "Airport")
        case "rail_station": tr("Vokzal", "Вокзал", "Railway station")
        case "train": tr("Poyezd", "Поезд", "Train")
        case "bus_station": tr("Avtovokzal", "Автовокзал", "Bus station")
        case "bus_route": tr("Avtobus qatnovi", "Автобусный рейс", "Bus route")
        case "city_transport": tr("Shahar transporti", "Городской транспорт", "City transport")
        case "metro": tr("Metro", "Метро", "Metro")
        case "person": tr("Alloma", "Личность", "Person")
        case "era": tr("Tarixiy davr", "Историческая эпоха", "Historical era")
        case "hist_event": tr("Tarixiy voqea", "Историческое событие", "Historical event")
        case "cuisine": tr("Milliy taom", "Национальная кухня", "Cuisine")
        case "craft": tr("Hunarmandchilik", "Ремесло", "Craft")
        case "tradition": tr("Anʼana", "Традиция", "Tradition")
        case "holiday": tr("Bayram", "Праздник", "Holiday")
        case "fest": tr("Tadbir", "Событие", "Event")
        case "guide": tr("Sayohatchilarga", "Путешественникам", "Travel tips")
        case "route": tr("Marshrut", "Маршрут", "Itinerary")
        default: tr("Maʼlumot", "Информация", "Info")
        }
    }

    /// Joy kategoriyasi (place.category)
    static func category(_ k: String) -> String {
        switch k {
        case "ansambl": tr("Ansambl", "Ансамбль", "Ensemble")
        case "madrasa": tr("Madrasa", "Медресе", "Madrasa")
        case "masjid": tr("Masjid", "Мечеть", "Mosque")
        case "maqbara": tr("Maqbara", "Мавзолей", "Mausoleum")
        case "minora": tr("Minora", "Минарет", "Minaret")
        case "ziyoratgoh": tr("Ziyoratgoh", "Место паломничества", "Pilgrimage site")
        case "qala": tr("Qalʼa", "Крепость", "Fortress")
        case "arxeologiya": tr("Arxeologiya", "Археология", "Archaeology")
        case "muzey": tr("Muzey", "Музей", "Museum")
        case "ibodatxona": tr("Ibodatxona", "Храм", "Temple & church")
        case "bog": tr("Bogʻ va park", "Сад и парк", "Park & garden")
        case "kongilochar": tr("Koʻngilochar", "Развлечения", "Entertainment")
        case "madaniyat": tr("Madaniyat", "Культура", "Culture & arts")
        case "bozor": tr("Bozor", "Базар", "Bazaar")
        case "tabiat": tr("Tabiat", "Природа", "Nature")
        case "dam-olish": tr("Dam olish", "Отдых", "Resort")
        case "zamonaviy": tr("Zamonaviy", "Современное", "Modern")
        default: humanize(k)
        }
    }

    static func venueKind(_ k: String) -> String {
        switch k {
        case "hotel": tr("Mehmonxona", "Отель", "Hotel")
        case "guesthouse": tr("Mehmon uyi", "Гостевой дом", "Guesthouse")
        case "hostel": tr("Hostel", "Хостел", "Hostel")
        case "resort": tr("Dam olish maskani", "База отдыха", "Resort")
        case "restaurant": tr("Restoran", "Ресторан", "Restaurant")
        case "cafe": tr("Kafe", "Кафе", "Café")
        case "choyxona": tr("Choyxona", "Чайхана", "Teahouse")
        case "osh": tr("Osh markazi", "Плов-центр", "Plov centre")
        case "fastfood": tr("Fast-fud", "Фастфуд", "Fast food")
        default: humanize(k)
        }
    }
    static let stayKinds: Set<String> = ["hotel", "guesthouse", "hostel", "resort"]

    /// Qulaylik: nom + SF Symbol
    static func feature(_ k: String) -> (String, String) {
        switch k {
        case "wifi": ("Wi-Fi", "wifi")
        case "breakfast": (tr("Nonushta kiritilgan", "Завтрак включён", "Breakfast included"), "cup.and.saucer")
        case "parking": (tr("Avtoturargoh", "Парковка", "Parking"), "parkingsign.circle")
        case "pool": (tr("Basseyn", "Бассейн", "Pool"), "figure.pool.swim")
        case "spa": (tr("Spa", "Спа", "Spa"), "sparkles")
        case "gym": (tr("Sport zali", "Тренажёрный зал", "Gym"), "dumbbell")
        case "restaurant": (tr("Restoran", "Ресторан", "Restaurant"), "fork.knife")
        case "transfer": (tr("Transfer", "Трансфер", "Transfers"), "car")
        case "ac": (tr("Konditsioner", "Кондиционер", "Air conditioning"), "snowflake")
        case "courtyard": (tr("Anʼanaviy hovli", "Традиционный двор", "Traditional courtyard"), "tree")
        case "terrace": (tr("Terrasa", "Терраса", "Terrace"), "sun.max")
        case "family": (tr("Oilaviy xonalar", "Семейные номера", "Family rooms"), "figure.2.and.child.holdinghands")
        case "card": (tr("Karta bilan toʻlov", "Оплата картой", "Cards accepted"), "creditcard")
        case "view": (tr("Obidaga manzara", "Вид на памятники", "Monument views"), "building.columns")
        case "live-music": (tr("Jonli musiqa", "Живая музыка", "Live music"), "music.note")
        case "banquet": (tr("Banket zali", "Банкетный зал", "Banquet hall"), "party.popper")
        case "kids": (tr("Bolalar uchun", "Для детей", "Kid-friendly"), "figure.and.child.holdinghands")
        case "vegetarian": (tr("Vegetarian taomlar", "Вегетарианские блюда", "Vegetarian options"), "leaf")
        case "delivery": (tr("Yetkazib berish", "Доставка", "Delivery"), "bicycle")
        default: (humanize(k), "checkmark.circle")
        }
    }

    static func cuisine(_ k: String) -> String {
        switch k {
        case "uzbek": tr("Oʻzbek", "Узбекская", "Uzbek")
        case "european": tr("Yevropa", "Европейская", "European")
        case "italian": tr("Italyan", "Итальянская", "Italian")
        case "asian": tr("Osiyo", "Азиатская", "Asian")
        case "turkish": tr("Turk", "Турецкая", "Turkish")
        case "georgian": tr("Gruzin", "Грузинская", "Georgian")
        case "grill": tr("Grill", "Гриль", "Grill")
        case "fastfood": tr("Fast-fud", "Фастфуд", "Fast food")
        case "coffee": tr("Qahva", "Кофе", "Coffee")
        case "desserts": tr("Shirinliklar", "Десерты", "Desserts")
        default: humanize(k)
        }
    }

    /// Narx darajasi 1–4 (mehmonxona — kecha uchun, ovqat — bir kishi uchun)
    static func price(_ n: Int, stay: Bool) -> String? {
        guard (1...4).contains(n) else { return nil }
        let stayT = [tr("~40 $ gacha", "до ~40 $", "up to ~$40"), "40–80 $", "80–150 $", tr("150 $ dan yuqori", "от 150 $", "$150+")]
        let eatT = [tr("70 ming soʻmgacha", "до 70 тыс. сум", "under 70k sum"), tr("70–150 ming soʻm", "70–150 тыс. сум", "70–150k sum"),
                    tr("150–300 ming soʻm", "150–300 тыс. сум", "150–300k sum"), tr("300 ming soʻmdan yuqori", "от 300 тыс. сум", "300k+ sum")]
        return String(repeating: "$", count: n) + " · " + (stay ? stayT : eatT)[n - 1]
    }

    static func field(_ k: String) -> String {
        switch k {
        case "olim": tr("Olim", "Учёный", "Scholar")
        case "shoir": tr("Shoir va adib", "Поэт и писатель", "Poet & writer")
        case "hukmdor": tr("Hukmdor", "Правитель", "Ruler")
        case "din": tr("Ilohiyotchi", "Богослов", "Theologian")
        case "sanat": tr("Sanʼatkor", "Деятель искусства", "Artist")
        case "zamonaviy": tr("Zamonaviy davr", "Новейшее время", "Modern era")
        default: humanize(k)
        }
    }

    static func recurring(_ k: String) -> String {
        switch k {
        case "annual": tr("Har yili", "Ежегодно", "Every year")
        case "biennial": tr("Ikki yilda bir marta", "Раз в два года", "Every two years")
        case "once": tr("Bir martalik", "Однократно", "One-off")
        default: humanize(k)
        }
    }

    static func routeTheme(_ k: String) -> String {
        switch k {
        case "klassik": tr("Klassik", "Классика", "Classic")
        case "toliq": tr("Katta sayohat", "Большое путешествие", "Grand tour")
        case "hunarmandchilik": tr("Hunarmandchilik", "Ремёсла", "Crafts")
        case "ekspeditsiya": tr("Ekspeditsiya", "Экспедиция", "Expedition")
        case "janub": tr("Janub", "Юг", "The south")
        case "toglar": tr("Togʻlar", "Горы", "Mountains")
        case "shahar": tr("Shahar sayri", "Город", "City break")
        case "ziyorat": tr("Ziyorat", "Паломничество", "Pilgrimage")
        case "eko": tr("Ekoturizm", "Экотуризм", "Eco-travel")
        case "gastronomiya": tr("Gastronomiya", "Гастрономия", "Food")
        case "tezkor": tr("Qisqa safar", "Экспресс", "Short trip")
        default: humanize(k)
        }
    }

    static func orgKind(_ k: String) -> String {
        switch k {
        case "markaziy": tr("Markaziy organ", "Центральный орган", "Central body")
        case "vazirlik": tr("Vazirlik", "Министерство", "Ministry")
        case "qomita": tr("Davlat qoʻmitasi", "Госкомитет", "State committee")
        case "agentlik": tr("Agentlik", "Агентство", "Agency")
        case "hokimiyat": tr("Hokimlik", "Хокимият", "Khokimiyat")
        case "dxm": tr("Davlat xizmatlari markazi", "Центр госуслуг", "Public Service Centre")
        case "iib": tr("Ichki ishlar (IIB)", "ОВД", "Police")
        case "yhxb": tr("YHXB", "ГУБДД", "Traffic police")
        case "migratsiya": tr("Migratsiya", "Миграция", "Migration")
        case "prokuratura": tr("Prokuratura", "Прокуратура", "Prosecutor’s office")
        case "sud": tr("Sud", "Суд", "Court")
        case "adliya": tr("Adliya", "Юстиция", "Justice")
        case "fhdyo": tr("FHDYO", "ЗАГС", "Civil registry")
        case "bojxona": tr("Bojxona", "Таможня", "Customs")
        case "soliq": tr("Soliq", "Налоговая", "Tax office")
        case "fvv": tr("FVV", "МЧС", "Emergencies")
        case "kadastr": tr("Kadastr", "Кадастр", "Cadastre")
        case "bandlik": tr("Bandlik", "Занятость", "Employment")
        case "ijtimoiy": tr("Ijtimoiy himoya", "Соцзащита", "Social protection")
        case "mudofaa": tr("Mudofaa ishlari", "Оборонные дела", "Military registration")
        case "boshqarma": tr("Boshqarma", "Управление", "Department")
        default: humanize(k)
        }
    }

    static func orgLevel(_ k: String) -> String {
        switch k {
        case "respublika": tr("Respublika darajasi", "Республиканский уровень", "National level")
        case "viloyat": tr("Viloyat darajasi", "Областной уровень", "Regional level")
        case "shahar": tr("Shahar darajasi", "Городской уровень", "City level")
        case "tuman": tr("Tuman darajasi", "Районный уровень", "District level")
        case "post": tr("Post / punkt", "Пост / пункт", "Post / checkpoint")
        default: humanize(k)
        }
    }

    static func ownership(_ k: String) -> String {
        switch k {
        case "davlat": tr("Davlat banki", "Государственный банк", "State-owned bank")
        case "xususiy": tr("Xususiy bank", "Частный банк", "Private bank")
        case "xorijiy": tr("Xorijiy kapitalli bank", "Банк с иностранным капиталом", "Foreign-owned bank")
        default: humanize(k)
        }
    }

    static func bankService(_ k: String) -> (String, String) {
        switch k {
        case "fx": (tr("Valyuta ayirboshlash", "Обмен валюты", "Currency exchange"), "dollarsign.arrow.circlepath")
        case "atm_foreign_cards": (tr("Xorijiy karta bilan bankomat", "Банкоматы для иностранных карт", "ATMs for foreign cards"), "creditcard.and.123")
        case "transfers": (tr("Xalqaro pul oʻtkazmalari", "Международные переводы", "International transfers"), "arrow.left.arrow.right")
        case "online_card": (tr("Masofadan karta ochish", "Онлайн-оформление карты", "Open a card online"), "iphone")
        case "nonresident_account": (tr("Norezidentlarga hisob va karta", "Счёт и карта для нерезидентов", "Accounts for non-residents"), "person.text.rectangle")
        case "deposits": (tr("Omonatlar", "Вклады", "Deposits"), "banknote")
        case "mortgage": (tr("Ipoteka", "Ипотека", "Mortgages"), "house")
        case "auto_loan": (tr("Avtokredit", "Автокредит", "Car loans"), "car")
        case "microloan": (tr("Mikroqarz", "Микрозайм", "Microloans"), "dollarsign.circle")
        case "business": (tr("Yuridik shaxslarga", "Для бизнеса", "Business banking"), "briefcase")
        default: (humanize(k), "checkmark.circle")
        }
    }

    static func cardBrand(_ k: String) -> String {
        switch k.lowercased() {
        case "uzcard": "Uzcard"; case "humo": "Humo"; case "visa": "Visa"; case "mastercard": "Mastercard"
        case "unionpay": "UnionPay"; case "jcb": "JCB"; case "mir": "Mir"; case "amex": "American Express"
        default: humanize(k)
        }
    }

    static func postKind(_ k: String) -> String {
        switch k {
        case "pochtamt": tr("Pochtamt", "Почтамт", "Main post office")
        case "bolim", "boʻlim": tr("Aloqa boʻlimi", "Отделение связи", "Post office")
        default: humanize(k)
        }
    }

    static func postService(_ k: String) -> String {
        switch k {
        case "ems": tr("EMS — xalqaro tezkor pochta", "EMS — международная экспресс-почта", "EMS express mail")
        case "bir-qadam": tr("«Bir qadam»", "«Bir qadam»", "Bir Qadam")
        case "xalq-global": "Xalq Global"
        case "uzum": "Uzum Market"
        case "ozon": "Ozon"
        case "zoodmall": "ZoodMall"
        default: humanize(k)
        }
    }

    static func transportMode(_ k: String) -> (String, String) {
        switch k {
        case "metro": (tr("Metro", "Метро", "Metro"), "tram.fill.tunnel")
        case "avtobus": (tr("Avtobus", "Автобус", "Bus"), "bus")
        case "marshrutka": (tr("Marshrutka", "Маршрутка", "Minibus"), "bus.doubledecker")
        case "tramvay": (tr("Tramvay", "Трамвай", "Tram"), "tram")
        case "trolleybus": (tr("Trolleybus", "Троллейбус", "Trolleybus"), "bolt.car")
        case "taksi": (tr("Taksi", "Такси", "Taxi"), "car")
        case "elektrobus": (tr("Elektrobus", "Электробус", "Electric bus"), "bolt")
        default: (humanize(k), "mappin.and.ellipse")
        }
    }

    static func trainType(_ k: String) -> String {
        switch k {
        case "highspeed": tr("Tezyurar", "Скоростной", "High-speed")
        case "fast": tr("Tezkor", "Скорый", "Express")
        case "passenger": tr("Yoʻlovchi", "Пассажирский", "Passenger")
        case "night": tr("Tungi", "Ночной", "Night")
        case "suburban": tr("Shahar atrofi", "Пригородный", "Suburban")
        default: humanize(k)
        }
    }

    static func districtType(_ k: String) -> String {
        switch k {
        case "shahar": tr("Shahar", "Город", "City")
        case "tuman": tr("Tuman", "Район", "District")
        default: humanize(k)
        }
    }

    /// Qisqa oy nomlari (mavsum chizig'i)
    static func monthShort(_ m: Int) -> String {
        let names: [String] = switch Lang.current {
        case .uz: ["Yan", "Fev", "Mar", "Apr", "May", "Iyn", "Iyl", "Avg", "Sen", "Okt", "Noy", "Dek"]
        case .ru: ["Янв", "Фев", "Мар", "Апр", "Май", "Июн", "Июл", "Авг", "Сен", "Окт", "Ноя", "Дек"]
        case .en: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        }
        return (1...12).contains(m) ? names[m - 1] : ""
    }

    /// Yil: manfiy — miloddan avvalgi
    static func year(_ y: Int) -> String {
        y < 0 ? tr("mil. av. \(-y)", "\(-y) до н. э.", "\(-y) BC") : "\(y)"
    }

    /// Ruscha ko'plik: 1 год / 2 года / 5 лет
    static func ruPlural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let m10 = n % 10, m100 = n % 100
        if m10 == 1 && m100 != 11 { return one }
        if (2...4).contains(m10) && !(12...14).contains(m100) { return few }
        return many
    }

    /// "dam-olish" → "Dam olish", "chilonzor_yoli" → "Chilonzor yoli"
    static func humanize(_ k: String) -> String {
        let s = k.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ").trimmingCharacters(in: .whitespaces)
        guard let f = s.first else { return k }
        return f.uppercased() + s.dropFirst()
    }

    /// Bekat slug'idan nom: "shovot-vokzali" → "Shovot", "toshkent-janubiy-vokzali" → "Toshkent janubiy"
    static func stationName(_ slug: String) -> String {
        var s = slug
        for suf in ["-vokzali", "-stansiyasi", "-bekati", "-temir-yol-vokzali"] where s.hasSuffix(suf) { s.removeLast(suf.count) }
        return humanize(s)
    }
}
