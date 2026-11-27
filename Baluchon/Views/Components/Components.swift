import SwiftUI
import UIKit

// MARK: - Palette « carnet de voyage »
//
// Papier crème, encre marine, vermillon des tampons, ocre des étiquettes.
// Pas de dégradés décoratifs ni de violet : les couleurs viennent des objets du voyage.

enum Theme {
    static let paper = Color(light: 0xF2ECE1, dark: 0x111726)
    static let card = Color(light: 0xFBF8F2, dark: 0x1A2133)
    static let ink = Color(light: 0x1C2540, dark: 0xF0E9DB)
    static let inkSoft = Color(light: 0x5C6479, dark: 0xA3AABB)
    static let stamp = Color(light: 0xC2412A, dark: 0xE6654B)
    static let ochre = Color(light: 0xC98A1E, dark: 0xE2AE48)
    static let sea = Color(light: 0x2F6A6E, dark: 0x6BB0AD)
    static let rule = Color(light: 0x1C2540, dark: 0xF0E9DB).opacity(0.14)

    /// Tableau des départs (mode voyage).
    static let board = Color(hex: 0x0E1320)
    static let boardTile = Color(hex: 0x1B2233)
    static let amber = Color(hex: 0xF2B544)

    static var inkUIColor: UIColor { UIColor(ink) }

    /// Titres en serif (police New York d'Apple) dans la barre de navigation.
    static func configureAppearance() {
        func serif(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
            return UIFont(descriptor: descriptor, size: size)
        }
        let navigationBar = UINavigationBar.appearance()
        navigationBar.largeTitleTextAttributes = [.font: serif(34, .bold), .foregroundColor: inkUIColor]
        navigationBar.titleTextAttributes = [.font: serif(17, .semibold), .foregroundColor: inkUIColor]
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

extension Font {
    /// Titres : serif, comme un guide de voyage imprimé.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Données : chasse fixe, comme une carte d'embarquement.
    static func ticket(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Identité des destinations

enum DestinationStyle {
    /// Couleur d'encre propre à chaque destination (inspirée du pays, jamais un dégradé).
    static func color(for key: String) -> Color {
        switch key {
        case "vn": Color(light: 0x2E7458, dark: 0x4FA07F)   // jade
        case "nyc": Color(light: 0x2B3A67, dark: 0x6F86C7)  // encre
        case "jp": Color(light: 0xB8392A, dark: 0xE0614D)   // vermillon
        case "th": Color(light: 0xC27C1E, dark: 0xE2A445)   // safran
        case "it": Color(light: 0xA9502F, dark: 0xD67B57)   // terre cuite
        case "es": Color(light: 0xB33A3A, dark: 0xDB6464)   // grenade
        case "pt": Color(light: 0x2A5A99, dark: 0x6D9BDB)   // azulejo
        case "gr": Color(light: 0x24678F, dark: 0x5EA3CC)   // égée
        case "ma": Color(light: 0xB0623A, dark: 0xD98B60)   // ocre rouge
        case "mx": Color(light: 0xA2405F, dark: 0xD06E8D)   // bougainvillier
        case "bali": Color(light: 0x5F7232, dark: 0x95AB61) // rizière
        default: Theme.inkSoft
        }
    }

    /// Code à trois lettres, façon étiquette de bagage.
    static func code(for key: String) -> String {
        let codes = ["vn": "VNM", "nyc": "NYC", "jp": "JPN", "th": "THA", "it": "ITA", "es": "ESP",
                     "pt": "PRT", "gr": "GRC", "ma": "MAR", "mx": "MEX", "bali": "IDN"]
        return codes[key] ?? String(key.prefix(3)).uppercased()
    }

    /// Légère inclinaison pour que les timbres ne soient pas alignés au cordeau.
    static func tilt(for key: String) -> Double {
        let seed = key.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return Double(seed % 5 - 2) * 0.7
    }
}

// MARK: - Formes

/// Bord perforé de timbre-poste.
struct PerforatedRectangle: Shape {
    var holeRadius: CGFloat = 3.5
    var spacing: CGFloat = 11

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        func hole(_ x: CGFloat, _ y: CGFloat) {
            path.addEllipse(in: CGRect(x: x - holeRadius, y: y - holeRadius, width: holeRadius * 2, height: holeRadius * 2))
        }
        var x = spacing / 2
        while x < rect.width {
            hole(x, 0)
            hole(x, rect.height)
            x += spacing
        }
        var y = spacing / 2
        while y < rect.height {
            hole(0, y)
            hole(rect.width, y)
            y += spacing
        }
        return path
    }
}

/// Billet avec deux encoches (carte d'embarquement, ticket de train).
struct TicketShape: Shape {
    /// Position verticale des encoches (0…1) ; `nil` = encoches à gauche/droite d'une découpe horizontale.
    var notchX: CGFloat? = nil
    /// Position horizontale absolue des encoches (en points), prioritaire sur `notchX`.
    var notchXPoints: CGFloat? = nil
    var notchY: CGFloat? = 0.5
    var notchRadius: CGFloat = 10
    var cornerRadius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: cornerRadius)
        if let notchY {
            let y = rect.minY + rect.height * notchY
            path.addEllipse(in: CGRect(x: rect.minX - notchRadius, y: y - notchRadius, width: notchRadius * 2, height: notchRadius * 2))
            path.addEllipse(in: CGRect(x: rect.maxX - notchRadius, y: y - notchRadius, width: notchRadius * 2, height: notchRadius * 2))
        }
        if let x0 = notchXPoints ?? notchX.map({ rect.width * $0 }) {
            let x = rect.minX + x0
            path.addEllipse(in: CGRect(x: x - notchRadius, y: rect.minY - notchRadius, width: notchRadius * 2, height: notchRadius * 2))
            path.addEllipse(in: CGRect(x: x - notchRadius, y: rect.maxY - notchRadius, width: notchRadius * 2, height: notchRadius * 2))
        }
        return path
    }
}

extension Shape {
    /// Remplit la forme en découpant les trous (règle pair-impair) sans déborder du cadre.
    func punched(_ color: Color) -> some View {
        fill(color, style: FillStyle(eoFill: true)).clipped()
    }
}

/// Ligne pointillée (découpe de billet).
struct DashedRule: View {
    var vertical = false
    var color: Color = Theme.rule

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                if vertical {
                    path.move(to: CGPoint(x: proxy.size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: proxy.size.width / 2, y: proxy.size.height))
                } else {
                    path.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
        }
        .frame(width: vertical ? 2 : nil, height: vertical ? nil : 2)
    }
}

