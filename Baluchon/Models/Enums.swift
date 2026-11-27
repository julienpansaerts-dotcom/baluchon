import Foundation

enum PlaceCategory: String, CaseIterable, Codable, Identifiable {
    case sight
    case activity
    case nature
    case restaurant
    case nightlife
    case shopping
    case hotel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sight: "À voir"
        case .activity: "Activités"
        case .nature: "Nature"
        case .restaurant: "Restaurants"
        case .nightlife: "Sorties"
        case .shopping: "Shopping"
        case .hotel: "Hébergements"
        }
    }

    var symbol: String {
        switch self {
        case .sight: "building.columns"
        case .activity: "figure.hiking"
        case .nature: "leaf"
        case .restaurant: "fork.knife"
        case .nightlife: "wineglass"
        case .shopping: "bag"
        case .hotel: "bed.double"
        }
    }

    /// Durée moyenne d'une visite, en heures (utilisée pour estimer la durée du voyage).
    var visitHours: Double {
        switch self {
        case .sight: 2
        case .activity: 3.5
        case .nature: 4
        case .restaurant: 1.5
        case .nightlife: 2
        case .shopping: 1.5
        case .hotel: 0
        }
    }
}

enum Decision: String, Codable {
    case pending
    case yes
    case no
}

/// Rythme du voyage : de « chill » à « pressé ».
enum Pace: String, CaseIterable, Codable, Identifiable {
    case chill
    case balanced
    case rushed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chill: "Flâneur"
        case .balanced: "Curieux"
        case .rushed: "Marathonien"
        }
    }

    var explanation: String {
        switch self {
        case .chill: "Deux ou trois choses par jour, des après-midi en terrasse et de vraies journées libres."
        case .balanced: "Un rythme soutenu sans courir, avec un peu de marge pour l'imprévu."
        case .rushed: "Réveil tôt, journées pleines : un maximum de choses en un minimum de jours."
        }
    }

    /// Heures d'activités par jour (hors repas).
    var dailyHours: Double {
        switch self {
        case .chill: 5
        case .balanced: 7
        case .rushed: 10
        }
    }

    /// Jours de marge ajoutés, en proportion des jours d'activités.
    var bufferRatio: Double {
        switch self {
        case .chill: 0.2
        case .balanced: 0.1
        case .rushed: 0
        }
    }

    /// Jours consommés par chaque changement de ville.
    var transferDays: Double {
        switch self {
        case .chill: 1
        case .balanced: 0.5
        case .rushed: 0.5
        }
    }
}

enum TaskCategory: String, CaseIterable, Codable, Identifiable {
    case documents
    case health
    case transport
    case lodging
    case activities
    case money
    case connectivity
    case offline
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .documents: "Papiers & formalités"
        case .health: "Santé & assurance"
        case .transport: "Transports"
        case .lodging: "Hébergements"
        case .activities: "Activités & restaurants"
        case .money: "Argent"
        case .connectivity: "Téléphone & internet"
        case .offline: "Préparation hors ligne"
        case .other: "Divers"
        }
    }

    var symbol: String {
        switch self {
        case .documents: "doc.text"
        case .health: "cross.case"
        case .transport: "airplane"
        case .lodging: "bed.double"
        case .activities: "ticket"
        case .money: "eurosign.circle"
        case .connectivity: "simcard"
        case .offline: "wifi.slash"
        case .other: "checklist"
        }
    }

    var sortIndex: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

enum BookingKind: String, CaseIterable, Codable, Identifiable {
    case flight
    case hotel
    case train
    case bus
    case car
    case activity
    case restaurant
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .flight: "Vol"
        case .hotel: "Hébergement"
        case .train: "Train"
        case .bus: "Bus"
        case .car: "Location de voiture"
        case .activity: "Activité / billet"
        case .restaurant: "Restaurant"
        case .other: "Autre"
        }
    }

    var symbol: String {
        switch self {
        case .flight: "airplane"
        case .hotel: "bed.double"
        case .train: "tram"
        case .bus: "bus"
        case .car: "car"
        case .activity: "ticket"
        case .restaurant: "fork.knife"
        case .other: "doc"
        }
    }
}
