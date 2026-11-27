import AVFoundation
import Foundation

/// Lecture à voix haute des phrases préécrites (100 % hors ligne si la voix est installée).
@MainActor
final class SpeechService: ObservableObject {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, language: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice(for: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    static func hasVoice(for language: String) -> Bool {
        let prefix = language.split(separator: "-").first.map(String.init) ?? language
        return AVSpeechSynthesisVoice.speechVoices().contains { $0.language.hasPrefix(prefix) }
    }

    private static func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let prefix = language.split(separator: "-").first.map(String.init) ?? language
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(prefix) }
        return candidates.first { $0.language == language && $0.quality == .enhanced }
            ?? candidates.first { $0.language == language }
            ?? candidates.max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: language)
    }
}
