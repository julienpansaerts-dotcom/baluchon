import SwiftData
import SwiftUI

struct TripsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "Aucun voyage pour l'instant",
                        systemImage: "suitcase.rolling",
                        description: Text("Ouvre une tuile dans « Inspirations », garde ce qui te plaît puis touche « Lancer le projet ».")
                    )
                } else {
                    List {
                        ForEach(trips) { trip in
                            NavigationLink(value: trip) {
                                TripRow(trip: trip)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(trips[index]) }
                            try? context.save()
                        }
                    }
                }
            }
            .navigationTitle("Mes voyages")
            .navigationDestination(for: Trip.self) { trip in
                TripDashboardView(trip: trip)
            }
        }
    }
}

private struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 14) {
            ProgressRing(percent: trip.readiness.percent, lineWidth: 5, showsLabel: false)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(trip.name).font(.headline)
                Group {
                    if let start = trip.startDate {
                        Text("Départ le \(start.shortFrench) · \(trip.totalDays) jours")
                    } else {
                        Text("\(trip.totalDays) jours · date à définir")
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(verbatim: "\(trip.readiness.percent)%").font(.headline.monospacedDigit())
        }
        .padding(.vertical, 4)
    }
}
