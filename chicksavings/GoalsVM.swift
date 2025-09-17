import Foundation

/// ViewModel for Goals screen.
/// Manages list of saving goals and supports CRUD + progress calculations.
@MainActor
final class GoalsVM: ObservableObject {
    @Published private(set) var goals: [Goal] = []

    private let data = DataEngine.shared
    private let logic = LogicEngine.shared

    init() {
        refresh()
    }

    func refresh() {
        goals = data.goals
    }

    // MARK: - CRUD

    func createGoal(name: String, type: Goal.GoalType, target: Decimal? = nil, deadline: Date? = nil) {
        _ = data.createGoal(name: name, type: type, target: target, deadline: deadline)
        HapticsManager.shared.impact(.light)
        refresh()
    }

    func updateGoal(_ goal: Goal) {
        data.updateGoal(goal)
        HapticsManager.shared.selectionChanged()
        refresh()
    }

    func deleteGoal(_ goal: Goal) {
        data.deleteGoal(id: goal.id)
        HapticsManager.shared.warning()
        refresh()
    }

    // MARK: - Helpers

    func progress(for goal: Goal) -> Double {
        guard goal.type == .fixed, let target = goal.target, target > 0 else { return 0 }
        let saved = goal.saved
        let pct = NSDecimalNumber(decimal: saved).doubleValue / NSDecimalNumber(decimal: target).doubleValue
        return min(max(pct, 0), 1)
    }

    func remainder(for goal: Goal) -> Decimal? {
        data.remainder(toTarget: goal)
    }

    func tenPercent(for goal: Goal) -> Decimal? {
        data.tenPercent(of: goal)
    }
}
