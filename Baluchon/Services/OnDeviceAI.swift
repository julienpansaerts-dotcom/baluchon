import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Analyse par le modèle de langage d'Apple, sur l'appareil (iOS 26+, appareils
/// compatibles Apple Intelligence) : gratuit, privé et hors ligne.
@available(iOS 26.0, *)
@Generable
struct GeneratedInspiration {
    @Guide(description: "Pays ou grande ville de destination principale, en français. Chaîne vide si inconnu.")
    var destination: String

    @Guide(description: "Lieux concrets cités : restaurants, sites, activités, plages, hôtels. Maximum 10.")
    var places: [GeneratedPlace]
}

@available(iOS 26.0, *)
@Generable
struct GeneratedPlace {
    @Guide(description: "Nom exact du lieu")
    var name: String

    @Guide(description: "Ville où se trouve le lieu, chaîne vide si inconnue")
    var city: String

    @Guide(description: "Catégorie, exactement un mot parmi : sight, activity, nature, restaurant, nightlife, shopping, hotel")
    var category: String
}

@available(iOS 26.0, *)
enum OnDeviceAI {
    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    static func analyze(text: String) async throws -> GeneratedInspiration {
        let session = LanguageModelSession(instructions: """
            Tu analyses des contenus de voyage (légendes Instagram ou TikTok, épingles Pinterest, articles de blog, \
            texte extrait de captures d'écran). Tu identifies la destination et les lieux concrets à visiter. \
            N'invente jamais de lieu absent du texte.
            """)
        let prompt = "Contenu à analyser :\n\(String(text.prefix(3500)))"
        let response = try await session.respond(to: prompt, generating: GeneratedInspiration.self)
        return response.content
    }
}

/// Compagnon de voyage conversationnel, entièrement hors ligne.
@available(iOS 26.0, *)
@MainActor
final class CompanionChat: ObservableObject {
    struct Message: Identifiable, Equatable {
        let id = UUID()
        let fromUser: Bool
        let text: String
    }

    @Published var messages: [Message] = []
    @Published var isThinking = false
    private let session: LanguageModelSession

    init(tripContext: String) {
        session = LanguageModelSession(instructions: """
            Tu es Baluchon, un compagnon de voyage bienveillant qui répond en français, de façon brève et pratique. \
            Tu fonctionnes hors ligne : si on te demande une information en temps réel (horaires du jour, météo), \
            dis-le honnêtement et propose une alternative. Voici le voyage de l'utilisateur :
            \(tripContext)
            """)
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }
        messages.append(Message(fromUser: true, text: trimmed))
        isThinking = true
        defer { isThinking = false }
        do {
            let response = try await session.respond(to: trimmed)
            messages.append(Message(fromUser: false, text: response.content))
        } catch {
            messages.append(Message(fromUser: false, text: "Désolé, je n'ai pas pu répondre (\(error.localizedDescription))."))
        }
    }
}
#endif

/// Indique si l'IA embarquée est utilisable sur cet appareil.
enum AICapabilities {
    static var onDeviceModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return OnDeviceAI.isAvailable
        }
        #endif
        return false
    }
}
