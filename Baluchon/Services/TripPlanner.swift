import Foundation

struct PlannerPlace: Equatable {
    var id: UUID = UUID()
    var name: String
    var category: PlaceCategory
    var city: String?
    var latitude: Double?
    var longitude: Double?
    var leadDays: Int = 0

    var needsBooking: Bool { leadDays > 0 }
}

struct PlannedStop: Equatable {
    var city: String
    var activityDays: Int
    var nights: Int
    var latitude: Double?
    var longitude: Double?
    var places: [PlannerPlace]
}

struct PlannedEntry: Equatable {
    var dayIndex: Int
    var slot: DaySlot
    var title: String
    var city: String
    var place: PlannerPlace?
}

struct PlannedTask: Equatable {
    var key: String
    var title: String
    var detail: String
    var category: TaskCategory
    var weight: Int
    var isBlocking: Bool
    var leadDays: Int
    var link: String?
}

struct TripPlan: Equatable {
    var stops: [PlannedStop]
    var activityDays: Int
    var transferDays: Int
    var bufferDays: Int
    var totalDays: Int
    /// Délai minimum conseillé entre aujourd'hui et le départ pour tout réserver sereinement.
    var bookingLeadDays: Int
    var entries: [PlannedEntry]
    var tasks: [PlannedTask]

    var hotelsCount: Int { stops.count }
    var totalNights: Int { max(totalDays - 1, 0) }
}

/// Calcule la durée idéale du voyage, les étapes, le nombre d'hôtels, le déroulé
/// jour par jour et le plan de préparation (rétroplanning).
enum TripPlanner {
    static let fallbackCityName = "Étape principale"

    static func plan(places: [PlannerPlace], destination: Destination?, pace: Pace, nationality: String = "FR") -> TripPlan {
        let stops = orderedStops(for: places, destination: destination, pace: pace)
        let activityDays = stops.reduce(0) { $0 + $1.activityDays }
        let transferDays = Int((Double(max(stops.count - 1, 0)) * pace.transferDays).rounded(.up))
        let bufferDays = Int((Double(activityDays) * pace.bufferRatio).rounded(.up))
        // +1 : jour d'arrivée (installation, décalage horaire)
        let totalDays = max(activityDays + transferDays + bufferDays + 1, 2)

        // Répartition des nuits : jours d'activités par ville, puis les jours de
        // transfert et de marge distribués à tour de rôle (en commençant par la première ville).
        var finalStops = stops
        var leftover = (totalDays - 1) - activityDays
        var index = 0
        while leftover > 0, !finalStops.isEmpty {
            finalStops[index % finalStops.count].nights += 1
            leftover -= 1
            index += 1
        }

        let entries = itinerary(for: finalStops, totalDays: totalDays, pace: pace)
        let tasks = preparationTasks(stops: finalStops, places: places, destination: destination, nationality: nationality)
        let lead = tasks.map(\.leadDays).max() ?? 0

        return TripPlan(stops: finalStops, activityDays: activityDays, transferDays: transferDays,
                        bufferDays: bufferDays, totalDays: totalDays, bookingLeadDays: lead,
                        entries: entries, tasks: tasks)
    }

