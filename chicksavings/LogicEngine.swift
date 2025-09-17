import Foundation

// Business logic engine:
// - Streaks & evolution
// - Achievements ("chickens")
// - Week Stats
// - Auto-deposits (weekly / monthly)

@MainActor
final class LogicEngine: ObservableObject {
    static let shared = LogicEngine()

    // Dependencies
    private let data = DataEngine.shared

    // MARK: - Streak storage
    private let streakDaysKey = "logic.streak.days"
    private let streakLastDateKey = "logic.streak.lastDate"
    private let freezeTokensKey = "logic.streak.freezeTokens"          // optional: soft-freeze quota
    private let freezeLastGrantMonthKey = "logic.streak.freezeGrant"   // grant 1 token per month

    private init() {
        grantMonthlyFreezeTokenIfNeeded()
    }

    // MARK: - Public API

    /// Call this after any new deposit is added.
    func processAfterTransaction(_ tx: Transaction) {
        registerStreak(with: tx.date)

        // Achievements
        evaluateBasicMilestones()
        evaluateEventBased(for: tx)
        evaluateEvolutions()

        // Optional: keep "Week Stats" fresh if you cache them elsewhere (here we compute on demand).
    }

    /// Compute "Week Stats" for the last 7 days (overall).
    func computeWeekStats() -> WeekStats {
        let last7 = data.transactionsInLast(days: 7)
        let total = last7.reduce(Decimal(0)) { $0 + $1.amount }
        let bestDay = bestWeekday(in: last7) ?? ""

        // Percent-to-goal: choose the first fixed goal as a reference (or 0 if none).
        if let g = data.goals.first(where: { $0.type == .fixed && $0.target != nil }),
           let target = g.target, target > 0 {
            // Progress this week relative to remaining to target
            let remaining = max(0, target - g.saved)
            let pct = remaining > 0 ? min(1.0, (NSDecimalNumber(decimal: total).doubleValue / NSDecimalNumber(decimal: remaining).doubleValue)) : 1.0
            return WeekStats(totalAdded: total, percentToGoal: pct, bestDay: bestDay)
        } else {
            return WeekStats(totalAdded: total, percentToGoal: 0, bestDay: bestDay)
        }
    }

    // MARK: - Auto-Deposits

    enum AutoFrequency: String, Codable {
        case weekly
        case monthly
    }

    struct AutoRule: Codable, Hashable {
        var goalId: UUID
        var amount: Decimal
        var frequency: AutoFrequency
        var startDate: Date
        var lastApplied: Date? // last date we auto-created a deposit
    }

    private let autoRulesKey = "logic.auto.rules.v1"
    private var autoRules: [AutoRule] = {
        // load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "logic.auto.rules.v1"),
           let rules = try? JSONDecoder().decode([AutoRule].self, from: data) {
            return rules
        }
        return []
    }() {
        didSet { saveAutoRules() }
    }

    func setAutoDeposit(goalId: UUID, amount: Decimal, frequency: AutoFrequency, startDate: Date = Date()) {
        // Replace rule if exists
        autoRules.removeAll { $0.goalId == goalId }
        autoRules.append(AutoRule(goalId: goalId, amount: amount, frequency: frequency, startDate: startDate, lastApplied: nil))
    }

    func removeAutoDeposit(goalId: UUID) {
        autoRules.removeAll { $0.goalId == goalId }
    }

    /// Should be called on app launch / resume to apply any due auto-deposits.
    func applyDueAutoDeposits(now: Date = Date()) {
        for i in autoRules.indices {
            let rule = autoRules[i]
            let checkpoints = dueCheckpoints(for: rule, upTo: now)
            guard !checkpoints.isEmpty else { continue }

            for date in checkpoints {
                _ = data.addTransaction(amount: rule.amount, goalId: rule.goalId, note: "Auto-deposit", tag: .other, date: date)
            }
            autoRules[i].lastApplied = checkpoints.max()
        }
    }

    // MARK: - Internal: Auto helpers

    private func dueCheckpoints(for rule: AutoRule, upTo now: Date) -> [Date] {
        let cal = Calendar.current
        let start = rule.lastApplied ?? rule.startDate
        guard start <= now else { return [] }

        var result: [Date] = []
        var current = nextOccurrence(after: start, freq: rule.frequency)

        while current <= now {
            result.append(current)
            current = nextOccurrence(after: current, freq: rule.frequency)
        }
        return result
    }

    private func nextOccurrence(after date: Date, freq: AutoFrequency) -> Date {
        let cal = Calendar.current
        switch freq {
        case .weekly:
            return cal.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly:
            return cal.date(byAdding: .month, value: 1, to: date) ?? date
        }
    }

    private func saveAutoRules() {
        if let data = try? JSONEncoder().encode(autoRules) {
            UserDefaults.standard.set(data, forKey: autoRulesKey)
        }
    }

    // MARK: - Streaks

    var currentStreakDays: Int {
        get { UserDefaults.standard.integer(forKey: streakDaysKey) }
        set { UserDefaults.standard.set(newValue, forKey: streakDaysKey) }
    }

    var lastDepositDate: Date? {
        get { UserDefaults.standard.object(forKey: streakLastDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: streakLastDateKey) }
    }

    var freezeTokens: Int {
        get { UserDefaults.standard.integer(forKey: freezeTokensKey) }
        set { UserDefaults.standard.set(newValue, forKey: freezeTokensKey) }
    }

