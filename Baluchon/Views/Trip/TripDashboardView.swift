import SwiftData
import SwiftUI

/// Tableau de bord du projet : la carte d'embarquement, l'avion qui avance
/// avec la préparation, les prochaines échéances et l'accès aux listes.
struct TripDashboardView: View {
    @Bindable var trip: Trip
    @State private var showingTravelSetup = false
    @State private var editingDate = false

    private var readiness: Readiness { trip.readiness }
    private var color: Color { DestinationStyle.color(for: trip.destinationKey) }

    private var upcoming: [PrepTask] {
        trip.tasks.filter { !$0.isDone }
            .sorted { lhs, rhs in
                if lhs.isBlocking != rhs.isBlocking { return lhs.isBlocking }
                return lhs.leadDays > rhs.leadDays
            }
    }

    private var daysUntilDeparture: Int? {
        guard let start = trip.startDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                               to: Calendar.current.startOfDay(for: start)).day
    }

    private var countdown: String {
        guard let days = daysUntilDeparture else { return "DATE À FIXER" }
        if days > 0 { return "J-\(days)" }
        if days == 0 { return "JOUR J" }
        return "EN VOYAGE"
    }

    var body: some View {
        List {
            Section {
                pass
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                if upcoming.isEmpty {
                    HStack(spacing: 12) {
                        StampMark(size: 34, color: Theme.sea)
                        Text("Tout est prêt. Bon voyage.").font(.display(17)).foregroundStyle(Theme.ink)
                    }
                    .cardRow()
                }
                ForEach(upcoming.prefix(4)) { task in
                    TaskRow(task: task, startDate: trip.startDate)
                        .cardRow()
                }
            } header: {
                SectionLabel("Prochaines étapes")
            }

            Section {
                NavigationLink { TasksView(trip: trip) } label: {
                    row("Plan de préparation", "checklist", "\(trip.tasks.filter(\.isDone).count)/\(trip.tasks.count)")
                }
                .cardRow()
                NavigationLink { ItineraryView(trip: trip) } label: {
                    row("Itinéraire jour par jour", "point.topleft.down.to.point.bottomright.curvepath", "\(trip.totalDays) J")
                }
                .cardRow()
                NavigationLink { BookingsView(trip: trip) } label: {
                    row("Réservations", "ticket", "\(trip.bookings.count)")
                }
                .cardRow()
                NavigationLink { PackingView(trip: trip) } label: {
                    row("Valise", "suitcase", "\(trip.packing.filter(\.isPacked).count)/\(trip.packing.count)")
                }
                .cardRow()
            } header: {
                SectionLabel("Le carnet")
            }

            Section {
                ForEach(trip.sortedStops) { stop in
                    HStack {
                        Text(stop.city).font(.display(17)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(stop.nights) N").font(.ticket(13, weight: .bold)).foregroundStyle(Theme.inkSoft)
                    }
                    .cardRow()
                }
                HStack {
                    Text("Rythme").foregroundStyle(Theme.inkSoft)
                    Spacer()
                    Text(trip.pace.label).font(.display(16)).foregroundStyle(Theme.ink)
                }
                .cardRow()
                Button(trip.startDate == nil ? "Fixer la date de départ" : "Modifier la date de départ") { editingDate = true }
                    .font(.ticket(13, weight: .bold))
                    .cardRow()
            } header: {
                SectionLabel("Le parcours")
            }

            Section {
                Button {
                    showingTravelSetup = true
                } label: {
                    HStack {
                        Text("Passer en mode voyage")
                        Spacer()
                        Image(systemName: "arrow.right").font(.system(size: 15, weight: .bold))
                    }
                    .padding(.horizontal, 20)
                }
                .buttonStyle(TicketButtonStyle(fill: Theme.ink, foreground: Theme.card))
                .accessibilityIdentifier("travel-mode-button")
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                Text("Le carnet se transforme en tableau des départs et fonctionne sans réseau : programme du jour, réservations, phrases, convertisseur, urgences.")
                    .padding(.top, 6)
            }
        }
        .paperBackground()
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingTravelSetup) {
            TravelModeSetupView(trip: trip)
        }
        .sheet(isPresented: $editingDate) {
            DateEditor(trip: trip)
                .presentationDetents([.medium, .large])
        }
    }

    /// Carte d'embarquement : destination, compte à rebours et avion de progression.
    private var pass: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel("Embarquement", color: Theme.card.opacity(0.8))
                    Spacer()
                    Text(countdown).font(.ticket(13, weight: .bold)).foregroundStyle(Theme.card)
                }
                HStack(alignment: .lastTextBaseline) {
                    Text(trip.name)
                        .font(.display(28, weight: .bold))
                        .foregroundStyle(Theme.card)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    Text(DestinationStyle.code(for: trip.destinationKey))
                        .font(.ticket(28, weight: .bold))
                        .foregroundStyle(Theme.card.opacity(0.9))
                }
                HStack(spacing: 18) {
                    passField("Départ", trip.startDate?.ticketDate ?? "--")
                    passField("Durée", "\(trip.totalDays) J")
                    passField("Pass.", "\(trip.travelers)")
                    passField("Étapes", "\(trip.stops.count)")
                }
            }
            .padding(18)
            .background(color)

            TicketTear()

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(readiness.percent)")
                        .font(.display(44, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text("% prêt").font(.ticket(14, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                    Spacer()
                    if readiness.blockers > 0 {
                        InkTag(text: "\(readiness.blockers) bloquant\(readiness.blockers > 1 ? "s" : "")")
                    } else {
                        InkTag(text: "Rien de bloquant", color: Theme.sea)
                    }
                }
                FlightProgress(percent: readiness.percent, tint: color)
                    .frame(height: 46)
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
                HStack {
                    Text("IDÉE").font(.ticket(10, weight: .bold))
                    Spacer()
                    Text("DÉPART").font(.ticket(10, weight: .bold))
                }
                .foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .animation(.snappy, value: readiness.percent)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
    }

    private func passField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.ticket(9, weight: .semibold)).foregroundStyle(Theme.card.opacity(0.75))
            Text(value).font(.ticket(14, weight: .bold)).foregroundStyle(Theme.card)
        }
    }

    private func row(_ title: String, _ symbol: String, _ value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 22)
            Text(title).font(.display(17)).foregroundStyle(Theme.ink)
            Spacer()
            Text(value).font(.ticket(13, weight: .semibold)).foregroundStyle(Theme.inkSoft)
        }
        .padding(.vertical, 3)
    }
}

