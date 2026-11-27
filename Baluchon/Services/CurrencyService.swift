import Foundation

/// Taux de change : récupéré en ligne au passage en mode voyage, puis utilisé hors ligne.
enum CurrencyService {
    private struct Response: Decodable {
        let result: String
        let rates: [String: Double]
    }

    /// Nombre d'unités de `target` pour 1 unité de `base`.
    static func fetchRate(base: String, target: String) async throws -> Double {
        if base == target { return 1 }
        guard let url = URL(string: "https://open.er-api.com/v6/latest/\(base)") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.result == "success", let rate = response.rates[target] else {
            throw URLError(.cannotParseResponse)
        }
        return rate
    }

    static func format(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.maximumFractionDigits = amount >= 1000 ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currency)"
    }
}

/// Liens vers Plans (Apple) et Google Maps pour chaque étape.
enum MapLinks {
    static func appleMaps(name: String, latitude: Double?, longitude: Double?) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        var items = [URLQueryItem(name: "q", value: name)]
        if let latitude, let longitude {
            items.append(URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"))
        }
        components?.queryItems = items
        return components?.url
    }

    static func googleMaps(name: String, city: String?, latitude: Double?, longitude: Double?) -> URL? {
        var components = URLComponents(string: "https://www.google.com/maps/search/")
        let query: String
        if let latitude, let longitude {
            query = "\(latitude),\(longitude)"
        } else {
            query = [name, city].compactMap { $0 }.joined(separator: ", ")
        }
        components?.queryItems = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "query", value: query)]
        return components?.url
    }
}
