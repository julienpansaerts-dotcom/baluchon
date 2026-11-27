import SwiftUI

/// Profil voyageur : sert aux formalités (nationalité), aux phrases et aux urgences.
/// Tout reste sur l'iPhone.
struct ProfileView: View {
    @AppStorage(UserProfile.Keys.name) private var name = ""
    @AppStorage(UserProfile.Keys.nationality) private var nationality = "FR"
    @AppStorage(UserProfile.Keys.baseCurrency) private var baseCurrency = "EUR"
    @AppStorage(UserProfile.Keys.bloodType) private var bloodType = ""
    @AppStorage(UserProfile.Keys.allergies) private var allergies = ""
    @AppStorage(UserProfile.Keys.insurance) private var insurance = ""
    @AppStorage(UserProfile.Keys.emergencyContact) private var emergencyContact = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom (pour les réservations)", text: $name)
                        .textContentType(.name)
                    Picker("Nationalité", selection: $nationality) {
                        ForEach(OfficialSources.nationalities, id: \.code) { Text($0.label).tag($0.code) }
                    }
                    Picker("Ma devise", selection: $baseCurrency) {
                        ForEach(["EUR", "CHF", "CAD", "USD", "GBP"], id: \.self) { Text($0).tag($0) }
                    }
                } header: {
                    Text("Voyageur")
                } footer: {
                    Text("La nationalité détermine les formalités d'entrée (visa…). Baluchon renvoie toujours vers la source officielle.")
                }

                Section {
                    TextField("Groupe sanguin", text: $bloodType)
                    TextField("Allergies", text: $allergies)
                    TextField("Assurance (nom + n° d'assistance)", text: $insurance)
                    TextField("Personne à prévenir (nom + téléphone)", text: $emergencyContact)
                } header: {
                    Text("Urgences — disponibles hors ligne")
                } footer: {
                    Text("Ces informations restent sur ton iPhone et s'affichent dans l'onglet Urgences du mode voyage.")
                }

                Section("Intelligence artificielle") {
                    if AICapabilities.onDeviceModelAvailable {
                        Label("IA Apple embarquée active : analyse plus fine et compagnon de voyage hors ligne", systemImage: "brain")
                    } else {
                        Label("Analyse par mots-clés et OCR (l'IA embarquée demande iOS 26 et un appareil compatible Apple Intelligence)",
                              systemImage: "text.viewfinder")
                    }
                }

                Section("À propos") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                    Text("Baluchon prépare ton voyage de A à Z à partir de tes inspirations.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profil")
        }
    }
}
