import SwiftData
import SwiftUI

/// Détail d'un timbre : l'utilisateur garde ou écarte chaque idée détectée,
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
    private var color: Color { DestinationStyle.color(for: destinationKey) }
    private var pending: [PlaceItem] { places.filter { $0.decision == .pending } }
    private var kept: [PlaceItem] { places.filter { $0.decision == .yes } }
    private var rejected: [PlaceItem] { places.filter { $0.decision == .no } }

    var body: some View {
        List {
            Section {
                header
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 12, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if !pending.isEmpty {
                Section {
                    ForEach(pending) { place in
                        PlaceRow(place: place, showsDecision: true, accent: color)
                            .cardRow()
                    }
                } header: {
                    SectionLabel("À trier — tu veux y aller ?", color: Theme.stamp)
                }
            }

            ForEach(PlaceCategory.allCases) { category in
                let items = kept.filter { $0.category == category }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { place in
                            PlaceRow(place: place, showsDecision: false, accent: color)
                                .cardRow()
                                .swipeActions {
                                    Button("Écarter") { withAnimation { place.decision = .no } }.tint(Theme.stamp)
                                }
                        }
                    } header: {
                        SectionLabel(category.label)
                    }
                }
            }

            Section {
                TextField("Un lieu, un resto, une activité…", text: $newPlaceName)
                    .font(.display(16))
                    .cardRow()
                Picker("Catégorie", selection: $newPlaceCategory) {
                    ForEach(PlaceCategory.allCases) { Text($0.label).tag($0) }
                }
                .cardRow()
                Button("Ajouter au timbre") { addPlace() }
                    .font(.ticket(13, weight: .bold))
                    .disabled(newPlaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .cardRow()
            } header: {
                SectionLabel("Ajouter à la main")
            }

            if !rejected.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showRejected) {
                        ForEach(rejected) { place in
                            HStack {
                                Text(place.name).foregroundStyle(Theme.inkSoft).strikethrough()
                                Spacer()
                                Button("REPRENDRE") { withAnimation { place.decision = .yes } }
                                    .buttonStyle(InkButtonStyle(color: Theme.inkSoft))
                            }
                        }
                    } label: {
                        Text("Écartés (\(rejected.count))").font(.ticket(13, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                    }
                    .cardRow()
                }
            }

            if !inspirations.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(inspirations) { inspiration in
                                sourceCard(inspiration)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                } header: {
                    SectionLabel("D'où viennent ces idées")
                }
            }
        }
        .paperBackground()
        .navigationTitle(destination?.name ?? destinationKey)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                showingLaunch = true
            } label: {
                HStack {
                    Text("Lancer le projet")
                    Spacer()
                    Text("\(kept.count) idée\(kept.count > 1 ? "s" : "")")
                        .font(.ticket(12, weight: .semibold))
                        .opacity(0.85)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                }
                .padding(.horizontal, 20)
            }
            .buttonStyle(TicketButtonStyle(fill: kept.isEmpty ? Theme.inkSoft.opacity(0.4) : Theme.stamp))
            .disabled(kept.isEmpty)
            .accessibilityIdentifier("launch-project")
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
        .sheet(isPresented: $showingLaunch) {
            LaunchTripView(destinationKey: destinationKey, places: kept) { trip in
                createdTrip = trip
            }
        }
        .navigationDestination(item: $createdTrip) { trip in
            TripDashboardView(trip: trip)
        }
        .sensoryFeedback(.selection, trigger: kept.count)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(DestinationStyle.code(for: destinationKey))
                    .font(.ticket(40, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 0) {
                    Text(destination?.name ?? destinationKey)
                        .font(.display(26, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    if let destination {
                        Text("\(destination.currencyCode) · \(destination.languageName)")
                            .font(.ticket(11))
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                    }
                }
            }
            HStack(spacing: 0) {
                counter(kept.count, "gardées", Theme.ink)
                Rectangle().fill(Theme.rule).frame(width: 1, height: 30)
                counter(pending.count, "à trier", Theme.stamp)
                Rectangle().fill(Theme.rule).frame(width: 1, height: 30)
                counter(rejected.count, "écartées", Theme.inkSoft)
            }
            .padding(.vertical, 10)
            .overlay(alignment: .top) { DashedRule() }
            .overlay(alignment: .bottom) { DashedRule() }
        }
    }

    private func counter(_ value: Int, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.display(24, weight: .bold))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(.spring, value: value)
            Text(label.uppercased()).font(.ticket(10, weight: .semibold)).tracking(1).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    private func sourceCard(_ inspiration: Inspiration) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            DataImage(data: inspiration.imageData, placeholder: inspiration.source.symbol)
                .frame(width: 112, height: 84)
                .clipped()
            Text(inspiration.source.label.uppercased())
                .font(.ticket(9, weight: .bold)).foregroundStyle(Theme.inkSoft)
            Text(inspiration.title)
                .font(.caption).foregroundStyle(Theme.ink)
                .lineLimit(2).frame(width: 112, alignment: .leading)
        }
        .padding(6)
        .background(Theme.card)
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .rotationEffect(.degrees(DestinationStyle.tilt(for: inspiration.id.uuidString) * 0.8))
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
    var accent: Color = Theme.ink

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: place.category.symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.display(17, weight: .medium))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 8) {
                    if let city = place.city {
                        Text(city.uppercased()).font(.ticket(10, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                    }
                    if place.needsBooking {
                        InkTag(text: "Réserver \(place.bookingLeadDays) j avant", color: Theme.ochre)
                    }
                }
            }
            Spacer(minLength: 8)
            if showsDecision {
                Button("NON") { withAnimation(.snappy) { place.decision = .no } }
                    .buttonStyle(InkButtonStyle(color: Theme.inkSoft))
                Button("OUI") { withAnimation(.snappy) { place.decision = .yes } }
                    .buttonStyle(InkButtonStyle(color: accent, filled: true))
            }
        }
        .padding(.vertical, 4)
    }
}