private struct DateEditor: View {
    @Bindable var trip: Trip
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Départ", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .cardRow()
            }
            .paperBackground()
            .navigationTitle("Date de départ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        trip.startDate = date
                        dismiss()
                    }
                }
                if trip.startDate != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Retirer", role: .destructive) {
                            trip.startDate = nil
                            dismiss()
                        }
                    }
                }
            }
            .onAppear { date = trip.startDate ?? Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date() }
        }
    }
}

/// Une tâche du plan : case de formulaire, tampon une fois faite.
struct TaskRow: View {
    @Bindable var task: PrepTask
    let startDate: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                task.isDone.toggle()
            } label: {
                StampCheckbox(isOn: task.isDone)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .medium), trigger: task.isDone)
            .accessibilityLabel(task.isDone ? "Fait" : "À faire")

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.display(16, weight: .medium))
                    .strikethrough(task.isDone, color: Theme.inkSoft)
                    .foregroundStyle(task.isDone ? Theme.inkSoft : Theme.ink)
                HStack(spacing: 8) {
                    if task.isBlocking && !task.isDone {
                        InkTag(text: "Bloquant")
                    }
                    if let due = task.dueDate(startDate: startDate) {
                        let late = due < Date() && !task.isDone
                        Text("AVANT LE \(due.ticketDate)")
                            .font(.ticket(10, weight: .semibold))
                            .foregroundStyle(late ? Theme.stamp : Theme.inkSoft)
                    } else if task.leadDays > 0 {
                        Text("J-\(task.leadDays)")
                            .font(.ticket(10, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 2)
    }
}
