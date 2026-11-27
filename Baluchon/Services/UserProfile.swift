import Foundation

/// Profil voyageur, stocké localement (UserDefaults) et disponible hors ligne.
struct UserProfile {
    enum Keys {
        static let name = "profile.name"
        static let nationality = "profile.nationality"
        static let baseCurrency = "profile.baseCurrency"
        static let bloodType = "profile.bloodType"
        static let allergies = "profile.allergies"
        static let insurance = "profile.insurance"
        static let emergencyContact = "profile.emergencyContact"
    }

    var name: String
    var nationality: String
    var baseCurrency: String
    var bloodType: String
    var allergies: String
    var insurance: String
    var emergencyContact: String

    static var current: UserProfile {
        let defaults = UserDefaults.standard
        return UserProfile(
            name: defaults.string(forKey: Keys.name) ?? "",
            nationality: defaults.string(forKey: Keys.nationality) ?? "FR",
            baseCurrency: defaults.string(forKey: Keys.baseCurrency) ?? "EUR",
            bloodType: defaults.string(forKey: Keys.bloodType) ?? "",
            allergies: defaults.string(forKey: Keys.allergies) ?? "",
            insurance: defaults.string(forKey: Keys.insurance) ?? "",
            emergencyContact: defaults.string(forKey: Keys.emergencyContact) ?? ""
        )
    }
}
