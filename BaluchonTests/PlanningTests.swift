import XCTest
@testable import Baluchon

final class TripPlannerTests: XCTestCase {
    private var vietnam: Destination { DestinationCatalog.destination(for: "vn")! }

    private var vietnamPlaces: [PlannerPlace] {
        [
            PlannerPlace(name: "Tunnels de Cu Chi", category: .activity, city: "Hô Chi Minh-Ville"),
            PlannerPlace(name: "Marché Ben Thanh", category: .sight, city: "Saigon"),
            PlannerPlace(name: "Lac Hoan Kiem", category: .sight, city: "Hanoï"),
            PlannerPlace(name: "Temple de la Littérature", category: .sight, city: "Hanoi"),
            PlannerPlace(name: "Train Street", category: .sight, city: "Hanoï"),
            PlannerPlace(name: "Vieille ville", category: .sight, city: "Hoi An"),
            PlannerPlace(name: "Cours de cuisine", category: .activity, city: "Hoi An"),
            PlannerPlace(name: "My Son", category: .sight, city: "Hoi An"),
            PlannerPlace(name: "Croisière baie d'Along", category: .activity, city: "Baie d'Along", leadDays: 21),
            PlannerPlace(name: "Pho Thin", category: .restaurant, city: "Hanoï"),
        ]
    }

    func testDurationAddsUp() {
        for pace in Pace.allCases {
            let plan = TripPlanner.plan(places: vietnamPlaces, destination: vietnam, pace: pace)
            XCTAssertEqual(plan.totalDays, plan.activityDays + plan.transferDays + plan.bufferDays + 1, pace.rawValue)
            XCTAssertEqual(plan.stops.reduce(0) { $0 + $1.nights }, plan.totalNights, pace.rawValue)
        }
    }

    func testChillTripIsLongerThanRushedTrip() {
        let chill = TripPlanner.plan(places: vietnamPlaces, destination: vietnam, pace: .chill)
        let rushed = TripPlanner.plan(places: vietnamPlaces, destination: vietnam, pace: .rushed)
        XCTAssertGreaterThan(chill.totalDays, rushed.totalDays)
    }

    func testCityAliasesAreMergedAndRouteIsLogical() {
        let plan = TripPlanner.plan(places: vietnamPlaces, destination: vietnam, pace: .balanced)
        // « Hanoi » et « Hanoï », « Saigon » et « Hô Chi Minh-Ville » sont fusionnés.
        XCTAssertEqual(plan.stops.map(\.city), ["Hanoï", "Baie d'Along", "Hoi An", "Hô Chi Minh-Ville"])
        XCTAssertEqual(plan.hotelsCount, 4)
    }

    func testPreparationTasks() {
        let plan = TripPlanner.plan(places: vietnamPlaces, destination: vietnam, pace: .balanced)
        let keys = plan.tasks.map(\.key)
        XCTAssertTrue(keys.contains("passport"))
        XCTAssertTrue(keys.contains("entry"))
        XCTAssertTrue(keys.contains("flights"))
        XCTAssertTrue(keys.contains("voice"))
        XCTAssertEqual(keys.filter { $0.hasPrefix("lodging:") }.count, plan.stops.count)
        XCTAssertEqual(keys.filter { $0.hasPrefix("transfer:") }.count, plan.stops.count - 1)
        XCTAssertEqual(keys.filter { $0.hasPrefix("place:") }.count, 1)
        XCTAssertTrue(plan.tasks.filter(\.isBlocking).allSatisfy { ["passport", "entry", "flights"].contains($0.key) })
        XCTAssertEqual(plan.bookingLeadDays, 90)
    }

    func testItineraryCoversEveryPlace() {
        let plan = TripPlanner.plan(places: vietnamPlaces, destination: vietnam, pace: .balanced)
        XCTAssertEqual(plan.entries.first?.dayIndex, 0)
        XCTAssertEqual(plan.entries.first?.slot, .transit)
        XCTAssertEqual(plan.entries.last?.dayIndex, plan.totalDays - 1)
        XCTAssertTrue(plan.entries.last?.title.hasPrefix("Départ") ?? false)
        XCTAssertEqual(plan.entries.compactMap(\.place).count, vietnamPlaces.count)
        XCTAssertTrue(plan.entries.allSatisfy { $0.dayIndex < plan.totalDays })
    }

    func testPlanWithoutCatalogDestination() {
        let places = [PlannerPlace(name: "Musée local", category: .sight, city: nil)]
        let plan = TripPlanner.plan(places: places, destination: nil, pace: .balanced)
        XCTAssertEqual(plan.stops.map(\.city), [TripPlanner.fallbackCityName])
        XCTAssertGreaterThanOrEqual(plan.totalDays, 2)
    }
}

