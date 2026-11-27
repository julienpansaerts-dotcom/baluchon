import SwiftData
import SwiftUI

/// Le mode voyage : l'app se transforme et tout fonctionne sans réseau.
struct TravelModeView: View {
    @Bindable var trip: Trip
    @State private var confirmExit = false

    var body: some View {
        TabView {
            NavigationStack { TodayView(trip: trip).toolbar { exitButton } }
                .tabItem { Label("Aujourd'hui", systemImage: "sun.max") }
            NavigationStack { PhrasesView(trip: trip).toolbar { exitButton } }
                .tabItem { Label("Phrases", systemImage: "character.bubble") }
            NavigationStack { CurrencyConverterView(trip: trip).toolbar { exitButton } }
                .tabItem { Label("Argent", systemImage: "arrow.left.arrow.right.circle") }
            NavigationStack { CompanionView(trip: trip).toolbar { exitButton } }
                .tabItem { Label("Compagnon", systemImage: "bubble.left.and.text.bubble.right") }
            NavigationStack { EmergencyView(trip: trip).toolbar { exitButton } }
                .tabItem { Label("Urgences", systemImage: "cross.case.fill") }
        }
        .tint(.orange)
        .confirmationDialog("Quitter le mode voyage ?", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("Revenir au mode préparation") { trip.isTravelModeActive = false }
        }
    }

    private var exitButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { confirmExit = true } label: { Image(systemName: "rectangle.portrait.and.arrow.right") }
                .accessibilityLabel("Quitter le mode voyage")
        }
    }
}

/// Déroulé du jour : quoi, où, quand, comment.
struct TodayView: View {
    let trip: Trip
    @State private var selectedDay = 0

    private var days: [ItineraryDays.Day] { ItineraryDays.days(for: trip) }

