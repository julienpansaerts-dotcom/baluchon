import Foundation
import SwiftData

/// Un contenu envoyé par l'utilisateur : post Instagram, vidéo TikTok, épingle
/// Pinterest, lien Google Maps, article de blog, capture d'écran…
@Model
final class Inspiration {
    var id: UUID
    var createdAt: Date
    var sourceRaw: String
    var urlString: String?
    var title: String
    var text: String
    @Attribute(.externalStorage) var imageData: Data?
    /// Clé de destination du catalogue (`nil` = pas encore classée).
    var destinationKey: String?
    var isAnalyzed: Bool

    init(source: InspirationSource, urlString: String? = nil, title: String = "", text: String = "", imageData: Data? = nil) {
        self.id = UUID()
        self.createdAt = Date()
        self.sourceRaw = source.rawValue
        self.urlString = urlString
        self.title = title
        self.text = text
        self.imageData = imageData
        self.destinationKey = nil
        self.isAnalyzed = false
    }

    var source: InspirationSource { InspirationSource(rawValue: sourceRaw) ?? .text }
}

/// Un élément détecté (restaurant, site, activité…) que l'utilisateur garde ou écarte.
@Model
final class PlaceItem {
    var id: UUID
    var name: String
    var categoryRaw: String
    var city: String?
    var destinationKey: String
    var latitude: Double?
    var longitude: Double?
    var decisionRaw: String
    var needsBooking: Bool
    var bookingLeadDays: Int
    var note: String
    var inspirationID: UUID?
    var createdAt: Date

    init(name: String, category: PlaceCategory, city: String?, destinationKey: String,
         latitude: Double? = nil, longitude: Double? = nil,
         needsBooking: Bool = false, bookingLeadDays: Int = 0, inspirationID: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.categoryRaw = category.rawValue
        self.city = city
        self.destinationKey = destinationKey
        self.latitude = latitude
        self.longitude = longitude
        self.decisionRaw = Decision.pending.rawValue
        self.needsBooking = needsBooking
        self.bookingLeadDays = bookingLeadDays
        self.note = ""
        self.inspirationID = inspirationID
        self.createdAt = Date()
    }

    var category: PlaceCategory {
        get { PlaceCategory(rawValue: categoryRaw) ?? .sight }
        set { categoryRaw = newValue.rawValue }
    }

    var decision: Decision {
        get { Decision(rawValue: decisionRaw) ?? .pending }
        set { decisionRaw = newValue.rawValue }
    }
}

/// Un projet de voyage lancé à partir d'une destination.
@Model
final class Trip {
    var id: UUID
    var name: String
    var destinationKey: String
    var createdAt: Date
    var startDate: Date?
    var paceRaw: String
    var travelers: Int
    var totalDays: Int
    var bookingLeadDays: Int
    var isTravelModeActive: Bool
    /// Taux de change mis en cache pour le mode hors ligne : 1 devise de base = `cachedRate` devise locale.
    var cachedRate: Double?
    var cachedRateDate: Date?
    var baseCurrency: String

    @Relationship(deleteRule: .cascade, inverse: \PrepTask.trip) var tasks: [PrepTask] = []
    @Relationship(deleteRule: .cascade, inverse: \Booking.trip) var bookings: [Booking] = []
    @Relationship(deleteRule: .cascade, inverse: \PackingItem.trip) var packing: [PackingItem] = []
    @Relationship(deleteRule: .cascade, inverse: \TripStop.trip) var stops: [TripStop] = []
    @Relationship(deleteRule: .cascade, inverse: \ItineraryEntry.trip) var itinerary: [ItineraryEntry] = []

    init(name: String, destinationKey: String, startDate: Date?, pace: Pace, travelers: Int,
         totalDays: Int, bookingLeadDays: Int, baseCurrency: String) {
        self.id = UUID()
        self.name = name
        self.destinationKey = destinationKey
        self.createdAt = Date()
        self.startDate = startDate
        self.paceRaw = pace.rawValue
        self.travelers = travelers
        self.totalDays = totalDays
        self.bookingLeadDays = bookingLeadDays
        self.isTravelModeActive = false
        self.cachedRate = nil
        self.cachedRateDate = nil
        self.baseCurrency = baseCurrency
    }

