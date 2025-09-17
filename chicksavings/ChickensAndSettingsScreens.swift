import SwiftUI
import WebKit

// MARK: - Chickens Screen

struct ChickensScreen: View {
    @StateObject private var vm = ChickensVM()

    var body: some View {
        NavigationStack {
            List {
                Section("Obtained") {
                    if vm.obtained.isEmpty {
                        Text("No Achievements yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(vm.obtained) { ch in
                            ChickenRow(chicken: ch)
                        }
                    }
                }
                Section("Locked") {
                    ForEach(vm.locked) { ch in
                        ChickenRow(chicken: ch, locked: true)
                    }
                }
            }
            .navigationTitle("Achievements")
            .onAppear { vm.refresh() }
        }
    }
}

private struct ChickenRow: View {
    let chicken: Chicken
    var locked: Bool = false

    var body: some View {
        HStack {
            Image(systemName: locked ? "lock.fill" : "checkmark.seal.fill")
                .foregroundColor(locked ? .gray : .green)
            VStack(alignment: .leading) {
                Text(chicken.title)
                    .font(.headline)
                Text(locked ? "Locked" : chicken.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !locked {
                VStack(alignment: .trailing) {
                    Text(chicken.rarity.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(chicken.evolution.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let date = chicken.obtainedAt {
                        Text(shortDate(date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        return f.string(from: date)
    }
}

// MARK: - Settings Screen (with Privacy page)

struct SettingsScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var showPrivacy = false

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Picker("Currency", selection: $appState.currencyCode) {
                        Text("USD").tag("USD")
                        Text("EUR").tag("EUR")
                        Text("GBP").tag("GBP")
                    }
                    Toggle("Use Grouping Separator", isOn: $appState.useGroupingSeparator)
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appState.theme) {
                        Text("Light").tag(AppState.Theme.light)
                        Text("Dark").tag(AppState.Theme.dark)
                        Text("Seasonal").tag(AppState.Theme.seasonal)
                    }
                }

                Section("Feedback") {
                    Toggle("Haptics", isOn: $appState.hapticsEnabled)
                }

                Section {
                    Button("Privacy") { showPrivacy = true }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPrivacy) {
                PrivacyPage()
            }
        }
    }
}

// MARK: - Privacy Page (neutral naming)

struct PrivacyPage: View {
    var body: some View {
        NavigationStack {
            InternalBrowser(url: URL(string: "https://google.com")!)
                .navigationTitle("Privacy")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct InternalBrowser: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}
