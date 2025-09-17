import Foundation
import UIKit

/// Simple haptics wrapper that respects the user's toggle saved in UserDefaults under "hapticsEnabled".
/// Works with impact, notification, and selection types. Safe to call from anywhere on main thread.
enum HapticImpactStyle {
    case light, medium, heavy, soft, rigid
}

@MainActor
final class HapticsManager {
    static let shared = HapticsManager()

    private init() {}

    // Read the current setting every time to stay in sync with AppState without wiring.
    private var isEnabled: Bool {
        (UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool) ?? true
    }

    // MARK: - Public API

    func impact(_ style: HapticImpactStyle) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style.toUIKit())
        generator.prepare()
        generator.impactOccurred()
    }

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    func selectionChanged() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    // Conveniences
    func success() { notification(.success) }
    func warning() { notification(.warning) }
    func error()   { notification(.error) }

    /// Call before a series of haptics to reduce latency.
    func warmup() {
        guard isEnabled else { return }
        // Warming common generators; iOS will manage power efficiently.
        UIImpactFeedbackGenerator(style: .light).prepare()
        UISelectionFeedbackGenerator().prepare()
    }
}

// MARK: - Mapping
private extension HapticImpactStyle {
    func toUIKit() -> UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light:  return .light
        case .medium: return .medium
        case .heavy:  return .heavy
        case .soft:   return .soft
        case .rigid:  return .rigid
        }
    }
}
