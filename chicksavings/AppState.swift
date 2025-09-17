import SwiftUI
import Combine

class AppState: ObservableObject {
    // Currency and formatting
    @Published var currencyCode: String = "USD"
    @Published var useGroupingSeparator: Bool = true

    // Theme
    enum Theme: String, CaseIterable {
        case light, dark, seasonal
    }
    @Published var theme: Theme = .light

    // Haptics
    @Published var hapticsEnabled: Bool = true

    // Example: save settings persistently
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Load saved values
        if let savedCurrency = UserDefaults.standard.string(forKey: "currencyCode") {
            self.currencyCode = savedCurrency
        }
        if let savedTheme = UserDefaults.standard.string(forKey: "theme"),
           let theme = Theme(rawValue: savedTheme) {
            self.theme = theme
        }
        self.useGroupingSeparator = UserDefaults.standard.bool(forKey: "useGroupingSeparator")
        self.hapticsEnabled = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true

        // Observe and save
        $currencyCode
            .sink { UserDefaults.standard.set($0, forKey: "currencyCode") }
            .store(in: &cancellables)

        $theme
            .sink { UserDefaults.standard.set($0.rawValue, forKey: "theme") }
            .store(in: &cancellables)

        $useGroupingSeparator
            .sink { UserDefaults.standard.set($0, forKey: "useGroupingSeparator") }
            .store(in: &cancellables)

        $hapticsEnabled
            .sink { UserDefaults.standard.set($0, forKey: "hapticsEnabled") }
            .store(in: &cancellables)
    }
}