    private var currentDayIndex: Int {
        guard let start = trip.startDate else { return 0 }
        let diff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start),
                                                   to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return min(max(diff, 0), max((days.last?.index ?? 0), 0))
    }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(days, id: \.index) { day in
                            Button {
                                selectedDay = day.index
                            } label: {
                                VStack(spacing: 2) {
                                    Text("J\(day.index + 1)").font(.headline)
                                    if let date = ItineraryDays.date(for: day.index, trip: trip) {
                                        Text(date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR"))))
                                            .font(.caption2)
                                    }
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(selectedDay == day.index ? Color.orange : Color.secondary.opacity(0.15),
                                            in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(selectedDay == day.index ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }

            if let day = days.first(where: { $0.index == selectedDay }) {
                Section(ItineraryDays.title(for: day.index, trip: trip)) {
                    ForEach(day.entries) { entry in
                        ItineraryEntryRow(entry: entry)
                    }
                }
            }

            let bookings = bookingsForSelectedDay
            if !bookings.isEmpty {
                Section("Réservations du jour") {
                    ForEach(bookings) { booking in
                        NavigationLink { BookingDetailView(booking: booking) } label: {
                            HStack {
                                Image(systemName: booking.kind.symbol).foregroundStyle(.orange)
                                BookingRow(booking: booking)
                            }
                        }
                    }
                }
            }

            if !trip.bookings.isEmpty {
                Section {
                    NavigationLink { BookingsView(trip: trip) } label: {
                        Label("Toutes mes réservations (\(trip.bookings.count))", systemImage: "folder")
                    }
                }
            }
        }
        .navigationTitle(trip.name)
        .onAppear { selectedDay = currentDayIndex }
    }

    private var bookingsForSelectedDay: [Booking] {
        guard let date = ItineraryDays.date(for: selectedDay, trip: trip) else { return [] }
        return trip.bookings.filter { booking in
            guard let start = booking.startDate else { return false }
            if Calendar.current.isDate(start, inSameDayAs: date) { return true }
            if let end = booking.endDate { return start <= date && date <= end }
            return false
        }
        .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
    }
}

/// Phrases préécrites, lues à voix haute, avec un mode « montrer » en grand.
struct PhrasesView: View {
    let trip: Trip
    @AppStorage(UserProfile.Keys.name) private var travelerName = ""
    @AppStorage(UserProfile.Keys.allergies) private var allergies = ""
    @State private var shown: Phrase?

    private var destination: Destination? { trip.destination }
    private var phrases: [Phrase] {
        Phrasebook.phrases(for: destination?.languageCode).map { $0.personalized(name: travelerName, allergy: allergies) }
    }

    var body: some View {
        List {
            if phrases.isEmpty {
                ContentUnavailableView("Pas de phrases pour cette destination",
                                       systemImage: "character.bubble",
                                       description: Text("Langue locale : \(destination?.languageName ?? "inconnue")."))
            } else {
                Section {
                    ForEach(phrases) { phrase in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(phrase.french).font(.caption).foregroundStyle(.secondary)
                            Text(phrase.local).font(.title3.weight(.semibold))
                            if let romanization = phrase.romanization {
                                Text(romanization).font(.callout).italic().foregroundStyle(.secondary)
                            }
                            HStack {
                                Button {
                                    if let language = destination?.languageCode {
                                        SpeechService.shared.speak(phrase.local, language: language)
                                    }
                                } label: { Label("Écouter", systemImage: "speaker.wave.2.fill") }
                                Button { shown = phrase } label: { Label("Montrer", systemImage: "arrow.up.left.and.arrow.down.right") }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                } footer: {
                    if travelerName.isEmpty {
                        Text("Ajoute ton nom dans le profil pour personnaliser la phrase de réservation.")
                    }
                }

                Section("Montrer une adresse au chauffeur") {
                    ForEach(trip.sortedStops) { stop in
                        Button { shown = Phrase(id: stop.city, french: "Adresse", local: stop.city, romanization: nil) } label: {
                            Label(stop.city, systemImage: "car.fill")
                        }
                    }
                }
            }
        }
        .navigationTitle("Phrases utiles")
        .fullScreenCover(item: $shown) { phrase in
            ShowPhraseView(phrase: phrase, language: destination?.languageCode)
        }
    }
}

private struct ShowPhraseView: View {
    let phrase: Phrase
    let language: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Text(phrase.local)
                    .font(.system(size: 52, weight: .bold))
                    .minimumScaleFactor(0.3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black)
                Text(phrase.french).font(.title3).foregroundStyle(.gray)
                Spacer()
                HStack(spacing: 16) {
                    if let language {
                        Button {
                            SpeechService.shared.speak(phrase.local, language: language)
                        } label: { Label("Écouter", systemImage: "speaker.wave.2.fill") }
                            .buttonStyle(.borderedProminent)
                    }
                    Button("Fermer") { dismiss() }.buttonStyle(.bordered)
                }
                .controlSize(.large)
            }
            .padding(32)
        }
        .onTapGesture(count: 2) { dismiss() }
    }
}

/// Convertisseur de monnaie hors ligne (taux enregistré au passage en mode voyage).
struct CurrencyConverterView: View {
    @Bindable var trip: Trip
    @State private var localAmount = ""
    @State private var homeAmount = ""
    @State private var manualRate = ""
    @FocusState private var focused: Field?

    private enum Field { case local, home }

    private var localCurrency: String { trip.destination?.currencyCode ?? trip.baseCurrency }
    private var rate: Double { trip.cachedRate ?? (localCurrency == trip.baseCurrency ? 1 : 0) }

    var body: some View {
        Form {
            if rate > 0 {
                Section {
                    HStack {
                        TextField("0", text: $localAmount).keyboardType(.decimalPad).focused($focused, equals: .local)
                            .font(.system(.title, design: .rounded, weight: .semibold))
                        Text(localCurrency).font(.headline).foregroundStyle(.secondary)
                    }
                    HStack {
                        TextField("0", text: $homeAmount).keyboardType(.decimalPad).focused($focused, equals: .home)
                            .font(.system(.title, design: .rounded, weight: .semibold))
                        Text(trip.baseCurrency).font(.headline).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("1 \(trip.baseCurrency) = \(rate.formatted(.number.precision(.fractionLength(0...4)))) \(localCurrency)"
                         + (trip.cachedRateDate.map { " · taux du \($0.shortFrench)" } ?? ""))
                }

                Section("Repères") {
                    ForEach(quickAmounts, id: \.self) { amount in
                        LabeledContent(CurrencyService.format(amount, currency: localCurrency),
                                       value: CurrencyService.format(amount / rate, currency: trip.baseCurrency))
                    }
                }
            }

            Section {
                HStack {
                    TextField("Taux manuel (1 \(trip.baseCurrency) = ? \(localCurrency))", text: $manualRate)
                        .keyboardType(.decimalPad)
                    Button("OK") {
                        if let value = Double(manualRate.replacingOccurrences(of: ",", with: ".")), value > 0 {
                            trip.cachedRate = value
                            trip.cachedRateDate = Date()
                            manualRate = ""
                        }
                    }
                }
            } header: {
                Text(rate > 0 ? "Corriger le taux" : "Saisir le taux de change")
            }
        }
        .navigationTitle("Convertisseur")
        .onChange(of: localAmount) { _, value in
            guard focused == .local, rate > 0 else { return }
            homeAmount = Self.convert(value, factor: 1 / rate)
        }
        .onChange(of: homeAmount) { _, value in
            guard focused == .home, rate > 0 else { return }
            localAmount = Self.convert(value, factor: rate)
        }
    }

    private var quickAmounts: [Double] {
        guard rate > 0 else { return [] }
        let magnitude = pow(10, floor(log10(max(rate, 1))))
        return [1, 5, 10, 50, 100].map { $0 * magnitude }
    }

    private static func convert(_ text: String, factor: Double) -> String {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: " ", with: "")) else { return "" }
        let result = value * factor
        return result.formatted(.number.precision(.fractionLength(0...(result >= 100 ? 0 : 2))).locale(Locale(identifier: "fr_FR")))
    }
}

