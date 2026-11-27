import SwiftData
import SwiftUI
import UIKit

/// Plan de préparation complet, par catégorie, avec rétroplanning.
struct TasksView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var context
    @State private var newTask = ""
    @State private var hideDone = false

    var body: some View {
        List {
            Section {
                Toggle("Masquer ce qui est fait", isOn: $hideDone)
            }
            ForEach(TaskCategory.allCases) { category in
                let tasks = trip.tasks
                    .filter { $0.category == category && (!hideDone || !$0.isDone) }
                    .sorted { $0.order < $1.order }
                if !tasks.isEmpty {
                    Section {
                        ForEach(tasks) { task in
                            VStack(alignment: .leading, spacing: 6) {
                                TaskRow(task: task, startDate: trip.startDate)
                                if !task.detail.isEmpty {
                                    Text(task.detail).font(.caption).foregroundStyle(.secondary)
                                        .padding(.leading, 36)
                                }
                                if let link = task.linkString, let url = URL(string: link) {
                                    Link(destination: url) {
                                        Label("Source officielle", systemImage: "arrow.up.right.square")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .padding(.leading, 36)
                                }
                            }
                            .swipeActions {
                                Button("Supprimer", role: .destructive) {
                                    context.delete(task)
                                    try? context.save()
                                }
                            }
                        }
                    } header: {
                        Label(category.label, systemImage: category.symbol)
                    }
                }
            }
            Section("Ajouter une tâche") {
                HStack {
                    TextField("Ex. : réserver le transfert aéroport", text: $newTask)
                    Button { addTask() } label: { Image(systemName: "plus.circle.fill") }
                        .disabled(newTask.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle("Plan de préparation")
    }

    private func addTask() {
        let task = PrepTask(key: "custom:\(UUID().uuidString)", title: newTask.trimmingCharacters(in: .whitespaces), detail: "",
                            category: .other, weight: 2, isBlocking: false, leadDays: 0, linkString: nil,
                            order: (trip.tasks.map(\.order).max() ?? 0) + 1)
        context.insert(task)
        task.trip = trip
        try? context.save()
        newTask = ""
    }
}

/// Déroulé jour par jour (aussi utilisé dans le mode voyage).
struct ItineraryView: View {
    let trip: Trip

    var body: some View {
        List {
            ForEach(ItineraryDays.days(for: trip), id: \.index) { day in
                Section {
                    ForEach(day.entries) { entry in
                        ItineraryEntryRow(entry: entry)
                    }
                } header: {
                    Text(ItineraryDays.title(for: day.index, trip: trip))
                }
            }
        }
        .navigationTitle("Itinéraire")
    }
}

enum ItineraryDays {
    struct Day {
        let index: Int
        let entries: [ItineraryEntry]
    }

    static func days(for trip: Trip) -> [Day] {
        let grouped = Dictionary(grouping: trip.itinerary, by: \.dayIndex)
        return grouped.keys.sorted().map { index in
            Day(index: index, entries: (grouped[index] ?? []).sorted {
                ($0.slot.sortIndex, $0.order) < ($1.slot.sortIndex, $1.order)
            })
        }
    }

    static func title(for index: Int, trip: Trip) -> String {
        if let start = trip.startDate, let date = Calendar.current.date(byAdding: .day, value: index, to: start) {
            return "Jour \(index + 1) — \(date.longFrench)"
        }
        return "Jour \(index + 1)"
    }

    static func date(for index: Int, trip: Trip) -> Date? {
        trip.startDate.flatMap { Calendar.current.date(byAdding: .day, value: index, to: $0) }
    }
}

struct ItineraryEntryRow: View {
    let entry: ItineraryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.slot.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .leading)
                Image(systemName: entry.category?.symbol ?? "arrow.triangle.swap")
                    .foregroundStyle(.tint)
                Text(entry.title).font(.body.weight(entry.slot == .transit ? .semibold : .regular))
            }
            if entry.slot != .transit {
                MapButtons(name: entry.title, city: entry.city, latitude: entry.latitude, longitude: entry.longitude)
                    .padding(.leading, 72)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Réservations : e-mails collés, analysés et rangés.
struct BookingsView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var context
    @State private var showingAdd = false

    var body: some View {
        List {
            if trip.bookings.isEmpty {
                ContentUnavailableView("Aucune réservation",
                                       systemImage: "envelope.open",
                                       description: Text("Colle le contenu de tes e-mails de confirmation (vol, hôtel, train, activité…). Baluchon les range et coche les tâches correspondantes."))
            }
            ForEach(BookingKind.allCases) { kind in
                let items = trip.bookings.filter { $0.kind == kind }.sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { booking in
                            NavigationLink { BookingDetailView(booking: booking) } label: { BookingRow(booking: booking) }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(items[index]) }
                            try? context.save()
                        }
                    } header: {
                        Label(kind.label, systemImage: kind.symbol)
                    }
                }
            }
        }
        .navigationTitle("Réservations")
        .toolbar {
            Button { showingAdd = true } label: { Label("Ajouter", systemImage: "plus") }
        }
        .sheet(isPresented: $showingAdd) {
            AddBookingView(trip: trip)
        }
    }
}

