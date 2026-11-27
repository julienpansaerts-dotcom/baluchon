import Foundation
import SwiftData

/// Import et analyse des inspirations : liens, textes, photos, contenus partagés.
@MainActor
enum InspirationPipeline {
    /// Importe ce que l'extension de partage a déposé.
    static func importSharedInbox(into context: ModelContext) async {
        for (item, imageData) in SharedInbox.pendingItems() {
            await add(urlString: item.urlString, text: item.text ?? "", imageData: imageData, into: context)
            SharedInbox.remove(item)
        }
    }

    static func add(urlString: String?, text: String, imageData: Data?, into context: ModelContext) async {
        let cleanURL = urlString?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let source: InspirationSource
        if let detected = InspirationSource.detect(urlString: cleanURL) {
            source = detected
        } else {
            source = imageData != nil ? .photo : .text
        }
        let inspiration = Inspiration(source: source, urlString: cleanURL, text: text, imageData: imageData)
        context.insert(inspiration)
        try? context.save()
        await analyze(inspiration, context: context)
    }

    static func analyze(_ inspiration: Inspiration, context: ModelContext) async {
        var corpus: [String] = [inspiration.title, inspiration.text]
        var mapsHint: GoogleMapsLinkParser.Result?

        if let urlString = inspiration.urlString, let url = URL(string: urlString) {
            let metadata = await LinkMetadataFetcher.fetch(url)
            if let title = metadata.title { corpus.append(title) }
            if let description = metadata.description { corpus.append(description) }
            if inspiration.title.isEmpty {
                inspiration.title = metadata.title ?? url.host ?? urlString
            }
            if inspiration.imageData == nil, let imageURL = metadata.imageURL,
               let fetched = try? await URLSession.shared.data(from: imageURL) {
                inspiration.imageData = fetched.0
            }
            let finalURL = metadata.finalURL ?? url
            corpus.append(finalURL.path.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
                .removingPercentEncoding ?? "")
            if inspiration.source == .googleMaps {
                mapsHint = GoogleMapsLinkParser.parse(finalURL)
                if let name = mapsHint?.name { corpus.append(name) }
            }
        }

        if let data = inspiration.imageData {
            corpus.append(await TextRecognizer.recognizeText(in: data))
        }

        let fullText = corpus.filter { !$0.isEmpty }.joined(separator: "\n")
        var result = KeywordAnalyzer.analyze(text: fullText)

        // Lien Google Maps : on place le lieu grâce à ses coordonnées.
        if let hint = mapsHint, let lat = hint.latitude, let lon = hint.longitude,
           let nearest = KeywordAnalyzer.nearestDestination(latitude: lat, longitude: lon) {
            let (destination, city) = nearest
            if result.destinationKey == nil { result.destinationKey = destination.key }
            if result.destinationKey == destination.key, let name = hint.name {
                let category = KeywordAnalyzer.category(forContext: fullText) ?? .sight
                result.places.insert(DetectedPlace(name: name, category: category, city: city.name,
                                                   latitude: lat, longitude: lon, leadDays: 0), at: 0)
            }
        }

        // IA embarquée (si disponible) : complète la destination et les lieux.
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), OnDeviceAI.isAvailable, !fullText.isEmpty,
           let generated = try? await OnDeviceAI.analyze(text: fullText) {
            merge(generated, into: &result)
        }
        #endif

        inspiration.destinationKey = result.destinationKey
        inspiration.isAnalyzed = true
        if inspiration.title.isEmpty {
            let firstLine = fullText.components(separatedBy: .newlines).first { !$0.isEmpty } ?? "Inspiration"
            inspiration.title = String(firstLine.prefix(80))
        }

        if let key = result.destinationKey {
            insertPlaces(result.places, destinationKey: key, inspirationID: inspiration.id, context: context)
        }
        try? context.save()
    }

    /// Classe manuellement une inspiration « à classer ».
    static func assign(_ inspiration: Inspiration, to destination: Destination, context: ModelContext) async {
        inspiration.destinationKey = destination.key
        let text = [inspiration.title, inspiration.text].joined(separator: "\n")
        let restricted = KeywordAnalyzer.analyze(text: text + "\n" + destination.name, catalog: [destination])
        insertPlaces(restricted.places, destinationKey: destination.key, inspirationID: inspiration.id, context: context)
        try? context.save()
    }

    static func insertPlaces(_ places: [DetectedPlace], destinationKey: String, inspirationID: UUID?, context: ModelContext) {
        let key = destinationKey
        let descriptor = FetchDescriptor<PlaceItem>(predicate: #Predicate { $0.destinationKey == key })
        let existing = (try? context.fetch(descriptor)) ?? []
        var knownNames = Set(existing.map { TextNormalizer.normalize($0.name) })
        for place in places {
            let normalized = TextNormalizer.normalize(place.name)
            guard !knownNames.contains(normalized) else { continue }
            knownNames.insert(normalized)
            context.insert(PlaceItem(name: place.name, category: place.category, city: place.city, destinationKey: key,
                                     latitude: place.latitude, longitude: place.longitude,
                                     needsBooking: place.needsBooking, bookingLeadDays: place.leadDays,
                                     inspirationID: inspirationID))
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func merge(_ generated: GeneratedInspiration, into result: inout AnalysisResult) {
        if result.destinationKey == nil, !generated.destination.isEmpty {
            let hints = ([generated.destination] + generated.places.map(\.city)).joined(separator: " ")
            result.destinationKey = KeywordAnalyzer.destination(named: hints)?.key
        }
        guard let destination = DestinationCatalog.destination(for: result.destinationKey) else { return }
        let known = Set(result.places.map { TextNormalizer.normalize($0.name) })
        for place in generated.places.prefix(10) where !place.name.isEmpty {
            if let catalogPlace = KeywordAnalyzer.catalogPlace(named: place.name, in: destination) {
                guard !known.contains(TextNormalizer.normalize(catalogPlace.name)) else { continue }
                result.places.append(DetectedPlace(name: catalogPlace.name, category: catalogPlace.category, city: catalogPlace.city,
                                                   latitude: catalogPlace.latitude, longitude: catalogPlace.longitude,
                                                   leadDays: catalogPlace.leadDays))
            } else if !known.contains(TextNormalizer.normalize(place.name)) {
                let city = KeywordAnalyzer.city(in: TextNormalizer.normalize(place.city), destination: destination)
                result.places.append(DetectedPlace(name: place.name, category: PlaceCategory(rawValue: place.category) ?? .sight,
                                                   city: city?.name ?? place.city.nilIfEmpty,
                                                   latitude: nil, longitude: nil, leadDays: 0))
            }
        }
    }
    #endif
}
