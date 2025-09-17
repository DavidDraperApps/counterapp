import Foundation

// MARK: - Goal
struct Goal: Identifiable, Codable, Hashable {
    enum GoalType: String, Codable {
        case fixed
        case uncapped
    }

    let id: UUID
    var name: String
    var type: GoalType
    var target: Decimal? // nil if uncapped
    var saved: Decimal
    var deadline: Date?

    init(name: String,
         type: GoalType = .fixed,
         target: Decimal? = nil,
         saved: Decimal = 0,
         deadline: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.target = target
        self.saved = saved
        self.deadline = deadline
    }
}

// MARK: - Transaction
struct Transaction: Identifiable, Codable, Hashable {
    enum Tag: String, Codable, CaseIterable {
        case salary, cashback, coins, gift, other
    }

    let id: UUID
    var date: Date
    var amount: Decimal // positive = deposit
    var goalId: UUID?
    var note: String?
    var tag: Tag

    init(amount: Decimal,
         goalId: UUID? = nil,
         note: String? = nil,
         tag: Tag = .other) {
        self.id = UUID()
        self.date = Date()
        self.amount = amount
        self.goalId = goalId
        self.note = note
        self.tag = tag
    }
}

// MARK: - Chicken (Achievement)
struct Chicken: Identifiable, Codable, Hashable {
    enum Rarity: String, Codable {
        case common, rare, epic, legendary
    }

    enum Evolution: String, Codable {
        case chick, hen, golden
    }

    let id: UUID
    var code: String // e.g. "first_deposit"
    var title: String
    var description: String
    var rarity: Rarity
    var evolution: Evolution
    var obtainedAt: Date?

    init(code: String,
         title: String,
         description: String,
         rarity: Rarity = .common,
         evolution: Evolution = .chick,
         obtainedAt: Date? = nil) {
        self.id = UUID()
        self.code = code
        self.title = title
        self.description = description
        self.rarity = rarity
        self.evolution = evolution
        self.obtainedAt = obtainedAt
    }
}

// MARK: - Week Stats
struct WeekStats: Codable, Hashable {
    var totalAdded: Decimal
    var percentToGoal: Double
    var bestDay: String // e.g. "Tuesday"

    init(totalAdded: Decimal = 0,
         percentToGoal: Double = 0,
         bestDay: String = "") {
        self.totalAdded = totalAdded
        self.percentToGoal = percentToGoal
        self.bestDay = bestDay
    }
}
