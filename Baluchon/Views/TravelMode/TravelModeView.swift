import SwiftData
import SwiftUI

/// Le mode voyage : le carnet devient un tableau des départs, et tout fonctionne sans réseau.
struct TravelModeView: View {
    @Bindable var trip: Trip
    @State private var confirmExit = false
    @State private var showIntro = true

    var body: some View {
        TabView {
            NavigationStack { TodayView(trip: trip).toolbar { exitButton } }
                .tabItem { Label("Aujourd'hui", systemImage: "clock") }
            NavigationStack { PhrasesView(trip: trip).toolbar { exitButton } }
                .tabItem { Label("Phrases", systemImage: "character.bubble") }
            NavigationStack { CurrencyConverterView(trip: trip).toolbar { exitButton } }
                .tabItem { Label("Argent", systemImage: "banknote") }
            NavigationStack { CompanionView(trip: trip).toolbar { exitButton } }
                .tabItem { Label("Compagnon", systemImage: "text.bubble") }
            NavigationStack { EmergencyView(trip: trip).toolbar { exitButton } }
                .tabItem { Label("Urgences", systemImage: "cross.case") }
        }
        .tint(Theme.amber)
        .preferredColorScheme(.dark)
        .overlay {
            if showIntro {
                DepartureIntro(trip: trip)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_300_000_000)
            withAnimation(.easeOut(duration: 0.5)) { showIntro = false }
        }
        .confirmationDialog("Quitter le mode voyage ?", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("Revenir au carnet de préparation") { trip.isTravelModeActive = false }
        }
    }

    private var exitButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { confirmExit = true } label: { Image(systemName: "book.closed") }
                .accessibilityLabel("Quitter le mode voyage")
        }
    }
}

/// Écran d'embarquement affiché à l'activation du mode voyage.
private struct DepartureIntro: View {
    let trip: Trip

    var body: some View {
        ZStack {
            Theme.board.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Text("DÉPARTS").font(.ticket(13, weight: .bold)).tracking(4).foregroundStyle(Theme.amber.opacity(0.7))
                SplitFlapText(text: "BON VOYAGE", size: 30)
                SplitFlapText(text: DestinationStyle.code(for: trip.destinationKey) + " " + (trip.startDate?.ticketDate ?? ""), size: 22)
                Text(trip.name)
                    .font(.display(22, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .padding(.top, 6)
            }
            .padding(28)
        }
    }
}

/// Fond et lignes du tableau des départs.
extension View {
    func boardBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.board.ignoresSafeArea())
    }

    func boardRow() -> some View {
        listRowBackground(Theme.boardTile)
    }
}

