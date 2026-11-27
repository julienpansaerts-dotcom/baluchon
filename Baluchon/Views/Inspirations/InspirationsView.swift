import SwiftData
import SwiftUI

/// Écran principal : les inspirations classées automatiquement en tuiles par destination.
struct InspirationsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Inspiration.createdAt, order: .reverse) private var inspirations: [Inspiration]
    @Query private var places: [PlaceItem]
    @State private var showingAdd = false

    private struct Tile: Identifiable {
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
                if inspirations.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        if analyzingCount > 0 {
                            Label("Analyse de \(analyzingCount) contenu(s) en cours…", systemImage: "sparkle.magnifyingglass")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                            ForEach(tiles) { tile in
                                NavigationLink(value: tile.key) {
                                    tileView(tile)
                                }
                                .buttonStyle(.plain)
                            }
                            if !unclassified.isEmpty {
                                NavigationLink {
                                    UnclassifiedView()
                                } label: {
                                    unclassifiedTile
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Mes envies")
            .navigationDestination(for: String.self) { key in
                DestinationDetailView(destinationKey: key)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: { Label("Ajouter", systemImage: "plus.circle.fill") }
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

    private func tileView(_ tile: Tile) -> some View {
        ZStack(alignment: .bottomLeading) {
            DestinationStyle.gradient(for: tile.key)
            if let cover = tile.cover {
                DataImage(data: cover)
                    .overlay(LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(tile.destination?.flag ?? "📍").font(.largeTitle)
                Text(tile.destination?.name ?? tile.key)
                    .font(.headline)
                Text("\(tile.ideaCount) idée\(tile.ideaCount > 1 ? "s" : "") · \(tile.sourceCount) source\(tile.sourceCount > 1 ? "s" : "")")
                    .font(.caption)
                HStack(spacing: 4) {
                    ForEach(tile.sources.prefix(5)) { source in
                        Image(systemName: source.symbol)
                    }
                    Spacer()
                    if tile.pendingCount > 0 {
                        Text("\(tile.pendingCount) à trier")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.white.opacity(0.25), in: Capsule())
                    }
                }
                .font(.caption2)
            }
            .foregroundStyle(.white)
            .padding(12)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }

    private var unclassifiedTile: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.folder").font(.largeTitle)
            Text("À classer").font(.headline)
            Text("\(unclassified.count) contenu(s)").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Rassemble tes envies de voyage").font(.title2.bold())
            Text("Partage vers **Baluchon** des posts Instagram ou Facebook, des vidéos TikTok ou YouTube Shorts, des épingles Pinterest, des lieux Google Maps, des articles de blog ou des captures d'écran. L'app les classe automatiquement par destination.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Label("Dans l'app d'origine : bouton Partager › Baluchon", systemImage: "square.and.arrow.up")
                Label("Ou ici : bouton + pour coller un lien ou choisir des photos", systemImage: "plus.circle")
            }
            .font(.callout)
            Button { showingAdd = true } label: {
                Label("Ajouter une inspiration", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(28)
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
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading) {
                            Text(item.title.isEmpty ? item.source.label : item.title).lineLimit(2)
                            Label(item.source.label, systemImage: item.source.symbol)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu {
                            ForEach(DestinationCatalog.all) { destination in
                                Button("\(destination.flag) \(destination.name)") {
                                    Task { await InspirationPipeline.assign(item, to: destination, context: context) }
                                }
                            }
                        } label: {
                            Text("Classer").font(.callout.weight(.semibold))
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(items[index]) }
                    try? context.save()
                }
            } footer: {
                Text("La destination n'a pas pu être reconnue automatiquement. Choisis-la pour ranger ce contenu.")
            }
        }
        .navigationTitle("À classer")
    }
}
