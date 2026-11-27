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
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if chat.messages.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Demande-moi ce que tu veux sur ton voyage.")
                                    .font(.display(20, weight: .semibold)).foregroundStyle(.white)
                                ForEach(["Qu'est-ce qu'on fait demain ?", "Comment dire merci ?", "Faut-il laisser un pourboire ?"], id: \.self) { idea in
                                    Button(idea) { Task { await chat.send(idea) } }
                                        .buttonStyle(InkButtonStyle(color: Theme.amber))
                                }
                                Text("Je fonctionne sans réseau, directement sur ton iPhone.")
                                    .font(.ticket(10)).foregroundStyle(.white.opacity(0.5))
                            }
                            .padding(.vertical, 8)
                        }
                        ForEach(chat.messages) { message in
                            HStack {
                                if message.fromUser { Spacer(minLength: 48) }
                                Text(message.text)
                                    .font(message.fromUser ? Font.body : Font.display(17))
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: 6)
                                        .fill(message.fromUser ? Theme.amber : Theme.boardTile))
                                    .foregroundStyle(message.fromUser ? Theme.board : Color.white)
                                if !message.fromUser { Spacer(minLength: 48) }
                            }
                            .id(message.id)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if chat.isThinking {
                            SplitFlapText(text: "...", size: 16).padding(.horizontal, 4)
                        }
                    }
                    .padding()
                    .animation(.snappy, value: chat.messages)
                }
                .onChange(of: chat.messages) { _, messages in
                    if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            HStack(spacing: 10) {
                TextField("Ta question…", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.boardTile))
                Button {
                    let text = input
                    input = ""
                    Task { await chat.send(text) }
                } label: {
                    Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.board)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.amber))
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || chat.isThinking)
            }
            .padding()
        }
        .background(Theme.board.ignoresSafeArea())
    }
}
#endif

/// Repli sans IA : fiches pratiques générées à partir du voyage.
private struct OfflineTipsView: View {
    let trip: Trip

    var body: some View {
        List {
            Section {
                Text("Le compagnon qui répond à tes questions utilise l'IA d'Apple directement sur l'iPhone (iOS 26 et appareil compatible Apple Intelligence). En attendant, voici tes fiches pratiques.")
                    .font(.callout).foregroundStyle(.white.opacity(0.75))
                    .listRowBackground(Color.clear)
            }
            if let destination = trip.destination {
                Section {
                    fact("Monnaie", destination.currencyCode)
                    fact("Langue", destination.languageName)
                    fact("Prises électriques", destination.plugTypes)
                } header: {
                    SectionLabel("Sur place", color: Theme.amber.opacity(0.8))
                }
            }
            Section {
                ForEach(trip.sortedStops) { stop in
                    fact(stop.city, "\(stop.nights) N")
                }
            } header: {
                SectionLabel("Étapes", color: Theme.amber.opacity(0.8))
            }
            Section {
                tip("Garde une copie de ton passeport séparée de l'original.")
                tip("Retire de l'argent aux distributeurs des banques, en journée.")
                tip("Les cartes téléchargées fonctionnent sans réseau.")
                tip("En cas de pépin, l'onglet Urgences contient tous les numéros utiles.")
            } header: {
                SectionLabel("Réflexes", color: Theme.amber.opacity(0.8))
            }
        }
        .boardBackground()
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.display(16)).foregroundStyle(.white)
            Spacer()
            Text(value).font(.ticket(13, weight: .bold)).foregroundStyle(Theme.amber).multilineTextAlignment(.trailing)
        }
        .boardRow()
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("—").font(.ticket(14, weight: .bold)).foregroundStyle(Theme.amber)
            Text(text).font(.callout).foregroundStyle(.white.opacity(0.9))
        }
        .boardRow()
    }
}
