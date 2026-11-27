import SwiftData
import SwiftUI

/// « Lancer le projet » : choix du rythme et de la date, estimation en direct
/// de la durée, des étapes, des hôtels et du délai de réservation.
struct LaunchTripView: View {
    let destinationKey: String
    let places: [PlaceItem]
    var onCreated: (Trip) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var pace: Pace = .balanced
    @State private var knowsDate = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var travelers = 2

    private var destination: Destination? { DestinationCatalog.destination(for: destinationKey) }

    private var plan: TripPlan {
        TripPlanner.plan(places: TripFactory.plannerPlaces(from: places), destination: destination, pace: pace,
                         nationality: UserProfile.current.nationality)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Voyage") {
                    TextField("Nom du voyage", text: $name, prompt: Text(defaultName))
                    Stepper("Voyageurs : \(travelers)", value: $travelers, in: 1...12)
                }

                Section {
                    Picker("Rythme", selection: $pace) {
                        ForEach(Pace.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(pace.explanation).font(.callout).foregroundStyle(.secondary)
                } header: {
                    Text("Rythme")
                }

                Section("Estimation") {
                    let estimate = plan
                    LabeledContent("Durée conseillée", value: "\(estimate.totalDays) jours / \(estimate.totalNights) nuits")
                    LabeledContent("Détail", value: "\(estimate.activityDays) j d'activités + \(estimate.transferDays) j de trajets + \(estimate.bufferDays) j de marge + 1 j d'arrivée")
                        .font(.caption)
                    LabeledContent("Hébergements à réserver", value: "\(estimate.hotelsCount)")
                    ForEach(estimate.stops, id: \.city) { stop in
                        HStack {
                            Image(systemName: "mappin.circle.fill").foregroundStyle(.tint)
                            Text(stop.city)
                            Spacer()
                            Text("\(stop.nights) nuit\(stop.nights > 1 ? "s" : "")").foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Temps nécessaire pour tout réserver", value: "\(estimate.bookingLeadDays) jours")
                    LabeledContent("Tâches de préparation", value: "\(estimate.tasks.count)")
                }

                Section {
                    Toggle("Je connais ma date de départ", isOn: $knowsDate)
                    if knowsDate {
                        DatePicker("Départ", selection: $startDate, in: Date()..., displayedComponents: .date)
                        let comfortable = TripPlanner.earliestComfortableDeparture(for: plan)
                        if startDate < comfortable {
                            Label("Départ un peu juste : certaines réservations demandent \(plan.bookingLeadDays) jours. Le plan mettra les urgences en avant.",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.callout).foregroundStyle(.orange)
                        } else {
                            Label("Tu as le temps de tout préparer sereinement.", systemImage: "checkmark.seal.fill")
                                .font(.callout).foregroundStyle(.green)
                        }
                    } else {
                        Text("Pour être serein, pars au plus tôt le \(TripPlanner.earliestComfortableDeparture(for: plan).longFrench).")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Date")
                }
            }
            .navigationTitle("Lancer le projet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lancer 🚀") { launch() }.bold()
                }
            }
        }
    }

    private var defaultName: String {
        "\(destination?.flag ?? "✈️") \(destination?.name ?? "Mon voyage")"
    }

    private func launch() {
        let trip = TripFactory.createTrip(
            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? defaultName : name,
            destinationKey: destinationKey,
            places: places,
            pace: pace,
            startDate: knowsDate ? startDate : nil,
            travelers: travelers,
            profile: UserProfile.current,
            context: context
        )
        dismiss()
        onCreated(trip)
    }
}
