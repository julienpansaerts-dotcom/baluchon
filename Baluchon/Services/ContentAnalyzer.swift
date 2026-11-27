import Foundation
import NaturalLanguage

/// Normalisation de texte : minuscules, sans accents, ponctuation remplacée par des espaces.
enum TextNormalizer {
    static func normalize(_ string: String) -> String {
        let folded = string
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "D")
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        var output = String.UnicodeScalarView()
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                output.append(scalar)
            } else {
                output.append(" ")
            }
        }
        let collapsed = String(output).split(separator: " ").joined(separator: " ")
        return " \(collapsed) "
    }

    /// Le texte normalisé `haystack` contient-il `alias` (mot entier, ou hashtag collé) ?
    static func haystack(_ haystack: String, contains alias: String) -> Bool {
        let needle = normalize(alias)
        guard needle.count > 2 else { return false }
        if haystack.contains(needle) { return true }
        let compact = needle.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 4 else { return false }
        if haystack.contains(" \(compact) ") { return true }
        // Hashtags du type #hoianfood ou #santorinisunset
        if compact.count >= 5, haystack.contains(" \(compact)") { return true }
        return false
    }
}

struct DetectedPlace: Equatable {
    var name: String
    var category: PlaceCategory
    var city: String?
    var latitude: Double?
    var longitude: Double?
    var leadDays: Int

    var needsBooking: Bool { leadDays > 0 }
}

struct AnalysisResult: Equatable {
    var destinationKey: String?
    var places: [DetectedPlace]
}

/// Analyse hors ligne, sans IA : reconnaissance par mots-clés à partir du catalogue,
/// lignes « 📍 » des légendes Instagram/TikTok et entités nommées (NaturalLanguage).
enum KeywordAnalyzer {
    static func analyze(text: String, catalog: [Destination] = DestinationCatalog.all) -> AnalysisResult {
        let normalized = TextNormalizer.normalize(text)
        guard let destination = bestDestination(in: normalized, catalog: catalog) else {
            return AnalysisResult(destinationKey: nil, places: [])
        }
        var places: [DetectedPlace] = []

        // 1. Lieux connus du catalogue
        for place in destination.places where matches(place, in: normalized) {
            places.append(DetectedPlace(name: place.name, category: place.category, city: place.city,
                                        latitude: place.latitude, longitude: place.longitude, leadDays: place.leadDays))
        }

        // 2. Lignes « 📍 Nom du lieu, Ville »
        for line in text.components(separatedBy: .newlines) where line.contains("📍") {
            guard let raw = line.components(separatedBy: "📍").last else { continue }
            let name = raw.components(separatedBy: CharacterSet(charactersIn: ",–—|-")).first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard name.count >= 3, name.count <= 60 else { continue }
            let matchedCity = city(in: TextNormalizer.normalize(line), destination: destination)
            if isCityOrCountry(name, destination: destination) { continue }
            appendUnique(DetectedPlace(name: name, category: category(forContext: line) ?? .sight,
                                       city: matchedCity?.name, latitude: nil, longitude: nil, leadDays: 0), to: &places)
        }

        // 3. Entités nommées dont le contexte indique une catégorie (« restaurant », « temple »…)
        for (name, line) in namedEntities(in: text) {
            guard let detectedCategory = category(forContext: line), !isCityOrCountry(name, destination: destination) else { continue }
            let matchedCity = city(in: TextNormalizer.normalize(line), destination: destination)
            appendUnique(DetectedPlace(name: name, category: detectedCategory, city: matchedCity?.name,
                                       latitude: nil, longitude: nil, leadDays: 0), to: &places)
        }

        return AnalysisResult(destinationKey: destination.key, places: places)
    }

    /// Destination la plus probable dans un texte normalisé.
    static func bestDestination(in normalized: String, catalog: [Destination] = DestinationCatalog.all) -> Destination? {
        var best: (Destination, Int)?
        for destination in catalog {
            var score = 0
            if TextNormalizer.haystack(normalized, contains: destination.name) { score += 3 }
            score += destination.keywords.filter { TextNormalizer.haystack(normalized, contains: $0) }.count * 2
            for city in destination.cities where ([city.name] + city.aliases).contains(where: { TextNormalizer.haystack(normalized, contains: $0) }) {
                score += 2
            }
            score += destination.places.filter { matches($0, in: normalized) }.count * 3
            if score > (best?.1 ?? 0) { best = (destination, score) }
        }
        return best?.0
    }

    static func destination(named name: String) -> Destination? {
        bestDestination(in: TextNormalizer.normalize(name))
    }

    /// Destination dont une ville est à moins de `maxKm` des coordonnées.
    static func nearestDestination(latitude: Double, longitude: Double, maxKm: Double = 400) -> (Destination, CatalogCity)? {
        var best: (Destination, CatalogCity, Double)?
        for destination in DestinationCatalog.all {
            for city in destination.cities {
                let distance = Geo.distanceKm(latitude, longitude, city.latitude, city.longitude)
                if distance <= maxKm, distance < (best?.2 ?? .infinity) {
                    best = (destination, city, distance)
                }
            }
        }
        return best.map { ($0.0, $0.1) }
    }

