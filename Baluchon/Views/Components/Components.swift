import SwiftUI
import UIKit

/// Anneau de progression affichant le pourcentage de préparation.
struct ProgressRing: View {
    var percent: Int
    var lineWidth: CGFloat = 12
    var showsLabel = true

    private var color: Color {
        switch percent {
        case ..<34: .orange
        case ..<67: .yellow
        case ..<100: .mint
        default: .green
        }
    }

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(percent, 0), 100)) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: percent)
            if showsLabel {
                Text(verbatim: "\(percent)%")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Préparation : \(percent) pour cent")
    }
}

/// Couleurs propres à chaque destination pour les tuiles.
enum DestinationStyle {
    static func gradient(for key: String) -> LinearGradient {
        let palettes: [[Color]] = [
            [.teal, .blue], [.orange, .pink], [.indigo, .purple], [.green, .teal],
            [.pink, .purple], [.yellow, .orange], [.blue, .indigo], [.mint, .green],
        ]
        let index = abs(key.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }) % palettes.count
        return LinearGradient(colors: palettes[index], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Miniature d'une image stockée en données.
struct DataImage: View {
    let data: Data?
    var placeholder = "photo"

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            ZStack {
                Color.secondary.opacity(0.15)
                Image(systemName: placeholder).foregroundStyle(.secondary)
            }
        }
    }
}

/// Boutons « Plans » et « Google Maps » pour un lieu.
struct MapButtons: View {
    let name: String
    let city: String?
    let latitude: Double?
    let longitude: Double?

    var body: some View {
        HStack(spacing: 8) {
            if let url = MapLinks.appleMaps(name: [name, city].compactMap { $0 }.joined(separator: ", "), latitude: latitude, longitude: longitude) {
                Link(destination: url) { Label("Plans", systemImage: "map") }
            }
            if let url = MapLinks.googleMaps(name: name, city: city, latitude: latitude, longitude: longitude) {
                Link(destination: url) { Label("Google Maps", systemImage: "mappin.circle") }
            }
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

extension Date {
    var shortFrench: String {
        formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR")))
    }

    var longFrench: String {
        formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR")))
    }
}
