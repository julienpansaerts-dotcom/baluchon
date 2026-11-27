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
                Toggle(isOn: $hideDone.animation(.snappy)) {
                    Text("Masquer ce qui est tamponné").font(.display(16)).foregroundStyle(Theme.ink)
                }
                .tint(Theme.stamp)
                .cardRow()
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
                                if !task.detail.isEmpty && !task.isDone {
                                    Text(task.detail).font(.footnote).foregroundStyle(Theme.inkSoft)
                                        .padding(.leading, 40)
                                }
                                if let link = task.linkString, let url = URL(string: link), !task.isDone {
                                    Link(destination: url) { Text("SOURCE OFFICIELLE ↗") }
                                        .buttonStyle(InkButtonStyle(color: Theme.sea))
                                        .padding(.leading, 40)
                                }
                            }
                            .cardRow()
                            .swipeActions {
                                Button("Supprimer", role: .destructive) {
                                    context.delete(task)
                                    try? context.save()
                                }
                            }
                        }
                    } header: {
                        let done = tasks.filter(\.isDone).count
                        HStack {
                            SectionLabel(category.label)
                            Spacer()
                            Text("\(done)/\(tasks.count)").font(.ticket(11, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
            }
            Section {
                HStack {
                    TextField("Ex. : réserver le transfert aéroport", text: $newTask)
                        .font(.display(16))
                    Button("AJOUTER") { addTask() }
                        .buttonStyle(InkButtonStyle(color: Theme.stamp))
                        .disabled(newTask.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .cardRow()
            } header: {
                SectionLabel("Ajouter une tâche")
            }
        }
        .paperBackground()
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
                    if day.entries.isEmpty {
                        FreeDayRow().cardRow()
                    }
                    ForEach(day.entries) { entry in
                        ItineraryEntryRow(entry: entry).cardRow()
                    }
                } header: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("J\(day.index + 1)").font(.display(20, weight: .bold)).foregroundStyle(Theme.ink)
                        SectionLabel(ItineraryDays.subtitle(for: day.index, trip: trip))
                    }
                    .textCase(nil)
                }
            }
        }
        .paperBackground()
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
        // Tous les jours du voyage, y compris les journées libres (marge) sans activité prévue.
        let count = max(trip.totalDays, (grouped.keys.max() ?? -1) + 1)
        return (0..<count).map { index in
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

    /// « VENDREDI 27 NOVEMBRE · TOKYO »
    static func subtitle(for index: Int, trip: Trip) -> String {
        let city = days(for: trip).first { $0.index == index }?.entries.first?.city
        let date = self.date(for: index, trip: trip)?.longFrench
        return [date, city].compactMap { $0 }.joined(separator: " · ")
    }

    static func date(for index: Int, trip: Trip) -> Date? {
        trip.startDate.flatMap { Calendar.current.date(byAdding: .day, value: index, to: $0) }
    }
}

/// Journée sans activité prévue : la marge du rythme choisi.
struct FreeDayRow: View {
    var tint: Color = Theme.sea

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("LIBRE")
                .font(.ticket(10, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 66, alignment: .leading)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Journée libre").font(.display(17, weight: .semibold))
                Text("Repos, flânerie, ou rattrapage si la météo a joué des tours.")
                    .font(.footnote).foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Une ligne du programme : créneau à chasse fixe, lieu en serif, liens de carte.
struct ItineraryEntryRow: View {
    let entry: ItineraryEntry
    var slotColor: Color = Theme.stamp

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.slot.label.uppercased())
                .font(.ticket(10, weight: .bold))
                .foregroundStyle(entry.slot == .transit ? Theme.inkSoft : slotColor)
                .frame(width: 66, alignment: .leading)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title)
                    .font(.display(17, weight: entry.slot == .transit ? .semibold : .regular))
                    .italic(entry.slot == .transit)
                if entry.slot != .transit {
                    MapButtons(name: entry.title, city: entry.city, latitude: entry.latitude, longitude: entry.longitude)
                }
            }
        }
        .padding(.vertical, 4)
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
                Text("Aucune réservation. Colle le contenu de tes e-mails de confirmation (vol, hôtel, train, activité) : Baluchon les range et tamponne les tâches correspondantes.")
                    .font(.display(16, weight: .regular))
                    .foregroundStyle(Theme.inkSoft)
                    .listRowBackground(Color.clear)
            }
            ForEach(BookingKind.allCases) { kind in
                let items = trip.bookings.filter { $0.kind == kind }.sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { booking in
                            NavigationLink { BookingDetailView(booking: booking) } label: { BookingRow(booking: booking) }
                                .cardRow()
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(items[index]) }
                            try? context.save()
                        }
                    } header: {
                        SectionLabel(kind.label)
                    }
                }
            }
        }
        .paperBackground()
        .navigationTitle("Réservations")
        .toolbar {
            Button { showingAdd = true } label: { Image(systemName: "plus") }
                .accessibilityLabel("Ajouter une réservation")
        }
        .sheet(isPresented: $showingAdd) {
            AddBookingView(trip: trip)
        }
    }
}

