import SwiftUI

/// Le passeport du voyageur : sert aux formalités (nationalité), aux phrases et aux urgences.
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
                    PassportPage(name: name, nationality: nationality, bloodType: bloodType)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                }

                Section {
                    LabeledField(label: "Nom", placeholder: "Pour les réservations", text: $name)
                        .cardRow()
                    Picker(selection: $nationality) {
                        ForEach(OfficialSources.nationalities, id: \.code) { Text($0.label).tag($0.code) }
                    } label: {
                        Text("Nationalité").font(.display(16))
                    }
                    .cardRow()
                    Picker(selection: $baseCurrency) {
                        ForEach(["EUR", "CHF", "CAD", "USD", "GBP"], id: \.self) { Text($0).tag($0) }
                    } label: {
                        Text("Ma devise").font(.display(16))
                    }
                    .cardRow()
                } header: {
                    SectionLabel("Voyageur")
                } footer: {
                    Text("La nationalité détermine les formalités d'entrée (visa…). Baluchon renvoie toujours vers la source officielle.")
                }

                Section {
                    LabeledField(label: "Groupe sanguin", placeholder: "Ex. : A+", text: $bloodType).cardRow()
                    LabeledField(label: "Allergies", placeholder: "Ex. : arachides", text: $allergies).cardRow()
                    LabeledField(label: "Assurance", placeholder: "Nom + n° d'assistance", text: $insurance, vertical: true).cardRow()
                    LabeledField(label: "Personne à prévenir", placeholder: "Nom + téléphone", text: $emergencyContact, vertical: true).cardRow()
                } header: {
                    SectionLabel("Urgences · disponibles hors ligne")
                } footer: {
                    Text("Ces informations restent sur ton iPhone et s'affichent dans l'onglet Urgences du mode voyage.")
                }

                Section {
                    Text(AICapabilities.onDeviceModelAvailable
                         ? "L'IA d'Apple tourne sur ton iPhone : analyse plus fine des contenus et compagnon de voyage hors ligne."
                         : "Analyse par mots-clés et lecture des captures (OCR). L'IA embarquée demande iOS 26 et un appareil compatible Apple Intelligence.")
                        .font(.callout)
                        .foregroundStyle(Theme.ink)
                        .cardRow()
                } header: {
                    SectionLabel("Analyse des contenus")
                }

                Section {
                    HStack {
                        Text("Version").foregroundStyle(Theme.inkSoft)
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                            .font(.ticket(13, weight: .semibold))
                    }
                    .cardRow()
                }
            }
            .paperBackground()
            .navigationTitle("Passeport")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Page d'identité façon passeport, avec sa bande lisible par machine.
private struct PassportPage: View {
    let name: String
    let nationality: String
    let bloodType: String

    private var nationalityCode: String {
        ["FR": "FRA", "BE": "BEL", "CH": "CHE", "CA": "CAN", "LU": "LUX"][nationality] ?? "XXX"
    }

    private var machineLine: String {
        let parts = TextNormalizer.normalize(name).split(separator: " ").map { $0.uppercased() }
        let surname = parts.last ?? "VOYAGEUR"
        let given = parts.dropLast().joined(separator: "<")
        let line = "P<\(nationalityCode)\(surname)<<\(given)"
        return String((line + String(repeating: "<", count: 44)).prefix(44))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PASSEPORT · PASSPORT")
                    .font(.ticket(10, weight: .bold)).tracking(2)
                Spacer()
                Text("BALUCHON").font(.ticket(10, weight: .bold)).tracking(2)
            }
            .foregroundStyle(Theme.card.opacity(0.85))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.ink)

            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(Theme.rule)
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.inkSoft.opacity(0.5))
                }
                .frame(width: 78, height: 98)
                .overlay(alignment: .bottomTrailing) {
                    StampMark(size: 34, color: Theme.stamp.opacity(0.75))
                        .offset(x: 14, y: 10)
                }

                VStack(alignment: .leading, spacing: 9) {
                    field("Nom / Name", name.isEmpty ? "—" : name)
                    HStack(spacing: 18) {
                        field("Nationalité", nationalityCode)
                        field("Groupe", bloodType.isEmpty ? "—" : bloodType)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)

            Text(machineLine)
                .font(.ticket(11.5, weight: .medium))
                .foregroundStyle(Theme.ink.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.rule))
        .padding(.horizontal, 4)
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.ticket(9, weight: .semibold)).foregroundStyle(Theme.inkSoft)
            Text(value).font(.display(18, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
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
                Text(label.uppercased()).font(.ticket(10, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                TextField(placeholder, text: $text).font(.display(16)).foregroundStyle(Theme.ink)
            }
        } else {
            HStack {
                Text(label).font(.display(16)).foregroundStyle(Theme.ink)
                Spacer(minLength: 16)
                TextField(placeholder, text: $text)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }
}