final class ReadinessTests: XCTestCase {
    typealias Input = ReadinessCalculator.TaskInput

    func testEmptyIsZero() {
        XCTAssertEqual(ReadinessCalculator.score(tasks: [], packedRatio: nil), Readiness(percent: 0, blockers: 0))
    }

    func testWeightedScore() {
        let score = ReadinessCalculator.score(tasks: [Input(weight: 10, isDone: false, isBlocking: true),
                                                      Input(weight: 10, isDone: true, isBlocking: false)], packedRatio: nil)
        XCTAssertEqual(score, Readiness(percent: 50, blockers: 1))
    }

    func testBlockersCapTheScore() {
        let score = ReadinessCalculator.score(tasks: [Input(weight: 5, isDone: false, isBlocking: true),
                                                      Input(weight: 95, isDone: true, isBlocking: false)], packedRatio: nil)
        XCTAssertEqual(score.percent, ReadinessCalculator.capWithBlockers)
    }

    func testPackingCounts() {
        let half = ReadinessCalculator.score(tasks: [Input(weight: 10, isDone: true, isBlocking: false)], packedRatio: 0.5)
        XCTAssertEqual(half.percent, 83)
        let full = ReadinessCalculator.score(tasks: [Input(weight: 10, isDone: true, isBlocking: true)], packedRatio: 1)
        XCTAssertEqual(full, Readiness(percent: 100, blockers: 0))
    }
}

final class BookingParserTests: XCTestCase {
    func testFlightFromJSONLD() {
        let email = """
        <html><body>Merci !
        <script type="application/ld+json">
        {"@context":"http://schema.org","@type":"FlightReservation","reservationNumber":"RXJ34P",
         "reservationFor":{"@type":"Flight","flightNumber":"110",
           "airline":{"@type":"Airline","name":"United","iataCode":"UA"},
           "departureAirport":{"@type":"Airport","name":"San Francisco Airport","iataCode":"SFO"},
           "departureTime":"2027-03-04T20:15:00-08:00",
           "arrivalAirport":{"@type":"Airport","name":"John F. Kennedy International Airport","iataCode":"JFK"},
           "arrivalTime":"2027-03-05T06:30:00-05:00"}}
        </script></body></html>
        """
        let booking = BookingParser.parse(email)
        XCTAssertEqual(booking.kind, .flight)
        XCTAssertEqual(booking.reference, "RXJ34P")
        XCTAssertEqual(booking.title, "Vol UA110 SFO → JFK")
        XCTAssertNotNil(booking.startDate)
        XCTAssertNotNil(booking.endDate)
    }

    func testLodgingFromJSONLDGraph() {
        let email = """
        <script type="application/ld+json">
        {"@graph":[{"@type":"Organization","name":"Booking"},
          {"@type":"LodgingReservation","reservationNumber":"4455667788",
           "reservationFor":{"@type":"LodgingBusiness","name":"Hoi An Riverside Villa",
             "address":{"@type":"PostalAddress","streetAddress":"12 Nguyen Du","addressLocality":"Hoi An","addressCountry":"VN"}},
           "checkinDate":"2027-04-01","checkoutDate":"2027-04-04"}]}
        </script>
        """
        let booking = BookingParser.parse(email)
        XCTAssertEqual(booking.kind, .hotel)
        XCTAssertEqual(booking.title, "Hoi An Riverside Villa")
        XCTAssertEqual(booking.reference, "4455667788")
        XCTAssertEqual(booking.location, "12 Nguyen Du, Hoi An, VN")
        XCTAssertNotNil(booking.startDate)
        XCTAssertNotNil(booking.endDate)
    }

    func testHeuristicHotelEmail() {
        let email = """
        Votre réservation à l'Hôtel Riverside est confirmée
        Référence de réservation : HX45PL2
        Arrivée : 12 mars 2027
        Départ : 15 mars 2027
        3 nuits, chambre double
        """
        let booking = BookingParser.parse(email)
        XCTAssertEqual(booking.kind, .hotel)
        XCTAssertEqual(booking.reference, "HX45PL2")
    }

    func testHeuristicFlightEmail() {
        let email = """
        Votre vol AF 123 Paris CDG → Hanoï
        Embarquement à 10:20, porte K42
        Numéro de dossier : QWERTY
        """
        let booking = BookingParser.parse(email)
        XCTAssertEqual(booking.kind, .flight)
        XCTAssertEqual(booking.reference, "QWERTY")
    }

    func testReferencePatterns() {
        XCTAssertEqual(BookingParser.reference(in: "Booking reference: AB12CD"), "AB12CD")
        XCTAssertEqual(BookingParser.reference(in: "Confirmation number: 7781234"), "7781234")
        XCTAssertNil(BookingParser.reference(in: "Merci pour votre réservation, à bientôt"))
    }
}
