import SwiftData
import SwiftUI

@main
struct BaluchonApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            Inspiration.self,
            PlaceItem.self,
            Trip.self,
            PrepTask.self,
            Booking.self,
            PackingItem.self,
            TripStop.self,
            ItineraryEntry.self,
        ])
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
                .tabItem { Label("Inspirations", systemImage: "sparkles") }
            TripsListView()
                .tabItem { Label("Voyages", systemImage: "suitcase.rolling") }
            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
    }
}
