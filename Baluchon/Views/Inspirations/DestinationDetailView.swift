import SwiftData
import SwiftUI

/// Détail d'une tuile : l'utilisateur garde ou écarte chaque élément détecté,
/// puis lance le projet.
struct DestinationDetailView: View {
    let destinationKey: String
    @Environment(\.modelContext) private var context
    @Query private var places: [PlaceItem]
    @Query private var inspirations: [Inspiration]
    @State private var showingLaunch = false
    @State private var createdTrip: Trip?
    @State private var newPlaceName = ""
    @State private var newPlaceCategory: PlaceCategory = .sight
    @State private var showRejected = false

    init(destinationKey: String) {
        self.destinationKey = destinationKey
        let key = destinationKey
        _places = Query(filter: #Predicate<PlaceItem> { $0.destinationKey == key }, sort: \PlaceItem.createdAt)
        let optionalKey: String? = destinationKey
        _inspirations = Query(filter: #Predicate<Inspiration> { $0.destinationKey == optionalKey },
                              sort: \Inspiration.createdAt, order: .reverse)
    }

    private var destination: Destination? { DestinationCatalog.destination(for: destinationKey) }
    private var pending: [PlaceItem] { places.filter { $0.decision == .pending } }
    private var kept: [PlaceItem] { places.filter { $0.decision == .yes } }
    private var rejected: [PlaceItem] { places.filter { $0.decision == .no } }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    stat("\(kept.count)", "gardés", .green)
                    stat("\(pending.count)", "à trier", .orange)
                    stat("\(rejected.count)", "écartés", .secondary)
                }
                .frame(maxWidth: .infinity)
            }

            if !pending.isEmpty {
                Section("À trier — tu veux le faire ?") {
                    ForEach(pending) { place in
                        PlaceRow(place: place, showsDecision: true)
                    }
                }
            }

            ForEach(PlaceCategory.allCases) { category in
                let items = kept.filter { $0.category == category }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { place in
                            PlaceRow(place: place, showsDecision: false)
                                .swipeActions {
                                    Button("Écarter") { place.decision = .no }.tint(.red)
                                }
                        }
                    } header: {
                        Label(category.label, systemImage: category.symbol)
                    }
                }
            }

            Section("Ajouter un lieu à la main") {
                TextField("Nom du lieu, restaurant, activité…", text: $newPlaceName)
                Picker("Catégorie", selection: $newPlaceCategory) {
                    ForEach(PlaceCategory.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                }
                Button("Ajouter") { addPlace() }
                    .disabled(newPlaceName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !rejected.isEmpty {
                Section {
                    DisclosureGroup("Écartés (\(rejected.count))", isExpanded: $showRejected) {
                        ForEach(rejected) { place in
                            HStack {
                                Text(place.name).foregroundStyle(.secondary)
                                Spacer()
                                Button("Reprendre") { place.decision = .yes }
                                    .font(.caption)
                            }
                        }
                    }
                }
            }

            if !inspirations.isEmpty {
                Section("Sources (\(inspirations.count))") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(inspirations) { inspiration in
                                sourceCard(inspiration)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("\(destination?.flag ?? "") \(destination?.name ?? destinationKey)")
        .safeAreaInset(edge: .bottom) {
            Button {
                showingLaunch = true
            } label: {
                Label("Lancer le projet", systemImage: "airplane.departure")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(kept.isEmpty)
            .accessibilityIdentifier("launch-project")
            .padding()
            .background(.bar)
        }
        .sheet(isPresented: $showingLaunch) {
            LaunchTripView(destinationKey: destinationKey, places: kept) { trip in
                createdTrip = trip
            }
        }
        .navigationDestination(item: $createdTrip) { trip in
            TripDashboardView(trip: trip)
        }
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack {
            Text(value).font(.title2.bold()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func sourceCard(_ inspiration: Inspiration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            DataImage(data: inspiration.imageData, placeholder: inspiration.source.symbol)
                .frame(width: 120, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Label(inspiration.source.label, systemImage: inspiration.source.symbol)
                .font(.caption2).foregroundStyle(.secondary)
            Text(inspiration.title).font(.caption).lineLimit(2).frame(width: 120, alignment: .leading)
        }
        .contextMenu {
            if let urlString = inspiration.urlString, let url = URL(string: urlString) {
                Link(destination: url) { Label("Ouvrir le lien", systemImage: "safari") }
            }
            Button(role: .destructive) {
                context.delete(inspiration)
                try? context.save()
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    private func addPlace() {
        let name = newPlaceName.trimmingCharacters(in: .whitespaces)
        var item = PlaceItem(name: name, category: newPlaceCategory, city: nil, destinationKey: destinationKey)
        if let destination, let match = KeywordAnalyzer.catalogPlace(named: name, in: destination) {
            item = PlaceItem(name: match.name, category: match.category, city: match.city, destinationKey: destinationKey,
                             latitude: match.latitude, longitude: match.longitude,
                             needsBooking: match.needsBooking, bookingLeadDays: match.leadDays)
        }
        item.decision = .yes
        context.insert(item)
        try? context.save()
        newPlaceName = ""
    }
}

struct PlaceRow: View {
    @Bindable var place: PlaceItem
    let showsDecision: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: place.category.symbol)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name).font(.body.weight(.medium))
                HStack(spacing: 6) {
                    if let city = place.city { Text(city) }
                    if place.needsBooking {
                        Label("à réserver ~\(place.bookingLeadDays) j avant", systemImage: "clock.badge.exclamationmark")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if showsDecision {
                Button { withAnimation { place.decision = .no } } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                Button { withAnimation { place.decision = .yes } } label: {
                    Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
