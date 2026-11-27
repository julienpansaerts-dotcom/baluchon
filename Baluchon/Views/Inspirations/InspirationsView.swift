import SwiftData
import SwiftUI

/// Le carnet d'envies : chaque destination reconnue devient un timbre.
struct InspirationsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Inspiration.createdAt, order: .reverse) private var inspirations: [Inspiration]
    @Query private var places: [PlaceItem]
    @State private var showingAdd = false

    struct Tile: Identifiable {
        let key: String
        let destination: Destination?
        let sourceCount: Int
        let ideaCount: Int
        let keptCount: Int
        let pendingCount: Int
        let cover: Data?
        let sources: [InspirationSource]
        var id: String { key }
    }

    private var tiles: [Tile] {
        let keys = Set(inspirations.compactMap(\.destinationKey)).union(places.map(\.destinationKey)).filter { !$0.isEmpty }
        return keys.map { key in
            let related = inspirations.filter { $0.destinationKey == key }
            let ideas = places.filter { $0.destinationKey == key }
            return Tile(key: key,
                        destination: DestinationCatalog.destination(for: key),
                        sourceCount: related.count,
                        ideaCount: ideas.count,
                        keptCount: ideas.filter { $0.decision == .yes }.count,
                        pendingCount: ideas.filter { $0.decision == .pending }.count,
                        cover: related.first { $0.imageData != nil }?.imageData,
                        sources: Array(Set(related.map(\.source))).sorted { $0.rawValue < $1.rawValue })
        }
        .sorted { $0.sourceCount > $1.sourceCount }
    }

    private var unclassified: [Inspiration] {
        inspirations.filter { $0.isAnalyzed && $0.destinationKey == nil }
    }

    private var analyzingCount: Int {
        inspirations.filter { !$0.isAnalyzed }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if inspirations.isEmpty {
                        emptyState
                    } else {
                        if analyzingCount > 0 {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Lecture de \(analyzingCount) contenu(s)…")
                                    .font(.ticket(12))
                                    .foregroundStyle(Theme.inkSoft)
                            }
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)], spacing: 22) {
                            ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                                NavigationLink(value: tile.key) {
                                    DestinationStamp(tile: tile)
                                }
                                .buttonStyle(StampPressStyle())
                                .accessibilityIdentifier("tile-\(tile.key)")
                                .staggered(index)
                            }
                            if !unclassified.isEmpty {
                                NavigationLink {
                                    UnclassifiedView()
                                } label: {
                                    UnclassifiedStamp(count: unclassified.count)
                                }
                                .buttonStyle(StampPressStyle())
                                .staggered(tiles.count)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(PaperBackground())
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { key in
                DestinationDetailView(destinationKey: key)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .accessibilityLabel("Ajouter une inspiration")
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddInspirationView()
            }
            .refreshable {
                await InspirationPipeline.importSharedInbox(into: context)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Carnet d'envies · \(inspirations.count) source\(inspirations.count > 1 ? "s" : "")")
            Text("Où est-ce qu'on part ?")
                .font(.display(34, weight: .bold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Ton carnet est vide. Glisses-y ce qui te fait envie : un post Instagram, une vidéo TikTok, une épingle Pinterest, un lieu Google Maps, un article de blog ou une capture d'écran.")
                .font(.display(18, weight: .regular))
                .foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 10) {
                stepRow("1", "Dans l'app d'origine, touche Partager puis Baluchon.")
                stepRow("2", "Baluchon lit le contenu et le range par destination.")
                stepRow("3", "Tu gardes ce qui te plaît, puis tu lances le voyage.")
            }
            Button { showingAdd = true } label: {
                Text("Ajouter une première envie")
            }
            .buttonStyle(TicketButtonStyle())
            .padding(.top, 8)
        }
        .padding(.top, 10)
    }

    private func stepRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(number).font(.ticket(13, weight: .bold)).foregroundStyle(Theme.stamp)
            Text(text).font(.callout).foregroundStyle(Theme.inkSoft)
        }
    }
}

/// Un timbre de destination : bord perforé, encre du pays, code à trois lettres.
struct DestinationStamp: View {
    let tile: InspirationsView.Tile