    var pace: Pace { Pace(rawValue: paceRaw) ?? .balanced }
    var destination: Destination? { DestinationCatalog.destination(for: destinationKey) }

    var readiness: Readiness {
        ReadinessCalculator.score(
            tasks: tasks.map { ReadinessCalculator.TaskInput(weight: $0.weight, isDone: $0.isDone, isBlocking: $0.isBlocking) },
            packedRatio: packing.isEmpty ? nil : Double(packing.filter(\.isPacked).count) / Double(packing.count)
        )
    }

    var endDate: Date? {
        guard let startDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: max(totalDays - 1, 0), to: startDate)
    }

    var sortedStops: [TripStop] { stops.sorted { $0.order < $1.order } }
}

@Model
final class PrepTask {
    var id: UUID
    var key: String
    var title: String
    var detail: String
    var categoryRaw: String
    var weight: Int
    var isBlocking: Bool
    var isDone: Bool
    var leadDays: Int
    var linkString: String?
    var order: Int
    var trip: Trip?

    init(key: String, title: String, detail: String, category: TaskCategory, weight: Int,
         isBlocking: Bool, leadDays: Int, linkString: String?, order: Int) {
        self.id = UUID()
        self.key = key
        self.title = title
        self.detail = detail
        self.categoryRaw = category.rawValue
        self.weight = weight
        self.isBlocking = isBlocking
        self.isDone = false
        self.leadDays = leadDays
        self.linkString = linkString
        self.order = order
    }

    var category: TaskCategory { TaskCategory(rawValue: categoryRaw) ?? .other }

    /// Date limite calculée à partir de la date de départ (rétroplanning).
    func dueDate(startDate: Date?) -> Date? {
        guard let startDate, leadDays > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: -leadDays, to: startDate)
    }
}

@Model
final class Booking {
    var id: UUID
    var kindRaw: String
    var title: String
    var reference: String
    var startDate: Date?
    var endDate: Date?
    var location: String
    var rawText: String
    var createdAt: Date
    var trip: Trip?

    init(kind: BookingKind, title: String, reference: String, startDate: Date?, endDate: Date?, location: String, rawText: String) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.title = title
        self.reference = reference
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.rawText = rawText
        self.createdAt = Date()
    }

    var kind: BookingKind {
        get { BookingKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }
}

@Model
final class PackingItem {
    var id: UUID
    var name: String
    var group: String
    var isPacked: Bool
    var order: Int
    var trip: Trip?

    init(name: String, group: String, order: Int) {
        self.id = UUID()
        self.name = name
        self.group = group
        self.isPacked = false
        self.order = order
    }
}

/// Une étape (ville) du voyage, avec son nombre de nuits.
@Model
final class TripStop {
    var id: UUID
    var city: String
    var nights: Int
    var order: Int
    var latitude: Double?
    var longitude: Double?
    var trip: Trip?

    init(city: String, nights: Int, order: Int, latitude: Double?, longitude: Double?) {
        self.id = UUID()
        self.city = city
        self.nights = nights
        self.order = order
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Une ligne du déroulé jour par jour.
@Model
final class ItineraryEntry {
    var id: UUID
    var dayIndex: Int
    var slotRaw: String
    var order: Int
    var title: String
    var city: String
    var categoryRaw: String?
    var latitude: Double?
    var longitude: Double?
    var trip: Trip?

    init(dayIndex: Int, slot: DaySlot, order: Int, title: String, city: String,
         category: PlaceCategory?, latitude: Double?, longitude: Double?) {
        self.id = UUID()
        self.dayIndex = dayIndex
        self.slotRaw = slot.rawValue
        self.order = order
        self.title = title
        self.city = city
        self.categoryRaw = category?.rawValue
        self.latitude = latitude
        self.longitude = longitude
    }

    var slot: DaySlot { DaySlot(rawValue: slotRaw) ?? .morning }
    var category: PlaceCategory? { categoryRaw.flatMap(PlaceCategory.init(rawValue:)) }
}

enum DaySlot: String, Codable, CaseIterable {
    case transit
    case morning
    case lunch
    case afternoon
    case evening

    var label: String {
        switch self {
        case .transit: "Trajet"
        case .morning: "Matin"
        case .lunch: "Midi"
        case .afternoon: "Après-midi"
        case .evening: "Soir"
        }
    }

    var sortIndex: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}
