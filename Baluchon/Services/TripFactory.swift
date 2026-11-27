import Foundation
import SwiftData

/// Crée un voyage complet (étapes, déroulé, tâches, valise) à partir du plan calculé.
@MainActor
enum TripFactory {
    static func plannerPlaces(from items: [PlaceItem]) -> [PlannerPlace] {
        items.map {
            PlannerPlace(id: $0.id, name: $0.name, category: $0.category, city: $0.city,
                         latitude: $0.latitude, longitude: $0.longitude, leadDays: $0.needsBooking ? max($0.bookingLeadDays, 1) : 0)
        }
    }

    @discardableResult
    static func createTrip(name: String, destinationKey: String, places: [PlaceItem], pace: Pace, startDate: Date?,
                           travelers: Int, profile: UserProfile, context: ModelContext) -> Trip {
        let destination = DestinationCatalog.destination(for: destinationKey)
        let plan = TripPlanner.plan(places: plannerPlaces(from: places), destination: destination, pace: pace, nationality: profile.nationality)

        let trip = Trip(name: name, destinationKey: destinationKey, startDate: startDate, pace: pace, travelers: travelers,
                        totalDays: plan.totalDays, bookingLeadDays: plan.bookingLeadDays, baseCurrency: profile.baseCurrency)
        context.insert(trip)

        for (index, stop) in plan.stops.enumerated() {
            let model = TripStop(city: stop.city, nights: stop.nights, order: index, latitude: stop.latitude, longitude: stop.longitude)
            context.insert(model)
            model.trip = trip
        }
        for (index, entry) in plan.entries.enumerated() {
            let model = ItineraryEntry(dayIndex: entry.dayIndex, slot: entry.slot, order: index, title: entry.title, city: entry.city,
                                       category: entry.place?.category, latitude: entry.place?.latitude, longitude: entry.place?.longitude)
            context.insert(model)
            model.trip = trip
        }
        for (index, task) in plan.tasks.enumerated() {
            let model = PrepTask(key: task.key, title: task.title, detail: task.detail, category: task.category, weight: task.weight,
                                 isBlocking: task.isBlocking, leadDays: task.leadDays, linkString: task.link, order: index)
            context.insert(model)
            model.trip = trip
        }
        for (index, item) in PackingList.items(for: destination).enumerated() {
            let model = PackingItem(name: item.name, group: item.group, order: index)
            context.insert(model)
            model.trip = trip
        }
        try? context.save()
        return trip
    }

    /// Coche automatiquement les tâches couvertes par une réservation ajoutée.
    static func applyBooking(_ booking: Booking, to trip: Trip) {
        let haystack = TextNormalizer.normalize([booking.title, booking.location, booking.rawText].joined(separator: " "))
        let pending = trip.tasks.filter { !$0.isDone }
        var matched: PrepTask?
        switch booking.kind {
        case .flight:
            matched = pending.first(where: { $0.key == "flights" })
        case .hotel:
            let lodging = pending.filter { $0.key.hasPrefix("lodging:") }
            matched = lodging.first(where: { task in
                let city = String(task.key.dropFirst("lodging:".count))
                return cityMatches(city, in: haystack, destination: trip.destination)
            })
            if matched == nil, lodging.count == 1 { matched = lodging.first }
        case .train, .bus, .car:
            matched = pending.first(where: { task in
                guard task.key.hasPrefix("transfer:"), let arrow = task.key.range(of: ">") else { return false }
                let city = String(task.key[arrow.upperBound...])
                return cityMatches(city, in: haystack, destination: trip.destination)
            })
        case .activity, .restaurant, .other:
            matched = pending.first(where: { task in
                guard task.key.hasPrefix("place:") else { return false }
                let name = task.title.replacingOccurrences(of: "Réserver : ", with: "")
                return TextNormalizer.haystack(haystack, contains: name)
            })
        }
        matched?.isDone = true
    }

    private static func cityMatches(_ city: String, in haystack: String, destination: Destination?) -> Bool {
        let aliases = destination?.cities.first { $0.name == city }?.aliases ?? []
        return ([city] + aliases).contains { TextNormalizer.haystack(haystack, contains: $0) }
    }
}

enum PackingList {
    struct Item {
        let name: String
        let group: String
    }

    static func items(for destination: Destination?) -> [Item] {
        var items: [Item] = [
            Item(name: "Passeport", group: "Papiers"),
            Item(name: "Copies papier et numériques des documents", group: "Papiers"),
            Item(name: "Carte bancaire + carte de secours", group: "Papiers"),
            Item(name: "Attestation d'assurance voyage", group: "Papiers"),
            Item(name: "Chargeur de téléphone", group: "Électronique"),
            Item(name: "Batterie externe", group: "Électronique"),
            Item(name: "Écouteurs", group: "Électronique"),
            Item(name: "Trousse à pharmacie (médicaments habituels, pansements, antidouleur)", group: "Santé"),
            Item(name: "Trousse de toilette", group: "Santé"),
            Item(name: "Vêtements pour \(destination == nil ? "le séjour" : "chaque jour + 1 tenue de rechange")", group: "Vêtements"),
            Item(name: "Chaussures confortables pour marcher", group: "Vêtements"),
            Item(name: "Petit sac à dos pour la journée", group: "Divers"),
            Item(name: "Gourde", group: "Divers"),
        ]
        if let destination {
            items.append(Item(name: "Adaptateur électrique (prises \(destination.plugTypes))", group: "Électronique"))
            if destination.isTropical {
                items += [
                    Item(name: "Répulsif anti-moustiques (zones tropicales)", group: "Santé"),
                    Item(name: "Crème solaire indice élevé", group: "Santé"),
                    Item(name: "Vêtements légers à manches longues", group: "Vêtements"),
                    Item(name: "K-way / poncho de pluie", group: "Vêtements"),
                ]
            } else {
                items.append(Item(name: "Crème solaire", group: "Santé"))
            }
        }
        return items
    }
}
