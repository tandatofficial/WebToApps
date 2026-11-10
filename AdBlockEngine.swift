import Foundation
import WebKit

class AdBlockEngine {
    static let shared = AdBlockEngine()
    var compiledRules: WKContentRuleList?

    let aggressiveAdHideCSS = """
    .stream-guard, .stream-guard-card, .stream-guard-notice,
    .float-ck, .banner-left, .banner-right, .ads-sticky, #popup-ads,
    #banner-bottom, .catfish-banner, .balloon, #ads_fixed, .floating-ads,
    div[id*='banner'], div[class*='banner'], div[id*='adv'], div[class*='adv'],
    .player-ads, #ad-overlay, .jw-banner, .jw-ads, .jw-ad, .video-ads-overlay,
    .adsbygoogle, ytm-promoted-sparkles-web-renderer,
    div[class*='ad-box'], div[id^='ad-slot'], div[class*='advertisement'],
    a[href*='bet'], a[href*='casino'], a[href*='nohu'], a[href*='taixiu'],
    a[href*='kubet'], a[href*='shbet'], a[href*='sunwin'], a[href*='go88'], a[href*='b52'],
    div[id*='spot_id'], div[class*='spot_id'], [data-ad], [data-zone],
    .ad-container, .ad-player, .ad-placeholder,
    iframe[src*='exoclick'], iframe[src*='trafficjunky'], iframe[src*='juicyads'],
    div[style*='z-index: 999999'], div[style*='z-index: 2147483647'] {
        display: none !important;
        visibility: hidden !important;
        opacity: 0 !important;
        pointer-events: none !important;
        height: 0 !important;
        width: 0 !important;
    }
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
                    "selector": ".stream-guard, .stream-guard-card, .float-ck, .banner-left, .banner-right, #popup-ads, .floating-ads, a[href*='bet'], a[href*='casino'], .catfish-banner, .ads-sticky, .jw-ads, .jw-ad, .player-ads, #ad-overlay, .ad-container, [data-ad]"
                }
            }
        ]
        """

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "AdGuardConfigurableRuleset",
            encodedContentRuleList: blockJSON
        ) { [weak self] ruleList, error in
            if let error = error {
                print("[AdBlockEngine] Compile Error: \(error)")
                return
            }
            self?.compiledRules = ruleList
        }
    }

    func makeConfiguration(settings: SiteShieldSettings = SiteShieldSettings(), isYouTube: Bool = false) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let userContent = config.userContentController

        // 1. Chỉ thêm quy tắc mạng chặn quảng cáo khi được BẬT
        if settings.adBlockEnabled, let rules = compiledRules {
            userContent.add(rules)
        }

        // 2. Chỉ tiêm CSS ẩn banner khi được BẬT
        if settings.adBlockEnabled {
            let cssScript = """
            const style = document.createElement('style');
            style.type = 'text/css';
            style.innerHTML = `\(aggressiveAdHideCSS)`;
            document.head ? document.head.appendChild(style) : document.documentElement.appendChild(style);
            """
            userContent.addUserScript(WKUserScript(source: cssScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        }

        // 3. Xây dựng Script tùy biến động theo cài đặt của từng trang web
        let customScript = """
        (function() {
            'use strict';

            const blockPopups = \(settings.blockPopups);
            const autoSkipVideoAds = \(settings.autoSkipVideoAds);
            const antiAdblockDefuser = \(settings.antiAdblockDefuser);

            // A. Chặn popup nhảy tab
            if (blockPopups) {
                window.open = function() { return null; };
                window.streamAdsLoaded = true;
            }

            // B. Anti-Adblock Defuser (Nguồn C / StreamGuard)
            if (antiAdblockDefuser) {
                try {
                    window.streamGuard = {
                        version: "guard-7",
                        status: () => ({ blocked: false, antiAdblock: false }),
                        ready: Promise.resolve(),
                        isBlocked: () => false,
                        reportAdResource: () => {},
                        waitForAccess: () => Promise.resolve(),
                        registerPlayer: () => {}
                    };
                    window.canRunAds = true;
                    window.isAdBlockActive = false;
                } catch(e) {}
            }

            // C. Chỉ tự động tua video quảng cáo khi người dùng chủ động BẬT tùy chọn này
            if (autoSkipVideoAds) {
                const skipAdsSafe = () => {
                    const videos = document.querySelectorAll('video');
                    videos.forEach(v => {
                        const dur = v.duration;
                        const src = (v.currentSrc || v.src || '').toLowerCase();
                        // Chỉ tua khi là video quảng cáo thực sự (chứa 'vast', 'preroll' hoặc nằm trong khung jw-ads)
                        const isStrictAd = src.includes('vast') || src.includes('preroll') || v.closest('.jw-ads') || v.closest('.videojs-ads');
                        if (isStrictAd && dur > 0 && dur <= 35) {
                            v.muted = true;
                            v.currentTime = dur || 9999;
                        }
                    });

                    // Click nút Bỏ qua quảng cáo tự nhiên của player
                    document.querySelectorAll('.jw-skip, .videojs-ad-skip, .ytp-ad-skip-button, button[aria-label*="skip"]').forEach(b => {
                        try { b.click(); } catch(e) {}
                    });
                };
                setInterval(skipAdsSafe, 400);
            }
        })();
        """

        userContent.addUserScript(WKUserScript(source: customScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        return config
    }
}