    private func grantMonthlyFreezeTokenIfNeeded() {
        let cal = Calendar.current
        let now = Date()
        let currentYM = cal.dateComponents([.year, .month], from: now)
        let last = UserDefaults.standard.object(forKey: freezeLastGrantMonthKey) as? Date
        let lastYM = last.map { cal.dateComponents([.year, .month], from: $0) }

        if lastYM == nil || lastYM!.year != currentYM.year || lastYM!.month != currentYM.month {
            freezeTokens = min(freezeTokens + 1, 3) // cap at 3
            UserDefaults.standard.set(now, forKey: freezeLastGrantMonthKey)
        }
    }

    /// Register deposit date → update daily streak with 1-day grace using freeze token (optional).
    private func registerStreak(with date: Date) {
        let cal = Calendar.current

        if let last = lastDepositDate {
            let lastDay = cal.startOfDay(for: last)
            let today = cal.startOfDay(for: date)
            guard let diff = cal.dateComponents([.day], from: lastDay, to: today).day else {
                // fallback: just set to today
                lastDepositDate = date
                return
            }

            switch diff {
            case 0:
                // same day: streak unchanged
                lastDepositDate = date
            case 1:
                // consecutive day
                currentStreakDays += 1
                lastDepositDate = date
            case 2 where freezeTokens > 0:
                // used a freeze token to preserve streak (one missed day)
                freezeTokens -= 1
                currentStreakDays += 1
                lastDepositDate = date
            default:
                // streak broken
                currentStreakDays = 1
                lastDepositDate = date
            }
        } else {
            // first ever deposit
            currentStreakDays = 1
            lastDepositDate = date
        }
    }

    // MARK: - Achievements

    private func evaluateBasicMilestones() {
        let totalDeposits = data.transactions.count
        if totalDeposits == 1 {
            data.markChickenObtained(code: "first_deposit")
        }
        if totalDeposits >= 10 {
            data.markChickenObtained(code: "ten_deposits")
        }
        if currentStreakDays >= 7 {
            data.markChickenObtained(code: "streak_7")
        }
    }

    private func markMilestonesIfNeeded(saved: Decimal, target: Decimal) {
        let progress = NSDecimalNumber(decimal: saved).doubleValue / NSDecimalNumber(decimal: target).doubleValue
        if progress >= 0.25 { data.markChickenObtained(code: "quarter_25") }
        if progress >= 0.50 { data.markChickenObtained(code: "quarter_50") }
        if progress >= 0.75 { data.markChickenObtained(code: "quarter_75") }
        if progress >= 1.00 { data.markChickenObtained(code: "full_100") }
    }
    
    
    private func evaluateEventBased(for tx: Transaction) {
        let cal = Calendar.current

        // Lunar Night: 00:00–01:00
        let hour = cal.component(.hour, from: tx.date)
        if hour == 0 {
            data.markChickenObtained(code: "lunar_night")
        }

        // Morning Saver: 06:00–09:00
        if (6...8).contains(hour) { // включаем 06:00–08:59
            data.markChickenObtained(code: "morning_bird")
        }

        // Evening Saver: 20:00–23:00
        if (20...23).contains(hour) {
            data.markChickenObtained(code: "evening_saver")
        }

        // Generous Tuesday
        if cal.component(.weekday, from: tx.date) == 3 { // 1=Sun, 2=Mon, 3=Tue…
            data.markChickenObtained(code: "generous_tuesday")
        }

        // Lucky 777: integer part ends with 777
        if endsWith777(tx.amount) {
            data.markChickenObtained(code: "lucky_777")
        }

        // Palindrome Date: yyyyMMdd is palindrome
        if isPalindromeDate(tx.date) {
            data.markChickenObtained(code: "palindrome_date")
        }

        // Progress milestones: 25/50/75/100% of a fixed goal (if tx is linked to goal)
        if let gid = tx.goalId, let g = data.goal(by: gid),
           g.type == .fixed, let target = g.target, target > 0 {
            markMilestonesIfNeeded(saved: g.saved, target: target)
        }
    }

    private func evaluateEvolutions() {
        // Simple rule: streak gates evolution
        // 1+ days: chick, 7+ days: hen, 30+ days: golden
        let evo: Chicken.Evolution
        if currentStreakDays >= 30 {
            evo = .golden
        } else if currentStreakDays >= 7 {
            evo = .hen
        } else {
            evo = .chick
        }

        // Upgrade evolution on any obtained chickens that are below this stage
        for ch in data.chickens {
            guard ch.obtainedAt != nil else { continue }
            if shouldUpgrade(from: ch.evolution, to: evo) {
                data.markChickenObtained(code: ch.code, evolution: evo)
            }
        }
    }

    private func shouldUpgrade(from: Chicken.Evolution, to: Chicken.Evolution) -> Bool {
        func rank(_ e: Chicken.Evolution) -> Int {
            switch e {
            case .chick: return 0
            case .hen: return 1
            case .golden: return 2
            }
        }
        return rank(to) > rank(from)
    }

    // MARK: - Helpers

    private func bestWeekday(in txs: [Transaction]) -> String? {
        guard !txs.isEmpty else { return nil }
        let cal = Calendar.current
        var sums: [Int: Decimal] = [:] // weekday → sum
        for t in txs {
            let wd = cal.component(.weekday, from: t.date) // 1=Sun
            sums[wd, default: 0] += t.amount
        }
        if let best = sums.max(by: { $0.value < $1.value })?.key {
            let symbols = cal.weekdaySymbols // Sunday…Saturday
            let idx = (best - 1 + symbols.count) % symbols.count
            return symbols[idx]
        }
        return nil
    }

    private func endsWith777(_ amount: Decimal) -> Bool {
        // take integer part modulo 1000
        let ns = NSDecimalNumber(decimal: amount)
        let intValue = Int(truncating: ns)
        return intValue % 1000 == 777
    }

    private func isPalindromeDate(_ date: Date) -> Bool {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd"
        let s = f.string(from: date)
        return s == String(s.reversed())
    }
}