    /// Date de départ la plus proche permettant de tout préparer.
    static func earliestComfortableDeparture(for plan: TripPlan, from today: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: plan.bookingLeadDays, to: today) ?? today
    }

    // MARK: - Étapes

    static func orderedStops(for places: [PlannerPlace], destination: Destination?, pace: Pace) -> [PlannedStop] {
        var groups: [String: [PlannerPlace]] = [:]
        var order: [String] = []
        for place in places where place.category != .hotel {
            let city = resolvedCity(for: place, destination: destination)
            if groups[city] == nil { order.append(city) }
            groups[city, default: []].append(place)
        }

        var stops: [PlannedStop] = order.map { city in
            let cityPlaces = groups[city] ?? []
            let hours = cityPlaces.filter { $0.category != .restaurant }.reduce(0.0) { $0 + $1.category.visitHours }
            var days = Int((hours / pace.dailyHours).rounded(.up))
            let restaurants = cityPlaces.filter { $0.category == .restaurant }.count
            days = max(days, Int((Double(restaurants) / 2).rounded(.up)), 1)
            let catalogCity = destination?.cities.first { $0.name == city }
            let coordinates = cityPlaces.compactMap { p -> (Double, Double)? in
                guard let lat = p.latitude, let lon = p.longitude else { return nil }
                return (lat, lon)
            }
            let count = Double(max(coordinates.count, 1))
            let averageLatitude: Double? = coordinates.isEmpty ? nil : coordinates.reduce(0.0) { $0 + $1.0 } / count
            let averageLongitude: Double? = coordinates.isEmpty ? nil : coordinates.reduce(0.0) { $0 + $1.1 } / count
            let latitude: Double? = catalogCity?.latitude ?? averageLatitude
            let longitude: Double? = catalogCity?.longitude ?? averageLongitude
            return PlannedStop(city: city, activityDays: days, nights: days, latitude: latitude, longitude: longitude, places: cityPlaces)
        }

        // Ordre du circuit : on part de la première ville du catalogue (listées du nord au sud
        // ou dans un ordre logique), puis on va toujours vers la ville la plus proche.
        if let destination {
            let catalogOrder = destination.cities.map(\.name)
            stops.sort { (catalogOrder.firstIndex(of: $0.city) ?? Int.max) < (catalogOrder.firstIndex(of: $1.city) ?? Int.max) }
        }
        guard stops.count > 2, stops.allSatisfy({ $0.latitude != nil }) else { return stops }
        var route = [stops.removeFirst()]
        while !stops.isEmpty {
            let last = route[route.count - 1]
            let nextIndex = stops.indices.min { a, b in
                Geo.distanceKm(last.latitude!, last.longitude!, stops[a].latitude!, stops[a].longitude!)
                    < Geo.distanceKm(last.latitude!, last.longitude!, stops[b].latitude!, stops[b].longitude!)
            }!
            route.append(stops.remove(at: nextIndex))
        }
        return route
    }

    static func resolvedCity(for place: PlannerPlace, destination: Destination?) -> String {
        if let city = place.city, !city.isEmpty {
            if let destination,
               let match = destination.cities.first(where: { c in
                   ([c.name] + c.aliases).contains { TextNormalizer.normalize($0) == TextNormalizer.normalize(city) }
               }) {
                return match.name
            }
            return city
        }
        if let destination, let lat = place.latitude, let lon = place.longitude,
           let nearest = destination.cities.min(by: {
               Geo.distanceKm(lat, lon, $0.latitude, $0.longitude) < Geo.distanceKm(lat, lon, $1.latitude, $1.longitude)
           }) {
            return nearest.name
        }
        return destination?.cities.first?.name ?? fallbackCityName
    }

    // MARK: - Déroulé jour par jour

    static func itinerary(for stops: [PlannedStop], totalDays: Int, pace: Pace) -> [PlannedEntry] {
        guard !stops.isEmpty else { return [] }
        var entries: [PlannedEntry] = []
        var day = 0

        for (stopIndex, stop) in stops.enumerated() {
            let firstDay = day
            let dayCount = max(stop.nights, 1)
            var budgets = Array(repeating: pace.dailyHours, count: dayCount)

            if stopIndex == 0 {
                entries.append(PlannedEntry(dayIndex: firstDay, slot: .transit, title: "Arrivée à \(stop.city) — installation", city: stop.city))
            } else {
                let previous = stops[stopIndex - 1].city
                entries.append(PlannedEntry(dayIndex: firstDay, slot: .transit, title: "Trajet \(previous) → \(stop.city)", city: stop.city))
            }
            budgets[0] = pace.dailyHours / 2

            // Activités : on remplit les journées dans l'ordre
            var dayCursor = 0
            for place in stop.places where place.category != .restaurant {
                while dayCursor < dayCount - 1, budgets[dayCursor] < min(place.category.visitHours, pace.dailyHours / 2) {
                    dayCursor += 1
                }
                let used = (dayCursor == 0 ? pace.dailyHours / 2 : pace.dailyHours) - budgets[dayCursor]
                let slot: DaySlot
                if place.category == .nightlife {
                    slot = .evening
                } else if dayCursor > 0 && used < 0.01 {
                    slot = .morning
                } else {
                    slot = .afternoon
                }
                entries.append(PlannedEntry(dayIndex: firstDay + dayCursor, slot: slot, title: place.name, city: stop.city, place: place))
                budgets[dayCursor] -= place.category.visitHours
            }

            // Restaurants : midi puis soir, répartis sur les journées
            let restaurants = stop.places.filter { $0.category == .restaurant }
            for (i, place) in restaurants.enumerated() {
                let dayOffset = (i / 2) % dayCount
                let slot: DaySlot = i % 2 == 0 ? .evening : .lunch
                entries.append(PlannedEntry(dayIndex: firstDay + dayOffset, slot: slot, title: place.name, city: stop.city, place: place))
            }

            day += dayCount
        }

        let lastDay = max(totalDays - 1, day)
        entries.append(PlannedEntry(dayIndex: lastDay, slot: .transit, title: "Départ — retour à la maison", city: stops.last?.city ?? ""))

        return entries.sorted { ($0.dayIndex, $0.slot.sortIndex) < ($1.dayIndex, $1.slot.sortIndex) }
    }

    // MARK: - Plan de préparation

    static func preparationTasks(stops: [PlannedStop], places: [PlannerPlace], destination: Destination?, nationality: String) -> [PlannedTask] {
        let sources = OfficialSources.forNationality(nationality)
        var tasks: [PlannedTask] = [
            PlannedTask(key: "passport", title: "Vérifier la validité du passeport",
                        detail: "Beaucoup de pays exigent un passeport valide 6 mois après la date de retour. Un renouvellement peut prendre plusieurs semaines.",
                        category: .documents, weight: 10, isBlocking: true, leadDays: 90, link: nil),
            PlannedTask(key: "entry", title: "Vérifier les conditions d'entrée (visa, e-visa, autorisation électronique)",
                        detail: "Elles dépendent de ta nationalité et changent régulièrement (ex. ESTA pour les États-Unis). Consulte la source officielle : \(sources.name).",
                        category: .documents, weight: 10, isBlocking: true, leadDays: 45, link: sources.travelAdviceURL),
            PlannedTask(key: "health", title: "Faire le point vaccins et santé",
                        detail: "Prends rendez-vous dans un centre de vaccinations internationales ou chez ton médecin, idéalement 6 à 8 semaines avant le départ (certains vaccins demandent plusieurs injections).",
                        category: .health, weight: 6, isBlocking: false, leadDays: 45, link: OfficialSources.healthURL),
            PlannedTask(key: "insurance", title: "Souscrire ou vérifier une assurance voyage (frais médicaux, rapatriement)",
                        detail: "Vérifie aussi ce que couvre ta carte bancaire. Note le numéro d'assistance dans ton profil : il sera dispo hors ligne.",
                        category: .health, weight: 6, isBlocking: false, leadDays: 14, link: nil),
            PlannedTask(key: "flights", title: "Réserver les vols aller-retour",
                        detail: "Les prix sont souvent les plus intéressants 6 à 10 semaines avant le départ pour un long-courrier.",
                        category: .transport, weight: 10, isBlocking: true, leadDays: 60, link: nil),
        ]

        for (i, stop) in stops.enumerated() {
            tasks.append(PlannedTask(key: "lodging:\(stop.city)", title: "Réserver l'hébergement à \(stop.city) (\(stop.nights) nuit\(stop.nights > 1 ? "s" : ""))",
                                     detail: "Choisis un quartier proche de ce que tu veux voir. Ajoute ensuite l'e-mail de confirmation dans Réservations.",
                                     category: .lodging, weight: 7, isBlocking: false, leadDays: 30, link: nil))
            if i > 0 {
                let from = stops[i - 1].city
                tasks.append(PlannedTask(key: "transfer:\(from)>\(stop.city)", title: "Prévoir le trajet \(from) → \(stop.city)",
                                         detail: "Train, bus, vol intérieur ou chauffeur : compare les options et réserve si besoin.",
                                         category: .transport, weight: 4, isBlocking: false, leadDays: 14, link: nil))
            }
        }

        for place in places where place.needsBooking {
            tasks.append(PlannedTask(key: "place:\(place.id.uuidString)", title: "Réserver : \(place.name)",
                                     detail: "Les places partent vite : réserve au moins \(place.leadDays) jours à l'avance.",
                                     category: .activities, weight: 3, isBlocking: false, leadDays: place.leadDays, link: nil))
        }

        let currency = destination?.currencyCode ?? "la devise locale"
        tasks += [
            PlannedTask(key: "money", title: "Préparer l'argent : carte sans frais à l'étranger, un peu de \(currency) en liquide",
                        detail: "Préviens ta banque et vérifie tes plafonds de paiement et de retrait.",
                        category: .money, weight: 2, isBlocking: false, leadDays: 7, link: nil),
            PlannedTask(key: "esim", title: "Prévoir internet sur place (eSIM ou forfait international)",
                        detail: "Vérifie que ton téléphone est compatible eSIM et désimlocké.",
                        category: .connectivity, weight: 2, isBlocking: false, leadDays: 3, link: nil),
            PlannedTask(key: "offlineMaps", title: "Télécharger les cartes hors ligne (\(stops.map(\.city).joined(separator: ", ")))",
                        detail: "Dans Google Maps : photo de profil › Cartes hors connexion. Dans Plans : photo de profil › Cartes hors ligne.",
                        category: .offline, weight: 3, isBlocking: false, leadDays: 2, link: nil),
        ]
        if let destination, let language = destination.languageCode, !language.hasPrefix("fr") {
            tasks.append(PlannedTask(key: "voice", title: "Télécharger la voix \(destination.languageName) pour la lecture des phrases",
                                     detail: "Réglages › Accessibilité › Contenu énoncé › Voix › \(destination.languageName.capitalized). Sans elle, la lecture à voix haute ne marche pas hors ligne.",
                                     category: .offline, weight: 2, isBlocking: false, leadDays: 2, link: nil))
        }
        tasks.append(PlannedTask(key: "travelMode", title: "Activer le mode voyage la veille du départ",
                                 detail: "Il enregistre le taux de change et vérifie que tout est disponible sans réseau.",
                                 category: .offline, weight: 3, isBlocking: false, leadDays: 1, link: nil))
        return tasks
    }
}