/// Grain de papier très léger, pour éviter l'aplat parfait.
struct PaperBackground: View {
    var body: some View {
        Theme.paper
            .overlay {
                Canvas { context, size in
                    var generator = SeededGenerator(seed: 7)
                    let count = Int(size.width * size.height / 260)
                    for _ in 0..<count {
                        let x = CGFloat.random(in: 0..<size.width, using: &generator)
                        let y = CGFloat.random(in: 0..<size.height, using: &generator)
                        let alpha = Double.random(in: 0.025...0.07, using: &generator)
                        context.fill(Path(CGRect(x: x, y: y, width: 1.1, height: 1.1)), with: .color(Theme.ink.opacity(alpha)))
                    }
                }
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

extension View {
    /// Fond papier pour les listes et formulaires.
    func paperBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(PaperBackground())
    }

    /// Ligne de liste sur fond carte.
    func cardRow() -> some View {
        listRowBackground(Theme.card)
    }
}

/// Intitulé de section en petites capitales à chasse fixe.
struct SectionLabel: View {
    let text: String
    var color: Color = Theme.inkSoft

    init(_ text: String, color: Color = Theme.inkSoft) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.ticket(11, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

// MARK: - Progression : un avion sur sa trajectoire

/// Trajectoire en arc, pointillée pour ce qui reste, pleine pour ce qui est fait.
struct FlightArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.6))
        return path
    }

    static func point(at t: CGFloat, in rect: CGRect) -> (CGPoint, Angle) {
        let p0 = CGPoint(x: rect.minX, y: rect.maxY)
        let p1 = CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.6)
        let p2 = CGPoint(x: rect.maxX, y: rect.maxY)
        let u = 1 - t
        let x = u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x
        let y = u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y
        let dx = 2 * u * (p1.x - p0.x) + 2 * t * (p2.x - p1.x)
        let dy = 2 * u * (p1.y - p0.y) + 2 * t * (p2.y - p1.y)
        return (CGPoint(x: x, y: y), Angle(radians: Double(atan2(dy, dx))))
    }
}

/// Place l'avion sur l'arc ; animable pour qu'il « vole » jusqu'à sa position.
private struct PlaneOnArc: GeometryEffect {
    var progress: CGFloat
    var size: CGSize

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size planeSize: CGSize) -> ProjectionTransform {
        let rect = CGRect(origin: .zero, size: size)
        let (point, angle) = FlightArc.point(at: progress, in: rect)
        let transform = CGAffineTransform(translationX: point.x, y: point.y)
            .rotated(by: CGFloat(angle.radians))
            .translatedBy(x: -planeSize.width / 2, y: -planeSize.height / 2)
        return ProjectionTransform(transform)
    }
}

struct FlightProgress: View {
    var percent: Int
    var tint: Color = Theme.stamp
    @State private var shown: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                FlightArc()
                    .stroke(Theme.inkSoft.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 6]))
                FlightArc()
                    .trim(from: 0, to: shown)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                Circle().fill(Theme.ink).frame(width: 7, height: 7)
                    .position(x: 0, y: size.height)
                Circle().strokeBorder(Theme.ink, lineWidth: 1.5).frame(width: 9, height: 9)
                    .position(x: size.width, y: size.height)
                Image(systemName: "airplane")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .fixedSize()
                    .modifier(PlaneOnArc(progress: shown, size: size))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).delay(0.15)) { shown = CGFloat(percent) / 100 }
        }
        .onChange(of: percent) { _, value in
            withAnimation(.spring(duration: 0.8)) { shown = CGFloat(value) / 100 }
        }
        .accessibilityElement()
        .accessibilityLabel("Préparation : \(percent) pour cent")
    }
}

