import SwiftData
import SwiftUI

/// Mes voyages : une pile de billets.
struct TripsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel("\(trips.count) billet\(trips.count > 1 ? "s" : "")")
                        Text("Mes voyages")
                            .font(.display(34, weight: .bold))
                            .foregroundStyle(Theme.ink)
                    }
                    if trips.isEmpty {
                        Text("Aucun voyage pour l'instant. Ouvre un timbre dans tes envies, garde ce qui te plaît, puis lance le projet.")
                            .font(.display(17, weight: .regular))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.top, 8)
                    }
                    ForEach(Array(trips.enumerated()), id: \.element.id) { index, trip in
                        NavigationLink(value: trip) {
                            TripTicket(trip: trip)
                        }
                        .buttonStyle(StampPressStyle())
                        .contextMenu {
                            Button(role: .destructive) {
                                context.delete(trip)
                                try? context.save()
                            } label: {
                                Label("Supprimer ce voyage", systemImage: "trash")
                            }
                        }
                        .staggered(index)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(PaperBackground())
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Trip.self) { trip in
                TripDashboardView(trip: trip)
            }
        }
    }
}

/// Un voyage présenté comme un billet de train : talon à gauche, trajet à droite.
private struct TripTicket: View {
    let trip: Trip

    private var color: Color { DestinationStyle.color(for: trip.destinationKey) }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("\(trip.readiness.percent)")
                    .font(.display(30, weight: .bold))
                Text("% PRÊT").font(.ticket(9, weight: .bold))
            }
            .foregroundStyle(Theme.card)
            .frame(width: 92)
            .frame(maxHeight: .infinity)
            .background(color)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(DestinationStyle.code(for: trip.destinationKey))
                        .font(.ticket(12, weight: .bold))
                        .foregroundStyle(color)
                    Spacer()
                    Text(trip.startDate.map { "DÉPART \($0.ticketDate)" } ?? "DATE À FIXER")
                        .font(.ticket(10, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                Text(trip.name)
                    .font(.display(21, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(trip.sortedStops.map(\.city).joined(separator: " — "))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
                Text("\(trip.totalDays) JOURS · \(trip.pace.label.uppercased())")
                    .font(.ticket(10, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 124)
        .background(Theme.card)
        .clipShape(TicketShape(notchXPoints: 92, notchY: nil, notchRadius: 8, cornerRadius: 10), style: FillStyle(eoFill: true))
        .shadow(color: .black.opacity(0.09), radius: 4, y: 2)
    }
}
