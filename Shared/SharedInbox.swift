import Foundation

/// Boîte de dépôt partagée entre l'extension de partage et l'app (App Group).
/// L'extension y écrit ce que l'utilisateur partage depuis Instagram, TikTok,
/// Safari, Photos…, et l'app l'importe et l'analyse à son ouverture.
enum SharedInbox {
    static let appGroupID = "group.app.baluchon"

    struct Item: Codable, Identifiable {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var urlString: String?
        var text: String?
        var imageFileName: String?
    }

    static var directory: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(urlString: String?, text: String?, imageData: Data?) throws {
        var item = Item(urlString: urlString, text: text)
        if let imageData {
            let name = "\(item.id.uuidString).jpg"
            try imageData.write(to: directory.appendingPathComponent(name), options: .atomic)
            item.imageFileName = name
        }
        let data = try JSONEncoder().encode(item)
        try data.write(to: directory.appendingPathComponent("\(item.id.uuidString).json"), options: .atomic)
    }

    static func pendingItems() -> [(item: Item, imageData: Data?)] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> (item: Item, imageData: Data?)? in
                guard let data = try? Data(contentsOf: url),
                      let item = try? JSONDecoder().decode(Item.self, from: data) else { return nil }
                let image = item.imageFileName.flatMap { try? Data(contentsOf: directory.appendingPathComponent($0)) }
                return (item, image)
            }
            .sorted { $0.item.createdAt < $1.item.createdAt }
    }

    static func remove(_ item: Item) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(item.id.uuidString).json"))
        if let name = item.imageFileName {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }
}
