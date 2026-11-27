import SwiftData
import SwiftUI

/// Vérification avant de partir : tout ce qui doit être disponible hors ligne.
struct TravelModeSetupView: View {
    @Bindable var trip: Trip
    @Environment(\.dismiss) private var dismiss
    @State private var isFetchingRate = false
    @State private var rateError: String?

    private var destination: Destination? { trip.destination }
    private var needsRate: Bool { (destination?.currencyCode ?? trip.baseCurrency) != trip.baseCurrency }
    private var voiceReady: Bool {
        guard let language = destination?.languageCode else { return true }
        return SpeechService.hasVoice(for: language)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    check("Déroulé jour par jour", ok: !trip.itinerary.isEmpty, detail: "\(trip.totalDays) jours planifiés")
                    check("Réservations enregistrées", ok: !trip.bookings.isEmpty,
                          detail: trip.bookings.isEmpty ? "Aucune réservation ajoutée (facultatif)" : "\(trip.bookings.count) réservation(s)")
                    if needsRate {
                        HStack {
                            check("Taux de change \(trip.baseCurrency) → \(destination?.currencyCode ?? "")", ok: trip.cachedRate != nil,
                                  detail: rateDetail)
                            if isFetchingRate { ProgressView() }
                        }
                    }
                    if let language = destination?.languageName, destination?.languageCode != nil {
                        check("Voix \(language) pour les phrases", ok: voiceReady,
                              detail: voiceReady ? "Installée" : "Réglages › Accessibilité › Contenu énoncé › Voix")
                    }
                    check("Cartes hors ligne", ok: trip.tasks.first(where: { $0.key == "offlineMaps" })?.isDone ?? false,
                          detail: "À télécharger dans Google Maps ou Plans, puis à cocher dans le plan")
                } header: {
                    Text("Prêt pour le hors ligne ?")
                } footer: {
                    if let rateError { Text(rateError).foregroundStyle(.red) }
                }

                Section {
                    Button {
                        Task { await activate() }
                    } label: {
                        Label("Activer le mode voyage", systemImage: "airplane.departure")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("activate-travel-mode")
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("Tu pourras revenir au mode préparation à tout moment.")
                }
            }
            .navigationTitle("Mode voyage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
            .task { await refreshRate() }
        }
    }

    private var rateDetail: String {
        guard let rate = trip.cachedRate else { return "Nécessite une connexion une fois" }
        let date = trip.cachedRateDate?.shortFrench ?? ""
        return "1 \(trip.baseCurrency) = \(rate.formatted(.number.precision(.fractionLength(0...4)))) \(destination?.currencyCode ?? "") (\(date))"
    }

    private func check(_ title: String, ok: Bool, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(ok ? Color.green : Color.orange)
                .font(.title3)
            VStack(alignment: .leading) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func refreshRate() async {
        guard needsRate, let target = destination?.currencyCode else { return }
        isFetchingRate = true
        defer { isFetchingRate = false }
        do {
            trip.cachedRate = try await CurrencyService.fetchRate(base: trip.baseCurrency, target: target)
            trip.cachedRateDate = Date()
            rateError = nil
        } catch {
            if trip.cachedRate == nil {
                rateError = "Impossible de récupérer le taux de change. Tu pourras le saisir à la main dans le convertisseur."
            }
        }
    }

    private func activate() async {
        await refreshRate()
        if let task = trip.tasks.first(where: { $0.key == "travelMode" }) { task.isDone = true }
        trip.isTravelModeActive = true
        dismiss()
    }
}
