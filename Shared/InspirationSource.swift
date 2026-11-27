import Foundation

/// Provenance d'une inspiration envoyée dans l'app.
enum InspirationSource: String, Codable, CaseIterable, Identifiable {
    case instagram
    case facebook
    case tiktok
    case youtube
    case pinterest
    case googleMaps
    case blog
    case photo
    case text

    var id: String { rawValue }

    var label: String {
        switch self {
        case .instagram: "Instagram"
        case .facebook: "Facebook"
        case .tiktok: "TikTok"
        case .youtube: "YouTube"
        case .pinterest: "Pinterest"
        case .googleMaps: "Google Maps"
        case .blog: "Article / blog"
        case .photo: "Photo"
        case .text: "Texte"
        }
    }

    /// Symbole SF Symbols (les logos de marques ne sont pas disponibles).
    var symbol: String {
        switch self {
        case .instagram: "camera.circle"
        case .facebook: "person.2.circle"
        case .tiktok: "music.note"
        case .youtube: "play.rectangle"
        case .pinterest: "pin.circle"
        case .googleMaps: "mappin.and.ellipse"
        case .blog: "doc.richtext"
        case .photo: "photo"
        case .text: "text.alignleft"
        }
    }

    /// Détecte la source à partir d'une URL partagée.
    static func detect(urlString: String?) -> InspirationSource? {
        guard let urlString,
              let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let rawHost = url.host?.lowercased() else { return nil }
        let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
        let path = url.path.lowercased()

        func matches(_ domains: [String]) -> Bool {
            domains.contains { host == $0 || host.hasSuffix("." + $0) }
        }

        if matches(["instagram.com", "instagr.am"]) { return .instagram }
        if matches(["facebook.com", "fb.com", "fb.watch"]) { return .facebook }
        if matches(["tiktok.com"]) { return .tiktok }
        if matches(["youtube.com", "youtu.be"]) { return .youtube }
        if matches(["pin.it"]) || host.hasPrefix("pinterest.") || host.contains(".pinterest.") { return .pinterest }
        if matches(["maps.app.goo.gl"]) || host.hasPrefix("maps.google.") { return .googleMaps }
        if host == "goo.gl", path.hasPrefix("/maps") { return .googleMaps }
        if host.hasPrefix("google."), path.hasPrefix("/maps") { return .googleMaps }
        return .blog
    }
}