    static func city(in normalized: String, destination: Destination) -> CatalogCity? {
        destination.cities.first { city in
            ([city.name] + city.aliases).contains { TextNormalizer.haystack(normalized, contains: $0) }
        }
    }

    static func catalogPlace(named name: String, in destination: Destination) -> CatalogPlace? {
        let normalized = TextNormalizer.normalize(name)
        return destination.places.first { matches($0, in: normalized) }
    }

    static func category(forContext context: String) -> PlaceCategory? {
        let normalized = TextNormalizer.normalize(context)
        let rules: [(PlaceCategory, [String])] = [
            (.hotel, ["hotel", "hostel", "auberge", "resort", "riad", "ryokan", "guesthouse", "homestay", "airbnb", "villa", "logement"]),
            (.restaurant, ["restaurant", "resto", "cafe", "coffee", "bistro", "brunch", "street food", "streetfood", "pho", "ramen",
                           "sushi", "pizzeria", "trattoria", "tapas", "boulangerie", "bakery", "food", "manger", "eat", "dinner", "lunch"]),
            (.nightlife, ["bar", "rooftop", "cocktail", "club", "speakeasy", "pub"]),
            (.activity, ["excursion", "tour", "cours de cuisine", "cooking class", "snorkeling", "plongee", "diving", "kayak",
                         "croisiere", "cruise", "trek", "spectacle", "show", "massage", "spa", "surf"]),
            (.nature, ["plage", "beach", "cascade", "waterfall", "lac", "lake", "mont", "mount", "randonnee", "hike", "rizieres",
                       "rice", "parc national", "national park", "ile", "island", "grotte", "cave", "cenote", "jungle", "viewpoint", "point de vue"]),
            (.shopping, ["boutique", "shop", "shopping", "mall", "concept store"]),
            (.sight, ["musee", "museum", "temple", "pagode", "pagoda", "palais", "palace", "cathedrale", "cathedral", "chateau",
                      "castle", "marche", "market", "quartier", "monument", "eglise", "church", "mosquee", "mosque", "sanctuaire", "shrine"]),
        ]
        for (category, words) in rules where words.contains(where: { TextNormalizer.haystack(normalized, contains: $0) }) {
            return category
        }
        return nil
    }

    // MARK: - Privé

    private static func matches(_ place: CatalogPlace, in normalized: String) -> Bool {
        ([place.name] + place.aliases).contains { TextNormalizer.haystack(normalized, contains: $0) }
    }

    private static func isCityOrCountry(_ name: String, destination: Destination) -> Bool {
        let normalized = TextNormalizer.normalize(name)
        if normalized == TextNormalizer.normalize(destination.name) { return true }
        return destination.cities.contains { city in
            ([city.name] + city.aliases).contains { TextNormalizer.normalize($0) == normalized }
        }
    }

    private static func appendUnique(_ place: DetectedPlace, to places: inout [DetectedPlace]) {
        let key = TextNormalizer.normalize(place.name)
        if !places.contains(where: { TextNormalizer.normalize($0.name) == key }) {
            places.append(place)
        }
    }

    /// Entités nommées (lieux, organisations) avec la ligne où elles apparaissent.
    private static func namedEntities(in text: String) -> [(String, String)] {
        var results: [(String, String)] = []
        for line in text.components(separatedBy: .newlines) where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            let tagger = NLTagger(tagSchemes: [.nameType])
            tagger.string = line
            let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
            tagger.enumerateTags(in: line.startIndex..<line.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
                if tag == .placeName || tag == .organizationName {
                    let name = String(line[range]).trimmingCharacters(in: .whitespaces)
                    if name.count >= 3 { results.append((name, line)) }
                }
                return results.count < 12
            }
            if results.count >= 12 { break }
        }
        return results
    }
}

enum Geo {
    static func distanceKm(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let radius = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return radius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

/// Lecture des liens Google Maps du type `/maps/place/Nom+du+lieu/@21.03,105.85,17z`.
enum GoogleMapsLinkParser {
    struct Result: Equatable {
        var name: String?
        var latitude: Double?
        var longitude: Double?
    }

    static func parse(_ url: URL) -> Result? {
        let path = url.path
        var result = Result()
        if let range = path.range(of: "/place/") {
            let rest = path[range.upperBound...]
            if let component = rest.split(separator: "/").first {
                result.name = component.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
                    ?? component.replacingOccurrences(of: "+", with: " ")
            }
        }
        let absolute = url.absoluteString
        if let at = absolute.range(of: "/@") {
            let coords = absolute[at.upperBound...].split(separator: ",")
            if coords.count >= 2, let lat = Double(coords[0]), let lon = Double(coords[1]) {
                result.latitude = lat
                result.longitude = lon
            }
        }
        if result.latitude == nil,
           let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "q" || $0.name == "query" })?.value {
            let parts = query.split(separator: ",")
            if parts.count == 2, let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
               let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                result.latitude = lat
                result.longitude = lon
            } else if result.name == nil {
                result.name = query
            }
        }
        return (result.name == nil && result.latitude == nil) ? nil : result
    }
}
