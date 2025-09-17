import Foundation
import Combine

// Centralized data layer: in-memory + UserDefaults persistence.
// Holds Goals, Transactions, and Chickens (achievements metadata + obtainedAt).
// Also provides quick presets and simple CSV import/export for transactions.

@MainActor
final class DataEngine: ObservableObject {
    static let shared = DataEngine()

    // MARK: - Published state
    @Published private(set) var goals: [Goal] = []
    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var chickens: [Chicken] = [] // catalog + obtainedAt

    // MARK: - Storage keys
    private let goalsKey = "data.goals.v1"
    private let txKey = "data.transactions.v1"
    private let chickensKey = "data.chickens.v1"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        loadAll()
        seedIfEmpty()
    }

    // MARK: - Load / Save
    private func loadAll() {
        if let gData = UserDefaults.standard.data(forKey: goalsKey),
           let decoded = try? decoder.decode([Goal].self, from: gData) {
            goals = decoded
        }
        if let tData = UserDefaults.standard.data(forKey: txKey),
           let decoded = try? decoder.decode([Transaction].self, from: tData) {
            transactions = decoded
        }
        if let cData = UserDefaults.standard.data(forKey: chickensKey),
           let decoded = try? decoder.decode([Chicken].self, from: cData) {
            chickens = decoded
        }
    }

    private func saveGoals() {
        if let data = try? encoder.encode(goals) {
            UserDefaults.standard.set(data, forKey: goalsKey)
        }
    }

    private func saveTransactions() {
        if let data = try? encoder.encode(transactions) {
            UserDefaults.standard.set(data, forKey: txKey)
        }
    }

    private func saveChickens() {
        if let data = try? encoder.encode(chickens) {
            UserDefaults.standard.set(data, forKey: chickensKey)
        }
    }

    // MARK: - Seed (demo)
    // MARK: - Seed (demo)
    private func seedIfEmpty() {
        if goals.isEmpty {
            let g1 = Goal(name: "Emergency Fund", type: .fixed, target: 2000, saved: 0)
            let g2 = Goal(name: "New iPhone", type: .fixed, target: 1300, saved: 0)
            let g3 = Goal(name: "Just Saving", type: .uncapped, target: nil, saved: 0)
            goals = [g1, g2, g3]
            saveGoals()
        }
        if chickens.isEmpty {
            chickens = [
                // базовые (переформулированы без слова "deposit")
                Chicken(code: "first_deposit",   title: "First Add",        description: "Make your first add.",                 rarity: .common,   evolution: .chick),
                Chicken(code: "streak_7",        title: "One Week Streak",  description: "Add for 7 days in a row.",             rarity: .rare,     evolution: .hen),
                Chicken(code: "ten_deposits",    title: "Ten Adds",         description: "Make 10 adds in total.",               rarity: .common,   evolution: .chick),

                // редкие события (тоже без "deposit")
                Chicken(code: "lunar_night",     title: "Lunar Night",      description: "Add between 00:00 and 01:00.",         rarity: .epic,     evolution: .hen),
                Chicken(code: "generous_tuesday",title: "Generous Tuesday", description: "Add on a Tuesday.",                    rarity: .rare,     evolution: .hen),
                Chicken(code: "lucky_777",       title: "Lucky Me",        description: "Amount ends with 777.",                rarity: .epic,     evolution: .golden),
                Chicken(code: "palindrome_date", title: "Palindrome Date",  description: "Add on a palindrome date.",            rarity: .legendary, evolution: .golden),

                // НОВЫЕ 6 достижений
                Chicken(code: "morning_bird",    title: "Morning Saver",    description: "Add between 06:00 and 09:00.",         rarity: .common,   evolution: .chick),
                Chicken(code: "evening_saver",   title: "Evening Saver",    description: "Add between 20:00 and 23:00.",         rarity: .common,   evolution: .chick),

                Chicken(code: "quarter_25",      title: "Quarter Way",      description: "Reach 25% of a fixed goal.",           rarity: .common,   evolution: .chick),
                Chicken(code: "quarter_50",      title: "Halfway There",    description: "Reach 50% of a fixed goal.",           rarity: .rare,     evolution: .chick),
                Chicken(code: "quarter_75",      title: "Almost There",     description: "Reach 75% of a fixed goal.",           rarity: .epic,     evolution: .hen),
                Chicken(code: "full_100",        title: "Goal Completed",   description: "Reach 100% of a fixed goal.",          rarity: .legendary, evolution: .golden)
            ]
            saveChickens()
        }
    }

    // MARK: - Goals CRUD
    func createGoal(name: String, type: Goal.GoalType, target: Decimal?, deadline: Date? = nil, emoji: String? = nil) -> Goal {
        var g = Goal(name: name, type: type, target: (type == .fixed ? target : nil), saved: 0, deadline: deadline)
        goals.append(g)
        saveGoals()
        return g
    }

    func updateGoal(_ goal: Goal) {
        guard let idx = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        goals[idx] = goal
        saveGoals()
    }

    func deleteGoal(id: UUID) {
        goals.removeAll { $0.id == id }
        // Also detach transactions bound to this goal (keep history but clear link)
        transactions = transactions.map { tx in
            var t = tx
            if t.goalId == id { t.goalId = nil }
            return t
        }
        saveGoals()
        saveTransactions()
    }

    func goal(by id: UUID?) -> Goal? {
        guard let id else { return nil }
        return goals.first { $0.id == id }
    }

    // Aggregate
    var totalSaved: Decimal {
        goals.map(\.saved).reduce(0, +)
    }

    // MARK: - Transactions CRUD
    @discardableResult
    func addTransaction(amount: Decimal,
                        goalId: UUID?,
                        note: String? = nil,
                        tag: Transaction.Tag = .other,
                        date: Date = Date()) -> Transaction {
        var tx = Transaction(amount: amount, goalId: goalId, note: note, tag: tag)
        tx.date = date
        transactions.append(tx)
        // Apply effect to goal balance if linked
        if let gid = goalId, let idx = goals.firstIndex(where: { $0.id == gid }) {
            goals[idx].saved += amount
            if goals[idx].saved < 0 { goals[idx].saved = 0 }
            saveGoals()
        }
        saveTransactions()
        return tx
    }

    func updateTransaction(_ tx: Transaction) {
        guard let idx = transactions.firstIndex(where: { $0.id == tx.id }) else { return }
        // Adjust goal balances if amount/goalId changed: recompute is safer
        let old = transactions[idx]
        transactions[idx] = tx
        recomputeGoalBalances()
        saveTransactions()
        saveGoals()
    }

    func deleteTransaction(id: UUID) {
        transactions.removeAll { $0.id == id }
        recomputeGoalBalances()
        saveTransactions()
        saveGoals()
    }

    func transactions(for goalId: UUID?) -> [Transaction] {
        transactions.filter { $0.goalId == goalId }.sorted(by: { $0.date > $1.date })
    }

    func recentTransactions(limit: Int = 50) -> [Transaction] {
        transactions.sorted(by: { $0.date > $1.date }).prefix(limit).map { $0 }
    }

    // Rebuild goal.saved from transactions
    func recomputeGoalBalances() {
        var sums: [UUID: Decimal] = [:]
        for tx in transactions {
            if let gid = tx.goalId {
                sums[gid, default: 0] += tx.amount
            }
        }
        goals = goals.map { g in
            var ng = g
            ng.saved = max(0, sums[g.id] ?? 0)
            return ng
        }
    }

    // MARK: - Quick presets & calculator
    func quickPresets() -> [Decimal] { [500, 1000] }

    // 10% of goal target (rounded down to nearest whole currency unit)
    func tenPercent(of goal: Goal) -> Decimal? {
        guard goal.type == .fixed, let target = goal.target else { return nil }
        return (target * 0.10).roundedDownCurrencyUnit()
    }

    // Remainder to target (if fixed)
    func remainder(toTarget goal: Goal) -> Decimal? {
        guard goal.type == .fixed, let target = goal.target else { return nil }
        let rem = target - goal.saved
        return rem > 0 ? rem.roundedDownCurrencyUnit() : 0
    }

    // MARK: - Week helpers (for "Week Stats")
    func transactionsInLast(days: Int) -> [Transaction] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return transactions.filter { $0.date >= start }
    }

    // MARK: - Chickens (achievements)
    func markChickenObtained(code: String, at date: Date = Date(), evolution: Chicken.Evolution? = nil) {
        guard let idx = chickens.firstIndex(where: { $0.code == code }) else { return }
        var c = chickens[idx]
        c.obtainedAt = c.obtainedAt ?? date
        if let evo = evolution { c.evolution = evo }
        chickens[idx] = c
        saveChickens()
    }

    func resetChicken(code: String) {
        guard let idx = chickens.firstIndex(where: { $0.code == code }) else { return }
        var c = chickens[idx]
        c.obtainedAt = nil
        chickens[idx] = c
        saveChickens()
    }

    // MARK: - CSV Export / Import (Transactions)
    // Export transactions as: date,amount,goalName,tag,note
    func exportTransactionsCSV() -> String {
        var lines: [String] = ["date,amount,goal,tag,note"]
        let df = ISO8601DateFormatter()
        for t in transactions.sorted(by: { $0.date < $1.date }) {
            let date = df.string(from: t.date)
            let amt = NSDecimalNumber(decimal: t.amount).stringValue
            let goalName = goal(by: t.goalId)?.name ?? ""
            let tag = t.tag.rawValue
            let note = (t.note ?? "").replacingOccurrences(of: ",", with: ";")
            lines.append("\(date),\(amt),\(goalName),\(tag),\(note)")
        }
        return lines.joined(separator: "\n")
    }

    // Basic import: ignores unknown goals (keeps goal empty), expects same header
    func importTransactionsCSV(_ csv: String) {
        let rows = csv.split(separator: "\n").map(String.init)
        guard rows.count > 1 else { return }
        let body = rows.dropFirst()
        let df = ISO8601DateFormatter()

        for row in body {
            let cols = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard cols.count >= 5 else { continue }
            let date = df.date(from: cols[0]) ?? Date()
            let amount = Decimal(string: cols[1]) ?? 0
            let goalName = cols[2]
            let tag = Transaction.Tag(rawValue: cols[3]) ?? .other
            let note = cols[4].replacingOccurrences(of: ";", with: ",")

            let gid = goals.first(where: { $0.name == goalName })?.id
            _ = addTransaction(amount: amount, goalId: gid, note: note, tag: tag, date: date)
        }
    }
}

// MARK: - Currency helpers
extension DataEngine {
    func currencyFormatter(currencyCode: String, grouping: Bool) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        f.usesGroupingSeparator = grouping
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }
}

// MARK: - Decimal helpers
private extension Decimal {
    static func * (lhs: Decimal, rhs: Double) -> Decimal {
        lhs * Decimal(string: String(rhs))!
    }

    func roundedDownCurrencyUnit() -> Decimal {
        var v = self
        var result = Decimal()
        NSDecimalRound(&result, &v, 0, .down)
        return result
    }
}
