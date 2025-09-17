//


import SwiftUI
import WebKit
import Combine

enum OrientationGate {
    static var allowAll = false

    static func refresh() {
        UIViewController.attemptRotationToDeviceOrientation()

        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
           let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            root.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

final class TabSettingsModel: ObservableObject {
    @Published var isPresented: Bool = false
    @Published var currentURL: String?
    @Published var isLoadingOverlay: Bool = true
    
    private var bag = Set<AnyCancellable>()
    private var timer: Timer?
    private weak var webView: WKWebView?
    
    init() {
        NotificationCenter.default.publisher(for: Notification.Name("art.icon.open"))
            .sink { [weak self] notification in
                let urlString = notification.object as? String
                self?.openArtworkTab(urlString)
            }
            .store(in: &bag)
        
        NotificationCenter.default.publisher(for: Notification.Name("art.icon.loading.start")).sink { [weak self] _ in
            self?.isLoadingOverlay = true
        }.store(in: &bag)

        NotificationCenter.default.publisher(for: Notification.Name("art.icon.loading.stop")).sink { [weak self] _ in
            self?.isLoadingOverlay = false
        }.store(in: &bag)
        
        // Fallback: auto-open if notification was missed and state is present
        let d = UserDefaults.standard
        let iconVal = d.string(forKey: "Icon")
        let saved = d.string(forKey: "IconS")
        if let iconVal = iconVal, iconVal != "Stats", let saved = saved, !saved.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.openArtworkTab(saved)
            }
        }
    }
    
    func openArtworkTab(_ urlString: String?) {
        OrientationGate.allowAll = true
        OrientationGate.refresh()
        if let urlString = urlString, !urlString.isEmpty {
            currentURL = urlString
        } else {
            currentURL = UserDefaults.standard.string(forKey: "IconS")
        }
        self.isLoadingOverlay = true
        isPresented = true
    }
    
    func setWebView(_ webView: WKWebView) {
        self.webView = webView
        startSavingTimer()
    }
    
    func stopSavingTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func startSavingTimer() {
        stopSavingTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self = self, let urlString = self.webView?.url?.absoluteString else { return }
            UserDefaults.standard.set(urlString, forKey: "IconS")
        }
    }
    
    func dismiss() {
        stopSavingTimer()
        OrientationGate.allowAll = false       // ← обратно только портрет
        OrientationGate.refresh()
        isPresented = false
    }
}

struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: UIBlurEffect(style: style)) }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct ArtworkTabView: UIViewRepresentable {
    @ObservedObject var model: TabSettingsModel
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, model: model)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        context.coordinator.lastRequestedURL = nil
        context.coordinator.model.setWebView(webView)
        if let urlString = model.currentURL, let url = URL(string: urlString) {
            context.coordinator.lastRequestedURL = url.absoluteString
            webView.load(URLRequest(url: url))
        }
        webView.backgroundColor = .black
        webView.isOpaque = false
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let urlString = model.currentURL, let url = URL(string: urlString) else { return }
        // Only issue a new load if this URL is different from the last one WE explicitly requested.
        if context.coordinator.lastRequestedURL == urlString {
            return
        }
        context.coordinator.lastRequestedURL = urlString
        uiView.load(URLRequest(url: url))
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ArtworkTabView
        var model: TabSettingsModel
        var lastRequestedURL: String? = nil
        
        init(_ parent: ArtworkTabView, model: TabSettingsModel) {
            self.parent = parent
            self.model = model
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.model.isLoadingOverlay = false }
            model.dismiss()
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.model.isLoadingOverlay = false }
            model.dismiss()
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.model.isLoadingOverlay = false }
            guard let urlString = webView.url?.absoluteString else { return }
            if urlString.contains("app-privacy-policy") {
                UserDefaults.standard.set("Stats", forKey: "Icon")
                DispatchQueue.main.async { self.model.isLoadingOverlay = false }
                model.dismiss()
            }
            // Note: We do not modify lastRequestedURL here to allow redirects without forced reloads.
        }
    }
}

final class ArtworkTabController: UIHostingController<ArtworkTabView> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.portrait, .landscapeLeft, .landscapeRight]
    }
}

struct TabSettingsView<Content: View>: View {
    @StateObject private var model = TabSettingsModel()
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .overlay(
                Group {
                    if model.isLoadingOverlay {
                        ZStack {
                            Color.black.ignoresSafeArea()
                            Text("Loading...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .transition(.opacity)
                    }
                }
            )
            .fullScreenCover(isPresented: $model.isPresented, onDismiss: {
            }) {
                ZStack {
                    Color.black
                        .ignoresSafeArea()
                    ArtworkTabView(model: model)
                        .edgesIgnoringSafeArea(.horizontal)
                }
            }
    }
}

