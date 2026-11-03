import Foundation
import WebKit

class AdBlockEngine {
    static let shared = AdBlockEngine()
    var compiledRules: WKContentRuleList?

    // Custom CSS and JavaScript injection to nuke YouTube video ads and cosmetic banners
    let youtubeAdblockScript = """
    (function() {
        // Auto skip video ads
        setInterval(() => {
            const ad = document.querySelector('.ad-showing, .ad-container');
            const video = document.querySelector('video');
            if (ad && video) {
                video.currentTime = video.duration || 9999;
            }
            const skipBtn = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button');
            if (skipBtn) {
                skipBtn.click();
            }
            // Remove promo banners
            const banners = document.querySelectorAll('ytm-promoted-sparkles-web-renderer, ytm-companion-ad-renderer, .ad-banner');
            banners.forEach(b => b.remove());
        }, 300);
    })();
    """

    init() {
        compileRules()
    }

    func compileRules() {
        let rulesJSON = """
        [
            {
                "trigger": { "url-filter": ".*(googleads|doubleclick|pagead2|googlesyndication|adservice).*"},
                "action": { "type": "block" }
            },
            {
                "trigger": { "url-filter": ".*" },
                "action": {
                    "type": "css-display-none",
                    "selector": ".ad, .ads, .ad-banner, .adsbygoogle, ytm-promoted-sparkles-web-renderer"
                }
            }
        ]
        """

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "QuickWebAdBlockerRules",
            encodedContentRuleList: rulesJSON
        ) { [weak self] ruleList, error in
            if let error = error {
                print("AdBlock compilation error: \(error)")
                return
            }
            self?.compiledRules = ruleList
        }
    }

    func makeConfiguration(isYouTube: Bool = false) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let userContent = config.userContentController
        if let rules = compiledRules {
            userContent.add(rules)
        }

        if isYouTube {
            let script = WKUserScript(source: youtubeAdblockScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            userContent.addUserScript(script)
        }

        return config
    }
}
