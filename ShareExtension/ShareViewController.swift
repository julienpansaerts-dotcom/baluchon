import UIKit
import UniformTypeIdentifiers

/// Extension « Partager vers Baluchon » : reçoit un lien (Instagram, TikTok,
/// YouTube, Pinterest, Facebook, Google Maps, blog), du texte ou des images
/// et les dépose dans la boîte partagée. L'analyse est faite par l'app.
final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .large)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        statusLabel.text = "Ajout à Baluchon…"
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [spinner, statusLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
        ])
        spinner.startAnimating()

        Task { await handleSharedItems() }
    }

    private func handleSharedItems() async {
        let extensionItems = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        var sharedURL: String?
        var texts: [String] = []
        var images: [Data] = []

        for item in extensionItems {
            if let text = item.attributedContentText?.string, !text.isEmpty {
                texts.append(text)
            }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
                       let url = loaded as? URL {
                        if url.isFileURL, let data = try? Data(contentsOf: url), let image = Self.downscaled(data) {
                            images.append(image)
                        } else if !url.isFileURL {
                            sharedURL = url.absoluteString
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    if let data = await Self.loadImageData(from: provider) {
                        images.append(data)
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
                       let text = loaded as? String {
                        texts.append(text)
                    }
                }
            }
        }

        let joinedText = texts.joined(separator: "\n")
        if sharedURL == nil { sharedURL = Self.firstURL(in: joinedText) }

        var saved = 0
        if sharedURL != nil || !joinedText.isEmpty {
            if (try? SharedInbox.save(urlString: sharedURL, text: joinedText, imageData: nil)) != nil { saved += 1 }
        }
        for image in images {
            if (try? SharedInbox.save(urlString: nil, text: joinedText.isEmpty ? nil : joinedText, imageData: image)) != nil {
                saved += 1
            }
        }

        spinner.stopAnimating()
        statusLabel.text = saved > 0
            ? "✅ Ajouté à Baluchon !\nOuvre l'app pour voir l'analyse."
            : "Rien à importer ici 🤔"
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private static func loadImageData(from provider: NSItemProvider) async -> Data? {
        guard let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier) else { return nil }
        if let url = loaded as? URL, let data = try? Data(contentsOf: url) { return downscaled(data) }
        if let image = loaded as? UIImage { return downscaled(image) }
        if let data = loaded as? Data { return downscaled(data) }
        return nil
    }

    private static func downscaled(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return downscaled(image)
    }

    /// Réduit l'image (mémoire limitée dans une extension) et la compresse en JPEG.
    private static func downscaled(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 2048
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height, 1))
        guard scale < 1 else { return image.jpegData(compressionQuality: 0.8) }
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    private static func firstURL(in text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return detector.firstMatch(in: text, options: [], range: range)?.url?.absoluteString
    }
}
