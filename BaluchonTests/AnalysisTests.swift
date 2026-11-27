import XCTest
@testable import Baluchon

final class SourceDetectionTests: XCTestCase {
    func testDetectsSocialNetworks() {
        XCTAssertEqual(InspirationSource.detect(urlString: "https://www.instagram.com/p/C1abc/"), .instagram)
        XCTAssertEqual(InspirationSource.detect(urlString: "https://www.facebook.com/share/p/xyz"), .facebook)
        XCTAssertEqual(InspirationSource.detect(urlString: "https://vm.tiktok.com/ZM123/"), .tiktok)
        XCTAssertEqual(InspirationSource.detect(urlString: "https://youtube.com/shorts/abc123"), .youtube)
        XCTAssertEqual(InspirationSource.detect(urlString: "https://youtu.be/abc123"), .youtube)
        XCTAssertEqual(InspirationSource.detect(urlString: "https://www.pinterest.fr/pin/123456/"), .pinterest)
        XCTAssertEqual(InspirationSource.detect(urlString: "https://pin.it/abcd"), .pinterest)
    }

    func testDetectsGoogleMapsAndBlogs() {
        XCTAssertEqual(InspirationSource.detect(urlString: "https://maps.app.goo.gl/abc"), .googleMaps)
        XCTAssertEqual(InspirationSource.detect(urlString: "https://www.google.com/maps/place/Pho+Thin"), .googleMaps)
        XCTAssertEqual(InspirationSource.detect(urlString: "https://monblogvoyage.fr/vietnam-15-jours"), .blog)
        XCTAssertNil(InspirationSource.detect(urlString: nil))
        XCTAssertNil(InspirationSource.detect(urlString: "pas une url"))
    }
}

final class TextNormalizerTests: XCTestCase {
    func testRemovesAccentsAndPunctuation() {
        XCTAssertEqual(TextNormalizer.normalize("Hội An !"), " hoi an ")
        XCTAssertEqual(TextNormalizer.normalize("Đà Nẵng"), " da nang ")
        XCTAssertEqual(TextNormalizer.normalize("L'Alhambra, Grenade"), " l alhambra grenade ")
    }

    func testMatchesWholeWordsAndHashtags() {
        let text = TextNormalizer.normalize("Coucher de soleil #santorinisunset et balade à Hoi An")
        XCTAssertTrue(TextNormalizer.haystack(text, contains: "Santorini"))
        XCTAssertTrue(TextNormalizer.haystack(text, contains: "hội an"))
        XCTAssertFalse(TextNormalizer.haystack(text, contains: "rome"))
    }
}

final class KeywordAnalyzerTests: XCTestCase {
    func testClassifiesVietnamAndFindsBookablePlace() {
        let result = KeywordAnalyzer.analyze(text: "Incroyable journée à Hoi An 🏮 puis croisière dans la baie d'Along #vietnam")
        XCTAssertEqual(result.destinationKey, "vn")
        let cruise = result.places.first { $0.name == "Croisière dans la baie d'Along" }
        XCTAssertNotNil(cruise)
        XCTAssertEqual(cruise?.needsBooking, true)
    }

    func testClassifiesNewYork() {
        let result = KeywordAnalyzer.analyze(text: "Sunset view from Top of the Rock, then dinner at Katz's 🥪 #nyc")
        XCTAssertEqual(result.destinationKey, "nyc")
        let names = result.places.map(\.name)
        XCTAssertTrue(names.contains("Top of the Rock"))
        XCTAssertTrue(names.contains("Katz's Delicatessen"))
    }

    func testReadsPinLinesFromCaptions() {
        let result = KeywordAnalyzer.analyze(text: "Meilleur bun cha de ma vie 😍\n📍 Bun Cha Huong Lien, Hanoi")
        XCTAssertEqual(result.destinationKey, "vn")
        let place = result.places.first { $0.name == "Bun Cha Huong Lien" }
        XCTAssertNotNil(place)
        XCTAssertEqual(place?.city, "Hanoï")
    }

    func testUnknownContentStaysUnclassified() {
        let result = KeywordAnalyzer.analyze(text: "Un super coucher de soleil")
        XCTAssertNil(result.destinationKey)
        XCTAssertTrue(result.places.isEmpty)
    }

    func testHashtagClassifiesGreece() {
        XCTAssertEqual(KeywordAnalyzer.analyze(text: "#santorinisunset 🌅").destinationKey, "gr")
    }

    func testNearestDestinationFromCoordinates() {
        let nearest = KeywordAnalyzer.nearestDestination(latitude: 21.0158, longitude: 105.8553)
        XCTAssertEqual(nearest?.0.key, "vn")
        XCTAssertEqual(nearest?.1.name, "Hanoï")
        XCTAssertNil(KeywordAnalyzer.nearestDestination(latitude: 64.1, longitude: -21.9))
    }

    func testGoogleMapsLinkParsing() throws {
        let url = try XCTUnwrap(URL(string: "https://www.google.com/maps/place/Pho+Thin/@21.0158,105.8553,17z/data=!3m1"))
        let parsed = GoogleMapsLinkParser.parse(url)
        XCTAssertEqual(parsed?.name, "Pho Thin")
        XCTAssertEqual(parsed?.latitude ?? 0, 21.0158, accuracy: 0.0001)
        XCTAssertEqual(parsed?.longitude ?? 0, 105.8553, accuracy: 0.0001)
    }

    func testLinkMetadataParsing() {
        let html = """
        <html><head><title>Fallback</title>
        <meta property="og:title" content="Vietnam en 15 jours" />
        <meta name="description" content="Notre itinéraire"/>
        <meta property="og:description" content="Hanoï, Hoi An &amp; Saigon">
        <meta content="https://example.com/cover.jpg" property="og:image">
        </head></html>
        """
        let metadata = LinkMetadataFetcher.parse(html: html)
        XCTAssertEqual(metadata.title, "Vietnam en 15 jours")
        XCTAssertEqual(metadata.description, "Hanoï, Hoi An & Saigon")
        XCTAssertEqual(metadata.imageURL?.absoluteString, "https://example.com/cover.jpg")
    }
}

final class CatalogTests: XCTestCase {
    func testCatalogIsConsistent() {
        let keys = DestinationCatalog.all.map(\.key)
        XCTAssertEqual(keys.count, Set(keys).count, "Clés de destination en double")
        for destination in DestinationCatalog.all {
            let cities = Set(destination.cities.map(\.name))
            for place in destination.places {
                XCTAssertTrue(cities.contains(place.city), "\(place.name) : ville inconnue \(place.city)")
            }
            XCTAssertFalse(destination.emergency.isEmpty, "\(destination.name) : pas de numéro d'urgence")
            if destination.languageCode != nil {
                XCTAssertEqual(Phrasebook.phrases(for: destination.languageCode).count, Phrasebook.frenchPrompts.count,
                               "\(destination.name) : phrases manquantes")
            }
        }
    }

    func testPhrasebookTablesAreComplete() {
        for prefix in Phrasebook.supportedLanguagePrefixes {
            XCTAssertEqual(Phrasebook.phrases(for: prefix).count, Phrasebook.frenchPrompts.count, prefix)
        }
        XCTAssertTrue(Phrasebook.phrases(for: nil).isEmpty)
    }

    func testPhrasePersonalization() throws {
        let phrase = try XCTUnwrap(Phrasebook.phrases(for: "es-MX").first { $0.id == "reservation" })
        XCTAssertEqual(phrase.personalized(name: "Camille", allergy: "").local, "Tengo una reserva a nombre de Camille")
    }
}
