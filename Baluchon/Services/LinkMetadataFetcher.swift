import Foundation

/// Récupère le titre, la description et l'image d'aperçu d'une page (balises Open Graph).
/// Fonctionne pour la plupart des blogs, TikTok, YouTube, Pinterest et parfois Instagram/Facebook
/// (quand la page n'est pas bloquée par un écran de connexion).
enum LinkMetadataFetcher {
    struct Metadata: Equatable {
        var title: String?
        var description: String?
        var imageURL: URL?
        var finalURL: URL?
    }

    static func fetch(_ url: URL) async -> Metadata {
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("fr-FR,fr;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        guard let result = try? await URLSession.shared.data(for: request) else {
            return Metadata(finalURL: url)
        }
        let (data, response) = result
        let html = String(data: data.prefix(600_000), encoding: .utf8)
            ?? String(decoding: data.prefix(600_000), as: UTF8.self)
        var metadata = parse(html: html, baseURL: response.url ?? url)
        metadata.finalURL = response.url ?? url
        return metadata
    }

    static func parse(html: String, baseURL: URL? = nil) -> Metadata {
        var properties: [String: String] = [:]
        for tag in matches(of: "<meta\\s[^>]*>", in: html) {
            guard let key = firstGroup(of: "(?:property|name)\\s*=\\s*[\"']([^\"']+)[\"']", in: tag)?.lowercased(),
                  let content = firstGroup(of: "content\\s*=\\s*\"([^\"]*)\"", in: tag)
                    ?? firstGroup(of: "content\\s*=\\s*'([^']*)'", in: tag) else { continue }
            if properties[key] == nil { properties[key] = decodeEntities(content) }
        }
        let htmlTitle = firstGroup(of: "<title[^>]*>([^<]*)</title>", in: html).map(decodeEntities)
        let title = properties["og:title"] ?? properties["twitter:title"] ?? htmlTitle
        let description = properties["og:description"] ?? properties["twitter:description"] ?? properties["description"]
        let image = (properties["og:image"] ?? properties["twitter:image"]).flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL }
        return Metadata(
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            imageURL: image,
            finalURL: nil
        )
    }

    // MARK: - Privé

    private static func matches(of pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }

    private static func firstGroup(of pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    static func decodeEntities(_ string: String) -> String {
        var result = string
        let entities = ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&#x27;": "'", "&apos;": "'",
                        "&lt;": "<", "&gt;": ">", "&nbsp;": " ", "&#064;": "@", "&#x40;": "@"]
        for (entity, value) in entities {
            result = result.replacingOccurrences(of: entity, with: value)
        }
        // Entités numériques décimales (&#233;) et hexadécimales (&#xE9;)
        if let regex = try? NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);") {
            let ns = result as NSString
            var output = ""
            var last = 0
            for match in regex.matches(in: result, range: NSRange(location: 0, length: ns.length)) {
                output += ns.substring(with: NSRange(location: last, length: match.range.location - last))
                let isHex = ns.substring(with: match.range(at: 1)) == "x"
                let digits = ns.substring(with: match.range(at: 2))
                if let code = UInt32(digits, radix: isHex ? 16 : 10), let scalar = Unicode.Scalar(code) {
                    output.append(Character(scalar))
                } else {
                    output += ns.substring(with: match.range)
                }
                last = match.range.location + match.range.length
            }
            output += ns.substring(from: last)
            result = output
        }
        return result
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
