import SwiftData
import SwiftUI

@main
struct BaluchonApp: App {
    private let container: ModelContainer

    init() {
        Theme.configureAppearance()
        let isDemo = DemoData.isEnabled
        let schema = Schema([
            Inspiration.self,
            PlaceItem.self,
            Trip.self,
            PrepTask.self,
            Booking.self,
            PackingItem.self,
            TripStop.self,
            ItineraryEntry.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isDemo)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Impossible d'ouvrir la base de données : \(error)")
        }
        if isDemo {
            DemoData.seed(into: container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.stamp)
        }
        .modelContainer(container)
    }
}

/// Affiche le mode voyage dès qu'un voyage est actif, sinon l'app de préparation.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<Trip> { $0.isTravelModeActive == true }) private var activeTrips: [Trip]

    var body: some View {
        Group {
            if let trip = activeTrips.first {
                TravelModeView(trip: trip)
            } else {
                MainTabView()
            }
        }
        .task { await InspirationPipeline.importSharedInbox(into: context) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await InspirationPipeline.importSharedInbox(into: context) }
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            InspirationsView()
                .tabItem { Label("Envies", systemImage: "mappin.and.ellipse") }
            TripsListView()
                .tabItem { Label("Voyages", systemImage: "suitcase") }
            ProfileView()
                .tabItem { Label("Passeport", systemImage: "person.text.rectangle") }
        }
    }
}
