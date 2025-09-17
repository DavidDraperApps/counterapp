import Foundation

/// ViewModel for the Ledger (transactions) screen.
/// Handles listing/filtering, creating, editing and deleting transactions,
/// quick presets (+500/+1000) and CSV import/export. Triggers achievements/streaks via LogicEngine.
@MainActor
final class LedgerVM: ObservableObject {
    // MARK: - Published state
    @Published private(set) var transactions: [Transaction] = []
    @Published var selectedTag: Transaction.Tag? = nil
    @Published var selectedGoalId: UUID? = nil

    // For simple add form
    @Published var draftAmount: Decimal = 0
    @Published var draftNote: String = ""
    @Published var draftTag: Transaction.Tag = .other
    @Published var draftGoalId: UUID? = nil

    private let data = DataEngine.shared
    private let logic = LogicEngine.shared

    init() {
        refresh()
    }

    // MARK: - Refresh / Filtering

    func refresh() {
        let all = data.recentTransactions(limit: 2000)
        transactions = applyFilters(to: all)
    }

    func setFilter(tag: Transaction.Tag?) {
        selectedTag = tag
        refresh()
    }

    func setFilter(goalId: UUID?) {
        selectedGoalId = goalId
        refresh()
    }

    private func applyFilters(to list: [Transaction]) -> [Transaction] {
        list.filter { tx in
            let tagOk = selectedTag == nil || tx.tag == selectedTag
            let goalOk = selectedGoalId == nil || tx.goalId == selectedGoalId
            return tagOk && goalOk
        }
    }

    // MARK: - Presets

    var presets: [Decimal] { data.quickPresets() }

    func addPreset(_ amount: Decimal, to goalId: UUID? = nil, tag: Transaction.Tag = .other) {
        let tx = data.addTransaction(amount: amount, goalId: goalId, note: "Quick add", tag: tag)
        logic.processAfterTransaction(tx)
        HapticsManager.shared.impact(.medium)
        refresh()
    }

    // MARK: - Create / Update / Delete

    @discardableResult
    func addTransaction() -> Transaction {
        let tx = data.addTransaction(amount: draftAmount,
                                     goalId: draftGoalId,
                                     note: draftNote.trimmingCharacters(in: .whitespacesAndNewlines),
                                     tag: draftTag)
        logic.processAfterTransaction(tx)
        HapticsManager.shared.success()
        clearDraft()
        refresh()
        return tx
    }

    func updateTransaction(_ tx: Transaction) {
        data.updateTransaction(tx)
        HapticsManager.shared.selectionChanged()
        refresh()
    }

    func deleteTransaction(_ tx: Transaction) {
        data.deleteTransaction(id: tx.id)
        HapticsManager.shared.warning()
        refresh()
    }

    func clearDraft() {
        draftAmount = 0
        draftNote = ""
        draftTag = .other
        draftGoalId = nil
    }

    // MARK: - Helpers: Calculator shortcuts

    func tenPercent(of goal: Goal) -> Decimal? {
        data.tenPercent(of: goal)
    }

    func remainder(to goal: Goal) -> Decimal? {
        data.remainder(toTarget: goal)
    }

    // MARK: - CSV

    func exportCSV() -> String {
        data.exportTransactionsCSV()
    }

    func importCSV(_ csv: String) {
        data.importTransactionsCSV(csv)
        HapticsManager.shared.impact(.light)
        refresh()
    }
}
