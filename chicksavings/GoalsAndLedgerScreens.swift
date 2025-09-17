import SwiftUI

// MARK: - Goals Screen + Ledger Screen (with strict numeric inputs)

struct GoalsScreen: View {
    @StateObject private var vm = GoalsVM()
    @EnvironmentObject private var appState: AppState
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(vm.goals) { goal in
                        GoalRow(goal: goal,
                                progress: vm.progress(for: goal),
                                remainder: vm.remainder(for: goal),
                                tenPercent: vm.tenPercent(for: goal),
                                onAddRemainder: { vm.updateGoalAddRemainder(goal) },
                                onAddTenPercent: { vm.updateGoalAddTenPercent(goal) })
                        .contextMenu {
                            Button("Delete", role: .destructive) { vm.deleteGoal(goal) }
                        }
                    }
                    .onDelete { idxSet in
                        idxSet.map { vm.goals[$0] }.forEach(vm.deleteGoal)
                    }
                } header: {
                    Text("Your Goals")
                }

                Section {
                    Button {
                        showAddSheet = true
                        HapticsManager.shared.selectionChanged()
                    } label: {
                        Label("Add Goal", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Goals")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { EditButton() } }
            .sheet(isPresented: $showAddSheet) {
                AddGoalSheet { name, type, target, deadline in
                    vm.createGoal(name: name, type: type, target: target, deadline: deadline)
                }
                .presentationDetents([.height(460), .medium])
            }
        }
    }
}

// Row with progress and quick calculators
private struct GoalRow: View {
    let goal: Goal
    let progress: Double
    let remainder: Decimal?
    let tenPercent: Decimal?
    var onAddRemainder: () -> Void
    var onAddTenPercent: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.name).font(.headline)
                Spacer()
                Text(goal.type == .fixed ? "Fixed" : "No cap")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            if goal.type == .fixed, let target = goal.target {
                ProgressView(value: progress)
                HStack(spacing: 12) {
                    Text("Saved: \(fmt(goal.saved))")
                    Text("Target: \(fmt(target))")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else {
                Text("Saved: \(fmt(goal.saved))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if let t = tenPercent, t > 0 {
                    Button("Add 10% (\(fmt(t)))") { onAddTenPercent() }
                        .buttonStyle(.borderedProminent)
                }
                if let r = remainder, r > 0 {
                    Button("To Target (\(fmt(r)))") { onAddRemainder() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func fmt(_ d: Decimal) -> String {
        let n = NSDecimalNumber(decimal: d)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f.string(from: n) ?? "\(d)"
    }
}

// Add goal sheet — Target amount: digits only
private struct AddGoalSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var type: Goal.GoalType = .fixed
    @State private var targetStr: String = ""
    @State private var deadline: Date? = nil
    @State private var useDeadline = false

    @State private var targetHasNonDigits: Bool = false

    let onCreate: (_ name: String, _ type: Goal.GoalType, _ target: Decimal?, _ deadline: Date?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    TextField("Name", text: $name)

                    Picker("Type", selection: $type) {
                        Text("Fixed").tag(Goal.GoalType.fixed)
                        Text("No cap").tag(Goal.GoalType.uncapped)
                    }

                    if type == .fixed {
                        TextField("Target amount (digits only)", text: $targetStr)
                            .keyboardType(.numberPad)
                            .onChange(of: targetStr) { newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                targetHasNonDigits = (filtered != newValue) && !newValue.isEmpty
                                if filtered != newValue { targetStr = filtered }
                            }
                        if targetHasNonDigits {
                            Text("Digits only are allowed.").foregroundColor(.red).font(.caption)
                        }
                    }

                    Toggle("Deadline", isOn: $useDeadline)
                    if useDeadline {
                        DatePicker(
                            "Pick date",
                            selection: Binding(
                                get: { deadline ?? Date() },
                                set: { deadline = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }
            }
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let targetDec: Decimal? = (type == .fixed) ? Decimal(string: targetStr) : nil
                        onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines),
                                 type,
                                 targetDec,
                                 useDeadline ? deadline : nil)
                        dismiss()
                    }
                    .disabled(!canCreate)
                }
            }
        }
    }

    private var canCreate: Bool {
        let nameOK = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if type == .uncapped { return nameOK }
        // fixed:
        return nameOK && !targetStr.isEmpty && !targetHasNonDigits && Decimal(string: targetStr) != nil
    }
}

// MARK: - GoalsVM convenience remains

private extension GoalsVM {
    func updateGoalAddTenPercent(_ goal: Goal) {
        guard let amount = tenPercent(for: goal) else { return }
        _ = DataEngine.shared.addTransaction(amount: amount, goalId: goal.id, note: "10% of goal", tag: .other)
        if let last = DataEngine.shared.recentTransactions(limit: 1).first {
            LogicEngine.shared.processAfterTransaction(last)
        }
        HapticsManager.shared.impact(.light)
        refresh()
    }

