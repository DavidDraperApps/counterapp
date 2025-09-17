import Foundation

/// ViewModel for Chickens (achievements) screen.
/// Provides obtained vs locked chickens, collections, and evolution handling.
@MainActor
final class ChickensVM: ObservableObject {
    @Published private(set) var chickens: [Chicken] = []
    @Published private(set) var obtained: [Chicken] = []
    @Published private(set) var locked: [Chicken] = []

    private let data = DataEngine.shared

    init() {
        refresh()
    }

    func refresh() {
        let all = data.chickens
        chickens = all.sorted { lhs, rhs in
            // obtained first by date, then locked by rarity
            let lObt = lhs.obtainedAt != nil
            let rObt = rhs.obtainedAt != nil
            if lObt != rObt { return lObt && !rObt }
            return lhs.title < rhs.title
        }
        obtained = all.filter { $0.obtainedAt != nil }
        locked = all.filter { $0.obtainedAt == nil }
    }

    // MARK: - Helpers

    func isObtained(_ chicken: Chicken) -> Bool {
        chicken.obtainedAt != nil
    }

    func rarityLabel(_ chicken: Chicken) -> String {
        chicken.rarity.rawValue.capitalized
    }

    func evolutionLabel(_ chicken: Chicken) -> String {
        chicken.evolution.rawValue.capitalized
    }

    func obtainedDateString(_ chicken: Chicken) -> String {
        guard let d = chicken.obtainedAt else { return "" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: d)
    }

    // Manual reset for testing/demo
    func resetChicken(_ code: String) {
        data.resetChicken(code: code)
        HapticsManager.shared.warning()
        refresh()
    }
}
