import SwiftUI

struct RootTabView: View {
    enum Tab { case home, goals, ledger, chickens, settings }
    @State private var selection: Tab = .home

    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $selection) {
            // Home
            HomeScreen()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

            // Goals
            GoalsScreen()
                .tabItem { Label("Goals", systemImage: "target") }
                .tag(Tab.goals)

            // Ledger
            LedgerScreen()
                .tabItem { Label("Ledger", systemImage: "list.bullet") }
                .tag(Tab.ledger)

            // Chickens
            ChickensScreen()
                .tabItem { Label("Achievements", systemImage: "bird") }
                .tag(Tab.chickens)

            // Settings (with built-in Privacy)
            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(Tab.settings)
        }
        .onChange(of: selection) { _ in
            HapticsManager.shared.selectionChanged()
        }
        .preferredColorScheme(colorSchemeForTheme(appState.theme))
    }

    // Map AppState theme to SwiftUI color scheme (seasonal → system)
    private func colorSchemeForTheme(_ theme: AppState.Theme) -> ColorScheme? {
        switch theme {
        case .light: return .light
        case .dark:  return .dark
        case .seasonal: return nil
        }
    }
}
