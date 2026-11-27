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
                    LabeledField(label: "Nom", placeholder: "Pour les réservations", text: $name)
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
                    LabeledField(label: "Groupe sanguin", placeholder: "Ex. : A+", text: $bloodType)
                    LabeledField(label: "Allergies", placeholder: "Ex. : arachides", text: $allergies)
                    LabeledField(label: "Assurance", placeholder: "Nom + n° d'assistance", text: $insurance, vertical: true)
                    LabeledField(label: "Personne à prévenir", placeholder: "Nom + téléphone", text: $emergencyContact, vertical: true)
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

/// Champ de formulaire avec son intitulé toujours visible.
private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var vertical = false

    var body: some View {
        if vertical {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                TextField(placeholder, text: $text)
            }
        } else {
            HStack {
                Text(label)
                Spacer(minLength: 16)
                TextField(placeholder, text: $text)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
