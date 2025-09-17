import Foundation

/// ViewModel for the Home (Dashboard) screen.
/// Provides aggregated balance, quick add options, and week stats.
@MainActor
final class HomeVM: ObservableObject {
    @Published private(set) var totalSaved: Decimal = 0
    @Published private(set) var weekStats: WeekStats = WeekStats()
    @Published private(set) var quickPresets: [Decimal] = []
    @Published private(set) var recentTransactions: [Transaction] = []

    private let data = DataEngine.shared
    private let logic = LogicEngine.shared

    init() {
        refresh()
    }

    func refresh() {
        totalSaved = data.totalSaved
        weekStats = logic.computeWeekStats()
        quickPresets = data.quickPresets()
        recentTransactions = data.recentTransactions(limit: 5)
    }

    // MARK: - Quick add actions

    func addPreset(_ amount: Decimal, goalId: UUID? = nil) {
        let tx = data.addTransaction(amount: amount,
                                     goalId: goalId,
                                     note: "Quick add",
                                     tag: .other)
        logic.processAfterTransaction(tx)
        HapticsManager.shared.impact(.medium)
        refresh()
    }

    func addTenPercent(of goal: Goal) {
        guard let amount = data.tenPercent(of: goal) else { return }
        let tx = data.addTransaction(amount: amount,
                                     goalId: goal.id,
                                     note: "10% of goal",
                                     tag: .other)
        logic.processAfterTransaction(tx)
        HapticsManager.shared.impact(.light)
        refresh()
    }

    func addRemainder(to goal: Goal) {
        guard let amount = data.remainder(toTarget: goal) else { return }
        let tx = data.addTransaction(amount: amount,
                                     goalId: goal.id,
                                     note: "Remainder to target",
                                     tag: .other)
        logic.processAfterTransaction(tx)
        HapticsManager.shared.success()
        refresh()
    }
}
