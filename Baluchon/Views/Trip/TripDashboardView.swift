import SwiftData
import SwiftUI

/// Tableau de bord du projet : pourcentage de préparation, échéances, accès aux listes.
struct TripDashboardView: View {
    @Bindable var trip: Trip
    @State private var showingTravelSetup = false
    @State private var editingDate = false

    private var readiness: Readiness { trip.readiness }

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

    var body: some View {
        List {
            Section {
                HStack(spacing: 20) {
                    ProgressRing(percent: readiness.percent)
                        .frame(width: 110, height: 110)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Préparation").font(.headline)
                        if let days = daysUntilDeparture {
                            Text(days >= 0 ? "J-\(days)" : "Voyage en cours ou passé")
                                .font(.title.bold())
                        }
                        if readiness.blockers > 0 {
                            Label("\(readiness.blockers) point(s) bloquant(s)", systemImage: "exclamationmark.octagon.fill")
                                .font(.callout).foregroundStyle(.red)
                        } else {
                            Label("Aucun point bloquant", systemImage: "checkmark.shield.fill")
                                .font(.callout).foregroundStyle(.green)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Prochaines étapes") {
                if upcoming.isEmpty {
                    Label("Tout est prêt, bon voyage ! 🎉", systemImage: "party.popper")
                }
                ForEach(upcoming.prefix(4)) { task in
                    TaskRow(task: task, startDate: trip.startDate)
                }
            }

            Section("Préparer") {
                NavigationLink { TasksView(trip: trip) } label: {
                    row("Plan de préparation", "checklist", "\(trip.tasks.filter(\.isDone).count)/\(trip.tasks.count)")
                }
                NavigationLink { ItineraryView(trip: trip) } label: {
                    row("Itinéraire jour par jour", "calendar", "\(trip.totalDays) j")
                }
                NavigationLink { BookingsView(trip: trip) } label: {
                    row("Réservations", "envelope.open", "\(trip.bookings.count)")
                }
                NavigationLink { PackingView(trip: trip) } label: {
                    row("Valise", "suitcase", "\(trip.packing.filter(\.isPacked).count)/\(trip.packing.count)")
                }
            }

            Section("Le voyage") {
                LabeledContent("Rythme", value: trip.pace.label)
                LabeledContent("Voyageurs", value: "\(trip.travelers)")
                if let start = trip.startDate, let end = trip.endDate {
                    LabeledContent("Dates", value: "\(start.shortFrench) → \(end.shortFrench)")
                }
                Button(trip.startDate == nil ? "Fixer la date de départ" : "Modifier la date de départ") { editingDate = true }
                ForEach(trip.sortedStops) { stop in
                    HStack {
                        Image(systemName: "mappin.circle.fill").foregroundStyle(.tint)
                        Text(stop.city)
                        Spacer()
                        Text("\(stop.nights) nuit\(stop.nights > 1 ? "s" : "")").foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button {
                    showingTravelSetup = true
                } label: {
                    Label("Passer en mode voyage", systemImage: "airplane.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("travel-mode-button")
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                Text("L'app se transforme et fonctionne sans réseau : déroulé du jour, réservations, phrases, convertisseur, urgences.")
            }
        }
        .navigationTitle(trip.name)
        .sheet(isPresented: $showingTravelSetup) {
            TravelModeSetupView(trip: trip)
        }
        .sheet(isPresented: $editingDate) {
            DateEditor(trip: trip)
                .presentationDetents([.medium])
        }
    }

    private func row(_ title: String, _ symbol: String, _ value: String) -> some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
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
            }
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

struct TaskRow: View {
    @Bindable var task: PrepTask
    let startDate: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation { task.isDone.toggle() }
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isDone ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? Color.secondary : Color.primary)
                HStack(spacing: 8) {
                    if task.isBlocking && !task.isDone {
                        Text("Bloquant").font(.caption2.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(.red, in: Capsule())
                    }
                    if let due = task.dueDate(startDate: startDate) {
                        let late = due < Date() && !task.isDone
                        Label("Avant le \(due.shortFrench)", systemImage: "calendar.badge.clock")
                            .foregroundStyle(late ? Color.red : Color.secondary)
                    } else if task.leadDays > 0 {
                        Label("\(task.leadDays) j avant le départ", systemImage: "clock")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
        }
    }
}