    func updateGoalAddRemainder(_ goal: Goal) {
        guard let amount = remainder(for: goal) else { return }
        _ = DataEngine.shared.addTransaction(amount: amount, goalId: goal.id, note: "Remainder to target", tag: .other)
        if let last = DataEngine.shared.recentTransactions(limit: 1).first {
            LogicEngine.shared.processAfterTransaction(last)
        }
        HapticsManager.shared.success()
        refresh()
    }
}

// MARK: - Ledger Screen

struct LedgerScreen: View {
    @StateObject private var vm = LedgerVM()
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Menu {
                            Button("All Tags") { vm.setFilter(tag: nil) }
                            ForEach(Transaction.Tag.allCases, id: \.self) { t in
                                Button(t.rawValue.capitalized) { vm.setFilter(tag: t) }
                            }
                        } label: {
                            Label(vm.selectedTag?.rawValue.capitalized ?? "All Tags", systemImage: "tag")
                                .padding(8)
                                .background(Capsule().fill(.secondary.opacity(0.15)))
                        }

                        Menu {
                            Button("All Goals") { vm.setFilter(goalId: nil) }
                            ForEach(DataEngine.shared.goals) { g in
                                Button(g.name) { vm.setFilter(goalId: g.id) }
                            }
                        } label: {
                            Label(labelForGoal(vm.selectedGoalId), systemImage: "target")
                                .padding(8)
                                .background(Capsule().fill(.secondary.opacity(0.15)))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                List {
                    Section {
                        ForEach(vm.transactions) { tx in
                            TransactionRowView(tx: tx)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        vm.deleteTransaction(tx)
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    } header: {
                        Text("Transactions")
                    }
                }
            }
            .navigationTitle("Ledger")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showAdd = true
                        HapticsManager.shared.selectionChanged()
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddTransactionSheet(vm: vm)
                    .presentationDetents([.height(460), .medium])
            }
        }
    }

    private func labelForGoal(_ id: UUID?) -> String {
        guard let id, let goal = DataEngine.shared.goal(by: id) else { return "All Goals" }
        return goal.name
    }
}

// Transaction row
private struct TransactionRowView: View {
    let tx: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatAmount(tx.amount)).bold()
                Text(tx.tag.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let note = tx.note, !note.isEmpty {
                    Text(note).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(shortDate(tx.date))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = (UserDefaults.standard.string(forKey: "currencyCode") ?? "USD")
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        return f.string(from: date)
    }
}

// Add transaction sheet — Amount: digits only
private struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: LedgerVM

    @State private var amountText: String = ""
    @State private var amountHasNonDigits: Bool = false

    @State private var note: String = ""
    @State private var selectedTag: Transaction.Tag = .other
    @State private var selectedGoalId: UUID? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField("0", text: $amountText)
                        .keyboardType(.numberPad)
                        .onChange(of: amountText) { newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            amountHasNonDigits = (filtered != newValue) && !newValue.isEmpty
                            if filtered != newValue { amountText = filtered }
                        }
                    if amountHasNonDigits {
                        Text("Digits only are allowed.").foregroundColor(.red).font(.caption)
                    }

                    // Presets (add whole integers)
                    HStack {
                        ForEach(vm.presets, id: \.self) { p in
                            Button("+\(plain(p))") {
                                let current = Decimal(string: amountText) ?? 0
                                let sum = current + p
                                amountText = plain(sum)
                                HapticsManager.shared.impact(.light)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Section("Goal & Tag") {
                    Picker("Goal", selection: Binding(get: { selectedGoalId },
                                                     set: { selectedGoalId = $0 })) {
                        Text("None").tag(nil as UUID?)
                        ForEach(DataEngine.shared.goals) { g in
                            Text(g.name).tag(g.id as UUID?)
                        }
                    }

                    Picker("Tag", selection: $selectedTag) {
                        ForEach(Transaction.Tag.allCases, id: \.self) { t in
                            Text(t.rawValue.capitalized).tag(t)
                        }
                    }
                }

                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                }

                if let gid = selectedGoalId, let goal = DataEngine.shared.goal(by: gid) {
                    Section("Calculator") {
                        HStack {
                            if let ten = vm.tenPercent(of: goal), ten > 0 {
                                Button("10% (\(plain(ten)))") {
                                    amountText = plain(ten)
                                    HapticsManager.shared.selectionChanged()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            if let rem = vm.remainder(to: goal), rem > 0 {
                                Button("Remainder (\(plain(rem)))") {
                                    amountText = plain(rem)
                                    HapticsManager.shared.selectionChanged()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        vm.draftAmount = Decimal(string: amountText) ?? 0
                        vm.draftNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        vm.draftTag = selectedTag
                        vm.draftGoalId = selectedGoalId
                        vm.addTransaction()
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
            .onAppear {
                selectedGoalId = vm.selectedGoalId
                selectedTag = vm.selectedTag ?? .other
            }
        }
    }

    private var canAdd: Bool {
        !amountText.isEmpty && !amountHasNonDigits && Decimal(string: amountText) != 0
    }

    private func plain(_ d: Decimal) -> String {
        let n = NSDecimalNumber(decimal: d)
        let f = NumberFormatter()
        f.numberStyle = .none
        return f.string(from: n) ?? "\(d)"
    }
}