struct BookingRow: View {
    let booking: Booking
    var accent: Color = Theme.ink

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: booking.kind.symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 22)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(booking.title).font(.display(16, weight: .medium)).lineLimit(2)
                HStack(spacing: 10) {
                    if let start = booking.startDate {
                        Text(start.ticketDate + " · " + start.formatted(date: .omitted, time: .shortened))
                    }
                    if !booking.reference.isEmpty {
                        Text("RÉF. \(booking.reference)").textSelection(.enabled)
                    }
                }
                .font(.ticket(10, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.vertical, 2)
    }
}

struct BookingDetailView: View {
    @Bindable var booking: Booking

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: Binding(get: { booking.kind }, set: { booking.kind = $0 })) {
                    ForEach(BookingKind.allCases) { Text($0.label).tag($0) }
                }
                .cardRow()
                TextField("Titre", text: $booking.title).font(.display(17)).cardRow()
                TextField("Référence", text: $booking.reference).font(.ticket(15, weight: .semibold)).cardRow()
                TextField("Lieu / adresse", text: $booking.location).cardRow()
                OptionalDatePicker(title: "Début", date: $booking.startDate).cardRow()
                OptionalDatePicker(title: "Fin", date: $booking.endDate).cardRow()
            } header: {
                SectionLabel("Réservation")
            }
            if !booking.location.isEmpty {
                Section {
                    MapButtons(name: booking.location, city: nil, latitude: nil, longitude: nil)
                        .listRowBackground(Color.clear)
                }
            }
            if !booking.rawText.isEmpty {
                Section {
                    Text(booking.rawText).font(.ticket(11)).textSelection(.enabled).cardRow()
                } header: {
                    SectionLabel("E-mail d'origine")
                }
            }
        }
        .paperBackground()
        .navigationTitle(booking.kind.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct OptionalDatePicker: View {
    let title: String
    @Binding var date: Date?

    var body: some View {
        if let current = date {
            HStack {
                DatePicker(title, selection: Binding(get: { current }, set: { date = $0 }))
                Button { date = nil } label: { Image(systemName: "xmark").foregroundStyle(Theme.inkSoft) }
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
                        .font(.ticket(12))
                        .cardRow()
                    Button("COLLER L'E-MAIL") {
                        if let pasted = UIPasteboard.general.string { raw = pasted }
                    }
                    .buttonStyle(InkButtonStyle(color: Theme.stamp))
                    .listRowBackground(Color.clear)
                } header: {
                    SectionLabel("E-mail de confirmation")
                } footer: {
                    Text("Dans Mail, sélectionne tout le texte de l'e-mail, copie-le, puis colle-le ici.")
                }
                if let parsed {
                    Section {
                        LabeledContent("Type", value: parsed.kind.label).cardRow()
                        LabeledContent("Titre", value: parsed.title).cardRow()
                        if let reference = parsed.reference { LabeledContent("Référence", value: reference).cardRow() }
                        if let start = parsed.startDate { LabeledContent("Début", value: start.formatted(date: .abbreviated, time: .shortened)).cardRow() }
                        if let end = parsed.endDate { LabeledContent("Fin", value: end.formatted(date: .abbreviated, time: .shortened)).cardRow() }
                        if let location = parsed.location { LabeledContent("Lieu", value: location).cardRow() }
                    } header: {
                        SectionLabel("Ce que Baluchon a lu", color: Theme.sea)
                    }
                }
            }
            .paperBackground()
            .navigationTitle("Nouvelle réservation")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: raw) { _, newValue in
                withAnimation(.snappy) {
                    parsed = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : BookingParser.parse(newValue)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ranger") { save() }.disabled(parsed == nil)
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
                let total = max(trip.packing.count, 1)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(packed)")
                            .font(.display(40, weight: .bold))
                            .contentTransition(.numericText())
                        Text("/ \(trip.packing.count) dans la valise").font(.ticket(13, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.rule)
                            Capsule().fill(Theme.ochre)
                                .frame(width: proxy.size.width * CGFloat(packed) / CGFloat(total))
                        }
                    }
                    .frame(height: 8)
                }
                .animation(.spring, value: packed)
                .listRowBackground(Color.clear)
            }
            ForEach(groups, id: \.self) { group in
                Section {
                    ForEach(trip.packing.filter { $0.group == group }.sorted { $0.order < $1.order }) { item in
                        PackingRow(item: item)
                            .cardRow()
                            .swipeActions {
                                Button("Supprimer", role: .destructive) {
                                    context.delete(item)
                                    try? context.save()
                                }
                            }
                    }
                } header: {
                    SectionLabel(group)
                }
            }
            Section {
                HStack {
                    TextField("Ex. : maillot de bain", text: $newItem).font(.display(16))
                    Button("AJOUTER") { addItem() }
                        .buttonStyle(InkButtonStyle(color: Theme.stamp))
                        .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .cardRow()
            } header: {
                SectionLabel("Ajouter")
            }
        }
        .paperBackground()
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
            item.isPacked.toggle()
        } label: {
            HStack(spacing: 10) {
                StampCheckbox(isOn: item.isPacked)
                Text(item.name)
                    .font(.display(16))
                    .strikethrough(item.isPacked, color: Theme.inkSoft)
                    .foregroundStyle(item.isPacked ? Theme.inkSoft : Theme.ink)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: item.isPacked)
    }
}
