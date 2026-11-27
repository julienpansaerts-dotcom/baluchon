import Foundation

struct ParsedBooking: Equatable {
    var kind: BookingKind
    var title: String
    var reference: String?
    var startDate: Date?
    var endDate: Date?
    var location: String?
}

/// Lit un e-mail de réservation collé dans l'app.
/// 1. Données structurées schema.org (JSON-LD) présentes dans beaucoup d'e-mails
///    de compagnies aériennes, d'hôtels et de plateformes : fiable et sans IA.
/// 2. Sinon, mots-clés + expressions régulières + détection de dates.
enum BookingParser {
    static func parse(_ raw: String) -> ParsedBooking {
        if let structured = parseJSONLD(raw) { return structured }
        return parseHeuristically(raw)
    }

    // MARK: - JSON-LD

    static func parseJSONLD(_ raw: String) -> ParsedBooking? {
        guard let regex = try? NSRegularExpression(
            pattern: "<script[^>]*application/ld\\+json[^>]*>(.*?)</script>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(raw.startIndex..., in: raw)
        for match in regex.matches(in: raw, range: range) {
            guard let jsonRange = Range(match.range(at: 1), in: raw),
                  let data = String(raw[jsonRange]).data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            if let reservation = findReservation(in: json), let booking = booking(from: reservation) {
                return booking
            }
        }
        return nil
    }

    private static func findReservation(in json: Any) -> [String: Any]? {
        if let dict = json as? [String: Any] {
            if let type = dict["@type"] as? String, type.hasSuffix("Reservation") { return dict }
            if let graph = dict["@graph"] { return findReservation(in: graph) }
        }
        if let array = json as? [Any] {
            for element in array {
                if let found = findReservation(in: element) { return found }
            }
        }
        return nil
    }

    private static func booking(from r: [String: Any]) -> ParsedBooking? {
        let type = r["@type"] as? String ?? ""
        let target = r["reservationFor"] as? [String: Any] ?? [:]
        let reference = r["reservationNumber"] as? String

        switch type {
        case "FlightReservation":
            let airline = (target["airline"] as? [String: Any])?["iataCode"] as? String ?? ""
            let number = target["flightNumber"] as? String ?? ""
            let from = airportName(target["departureAirport"])
            let to = airportName(target["arrivalAirport"])
            return ParsedBooking(kind: .flight, title: "Vol \(airline)\(number) \(from) → \(to)".trimmingCharacters(in: .whitespaces),
                                 reference: reference, startDate: date(target["departureTime"]), endDate: date(target["arrivalTime"]),
                                 location: from)
        case "LodgingReservation":
            let name = target["name"] as? String ?? "Hébergement"
            return ParsedBooking(kind: .hotel, title: name, reference: reference,
                                 startDate: date(r["checkinTime"] ?? r["checkinDate"]),
                                 endDate: date(r["checkoutTime"] ?? r["checkoutDate"]),
                                 location: address(target["address"]))
        case "TrainReservation", "BusReservation":
            let from = (target["departureStation"] as? [String: Any])?["name"] as? String
                ?? (target["departureBusStop"] as? [String: Any])?["name"] as? String ?? ""
            let to = (target["arrivalStation"] as? [String: Any])?["name"] as? String
                ?? (target["arrivalBusStop"] as? [String: Any])?["name"] as? String ?? ""
            let kind: BookingKind = type == "TrainReservation" ? .train : .bus
            return ParsedBooking(kind: kind, title: "\(kind.label) \(from) → \(to)", reference: reference,
                                 startDate: date(target["departureTime"]), endDate: date(target["arrivalTime"]), location: from)
        case "FoodEstablishmentReservation":
            return ParsedBooking(kind: .restaurant, title: target["name"] as? String ?? "Restaurant", reference: reference,
                                 startDate: date(r["startTime"]), endDate: nil, location: address(target["address"]))
        case "EventReservation":
            return ParsedBooking(kind: .activity, title: target["name"] as? String ?? "Événement", reference: reference,
                                 startDate: date(target["startDate"]), endDate: date(target["endDate"]),
                                 location: address((target["location"] as? [String: Any])?["address"]))
        case "RentalCarReservation":
            return ParsedBooking(kind: .car, title: "Location de voiture", reference: reference,
                                 startDate: date(r["pickupTime"]), endDate: date(r["dropoffTime"]),
                                 location: (r["pickupLocation"] as? [String: Any])?["name"] as? String)
        default:
            return ParsedBooking(kind: .other, title: target["name"] as? String ?? "Réservation", reference: reference,
                                 startDate: date(r["startTime"]), endDate: date(r["endTime"]), location: nil)
        }
    }

    private static func airportName(_ value: Any?) -> String {
        guard let airport = value as? [String: Any] else { return "" }
        return airport["iataCode"] as? String ?? airport["name"] as? String ?? ""
    }

    private static func address(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        guard let dict = value as? [String: Any] else { return nil }
        let parts = ["streetAddress", "addressLocality", "addressCountry"].compactMap { dict[$0] as? String }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    static func date(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: string) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }

    // MARK: - Heuristique

    static func parseHeuristically(_ raw: String) -> ParsedBooking {
        let text = stripHTML(raw)
        let normalized = TextNormalizer.normalize(text)
        let rules: [(BookingKind, [String])] = [
            (.flight, ["vol", "flight", "boarding", "embarquement", "pnr", "airline", "aeroport", "airport", "e ticket", "billet electronique"]),
            (.hotel, ["hotel", "check in", "arrivee", "nuit", "nuits", "night", "booking com", "airbnb", "hebergement", "chambre", "room"]),
            (.train, ["train", "sncf", "eurostar", "gare", "voiture", "railway", "station", "shinkansen", "trenitalia", "renfe"]),
            (.bus, ["bus", "flixbus", "autocar", "coach"]),
            (.car, ["location de voiture", "car rental", "hertz", "europcar", "sixt", "permis"]),
            (.restaurant, ["restaurant", "table", "couverts", "diner", "thefork", "lafourchette"]),
            (.activity, ["visite", "excursion", "getyourguide", "viator", "tour", "musee", "museum", "entree", "admission", "billet"]),
        ]
        var best: (BookingKind, Int) = (.other, 0)
        for (kind, words) in rules {
            let score = words.filter { TextNormalizer.haystack(normalized, contains: $0) }.count
            if score > best.1 { best = (kind, score) }
        }

        let dates = detectDates(in: text)
        let firstLine = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && $0.count <= 100 }

        return ParsedBooking(kind: best.0,
                             title: firstLine ?? "Réservation \(best.0.label.lowercased())",
                             reference: reference(in: text),
                             startDate: dates.first,
                             endDate: dates.count > 1 ? dates.last : nil,
                             location: nil)
    }

    static func reference(in text: String) -> String? {
        let pattern = "(?i)(?:r[ée]f[ée]rence|confirmation|r[ée]servation|booking|pnr|dossier)"
            + "(?:\\s+(?:number|num[ée]ro|no\\.?|code|de\\s+r[ée]servation|reference|ref))?"
            + "\\s*[:#°]*\\s*(?:n°|no)?\\s*[:#]?\\s*"
            + "((?-i:[A-Z0-9][A-Z0-9-]{4,13}))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private static func detectDates(in text: String) -> [Date] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return [] }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let dates = matches.compactMap(\.date)
        return Array(Set(dates)).sorted()
    }

    private static func stripHTML(_ raw: String) -> String {
        guard raw.contains("<") else { return raw }
        var text = raw.replacingOccurrences(of: "<br\\s*/?>|</p>|</div>|</tr>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "(?s)<style.*?</style>|<script.*?</script>", with: "", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return LinkMetadataFetcher.decodeEntities(text)
    }
}
