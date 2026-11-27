import Foundation

struct Readiness: Equatable {
    var percent: Int
    var blockers: Int
}

/// Pourcentage de préparation pondéré : un passeport ou un vol compte bien plus
/// qu'un adaptateur. Tant qu'un élément bloquant (passeport, visa, vols) n'est pas
/// fait, le score est plafonné à 90 %.
enum ReadinessCalculator {
    struct TaskInput {
        var weight: Int
        var isDone: Bool
        var isBlocking: Bool
    }

    static let packingWeight = 5
    static let capWithBlockers = 90

    static func score(tasks: [TaskInput], packedRatio: Double?) -> Readiness {
        var total = Double(tasks.reduce(0) { $0 + max($1.weight, 0) })
        var done = Double(tasks.filter(\.isDone).reduce(0) { $0 + max($1.weight, 0) })
        if let packedRatio {
            total += Double(packingWeight)
            done += Double(packingWeight) * min(max(packedRatio, 0), 1)
        }
        let blockers = tasks.filter { $0.isBlocking && !$0.isDone }.count
        guard total > 0 else { return Readiness(percent: 0, blockers: blockers) }
        var percent = Int((done / total * 100).rounded())
        if blockers > 0 { percent = min(percent, capWithBlockers) }
        return Readiness(percent: percent, blockers: blockers)
    }
}
