import SwiftUI
import WebKit

struct WebBrowserView: UIViewRepresentable {
    let url: URL
    let isYouTube: Bool
    var settings: SiteShieldSettings = SiteShieldSettings()

    func makeUIView(context: Context) -> WKWebView {
        let config = AdBlockEngine.shared.makeConfiguration(settings: settings, isYouTube: isYouTube)
        let webView = WKWebView(frame: .zero, configuration: config)

        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.decelerationRate = .normal
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .black

        // Custom User-Agent chuẩn iOS 15.4 Mobile Safari
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Mobile/15E148 Safari/604.1"

        let request = URLRequest(url: url)
        webView.load(request)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
