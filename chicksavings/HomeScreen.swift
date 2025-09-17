import SwiftUI

struct HomeScreen: View {
    @StateObject private var vm = HomeVM()
    @EnvironmentObject private var appState: AppState

    // Navigation to Goals
    @State private var goToGoals: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ===== Total Saved card =====
                    VStack(spacing: 6) {
                        Text("Total Saved")
                            .font(.headline)
                        Text(totalSavedText())
                            .font(.largeTitle).bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 14).fill(.secondary.opacity(0.1)))

                    // ===== Get Started / Add Goal =====
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Get started")
                            .font(.headline)
                        Text("Create your first goal to start tracking your savings and unlock chickens.")
                            .foregroundStyle(.secondary)
                        HStack {
                            NavigationLink(destination: GoalsScreen(), isActive: $goToGoals) { EmptyView() }
                                .hidden()
                            Button {
                                goToGoals = true
                                HapticsManager.shared.selectionChanged()
                            } label: {
                                Label("Add Goal", systemImage: "plus.circle.fill")
                                    .font(.body.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 14).fill(.secondary.opacity(0.08)))

                    // ===== Week Stats =====
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This Week")
                            .font(.headline)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Added: \(formatCurrency(vm.weekStats.totalAdded))")
                                Text("To Goal: \(Int(vm.weekStats.percentToGoal * 100))%")
                                if !vm.weekStats.bestDay.isEmpty {
                                    Text("Best Day: \(vm.weekStats.bestDay)")
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 14).fill(.secondary.opacity(0.08)))

                    // ===== Recent (moved lower, clearer) =====
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent")
                            .font(.headline)
                        if vm.recentTransactions.isEmpty {
                            Text("No transactions yet.")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(vm.recentTransactions) { tx in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formatCurrency(tx.amount)).bold()
                                        Text(tx.tag.rawValue.capitalized)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(shortDate(tx.date))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 6)
                                Divider()
                                    .opacity(tx.id == vm.recentTransactions.last?.id ? 0 : 1)
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 14).strokeBorder(.secondary.opacity(0.15)))
                }
                .padding()
            }
            .navigationTitle("Home")
            .onAppear { vm.refresh() }
        }
    }

    // MARK: - Helpers
    private func totalSavedText() -> String {
        // Show dash if nothing saved (or zero)
        if vm.totalSaved == 0 {
            return "—"
        } else {
            return formatCurrency(vm.totalSaved)
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let f = data.currencyFormatter(currencyCode: appState.currencyCode,
                                       grouping: appState.useGroupingSeparator)
        return f.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }

    private var data: DataEngine { DataEngine.shared }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        return f.string(from: date)
    }
}