/// Infos d'urgence, disponibles hors ligne.
struct EmergencyView: View {
    let trip: Trip
    @AppStorage(UserProfile.Keys.bloodType) private var bloodType = ""
    @AppStorage(UserProfile.Keys.allergies) private var allergies = ""
    @AppStorage(UserProfile.Keys.insurance) private var insurance = ""
    @AppStorage(UserProfile.Keys.emergencyContact) private var emergencyContact = ""
    @AppStorage(UserProfile.Keys.nationality) private var nationality = "FR"

    var body: some View {
        List {
            if let destination = trip.destination {
                Section("Numéros d'urgence — \(destination.name)") {
                    ForEach(destination.emergency, id: \.self) { item in
                        phoneRow(item.label, item.number)
                    }
                    if !destination.emergency.contains(where: { $0.number == "112" }) {
                        phoneRow("112 (fonctionne depuis la plupart des mobiles)", "112")
                    }
                }
            }
            Section("Mes infos médicales") {
                LabeledContent("Groupe sanguin", value: bloodType.isEmpty ? "Non renseigné" : bloodType)
                LabeledContent("Allergies", value: allergies.isEmpty ? "Non renseignées" : allergies)
            }
            Section("Assurance & contacts") {
                LabeledContent("Assurance / assistance", value: insurance.isEmpty ? "Non renseignée" : insurance)
                LabeledContent("Personne à prévenir", value: emergencyContact.isEmpty ? "Non renseignée" : emergencyContact)
            }
            Section {
                Text("Note l'adresse et le numéro de ton ambassade ou consulat avant de partir : \(OfficialSources.forNationality(nationality).name) les publie pour chaque pays.")
                    .font(.callout)
            } header: {
                Text("Ambassade")
            }
        }
        .navigationTitle("Urgences")
    }

    private func phoneRow(_ label: String, _ number: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            if let url = URL(string: "tel:\(number)") {
                Link(destination: url) {
                    Label(number, systemImage: "phone.fill").font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }
}
