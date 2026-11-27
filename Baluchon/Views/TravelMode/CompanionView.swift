import SwiftUI

/// Compagnon de voyage : IA embarquée si l'appareil le permet, sinon fiches pratiques.
struct CompanionView: View {
    let trip: Trip

    var body: some View {
        content.navigationTitle("Compagnon")
    }

    @ViewBuilder
    private var content: some View {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if AICapabilities.onDeviceModelAvailable {
                AICompanionView(trip: trip)
            } else {
                OfflineTipsView(trip: trip)
            }
        } else {
            OfflineTipsView(trip: trip)
        }
        #else
        OfflineTipsView(trip: trip)
        #endif
    }

    /// Résumé du voyage donné au compagnon.
    static func context(for trip: Trip) -> String {
        var lines = ["Voyage : \(trip.name), \(trip.totalDays) jours, rythme \(trip.pace.label)."]
        if let destination = trip.destination {
            lines.append("Destination : \(destination.name). Monnaie : \(destination.currencyCode). Langue : \(destination.languageName).")
        }
        lines.append("Étapes : " + trip.sortedStops.map { "\($0.city) (\($0.nights) nuits)" }.joined(separator: ", "))
        for day in ItineraryDays.days(for: trip).prefix(30) {
            lines.append("Jour \(day.index + 1) : " + day.entries.map(\.title).joined(separator: " ; "))
        }
        for booking in trip.bookings {
            lines.append("Réservation \(booking.kind.label) : \(booking.title) \(booking.reference)")
        }
        return lines.joined(separator: "\n")
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
private struct AICompanionView: View {
    @StateObject private var chat: CompanionChat
    @State private var input = ""

    init(trip: Trip) {
        _chat = StateObject(wrappedValue: CompanionChat(tripContext: CompanionView.context(for: trip)))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if chat.messages.isEmpty {
                            Text("Pose-moi une question sur ton voyage : « Qu'est-ce qu'on fait demain ? », « Comment dire merci ? », « Combien de pourboire laisser ? »… Je fonctionne sans réseau.")
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                        ForEach(chat.messages) { message in
                            HStack {
                                if message.fromUser { Spacer(minLength: 40) }
                                Text(message.text)
                                    .padding(12)
                                    .background(message.fromUser ? Color.orange.opacity(0.85) : Color.secondary.opacity(0.15),
                                                in: RoundedRectangle(cornerRadius: 16))
                                    .foregroundStyle(message.fromUser ? Color.white : Color.primary)
                                if !message.fromUser { Spacer(minLength: 40) }
                            }
                            .id(message.id)
                        }
                        if chat.isThinking {
                            ProgressView().padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: chat.messages) { _, messages in
                    if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            HStack {
                TextField("Ta question…", text: $input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                Button {
                    let text = input
                    input = ""
                    Task { await chat.send(text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || chat.isThinking)
            }
            .padding()
            .background(.bar)
        }
    }
}
#endif

/// Repli sans IA : fiches pratiques générées à partir du voyage.
private struct OfflineTipsView: View {
    let trip: Trip

    var body: some View {
        List {
            Section {
                Text("Le compagnon conversationnel utilise l'IA d'Apple directement sur l'iPhone (iOS 26 et appareil compatible Apple Intelligence). En attendant, voici tes fiches pratiques.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if let destination = trip.destination {
                Section("Sur place") {
                    LabeledContent("Monnaie", value: destination.currencyCode)
                    LabeledContent("Langue", value: destination.languageName)
                    LabeledContent("Prises électriques", value: destination.plugTypes)
                }
            }
            Section("Étapes") {
                ForEach(trip.sortedStops) { stop in
                    LabeledContent(stop.city, value: "\(stop.nights) nuit\(stop.nights > 1 ? "s" : "")")
                }
            }
            Section("Réflexes") {
                Label("Garde une copie de ton passeport séparée de l'original", systemImage: "doc.on.doc")
                Label("Retire de l'argent dans les distributeurs des banques, en journée", systemImage: "banknote")
                Label("Les cartes hors ligne fonctionnent sans réseau : pense à les télécharger", systemImage: "map")
                Label("En cas de pépin, l'onglet Urgences contient tous les numéros utiles", systemImage: "cross.case")
            }
        }
    }
}
