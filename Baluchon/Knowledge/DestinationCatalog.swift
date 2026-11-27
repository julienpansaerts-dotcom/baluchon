import Foundation

struct CatalogCity: Hashable {
    let name: String
    let aliases: [String]
    let latitude: Double
    let longitude: Double

    init(_ name: String, _ latitude: Double, _ longitude: Double, aliases: [String] = []) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.aliases = aliases
    }
}

struct CatalogPlace: Hashable {
    let name: String
    let aliases: [String]
    let city: String
    let category: PlaceCategory
    let latitude: Double
    let longitude: Double
    /// Nombre de jours conseillés pour réserver à l'avance (0 = pas besoin).
    let leadDays: Int

    init(_ name: String, city: String, _ category: PlaceCategory, _ latitude: Double, _ longitude: Double,
         book leadDays: Int = 0, aliases: [String] = []) {
        self.name = name
        self.city = city
        self.category = category
        self.latitude = latitude
        self.longitude = longitude
        self.leadDays = leadDays
        self.aliases = aliases
    }

    var needsBooking: Bool { leadDays > 0 }
}

struct EmergencyNumber: Hashable {
    let label: String
    let number: String
}

struct Destination: Identifiable, Hashable {
    let key: String
    let name: String
    let flag: String
    let keywords: [String]
    let cities: [CatalogCity]
    let places: [CatalogPlace]
    let currencyCode: String
    /// Code BCP-47 pour les phrases préécrites et la synthèse vocale (`nil` si non géré).
    let languageCode: String?
    let languageName: String
    let plugTypes: String
    let isTropical: Bool
    let emergency: [EmergencyNumber]

    var id: String { key }
}

/// Catalogue embarqué (fonctionne hors ligne). Il sert à reconnaître les
/// destinations, à placer les lieux sur la carte et à préparer le mode voyage.
/// Les conditions d'entrée (visa…) ne sont volontairement PAS codées en dur :
/// elles dépendent de la nationalité et changent ; l'app renvoie vers les sources officielles.
enum DestinationCatalog {
    static func destination(for key: String?) -> Destination? {
        guard let key else { return nil }
        return all.first { $0.key == key }
    }

