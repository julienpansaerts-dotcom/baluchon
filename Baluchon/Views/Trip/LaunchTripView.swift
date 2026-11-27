import SwiftData
import SwiftUI

/// « Lancer le projet » : rythme et date, avec une carte d'embarquement recalculée
/// en direct (durée, étapes, hébergements, délai de réservation).
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
    private var color: Color { DestinationStyle.color(for: destinationKey) }

    private var plan: TripPlan {
        TripPlanner.plan(places: TripFactory.plannerPlaces(from: places), destination: destination, pace: pace,
                         nationality: UserProfile.current.nationality)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    nameBlock
                    paceBlock
                    BoardingPass(plan: plan, code: DestinationStyle.code(for: destinationKey),
                                 destinationName: destination?.name ?? "Voyage", travelers: travelers,
                                 startDate: knowsDate ? startDate : nil, color: color)
                    dateBlock
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .background(PaperBackground())
            .navigationTitle("Lancer le projet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lancer") { launch() }
                        .font(.ticket(15, weight: .bold))
                        .accessibilityIdentifier("confirm-launch")
                }
            }
        }
    }

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Nom du voyage")
            TextField("", text: $name, prompt: Text(defaultName).foregroundStyle(Theme.inkSoft.opacity(0.7)))
                .font(.display(26, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 6)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.ink.opacity(0.25)).frame(height: 1) }
            HStack {
                Text("Voyageurs").font(.callout).foregroundStyle(Theme.inkSoft)
                Spacer()
                Button { if travelers > 1 { travelers -= 1 } } label: { Image(systemName: "minus") }
                    .buttonStyle(InkButtonStyle(color: Theme.ink))
                Text("\(travelers)")
                    .font(.ticket(18, weight: .bold))
                    .frame(minWidth: 34)
                    .contentTransition(.numericText())
                Button { if travelers < 12 { travelers += 1 } } label: { Image(systemName: "plus") }
                    .buttonStyle(InkButtonStyle(color: Theme.ink))
            }
            .animation(.snappy, value: travelers)
        }
    }

    private var paceBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Ton rythme")
            HStack(spacing: 10) {
                ForEach(Pace.allCases) { option in
                    let selected = option == pace
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { pace = option }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: symbol(for: option))
                                .font(.system(size: 22, weight: .medium))
                            Text(option.label)
                                .font(.display(15, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(selected ? Theme.card : Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 6).fill(selected ? Theme.ink : Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.ink.opacity(selected ? 0 : 0.15)))
                    }
                    .buttonStyle(StampPressStyle())
                }
            }
            .sensoryFeedback(.selection, trigger: pace)
            Text(pace.explanation)
                .font(.callout)
                .foregroundStyle(Theme.inkSoft)
                .id(pace)
                .transition(.opacity)
        }
    }

    private var dateBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Date de départ")
            Toggle(isOn: $knowsDate.animation(.snappy)) {
                Text("Je connais ma date").font(.display(17)).foregroundStyle(Theme.ink)
            }
            .tint(Theme.stamp)
            if knowsDate {
                DatePicker("Départ", selection: $startDate, in: Date()..., displayedComponents: .date)
                    .font(.display(17))
                let comfortable = TripPlanner.earliestComfortableDeparture(for: plan)
                if startDate < comfortable {
                    note("Un peu juste : certaines réservations demandent \(plan.bookingLeadDays) jours. Le plan mettra les urgences en tête.",
                         color: Theme.stamp)
                } else {
                    note("Tu as le temps de tout préparer sans stress.", color: Theme.sea)
                }
            } else {
                note("Pour être serein, pars au plus tôt le \(TripPlanner.earliestComfortableDeparture(for: plan).longFrench).",
                     color: Theme.inkSoft)
            }
        }
    }

    private func note(_ text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle().fill(color).frame(width: 3)
            Text(text).font(.callout).foregroundStyle(Theme.ink)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func symbol(for pace: Pace) -> String {
        switch pace {
        case .chill: "figure.walk"
        case .balanced: "figure.hiking"
        case .rushed: "figure.run"
        }
    }

    private var defaultName: String {
        destination?.name ?? "Mon voyage"
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

/// Estimation présentée comme une carte d'embarquement.
struct BoardingPass: View {
    let plan: TripPlan
    let code: String
    let destinationName: String
    let travelers: Int
    let startDate: Date?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SectionLabel("Carte d'embarquement", color: Theme.card.opacity(0.85))
                    Spacer()
                    Text("\(travelers) PASS.").font(.ticket(11, weight: .bold)).foregroundStyle(Theme.card.opacity(0.85))
                }
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ICI").font(.ticket(30, weight: .bold))
                        Text("Chez toi").font(.caption).opacity(0.8)
                    }
                    Spacer()
                    Image(systemName: "airplane").font(.system(size: 20, weight: .semibold))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(code).font(.ticket(30, weight: .bold))
                        Text(destinationName).font(.caption).opacity(0.8)
                    }
                }
                .foregroundStyle(Theme.card)
                HStack(spacing: 0) {
                    figure("\(plan.totalDays)", "jours")
                    figure("\(plan.totalNights)", "nuits")
                    figure("\(plan.hotelsCount)", "hôtels")
                    figure("\(plan.bookingLeadDays)", "j pour réserver")
                }
                .foregroundStyle(Theme.card)
            }
            .padding(18)
            .background(color)

            TicketTear()

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(plan.stops.enumerated()), id: \.offset) { index, stop in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(spacing: 0) {
                            Rectangle().fill(index == 0 ? Color.clear : Theme.rule).frame(width: 1.5)
                            Circle().strokeBorder(color, lineWidth: 2).frame(width: 11, height: 11)
                            Rectangle().fill(index == plan.stops.count - 1 ? Color.clear : Theme.rule).frame(width: 1.5)
                        }
                        .frame(width: 12)
                        Text(stop.city).font(.display(17)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(stop.nights) N").font(.ticket(13, weight: .bold)).foregroundStyle(Theme.inkSoft)
                    }
                    .frame(height: 36)
                }
                Text("\(plan.activityDays) j d'activités · \(plan.transferDays) j de trajets · \(plan.bufferDays) j de marge · 1 j d'arrivée")
                    .font(.ticket(10))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 10)
                if let startDate {
                    Text("DÉPART \(startDate.ticketDate)")
                        .font(.ticket(12, weight: .bold))
                        .foregroundStyle(Theme.stamp)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .padding(.top, 4)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: plan.totalDays)
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.display(26, weight: .bold))
                .contentTransition(.numericText())
            Text(label.uppercased())
                .font(.ticket(9, weight: .semibold))
                .opacity(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Ligne de découpe d'un billet : pointillés et deux encoches couleur papier.
struct TicketTear: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Theme.paper).frame(width: 20, height: 20).offset(x: -10)
            DashedRule(color: Theme.inkSoft.opacity(0.5))
            Circle().fill(Theme.paper).frame(width: 20, height: 20).offset(x: 10)
        }
        .frame(height: 20)
    }
}