// MARK: - Tampons

/// Coup de tampon « fait » : arrive en s'écrasant, légèrement de travers.
struct StampMark: View {
    var size: CGFloat = 26
    var color: Color = Theme.stamp

    var body: some View {
        ZStack {
            Circle().strokeBorder(color, lineWidth: 1.6)
            Circle().strokeBorder(color.opacity(0.7), lineWidth: 0.8).padding(3)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.42, weight: .heavy))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-14))
    }
}

/// Case à cocher façon formulaire de douane, remplacée par un tampon une fois cochée.
struct StampCheckbox: View {
    var isOn: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Theme.inkSoft.opacity(isOn ? 0 : 0.6), lineWidth: 1.4)
                .frame(width: 20, height: 20)
            if isOn {
                StampMark(size: 28)
                    .transition(.asymmetric(insertion: .scale(scale: 1.9).combined(with: .opacity), removal: .opacity))
            }
        }
        .frame(width: 30, height: 30)
        .animation(.spring(response: 0.28, dampingFraction: 0.55), value: isOn)
    }
}

/// Étiquette rectangulaire à l'encre (ex. « BLOQUANT »).
struct InkTag: View {
    let text: String
    var color: Color = Theme.stamp

    var body: some View {
        Text(text.uppercased())
            .font(.ticket(9.5, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(color, lineWidth: 1))
    }
}

// MARK: - Tableau des départs (split-flap)

/// Texte qui défile lettre par lettre comme un tableau des départs d'aéroport.
struct SplitFlapText: View {
    let text: String
    var size: CGFloat = 22
    var tile: Color = Theme.boardTile
    var ink: Color = Theme.amber
    @State private var shown: [Character] = []

    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, character in
                Text(String(character))
                    .font(.ticket(size, weight: .bold))
                    .foregroundStyle(ink)
                    .frame(width: size * 0.78, height: size * 1.32)
                    .background(tile, in: RoundedRectangle(cornerRadius: 3))
                    .overlay(Rectangle().fill(Color.black.opacity(0.55)).frame(height: 1))
            }
        }
        .task(id: text) { await animate() }
        .accessibilityElement()
        .accessibilityLabel(text)
    }

    private func animate() async {
        let target = Array(text.uppercased())
        shown = target.map { $0 == " " ? " " : Self.alphabet.randomElement() ?? $0 }
        let steps = 14
        for step in 0...steps {
            try? await Task.sleep(nanoseconds: 45_000_000)
            shown = target.enumerated().map { index, character in
                if character == " " || step >= min(4 + index, steps) { return character }
                return Self.alphabet.randomElement() ?? character
            }
        }
        shown = target
    }
}

// MARK: - Boutons

/// Bouton principal en forme de billet.
struct TicketButtonStyle: ButtonStyle {
    var fill: Color = Theme.stamp
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(19, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(TicketShape(notchX: 0.86, notchY: nil, notchRadius: 7, cornerRadius: 10).punched(fill))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Petit bouton texte à l'encre (OUI / NON, ÉCOUTER…).
struct InkButtonStyle: ButtonStyle {
    var color: Color = Theme.ink
    var filled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ticket(12, weight: .bold))
            .tracking(1)
            .foregroundStyle(filled ? Theme.card : color)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 4).fill(filled ? color : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(color, lineWidth: 1.2))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Divers

/// Miniature d'une image stockée en données.
struct DataImage: View {
    let data: Data?
    var placeholder = "photo"

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            ZStack {
                Theme.rule
                Image(systemName: placeholder).foregroundStyle(Theme.inkSoft)
            }
        }
    }
}

/// Liens « Plans » et « Google Maps » pour un lieu.
struct MapButtons: View {
    let name: String
    let city: String?
    let latitude: Double?
    let longitude: Double?
    var color: Color = Theme.sea

    var body: some View {
        HStack(spacing: 8) {
            if let url = MapLinks.appleMaps(name: [name, city].compactMap { $0 }.joined(separator: ", "), latitude: latitude, longitude: longitude) {
                Link(destination: url) { Text("PLANS") }
                    .buttonStyle(InkButtonStyle(color: color))
            }
            if let url = MapLinks.googleMaps(name: name, city: city, latitude: latitude, longitude: longitude) {
                Link(destination: url) { Text("GOOGLE MAPS") }
                    .buttonStyle(InkButtonStyle(color: color))
            }
        }
    }
}

/// Apparition échelonnée (cartes qui se posent sur la table).
struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(Double(index) * 0.06)) { visible = true }
            }
    }
}

extension View {
    func staggered(_ index: Int) -> some View { modifier(StaggeredAppear(index: index)) }
}

extension Date {
    var shortFrench: String {
        formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR")))
    }

    var longFrench: String {
        formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR")))
    }

    /// « 27 NOV » pour les billets.
    var ticketDate: String {
        formatted(.dateTime.day(.twoDigits).month(.abbreviated).locale(Locale(identifier: "fr_FR")))
            .uppercased().replacingOccurrences(of: ".", with: "")
    }
}
