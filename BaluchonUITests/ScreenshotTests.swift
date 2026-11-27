import XCTest

/// Parcourt l'app avec les données de démonstration et prend une capture de chaque écran.
/// Les captures sont extraites du résultat de test par la CI (artefact « screenshots »).
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-demoData", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
    }

    func testCaptureAllScreens() {
        // 1. Inspirations (tuiles)
        XCTAssertTrue(app.buttons["tile-vn"].waitForExistence(timeout: 15), "Tuile Vietnam absente")
        snapshot("01-inspirations")

        // 2. Détail d'une tuile : tri oui / non
        app.buttons["tile-vn"].tap()
        XCTAssertTrue(app.buttons["launch-project"].waitForExistence(timeout: 10))
        snapshot("02-destination")
        app.swipeUp()
        snapshot("03-destination-suite")

        // 3. Lancer le projet
        app.buttons["launch-project"].tap()
        XCTAssertTrue(app.buttons["confirm-launch"].waitForExistence(timeout: 10))
        pause(1)
        snapshot("04-lancer-le-projet")
        app.buttons["confirm-launch"].tap()
        XCTAssertTrue(app.staticTexts["IDÉE"].waitForExistence(timeout: 10), "Tableau de bord non affiché")
        pause(1)
        snapshot("05-tableau-de-bord-nouveau")

        // 4. Profil
        app.tabBars.buttons["Passeport"].tap()
        pause(1)
        snapshot("06-profil")

        // 5. Voyages → voyage au Japon (données de démo)
        app.tabBars.buttons["Voyages"].tap()
        pause(1)
        snapshot("07-mes-voyages")
        let japan = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Japon'")).firstMatch
        XCTAssertTrue(japan.waitForExistence(timeout: 10))
        japan.tap()
        pause(1)
        snapshot("08-tableau-de-bord-japon")

        openRow("Plan de préparation", snapshot: "09-plan-de-preparation")
        openRow("Itinéraire jour par jour", snapshot: "10-itineraire")
        openRow("Réservations", snapshot: "11-reservations")
        openRow("Valise", snapshot: "12-valise")

        // 6. Mode voyage
        let travelButton = app.buttons["travel-mode-button"]
        scrollTo(travelButton)
        travelButton.tap()
        XCTAssertTrue(app.buttons["activate-travel-mode"].waitForExistence(timeout: 10))
        pause(3)
        snapshot("13-avant-le-depart")
        app.buttons["activate-travel-mode"].tap()
        if app.staticTexts["DÉPARTS"].waitForExistence(timeout: 15) {
            snapshot("14-bon-voyage")
        }
        XCTAssertTrue(app.tabBars.buttons["Phrases"].waitForExistence(timeout: 15))
        pause(9)
        snapshot("15-mode-voyage-aujourdhui")

        for (tab, name) in [("Phrases", "16-phrases"), ("Argent", "17-convertisseur"),
                            ("Compagnon", "18-compagnon"), ("Urgences", "19-urgences")] {
            app.tabBars.buttons[tab].tap()
            pause(1)
            snapshot(name)
        }
    }

    // MARK: - Outils

    private func openRow(_ label: String, snapshot name: String) {
        let row = app.staticTexts[label].firstMatch
        scrollTo(row)
        guard row.exists else {
            XCTFail("Ligne « \(label) » introuvable")
            return
        }
        row.tap()
        pause(1)
        snapshot(name)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        pause(1)
    }

    private func scrollTo(_ element: XCUIElement) {
        var attempts = 0
        while !(element.exists && element.isHittable) && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
