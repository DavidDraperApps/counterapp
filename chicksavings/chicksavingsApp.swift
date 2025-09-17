import SwiftUI

@main
struct ChickSavingsApp: App {
    // Global app state (settings, data engines, etc.)
    @StateObject private var appState = AppState()

    
    
    @Environment(\.scenePhase) private var scenePhase
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        NotificationCenter.default.post(name: Notification.Name("art.icon.loading.start"), object: nil)
        IconSettings.shared.attach()

        
    }
    
    
    
    
    var body: some Scene {
        WindowGroup {
            TabSettingsView{
                RootTabView()
                    .environmentObject(appState)
            }
            
            
            .onAppear {
                OrientationGate.allowAll = false
            }
            
            
        }
    }
    
    
    
    final class AppDelegate: NSObject, UIApplicationDelegate {
        func application(_ application: UIApplication,
                         supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
            if OrientationGate.allowAll {
                return [.portrait, .landscapeLeft, .landscapeRight]
            } else {
                return [.portrait]
            }
        }
    }
    
    
    
    
    
    
    
}