    private var color: Color { DestinationStyle.color(for: tile.key) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                color
                if let cover = tile.cover {
                    DataImage(data: cover)
                        .saturation(0.35)
                        .overlay(color.opacity(0.55))
                        .clipped()
                }
                PostmarkLines()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.2)
                    .frame(width: 46, height: 26)
                    .padding(.top, 50)
                    .padding(.trailing, 10)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                VStack(alignment: .leading, spacing: 2) {
                    Text(DestinationStyle.code(for: tile.key))
                        .font(.ticket(30, weight: .bold))
                        .tracking(2)
                    Spacer(minLength: 0)
                    Text(tile.destination?.name ?? tile.key)
                        .font(.display(19, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(.white)
                .padding(12)
            }
            .frame(height: 128)
            .clipShape(Rectangle())

            HStack(alignment: .firstTextBaseline) {
                Text("\(tile.ideaCount) idée\(tile.ideaCount > 1 ? "s" : "")")
                    .font(.ticket(11, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if tile.pendingCount > 0 {
                    Text("\(tile.pendingCount) à trier")
                        .font(.ticket(10, weight: .bold))
                        .foregroundStyle(Theme.stamp)
                } else {
                    Text("\(tile.keptCount) gardée\(tile.keptCount > 1 ? "s" : "")")
                        .font(.ticket(10, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .padding(.horizontal, 2)
            .padding(.top, 9)
        }
        .padding(9)
        .background(PerforatedRectangle().punched(Theme.card))
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 2)
        .rotationEffect(.degrees(DestinationStyle.tilt(for: tile.key)))
        .accessibilityElement(children: .combine)
    }
}

/// Lignes ondulées d'oblitération postale.
struct PostmarkLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let lines = 4
        for i in 0..<lines {
            let y = rect.minY + rect.height * CGFloat(i) / CGFloat(lines - 1)
            path.move(to: CGPoint(x: rect.minX, y: y))
            var x = rect.minX
            let wave: CGFloat = 12
            while x < rect.maxX {
                path.addQuadCurve(to: CGPoint(x: x + wave, y: y),
                                  control: CGPoint(x: x + wave / 2, y: y + (Int(x / wave) % 2 == 0 ? -3 : 3)))
                x += wave
            }
        }
        return path
    }
}

struct UnclassifiedStamp: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("???")
                .font(.ticket(30, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.inkSoft.opacity(0.7))
            Spacer(minLength: 0)
            Text("À classer")
                .font(.display(19, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("\(count) contenu(s) sans destination")
                .font(.ticket(10))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 172, alignment: .topLeading)
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.inkSoft.opacity(0.5), style: StrokeStyle(lineWidth: 1.3, dash: [5, 4])))
        .rotationEffect(.degrees(1.2))
    }
}

/// Appui : le timbre se soulève légèrement.
struct StampPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Inspirations dont la destination n'a pas été reconnue : l'utilisateur choisit.
struct UnclassifiedView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Inspiration> { $0.isAnalyzed == true && $0.destinationKey == nil },
           sort: \Inspiration.createdAt, order: .reverse) private var items: [Inspiration]

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        DataImage(data: item.imageData, placeholder: item.source.symbol)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title.isEmpty ? item.source.label : item.title)
                                .font(.display(16)).foregroundStyle(Theme.ink).lineLimit(2)
                            Text(item.source.label.uppercased())
                                .font(.ticket(10, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                        }
                        Spacer()
                        Menu {
                            ForEach(DestinationCatalog.all) { destination in
                                Button("\(destination.name) · \(DestinationStyle.code(for: destination.key))") {
                                    Task { await InspirationPipeline.assign(item, to: destination, context: context) }
                                }
                            }
                        } label: {
                            Text("CLASSER")
                        }
                        .buttonStyle(InkButtonStyle(color: Theme.stamp))
                    }
                    .cardRow()
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(items[index]) }
                    try? context.save()
                }
            } footer: {
                Text("La destination n'a pas été reconnue. Choisis-la pour ranger ce contenu dans le bon timbre.")
            }
        }
        .paperBackground()
        .navigationTitle("À classer")
    }
}