/// Programme du jour : quoi, où, quand, comment.
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

    private var selectedCity: String {
        days.first { $0.index == selectedDay }?.entries.first?.city
            ?? trip.sortedStops.first?.city ?? ""
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("PROGRAMME DU JOUR").font(.ticket(11, weight: .bold)).tracking(3).foregroundStyle(Theme.amber.opacity(0.7))
                    SplitFlapText(text: "J\(selectedDay + 1) \(cityCode(selectedCity))", size: 26)
                    if let date = ItineraryDays.date(for: selectedDay, trip: trip) {
                        Text(date.longFrench.capitalized + " · " + selectedCity)
                            .font(.display(18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(days, id: \.index) { day in
                                Button {
                                    withAnimation(.snappy) { selectedDay = day.index }
                                } label: {
                                    VStack(spacing: 3) {
                                        Text("J\(day.index + 1)").font(.ticket(15, weight: .bold))
                                        if let date = ItineraryDays.date(for: day.index, trip: trip) {
                                            Text(date.ticketDate).font(.ticket(9, weight: .medium))
                                        }
                                    }
                                    .foregroundStyle(selectedDay == day.index ? Theme.board : Theme.amber)
                                    .frame(width: 54, height: 50)
                                    .background(RoundedRectangle(cornerRadius: 4).fill(selectedDay == day.index ? Theme.amber : Theme.boardTile))
                                    .overlay(Rectangle().fill(Color.black.opacity(0.35)).frame(height: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .sensoryFeedback(.selection, trigger: selectedDay)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 10, trailing: 16))
            }

            if let day = days.first(where: { $0.index == selectedDay }) {
                Section {
                    if day.entries.isEmpty {
                        FreeDayRow(tint: Theme.amber).boardRow()
                    }
                    ForEach(day.entries) { entry in
                        BoardEntryRow(entry: entry).boardRow()
                    }
                }
            }

            let bookings = bookingsForSelectedDay
            if !bookings.isEmpty {
                Section {
                    ForEach(bookings) { booking in
                        NavigationLink { BookingDetailView(booking: booking) } label: {
                            BookingRow(booking: booking, accent: Theme.amber)
                        }
                        .boardRow()
                    }
                } header: {
                    SectionLabel("Réservations du jour", color: Theme.amber.opacity(0.8))
                }
            }

            if !trip.bookings.isEmpty {
                Section {
                    NavigationLink { BookingsView(trip: trip) } label: {
                        HStack {
                            Text("Toutes mes réservations").font(.display(16))
                            Spacer()
                            Text("\(trip.bookings.count)").font(.ticket(13, weight: .bold)).foregroundStyle(Theme.amber)
                        }
                    }
                    .boardRow()
                }
            }
        }
        .boardBackground()
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { selectedDay = currentDayIndex }
    }

    private func cityCode(_ city: String) -> String {
        let letters = TextNormalizer.normalize(city).replacingOccurrences(of: " ", with: "")
        return String(letters.prefix(3)).uppercased()
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

/// Ligne du tableau : créneau en ambre, lieu en blanc, liens de carte.
private struct BoardEntryRow: View {
    let entry: ItineraryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.slot.label.uppercased())
                .font(.ticket(10, weight: .bold))
                .foregroundStyle(entry.slot == .transit ? Color.white.opacity(0.5) : Theme.amber)
                .frame(width: 70, alignment: .leading)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title)
                    .font(.display(18, weight: entry.slot == .transit ? .regular : .semibold))
                    .italic(entry.slot == .transit)
                    .foregroundStyle(.white)
                if entry.slot != .transit {
                    MapButtons(name: entry.title, city: entry.city, latitude: entry.latitude, longitude: entry.longitude,
                               color: Theme.amber)
                }
            }
        }
        .padding(.vertical, 5)
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
                Text("Pas de phrases préécrites pour cette destination. Langue locale : \(destination?.languageName ?? "inconnue").")
                    .font(.display(16))
                    .foregroundStyle(.white.opacity(0.8))
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(phrases) { phrase in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(phrase.french.uppercased())
                                .font(.ticket(10, weight: .semibold))
                                .foregroundStyle(Theme.amber.opacity(0.8))
                            Text(phrase.local)
                                .font(.display(23, weight: .semibold))
                                .foregroundStyle(.white)
                            if let romanization = phrase.romanization {
                                Text(romanization).font(.callout).italic().foregroundStyle(.white.opacity(0.6))
                            }
                            HStack(spacing: 8) {
                                Button("ÉCOUTER") {
                                    if let language = destination?.languageCode {
                                        SpeechService.shared.speak(phrase.local, language: language)
                                    }
                                }
                                .buttonStyle(InkButtonStyle(color: Theme.amber))
                                Button("MONTRER") { shown = phrase }
                                    .buttonStyle(InkButtonStyle(color: Theme.amber))
                            }
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 6)
                        .boardRow()
                    }
                } footer: {
                    if travelerName.isEmpty {
                        Text("Ajoute ton nom dans le passeport pour personnaliser la phrase de réservation.")
                    }
                }

                Section {
                    ForEach(trip.sortedStops) { stop in
                        Button {
                            shown = Phrase(id: stop.city, french: "Pouvez-vous m'emmener ici ?", local: stop.city, romanization: nil)
                        } label: {
                            HStack {
                                Text(stop.city).font(.display(17)).foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "arrow.up.left.and.arrow.down.right").foregroundStyle(Theme.amber)
                            }
                        }
                        .boardRow()
                    }
                } header: {
                    SectionLabel("Montrer au chauffeur", color: Theme.amber.opacity(0.8))
                }
            }
        }
        .boardBackground()
        .navigationTitle("Phrases utiles")
        .fullScreenCover(item: $shown) { phrase in
            ShowPhraseView(phrase: phrase, language: destination?.languageCode)
        }
    }
}

