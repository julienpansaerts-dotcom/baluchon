import Foundation
import SwiftData

/// Données de démonstration, chargées en mémoire quand l'app est lancée avec
/// l'argument `-demoData` (tests UI, captures d'écran, démos).
@MainActor
enum DemoData {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-demoData") }

    static func seed(into context: ModelContext) {
        seedProfile()
        seedInspirations(into: context)
        seedJapanTrip(into: context)
        try? context.save()
    }

    private static func seedProfile() {
        let defaults = UserDefaults.standard
        defaults.set("Camille Martin", forKey: UserProfile.Keys.name)
        defaults.set("FR", forKey: UserProfile.Keys.nationality)
        defaults.set("EUR", forKey: UserProfile.Keys.baseCurrency)
        defaults.set("O+", forKey: UserProfile.Keys.bloodType)
        defaults.set("arachides", forKey: UserProfile.Keys.allergies)
        defaults.set("Assur'Voyage — +33 1 23 45 67 89", forKey: UserProfile.Keys.insurance)
        defaults.set("Alex — +33 6 12 34 56 78", forKey: UserProfile.Keys.emergencyContact)
    }

    private static func seedInspirations(into context: ModelContext) {
        let sources: [(InspirationSource, String, String?)] = [
            (.instagram, "Croisière magique dans la baie d'Along 🌊", "vn"),
            (.tiktok, "Street food à Hanoï : le meilleur bun cha", "vn"),
            (.pinterest, "Hoi An by night, les lanternes 🏮", "vn"),
            (.blog, "Vietnam : itinéraire de 3 semaines du nord au sud", "vn"),
            (.youtube, "NYC en 4 jours — tous les spots", "nyc"),
            (.instagram, "Sunset depuis Top of the Rock", "nyc"),
            (.googleMaps, "Fushimi Inari Taisha", "jp"),
            (.photo, "Coucher de soleil", nil),
        ]
        for (index, (source, title, key)) in sources.enumerated() {
            let inspiration = Inspiration(source: source, urlString: nil, title: title, text: title)
            inspiration.destinationKey = key
            inspiration.isAnalyzed = true
            inspiration.createdAt = Date().addingTimeInterval(Double(-index) * 3600)
            context.insert(inspiration)
        }

        let decisions: [(String, String, Decision)] = [
            ("vn", "Lac Hoan Kiem", .yes),
            ("vn", "Croisière dans la baie d'Along", .yes),
            ("vn", "Tam Coc", .yes),
            ("vn", "Vieille ville de Hoi An", .yes),
            ("vn", "Cité impériale de Hué", .yes),
            ("vn", "Tunnels de Cu Chi", .pending),
            ("vn", "Train Street", .pending),
            ("vn", "Rizières de Sapa", .no),
            ("nyc", "Top of the Rock", .yes),
            ("nyc", "Central Park", .pending),
            ("nyc", "Katz's Delicatessen", .pending),
            ("nyc", "MoMA", .pending),
        ]
        for (key, name, decision) in decisions {
            guard let destination = DestinationCatalog.destination(for: key),
                  let place = destination.places.first(where: { $0.name == name }) else { continue }
            let item = PlaceItem(name: place.name, category: place.category, city: place.city, destinationKey: key,
                                 latitude: place.latitude, longitude: place.longitude,
                                 needsBooking: place.needsBooking, bookingLeadDays: place.leadDays)
            item.decision = decision
            context.insert(item)
        }
        let custom: [(String, PlaceCategory, String, Decision)] = [
            ("Bun Cha Huong Lien", .restaurant, "Hanoï", .pending),
            ("Banh Mi Phuong", .restaurant, "Hoi An", .yes),
            ("Cours de cuisine à Hoi An", .activity, "Hoi An", .yes),
        ]
        for (name, category, city, decision) in custom {
            let item = PlaceItem(name: name, category: category, city: city, destinationKey: "vn")
            item.decision = decision
            context.insert(item)
        }
    }

    private static func seedJapanTrip(into context: ModelContext) {
        guard let japan = DestinationCatalog.destination(for: "jp") else { return }
        let names = ["Carrefour de Shibuya", "Temple Senso-ji", "teamLab Planets", "Fushimi Inari",
                     "Kinkaku-ji (Pavillon d'or)", "Bambouseraie d'Arashiyama", "Parc de Nara", "Dotonbori"]
        let items: [PlaceItem] = names.compactMap { name in
            guard let place = japan.places.first(where: { $0.name == name }) else { return nil }
            let item = PlaceItem(name: place.name, category: place.category, city: place.city, destinationKey: "jp",
                                 latitude: place.latitude, longitude: place.longitude,
                                 needsBooking: place.needsBooking, bookingLeadDays: place.leadDays)
            item.decision = .yes
            context.insert(item)
            return item
        }

        let start = Calendar.current.startOfDay(for: Date())
        let trip = TripFactory.createTrip(name: "Japon au printemps", destinationKey: "jp", places: items,
                                          pace: .balanced, startDate: start, travelers: 2,
                                          profile: UserProfile.current, context: context)

        let doneKeys: Set<String> = ["passport", "entry", "health", "insurance", "flights", "money", "esim", "offlineMaps"]
        for task in trip.tasks where doneKeys.contains(task.key) || task.key.hasPrefix("lodging:") || task.key.hasPrefix("place:") {
            task.isDone = true
        }
        for item in trip.packing.sorted(by: { $0.order < $1.order }).prefix(9) {
            item.isPacked = true
        }

        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: start) ?? start
            return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        let bookings: [Booking] = [
            Booking(kind: .flight, title: "Vol AF276 CDG → HND", reference: "QX7P2L", startDate: at(0, 7, 15), endDate: at(0, 9, 50),
                    location: "Aéroport de Tokyo-Haneda", rawText: ""),
            Booking(kind: .hotel, title: "Hotel Gracery Shinjuku", reference: "4482019377", startDate: at(0, 15), endDate: at(4, 11),
                    location: "1-19-1 Kabukicho, Shinjuku, Tokyo", rawText: ""),
            Booking(kind: .activity, title: "teamLab Planets — entrée 10:00", reference: "TLP-88231", startDate: at(1, 10), endDate: nil,
                    location: "6-1-16 Toyosu, Koto, Tokyo", rawText: ""),
            Booking(kind: .train, title: "Shinkansen Nozomi Tokyo → Kyoto", reference: "JR-5521", startDate: at(4, 9, 30), endDate: at(4, 11, 45),
                    location: "Gare de Tokyo", rawText: ""),
        ]
        for booking in bookings {
            context.insert(booking)
            booking.trip = trip
        }
        trip.cachedRate = 162.4
        trip.cachedRateDate = Date()
    }
}
