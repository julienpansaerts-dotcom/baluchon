import Foundation
import UIKit
import Vision

/// OCR sur l'appareil (framework Vision) : lit le texte des captures d'écran
/// Instagram, TikTok, Pinterest… sans connexion et sans envoyer l'image.
enum TextRecognizer {
    static func recognizeText(in data: Data) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = UIImage(data: data), let cgImage = image.cgImage else {
                    continuation.resume(returning: "")
                    return
                }
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["fr-FR", "en-US", "es-ES", "it-IT", "pt-BR", "de-DE"]
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
                let lines = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
        }
    }
}