/// La phrase en très grand, sur une carte papier, pour la montrer à quelqu'un.
private struct ShowPhraseView: View {
    let phrase: Phrase
    let language: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: 0xF4EEE2).ignoresSafeArea()
            VStack(spacing: 26) {
                Spacer()
                Text(phrase.local)
                    .font(.system(size: 54, weight: .bold, design: .serif))
                    .minimumScaleFactor(0.3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: 0x1C2540))
                Text(phrase.french)
                    .font(.ticket(14, weight: .medium))
                    .foregroundStyle(Color(hex: 0x5C6479))
                Spacer()
                HStack(spacing: 12) {
                    if let language {
                        Button("ÉCOUTER") { SpeechService.shared.speak(phrase.local, language: language) }
                            .buttonStyle(InkButtonStyle(color: Color(hex: 0xC2412A), filled: true))
                    }
                    Button("FERMER") { dismiss() }
                        .buttonStyle(InkButtonStyle(color: Color(hex: 0x1C2540)))
                }
            }
            .padding(32)
        }
        .preferredColorScheme(.light)
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
        List {
            if rate > 0 {
                Section {
                    amountField($localAmount, currency: localCurrency, field: .local)
                        .boardRow()
                    amountField($homeAmount, currency: trip.baseCurrency, field: .home)
                        .boardRow()
                } footer: {
                    Text("1 \(trip.baseCurrency) = \(rate.formatted(.number.precision(.fractionLength(0...4)))) \(localCurrency)"
                         + (trip.cachedRateDate.map { " · taux du \($0.shortFrench)" } ?? ""))
                        .font(.ticket(11))
                }

                Section {
                    ForEach(quickAmounts, id: \.self) { amount in
                        HStack {
                            Text(CurrencyService.format(amount, currency: localCurrency))
                                .font(.ticket(15, weight: .semibold)).foregroundStyle(.white)
                            Spacer()
                            Text(CurrencyService.format(amount / rate, currency: trip.baseCurrency))
                                .font(.ticket(15, weight: .bold)).foregroundStyle(Theme.amber)
                        }
                        .boardRow()
                    }
                } header: {
                    SectionLabel("Repères", color: Theme.amber.opacity(0.8))
                }
            }

            Section {
                HStack {
                    TextField("1 \(trip.baseCurrency) = ? \(localCurrency)", text: $manualRate)
                        .keyboardType(.decimalPad)
                        .font(.ticket(15))
                    Button("OK") {
                        if let value = Double(manualRate.replacingOccurrences(of: ",", with: ".")), value > 0 {
                            trip.cachedRate = value
                            trip.cachedRateDate = Date()
                            manualRate = ""
                        }
                    }
                    .buttonStyle(InkButtonStyle(color: Theme.amber))
                }
                .boardRow()
            } header: {
                SectionLabel(rate > 0 ? "Corriger le taux" : "Saisir le taux de change", color: Theme.amber.opacity(0.8))
            }
        }
        .boardBackground()
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

    private func amountField(_ text: Binding<String>, currency: String, field: Field) -> some View {
        HStack {
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .focused($focused, equals: field)
                .font(.ticket(32, weight: .bold))
                .foregroundStyle(focused == field ? Theme.amber : .white)
            Text(currency).font(.ticket(15, weight: .bold)).foregroundStyle(Theme.amber.opacity(0.8))
        }
        .padding(.vertical, 6)
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

    private let alert = Color(hex: 0xE5533D)

    var body: some View {
        List {
            if let destination = trip.destination {
                Section {
                    ForEach(destination.emergency, id: \.self) { item in
                        phoneRow(item.label, item.number)
                    }
                    if !destination.emergency.contains(where: { $0.number == "112" }) {
                        phoneRow("112 — depuis la plupart des mobiles", "112")
                    }
                } header: {
                    SectionLabel("Numéros d'urgence · \(destination.name)", color: alert)
                }
            }
            Section {
                info("Groupe sanguin", bloodType.isEmpty ? "Non renseigné" : bloodType)
                info("Allergies", allergies.isEmpty ? "Non renseignées" : allergies)
                info("Assurance / assistance", insurance.isEmpty ? "Non renseignée" : insurance)
                info("Personne à prévenir", emergencyContact.isEmpty ? "Non renseignée" : emergencyContact)
            } header: {
                SectionLabel("Mes informations", color: Theme.amber.opacity(0.8))
            }
            Section {
                Text("Note l'adresse et le numéro de ton ambassade ou consulat avant de partir : \(OfficialSources.forNationality(nationality).name) les publie pour chaque pays.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.8))
                    .boardRow()
            } header: {
                SectionLabel("Ambassade", color: Theme.amber.opacity(0.8))
            }
        }
        .boardBackground()
        .navigationTitle("Urgences")
    }

    private func info(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(.ticket(10, weight: .semibold)).foregroundStyle(.white.opacity(0.55))
            Text(value).font(.display(17)).foregroundStyle(.white)
        }
        .padding(.vertical, 2)
        .boardRow()
    }

    private func phoneRow(_ label: String, _ number: String) -> some View {
        HStack {
            Text(label).font(.display(16)).foregroundStyle(.white)
            Spacer()
            if let url = URL(string: "tel:\(number)") {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill").font(.system(size: 13, weight: .bold))
                        Text(number).font(.ticket(20, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 5).fill(alert))
                }
            }
        }
        .boardRow()
    }
}