    static let all: [Destination] = [
        Destination(
            key: "vn", name: "Vietnam", flag: "🇻🇳",
            keywords: ["vietnam", "viet nam", "việt nam", "pho", "banh mi", "bun cha", "ao dai"],
            cities: [
                CatalogCity("Hanoï", 21.0285, 105.8542, aliases: ["hanoi", "ha noi"]),
                CatalogCity("Sapa", 22.3364, 103.8438, aliases: ["sa pa"]),
                CatalogCity("Baie d'Along", 20.9101, 107.1839, aliases: ["ha long", "halong", "lan ha"]),
                CatalogCity("Ninh Binh", 20.2506, 105.9745, aliases: ["ninh bình", "tam coc", "trang an"]),
                CatalogCity("Hué", 16.4637, 107.5909, aliases: ["hue"]),
                CatalogCity("Hoi An", 15.8801, 108.3380, aliases: ["hoian", "hội an"]),
                CatalogCity("Da Nang", 16.0544, 108.2022, aliases: ["danang", "đà nẵng"]),
                CatalogCity("Hô Chi Minh-Ville", 10.8231, 106.6297, aliases: ["ho chi minh", "saigon", "sai gon", "hcmc"]),
                CatalogCity("Delta du Mékong", 10.0452, 105.7469, aliases: ["mekong", "can tho"]),
                CatalogCity("Phu Quoc", 10.2899, 103.9840, aliases: ["phú quốc"]),
            ],
            places: [
                CatalogPlace("Lac Hoan Kiem", city: "Hanoï", .sight, 21.0288, 105.8525, aliases: ["hoan kiem"]),
                CatalogPlace("Train Street", city: "Hanoï", .sight, 21.0262, 105.8433, aliases: ["rue du train"]),
                CatalogPlace("Croisière dans la baie d'Along", city: "Baie d'Along", .activity, 20.9101, 107.1839, book: 21,
                             aliases: ["croisiere", "cruise", "halong bay", "ha long bay", "lan ha bay"]),
                CatalogPlace("Tam Coc", city: "Ninh Binh", .nature, 20.2156, 105.9375, aliases: ["trang an", "mua cave"]),
                CatalogPlace("Rizières de Sapa", city: "Sapa", .nature, 22.3364, 103.8438, aliases: ["rice terraces", "rizieres"]),
                CatalogPlace("Cité impériale de Hué", city: "Hué", .sight, 16.4698, 107.5786, aliases: ["imperial city", "cite imperiale"]),
                CatalogPlace("Vieille ville de Hoi An", city: "Hoi An", .sight, 15.8770, 108.3266, aliases: ["ancient town", "old town hoi an"]),
                CatalogPlace("Ba Na Hills (Golden Bridge)", city: "Da Nang", .sight, 15.9950, 107.9960, aliases: ["golden bridge", "ba na", "pont d or"]),
                CatalogPlace("Tunnels de Cu Chi", city: "Hô Chi Minh-Ville", .activity, 11.1426, 106.4630, aliases: ["cu chi"]),
            ],
            currencyCode: "VND", languageCode: "vi-VN", languageName: "vietnamien",
            plugTypes: "A, C, D", isTropical: true,
            emergency: [
                EmergencyNumber(label: "Police", number: "113"),
                EmergencyNumber(label: "Pompiers", number: "114"),
                EmergencyNumber(label: "Ambulance", number: "115"),
            ]
        ),
        Destination(
            key: "nyc", name: "New York", flag: "🇺🇸",
            keywords: ["new york", "nyc", "newyork", "big apple"],
            cities: [
                CatalogCity("Manhattan", 40.7831, -73.9712, aliases: ["new york city"]),
                CatalogCity("Brooklyn", 40.6782, -73.9442, aliases: ["dumbo", "williamsburg"]),
            ],
            places: [
                CatalogPlace("Statue de la Liberté", city: "Manhattan", .sight, 40.6892, -74.0445, book: 30, aliases: ["statue of liberty", "statue de la liberte"]),
                CatalogPlace("Central Park", city: "Manhattan", .nature, 40.7829, -73.9654),
                CatalogPlace("Empire State Building", city: "Manhattan", .sight, 40.7484, -73.9857, book: 7),
                CatalogPlace("Top of the Rock", city: "Manhattan", .sight, 40.7593, -73.9794, book: 7, aliases: ["rockefeller"]),
                CatalogPlace("Summit One Vanderbilt", city: "Manhattan", .sight, 40.7527, -73.9787, book: 14, aliases: ["summit"]),
                CatalogPlace("High Line", city: "Manhattan", .sight, 40.7480, -74.0048),
                CatalogPlace("MoMA", city: "Manhattan", .sight, 40.7614, -73.9776, book: 7, aliases: ["museum of modern art"]),
                CatalogPlace("Metropolitan Museum of Art", city: "Manhattan", .sight, 40.7794, -73.9632, aliases: ["the met", "metropolitan museum"]),
                CatalogPlace("Pont de Brooklyn", city: "Brooklyn", .sight, 40.7061, -73.9969, aliases: ["brooklyn bridge"]),
                CatalogPlace("Spectacle à Broadway", city: "Manhattan", .activity, 40.7590, -73.9845, book: 21, aliases: ["broadway"]),
                CatalogPlace("Katz's Delicatessen", city: "Manhattan", .restaurant, 40.7223, -73.9874, aliases: ["katz", "katzs"]),
            ],
            currencyCode: "USD", languageCode: "en-US", languageName: "anglais",
            plugTypes: "A, B", isTropical: false,
            emergency: [EmergencyNumber(label: "Urgences (police, pompiers, ambulance)", number: "911")]
        ),
        Destination(
            key: "jp", name: "Japon", flag: "🇯🇵",
            keywords: ["japon", "japan", "nihon", "日本", "ramen", "sushi", "onsen", "ryokan", "sakura"],
            cities: [
                CatalogCity("Tokyo", 35.6762, 139.6503, aliases: ["東京", "shibuya", "shinjuku", "asakusa"]),
                CatalogCity("Hakone", 35.2324, 139.1069, aliases: ["fuji", "kawaguchiko"]),
                CatalogCity("Kyoto", 35.0116, 135.7681, aliases: ["京都", "gion", "arashiyama"]),
                CatalogCity("Nara", 34.6851, 135.8048),
                CatalogCity("Osaka", 34.6937, 135.5023, aliases: ["大阪", "dotonbori"]),
                CatalogCity("Hiroshima", 34.3853, 132.4553, aliases: ["miyajima"]),
            ],
            places: [
                CatalogPlace("Carrefour de Shibuya", city: "Tokyo", .sight, 35.6595, 139.7005, aliases: ["shibuya crossing"]),
                CatalogPlace("Temple Senso-ji", city: "Tokyo", .sight, 35.7148, 139.7967, aliases: ["sensoji", "senso ji"]),
                CatalogPlace("teamLab Planets", city: "Tokyo", .activity, 35.6491, 139.7898, book: 30, aliases: ["teamlab"]),
                CatalogPlace("Musée Ghibli", city: "Tokyo", .sight, 35.6962, 139.5704, book: 45, aliases: ["ghibli"]),
                CatalogPlace("Mont Fuji", city: "Hakone", .nature, 35.3606, 138.7274, aliases: ["mount fuji", "fujisan"]),
                CatalogPlace("Fushimi Inari", city: "Kyoto", .sight, 34.9671, 135.7727, aliases: ["fushimi inari taisha"]),
                CatalogPlace("Kinkaku-ji (Pavillon d'or)", city: "Kyoto", .sight, 35.0394, 135.7292, aliases: ["kinkakuji", "golden pavilion", "pavillon d or"]),
                CatalogPlace("Bambouseraie d'Arashiyama", city: "Kyoto", .nature, 35.0170, 135.6713, aliases: ["bamboo forest", "bambouseraie"]),
                CatalogPlace("Parc de Nara", city: "Nara", .nature, 34.6851, 135.8430, aliases: ["nara park", "daims", "deer park"]),
                CatalogPlace("Dotonbori", city: "Osaka", .sight, 34.6687, 135.5013),
                CatalogPlace("Mémorial de la paix", city: "Hiroshima", .sight, 34.3955, 132.4536, aliases: ["peace memorial", "memorial de la paix"]),
            ],
            currencyCode: "JPY", languageCode: "ja-JP", languageName: "japonais",
            plugTypes: "A, B", isTropical: false,
            emergency: [
                EmergencyNumber(label: "Police", number: "110"),
                EmergencyNumber(label: "Pompiers / ambulance", number: "119"),
            ]
        ),
        Destination(
            key: "th", name: "Thaïlande", flag: "🇹🇭",
            keywords: ["thailande", "thailand", "pad thai", "tuk tuk"],
            cities: [
                CatalogCity("Bangkok", 13.7563, 100.5018, aliases: ["krung thep"]),
                CatalogCity("Ayutthaya", 14.3532, 100.5689),
                CatalogCity("Chiang Mai", 18.7883, 98.9853, aliases: ["chiangmai"]),
                CatalogCity("Koh Samui", 9.5120, 100.0136, aliases: ["ko samui", "samui", "koh phangan", "koh tao"]),
                CatalogCity("Phuket", 7.8804, 98.3923),
                CatalogCity("Krabi", 8.0863, 98.9063, aliases: ["ao nang", "railay", "phi phi"]),
            ],
            places: [
                CatalogPlace("Grand Palais", city: "Bangkok", .sight, 13.7500, 100.4913, aliases: ["grand palace"]),
                CatalogPlace("Wat Arun", city: "Bangkok", .sight, 13.7437, 100.4888),
                CatalogPlace("Wat Pho", city: "Bangkok", .sight, 13.7465, 100.4927),
                CatalogPlace("Doi Suthep", city: "Chiang Mai", .sight, 18.8048, 98.9216),
                CatalogPlace("Sanctuaire d'éléphants éthique", city: "Chiang Mai", .activity, 18.7883, 98.9853, book: 14,
                             aliases: ["elephant sanctuary", "sanctuaire elephants", "elephant nature park"]),
                CatalogPlace("Railay Beach", city: "Krabi", .nature, 8.0115, 98.8378),
                CatalogPlace("Îles Phi Phi", city: "Krabi", .nature, 7.7407, 98.7784, book: 7, aliases: ["phi phi", "maya bay"]),
            ],
            currencyCode: "THB", languageCode: "th-TH", languageName: "thaï",
            plugTypes: "A, B, C, O", isTropical: true,
            emergency: [
                EmergencyNumber(label: "Police touristique (anglais)", number: "1155"),
                EmergencyNumber(label: "Police", number: "191"),
                EmergencyNumber(label: "Ambulance", number: "1669"),
                EmergencyNumber(label: "Pompiers", number: "199"),
            ]
        ),
        Destination(
            key: "it", name: "Italie", flag: "🇮🇹",
            keywords: ["italie", "italy", "italia", "toscane", "tuscany", "dolce vita", "gelato"],
            cities: [
                CatalogCity("Milan", 45.4642, 9.1900, aliases: ["milano"]),
                CatalogCity("Venise", 45.4408, 12.3155, aliases: ["venezia", "venice"]),
                CatalogCity("Cinque Terre", 44.1270, 9.7090, aliases: ["manarola", "vernazza"]),
                CatalogCity("Florence", 43.7696, 11.2558, aliases: ["firenze"]),
                CatalogCity("Rome", 41.9028, 12.4964, aliases: ["roma"]),
                CatalogCity("Naples", 40.8518, 14.2681, aliases: ["napoli", "pompei"]),
                CatalogCity("Côte amalfitaine", 40.6281, 14.4850, aliases: ["amalfi", "positano", "amalfi coast"]),
            ],
            places: [
                CatalogPlace("Colisée", city: "Rome", .sight, 41.8902, 12.4922, book: 30, aliases: ["colosseum", "colosseo", "colisee"]),
                CatalogPlace("Musées du Vatican", city: "Rome", .sight, 41.9065, 12.4536, book: 30, aliases: ["vatican", "chapelle sixtine", "sistine"]),
                CatalogPlace("Fontaine de Trevi", city: "Rome", .sight, 41.9009, 12.4833, aliases: ["trevi"]),
                CatalogPlace("Galerie des Offices", city: "Florence", .sight, 43.7678, 11.2553, book: 21, aliases: ["uffizi", "offices"]),
                CatalogPlace("La Cène de Léonard de Vinci", city: "Milan", .sight, 45.4659, 9.1709, book: 60, aliases: ["last supper", "cenacolo", "la cene"]),
                CatalogPlace("Place Saint-Marc", city: "Venise", .sight, 45.4341, 12.3388, aliases: ["san marco", "saint marc"]),
                CatalogPlace("Pompéi", city: "Naples", .sight, 40.7489, 14.4848, book: 7, aliases: ["pompeii", "pompei"]),
            ],
            currencyCode: "EUR", languageCode: "it-IT", languageName: "italien",
            plugTypes: "C, F, L", isTropical: false,
            emergency: [EmergencyNumber(label: "Urgences (numéro européen)", number: "112")]
        ),
        Destination(
            key: "es", name: "Espagne", flag: "🇪🇸",
            keywords: ["espagne", "spain", "espana", "andalousie", "andalucia", "tapas", "paella"],
            cities: [
                CatalogCity("Barcelone", 41.3874, 2.1686, aliases: ["barcelona"]),
                CatalogCity("Madrid", 40.4168, -3.7038),
                CatalogCity("Valence", 39.4699, -0.3763, aliases: ["valencia"]),
                CatalogCity("Séville", 37.3891, -5.9845, aliases: ["sevilla", "seville"]),
                CatalogCity("Grenade", 37.1773, -3.5986, aliases: ["granada"]),
            ],
            places: [
                CatalogPlace("Sagrada Família", city: "Barcelone", .sight, 41.4036, 2.1744, book: 30, aliases: ["sagrada familia"]),
                CatalogPlace("Parc Güell", city: "Barcelone", .sight, 41.4145, 2.1527, book: 14, aliases: ["park guell", "parc guell"]),
                CatalogPlace("Musée du Prado", city: "Madrid", .sight, 40.4138, -3.6921, book: 7, aliases: ["prado"]),
                CatalogPlace("Alcázar de Séville", city: "Séville", .sight, 37.3831, -5.9902, book: 14, aliases: ["alcazar"]),
                CatalogPlace("Plaza de España", city: "Séville", .sight, 37.3772, -5.9869, aliases: ["plaza de espana"]),
                CatalogPlace("Alhambra", city: "Grenade", .sight, 37.1761, -3.5881, book: 60),
            ],
            currencyCode: "EUR", languageCode: "es-ES", languageName: "espagnol",
            plugTypes: "C, F", isTropical: false,
            emergency: [EmergencyNumber(label: "Urgences (numéro européen)", number: "112")]
        ),
        Destination(
            key: "pt", name: "Portugal", flag: "🇵🇹",
            keywords: ["portugal", "pasteis de nata", "pastel de nata", "azulejos"],
            cities: [
                CatalogCity("Porto", 41.1579, -8.6291),
                CatalogCity("Lisbonne", 38.7223, -9.1393, aliases: ["lisboa", "lisbon"]),
                CatalogCity("Sintra", 38.8029, -9.3817),
                CatalogCity("Algarve", 37.1028, -8.6730, aliases: ["lagos", "faro", "benagil"]),
            ],
            places: [
                CatalogPlace("Livraria Lello", city: "Porto", .sight, 41.1469, -8.6149, book: 7, aliases: ["lello"]),
                CatalogPlace("Pont Dom-Luís", city: "Porto", .sight, 41.1399, -8.6094, aliases: ["ponte luis", "dom luis"]),
                CatalogPlace("Tour de Belém", city: "Lisbonne", .sight, 38.6916, -9.2160, aliases: ["belem"]),
                CatalogPlace("Tram 28", city: "Lisbonne", .activity, 38.7139, -9.1334, aliases: ["electrico 28"]),
                CatalogPlace("Palais de Pena", city: "Sintra", .sight, 38.7876, -9.3906, book: 14, aliases: ["pena palace", "palacio da pena"]),
                CatalogPlace("Ponta da Piedade", city: "Algarve", .nature, 37.0806, -8.6693),
            ],
            currencyCode: "EUR", languageCode: "pt-PT", languageName: "portugais",
            plugTypes: "C, F", isTropical: false,
            emergency: [EmergencyNumber(label: "Urgences (numéro européen)", number: "112")]
        ),
        Destination(
            key: "gr", name: "Grèce", flag: "🇬🇷",
            keywords: ["grece", "greece", "cyclades", "hellas"],
            cities: [
                CatalogCity("Athènes", 37.9838, 23.7275, aliases: ["athens", "athenes"]),
                CatalogCity("Mykonos", 37.4467, 25.3289),
                CatalogCity("Naxos", 37.1036, 25.3766, aliases: ["paros"]),
                CatalogCity("Santorin", 36.3932, 25.4615, aliases: ["santorini", "oia", "fira"]),
                CatalogCity("Crète", 35.3387, 25.1442, aliases: ["crete", "heraklion", "chania", "la canee"]),
            ],
            places: [
                CatalogPlace("Acropole", city: "Athènes", .sight, 37.9715, 23.7257, book: 14, aliases: ["acropolis", "parthenon"]),
                CatalogPlace("Little Venice", city: "Mykonos", .sight, 37.4458, 25.3256),
                CatalogPlace("Coucher de soleil à Oia", city: "Santorin", .sight, 36.4618, 25.3753, aliases: ["oia sunset"]),
                CatalogPlace("Palais de Knossos", city: "Crète", .sight, 35.2980, 25.1631, book: 7, aliases: ["knossos"]),
                CatalogPlace("Plage de Balos", city: "Crète", .nature, 35.5833, 23.5889, aliases: ["balos"]),
            ],
            currencyCode: "EUR", languageCode: "el-GR", languageName: "grec",
            plugTypes: "C, F", isTropical: false,
            emergency: [EmergencyNumber(label: "Urgences (numéro européen)", number: "112")]
        ),
        Destination(
            key: "ma", name: "Maroc", flag: "🇲🇦",
            keywords: ["maroc", "morocco", "sahara", "riad", "tajine", "medina"],
            cities: [
                CatalogCity("Chefchaouen", 35.1688, -5.2636, aliases: ["chaouen"]),
                CatalogCity("Fès", 34.0181, -5.0078, aliases: ["fes", "fez"]),
                CatalogCity("Marrakech", 31.6295, -7.9811, aliases: ["marrakesh"]),
                CatalogCity("Essaouira", 31.5085, -9.7595),
                CatalogCity("Merzouga", 31.0802, -4.0134, aliases: ["erg chebbi"]),
            ],
            places: [
                CatalogPlace("Jardin Majorelle", city: "Marrakech", .sight, 31.6417, -8.0031, book: 7, aliases: ["majorelle"]),
                CatalogPlace("Place Jemaa el-Fna", city: "Marrakech", .sight, 31.6258, -7.9891, aliases: ["jemaa el fna", "jamaa el fna"]),
                CatalogPlace("Médina de Fès", city: "Fès", .sight, 34.0648, -4.9734, aliases: ["fes el bali"]),
                CatalogPlace("Ville bleue de Chefchaouen", city: "Chefchaouen", .sight, 35.1688, -5.2636, aliases: ["blue city", "ville bleue"]),
                CatalogPlace("Nuit en bivouac dans le désert", city: "Merzouga", .activity, 31.0802, -4.0134, book: 21, aliases: ["bivouac", "desert camp"]),
            ],
            currencyCode: "MAD", languageCode: nil, languageName: "arabe, amazigh (le français est très répandu)",
            plugTypes: "C, E", isTropical: false,
            emergency: [
                EmergencyNumber(label: "Police (en ville)", number: "19"),
                EmergencyNumber(label: "Gendarmerie (hors ville)", number: "177"),
                EmergencyNumber(label: "Pompiers / ambulance", number: "15"),
            ]
        ),
        Destination(
            key: "mx", name: "Mexique", flag: "🇲🇽",
            keywords: ["mexique", "mexico", "yucatan", "cenote", "tacos", "riviera maya"],
            cities: [
                CatalogCity("Mexico", 19.4326, -99.1332, aliases: ["ciudad de mexico", "cdmx", "mexico city"]),
                CatalogCity("Oaxaca", 17.0732, -96.7266),
                CatalogCity("Mérida", 20.9674, -89.5926, aliases: ["merida", "valladolid"]),
                CatalogCity("Cancún", 21.1619, -86.8515, aliases: ["cancun"]),
                CatalogCity("Playa del Carmen", 20.6296, -87.0739),
                CatalogCity("Tulum", 20.2114, -87.4654),
            ],
            places: [
                CatalogPlace("Teotihuacan", city: "Mexico", .sight, 19.6925, -98.8438),
                CatalogPlace("Musée Frida Kahlo", city: "Mexico", .sight, 19.3551, -99.1625, book: 21, aliases: ["frida kahlo", "casa azul"]),
                CatalogPlace("Hierve el Agua", city: "Oaxaca", .nature, 16.8656, -96.2761),
                CatalogPlace("Chichén Itzá", city: "Mérida", .sight, 20.6843, -88.5678, book: 7, aliases: ["chichen itza"]),
                CatalogPlace("Cenote Ik Kil", city: "Mérida", .nature, 20.6608, -88.5506, aliases: ["ik kil"]),
                CatalogPlace("Ruines de Tulum", city: "Tulum", .sight, 20.2147, -87.4291, aliases: ["tulum ruins"]),
            ],
            currencyCode: "MXN", languageCode: "es-MX", languageName: "espagnol",
            plugTypes: "A, B", isTropical: true,
            emergency: [EmergencyNumber(label: "Urgences", number: "911")]
        ),
        Destination(
            key: "bali", name: "Bali & Indonésie", flag: "🇮🇩",
            keywords: ["bali", "indonesie", "indonesia", "nusa", "gili"],
            cities: [
                CatalogCity("Yogyakarta", -7.7956, 110.3695, aliases: ["jogja", "borobudur"]),
                CatalogCity("Ubud", -8.5069, 115.2625),
                CatalogCity("Canggu", -8.6478, 115.1385, aliases: ["seminyak"]),
                CatalogCity("Uluwatu", -8.8291, 115.0849),
                CatalogCity("Nusa Penida", -8.7275, 115.5444, aliases: ["nusa lembongan"]),
                CatalogCity("Îles Gili", -8.3500, 116.0389, aliases: ["gili trawangan", "gili air", "gili meno"]),
            ],
            places: [
                CatalogPlace("Borobudur", city: "Yogyakarta", .sight, -7.6079, 110.2038, book: 14),
                CatalogPlace("Rizières de Tegallalang", city: "Ubud", .nature, -8.4335, 115.2793, aliases: ["tegallalang", "rice terrace"]),
                CatalogPlace("Forêt des singes", city: "Ubud", .nature, -8.5188, 115.2585, aliases: ["monkey forest"]),
                CatalogPlace("Lever de soleil au mont Batur", city: "Ubud", .activity, -8.2420, 115.3751, book: 3, aliases: ["batur", "mount batur"]),
                CatalogPlace("Temple d'Uluwatu", city: "Uluwatu", .sight, -8.8291, 115.0849, aliases: ["uluwatu temple", "kecak"]),
                CatalogPlace("Kelingking Beach", city: "Nusa Penida", .nature, -8.7505, 115.4746, aliases: ["kelingking"]),
            ],
            currencyCode: "IDR", languageCode: "id-ID", languageName: "indonésien",
            plugTypes: "C, F", isTropical: true,
            emergency: [
                EmergencyNumber(label: "Urgences", number: "112"),
                EmergencyNumber(label: "Police", number: "110"),
                EmergencyNumber(label: "Ambulance", number: "118"),
            ]
        ),
    ]
}