struct BookingRow: View {
    let booking: Booking

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(booking.title).font(.body.weight(.medium)).lineLimit(2)
            HStack(spacing: 8) {
                if let start = booking.startDate {
                    Label(start.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                }
                if !booking.reference.isEmpty {
                    Label(booking.reference, systemImage: "number").textSelection(.enabled)
                }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct BookingDetailView: View {
    @Bindable var booking: Booking

    var body: some View {
        Form {
            Section("Réservation") {
                Picker("Type", selection: Binding(get: { booking.kind }, set: { booking.kind = $0 })) {
                    ForEach(BookingKind.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                }
                TextField("Titre", text: $booking.title)
                TextField("Référence", text: $booking.reference)
                TextField("Lieu / adresse", text: $booking.location)
                OptionalDatePicker(title: "Début", date: $booking.startDate)
                OptionalDatePicker(title: "Fin", date: $booking.endDate)
            }
            if !booking.location.isEmpty {
                Section {
                    MapButtons(name: booking.location, city: nil, latitude: nil, longitude: nil)
                }
            }
            if !booking.rawText.isEmpty {
                Section("E-mail d'origine") {
                    Text(booking.rawText).font(.caption).textSelection(.enabled)
                }
            }
        }
        .navigationTitle(booking.kind.label)
    }
}

struct OptionalDatePicker: View {
    let title: String
    @Binding var date: Date?

    var body: some View {
        if let current = date {
            HStack {
                DatePicker(title, selection: Binding(get: { current }, set: { date = $0 }))
                Button { date = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain)
            }
        } else {
            Button("Ajouter : \(title.lowercased())") { date = Date() }
        }
    }
}

struct AddBookingView: View {
    let trip: Trip
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var raw = ""
    @State private var parsed: ParsedBooking?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $raw).frame(minHeight: 180)
                        .font(.callout)
                    Button {
                        if let pasted = UIPasteboard.general.string { raw = pasted }
                    } label: {
                        Label("Coller l'e-mail", systemImage: "doc.on.clipboard")
                    }
                } header: {
                    Text("Contenu de l'e-mail de confirmation")
                } footer: {
                    Text("Astuce : dans Mail, sélectionne tout le texte de l'e-mail, copie-le, puis colle-le ici.")
                }
                if let parsed {
                    Section("Détecté") {
                        LabeledContent("Type", value: parsed.kind.label)
                        LabeledContent("Titre", value: parsed.title)
                        if let reference = parsed.reference { LabeledContent("Référence", value: reference) }
                        if let start = parsed.startDate { LabeledContent("Début", value: start.formatted(date: .abbreviated, time: .shortened)) }
                        if let end = parsed.endDate { LabeledContent("Fin", value: end.formatted(date: .abbreviated, time: .shortened)) }
                        if let location = parsed.location { LabeledContent("Lieu", value: location) }
                    }
                }
            }
            .navigationTitle("Nouvelle réservation")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: raw) { _, newValue in
                parsed = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : BookingParser.parse(newValue)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }.disabled(parsed == nil)
                }
            }
        }
    }

    private func save() {
        guard let parsed else { return }
        let booking = Booking(kind: parsed.kind, title: parsed.title, reference: parsed.reference ?? "",
                              startDate: parsed.startDate, endDate: parsed.endDate, location: parsed.location ?? "", rawText: raw)
        context.insert(booking)
        booking.trip = trip
        TripFactory.applyBooking(booking, to: trip)
        try? context.save()
        dismiss()
    }
}

/// Préparation de la valise.
struct PackingView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var context
    @State private var newItem = ""

    private var groups: [String] {
        var seen: [String] = []
        for item in trip.packing.sorted(by: { $0.order < $1.order }) where !seen.contains(item.group) {
            seen.append(item.group)
        }
        return seen
    }

    var body: some View {
        List {
            Section {
                let packed = trip.packing.filter(\.isPacked).count
                ProgressView(value: Double(packed), total: Double(max(trip.packing.count, 1))) {
                    Text("\(packed) / \(trip.packing.count) dans la valise")
                }
            }
            ForEach(groups, id: \.self) { group in
                Section(group) {
                    ForEach(trip.packing.filter { $0.group == group }.sorted { $0.order < $1.order }) { item in
                        PackingRow(item: item)
                            .swipeActions {
                                Button("Supprimer", role: .destructive) {
                                    context.delete(item)
                                    try? context.save()
                                }
                            }
                    }
                }
            }
            Section("Ajouter") {
                HStack {
                    TextField("Ex. : maillot de bain", text: $newItem)
                    Button { addItem() } label: { Image(systemName: "plus.circle.fill") }
                        .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle("Valise")
    }

    private func addItem() {
        let item = PackingItem(name: newItem.trimmingCharacters(in: .whitespaces), group: "Perso",
                               order: (trip.packing.map(\.order).max() ?? 0) + 1)
        context.insert(item)
        item.trip = trip
        try? context.save()
        newItem = ""
    }
}

private struct PackingRow: View {
    @Bindable var item: PackingItem

    var body: some View {
        Button {
            withAnimation { item.isPacked.toggle() }
        } label: {
            HStack {
                Image(systemName: item.isPacked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(item.isPacked ? Color.green : Color.secondary)
                Text(item.name)
                    .strikethrough(item.isPacked)
                    .foregroundStyle(item.isPacked ? Color.secondary : Color.primary)
            }
        }
        .buttonStyle(.plain)
    }
}