/// Sources officielles pour les formalités (jamais générées par une IA).
enum OfficialSources {
    struct Source {
        let name: String
        let travelAdviceURL: String
    }

    static let healthURL = "https://www.pasteur.fr/fr/centre-medical"

    struct Nationality: Hashable {
        let code: String
        let label: String
    }

    static let nationalities: [Nationality] = [
        Nationality(code: "FR", label: "Française"),
        Nationality(code: "BE", label: "Belge"),
        Nationality(code: "CH", label: "Suisse"),
        Nationality(code: "CA", label: "Canadienne"),
        Nationality(code: "LU", label: "Luxembourgeoise"),
        Nationality(code: "OTHER", label: "Autre"),
    ]

    static func forNationality(_ code: String) -> Source {
        switch code {
        case "BE": Source(name: "SPF Affaires étrangères (Belgique)", travelAdviceURL: "https://diplomatie.belgium.be/fr")
        case "CH": Source(name: "DFAE (Suisse)", travelAdviceURL: "https://www.eda.admin.ch/eda/fr/dfae.html")
        case "CA": Source(name: "Gouvernement du Canada — Conseils aux voyageurs", travelAdviceURL: "https://voyage.gc.ca/destinations")
        case "LU": Source(name: "Ministère des Affaires étrangères (Luxembourg)", travelAdviceURL: "https://maee.gouvernement.lu/fr.html")
        case "FR": Source(name: "France Diplomatie — Conseils aux voyageurs", travelAdviceURL: "https://www.diplomatie.gouv.fr/fr/conseils-aux-voyageurs/")
        default: Source(name: "l'ambassade du pays de destination", travelAdviceURL: "https://www.diplomatie.gouv.fr/fr/conseils-aux-voyageurs/")
        }
    }
}
