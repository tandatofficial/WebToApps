import Foundation
import WebKit

class AdBlockEngine {
    static let shared = AdBlockEngine()
    var compiledRules: WKContentRuleList?

    let aggressiveAdHideCSS = """
    .float-ck, .banner-left, .banner-right, .ads-sticky, #popup-ads,
    #banner-bottom, .catfish-banner, .balloon, #ads_fixed, .floating-ads,
    div[id*='banner'], div[class*='banner'], div[id*='adv'], div[class*='adv'],
    .player-ads, #ad-overlay, .jw-banner, .jw-ads, .jw-ad, .video-ads-overlay,
    .adsbygoogle, ytm-promoted-sparkles-web-renderer, ytm-companion-ad-renderer,
    div[class*='ad-box'], div[id^='ad-slot'], div[class*='advertisement'],
    a[href*='bet'], a[href*='casino'], a[href*='nohu'], a[href*='taixiu'],
    a[href*='kubet'], a[href*='shbet'], a[href*='sunwin'], a[href*='go88'], a[href*='b52'],
    iframe[src*='doubleclick'], iframe[src*='googleads'], iframe[src*='adnxs'],
    iframe[src*='exoclick'], iframe[src*='adsterra'], iframe[src*='propellerads'],
    div[style*='z-index: 999999'], div[style*='z-index: 2147483647'] {
        display: none !important;
        visibility: hidden !important;
        opacity: 0 !important;
        pointer-events: none !important;
        height: 0 !important;
        width: 0 !important;
        position: absolute !important;
        top: -9999px !important;
    }
    """

    let coreEngineJS = """
    (function() {
        'use strict';
        const isAdUrl = (url) => {
            if (!url || typeof url !== 'string') return false;
            return /(vast|vpaid|ima3|doubleclick|googleads|gmsg|pagead|preroll|midroll|ads\\.xml|ad\\.m3u8|sponsor|promo|bet88|kubet|sunwin|nohu|casino)/i.test(url);
        };

        // Bẻ gãy gán link video quảng cáo
        const originalSrcDescriptor = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'src');
        if (originalSrcDescriptor && originalSrcDescriptor.set) {
            Object.defineProperty(HTMLMediaElement.prototype, 'src', {
                set: function(val) {
                    if (isAdUrl(val)) {
                        console.log("[AdGuard Extension] Blocked Video Ad URL:", val);
                        return;
                    }
                    return originalSrcDescriptor.set.call(this, val);
                },
                get: function() { return originalSrcDescriptor.get.call(this); }
            });
        }

        // Tự động tua hết video quảng cáo
        const originalPlay = HTMLMediaElement.prototype.play;
        HTMLMediaElement.prototype.play = function() {
            const v = this;
            const src = v.currentSrc || v.src || '';
            const d = v.duration;
            if (isAdUrl(src) || (d > 0 && d <= 35 && (v.closest('[class*="ad"]') || v.closest('[id*="ad"]')))) {
                v.muted = true;
                v.currentTime = d || 9999;
                return Promise.resolve();
            }
            return originalPlay.apply(this, arguments);
        };

        // Chặn window.open và popup nhảy tab
        window.open = function() { return null; };

        // Xóa sạch phần tử quảng cáo liên tục
        const wipe = () => {
            document.querySelectorAll(".float-ck, .banner-left, .banner-right, #popup-ads, .floating-ads, a[href*='bet'], a[href*='casino'], .jw-ads, .player-ads, #ad-overlay, .adsbygoogle").forEach(e => e.remove());
            document.querySelectorAll('.ytp-ad-skip-button, .jw-skip, .videojs-ad-skip').forEach(b => b.click());
        };
        setInterval(wipe, 180);
        document.addEventListener('DOMContentLoaded', wipe);
    })();
    """

    init() {
        compileRules()
    }

    func compileRules() {
        let blockJSON = """
        [
            {
                "trigger": {
                    "url-filter": ".*(vast|vpaid|ima3|doubleclick|googleads|googlesyndication|pagead|exoclick|popads|propellerads|popcash|adnxs|trafficjunky|adsterra|hilltopads|clickadu|juicyads|mgid|admatic|yadro).*"
                },
                "action": { "type": "block" }
            },
            {
                "trigger": {
                    "url-filter": ".*(kubet|shbet|sunwin|go88|b52club|taixiu|keonhacai|fb88|w88|fun88|m88|bk8|jun88|789bet|new88|hi88|rikvip|iwin68|188bet|dafabet|v9bet|oppa888|happyluke).*"
                },
                "action": { "type": "block" }
            },
            {
                "trigger": { "url-filter": ".*" },
                "action": {
                    "type": "css-display-none",
                    "selector": ".float-ck, .banner-left, .banner-right, #popup-ads, .floating-ads, a[href*='bet'], a[href*='casino'], .catfish-banner, .ads-sticky, .jw-ads, .jw-ad, .player-ads, #ad-overlay, .adsbygoogle"
                }
            }
        ]
        """

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "AdGuardExtensionRuleset",
            encodedContentRuleList: blockJSON
        ) { [weak self] ruleList, error in
            if let error = error {
                print("[AdGuard] Error: \(error)")
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

        // 1. Inject Stylesheet CSS diệt banner
        let cssScript = """
        const style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = `\(aggressiveAdHideCSS)`;
        document.head ? document.head.appendChild(style) : document.documentElement.appendChild(style);
        """
        userContent.addUserScript(WKUserScript(source: cssScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        // 2. Inject Core Prototype Video Ad Interceptor
        userContent.addUserScript(WKUserScript(source: coreEngineJS, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        // 3. Inject các UserScripts / Extensions đang kích hoạt từ ExtensionStore
        for script in ExtensionStore.shared.userScripts where script.isEnabled {
            let userScript = WKUserScript(source: script.code, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            userContent.addUserScript(userScript)
        }

        return config
    }
}
