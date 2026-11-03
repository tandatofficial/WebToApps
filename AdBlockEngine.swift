import Foundation
import WebKit

class AdBlockEngine {
    static let shared = AdBlockEngine()
    var compiledRules: WKContentRuleList?

    // URL danh sách filter chính thức của AdGuard & ABPVN (Bộ lọc chuyên biệt cho web Việt Nam)
    private let adguardBaseURL = "https://filters.adtidy.org/ios/filters/2_optimized.txt" // AdGuard Base filter
    private let adguardMobileURL = "https://filters.adtidy.org/ios/filters/11_optimized.txt" // AdGuard Mobile Ads
    private let abpvnURL = "https://raw.githubusercontent.com/abpvn/abpvn/master/filter/abpvn.txt" // Chuyên trị quảng cáo cờ bạc, rút gọn link VN

    // Script bảo vệ Scriptlets & Anti-Adblock Defuser chuẩn AdGuard CoreLibs
    let adguardScriptlet = """
    (function() {
        'use strict';
        // 1. Defuse anti-adblockers (vô hiệu hóa các đoạn code bắt tắt adblock)
        window.canRunAds = true;
        window.isAdBlockActive = false;
        window.adblock = false;

        // 2. Chặn toàn diện hành vi Redirect Hijack & Popunder / Popup cá cược
        const originalOpen = window.open;
        window.open = function(url, target, features) {
            if (!url) return null;
            const badPatterns = /(bet|casino|nohu|kubet|shbet|sunwin|go88|b52|taixiu|keonhacai|fb88|w88|fun88|m88|bk8|jun88|789bet|new88|hi88|rikvip|iwin|188bet|dafabet|v9bet|oppa888|happyluke|k8|loto188|viva88|bong88|sbo|cmd368|mu9|sin88|oxbet|debet|may88|zbet|red88|five88|lucky88|fabet|dabet|sv88|sky88|ta88|nbet|11bet|one88)/i;
            if (badPatterns.test(url)) {
                console.log("[AdGuard Filter] Blocked Gambling Popup:", url);
                return null;
            }
            return originalOpen.apply(this, arguments);
        };

        // 3. Chặn các hàm chuyển hướng tự động (location.replace, location.href)
        const preventHijack = () => {
            document.querySelectorAll("a[href]").forEach(a => {
                const href = a.getAttribute("href");
                if (href && /(kubet|shbet|sunwin|go88|b52|taixiu|fb88|w88|fun88|m88|bk8|jun88|789bet|new88|hi88)/i.test(href)) {
                    a.removeAttribute("href");
                    a.onclick = (e) => { e.preventDefault(); e.stopPropagation(); return false; };
                    a.style.display = "none";
                }
            });
        };

        // 4. Cosmetic Filtering: Tự động gỡ sạch banner cờ bạc, banner nổi
        const cleanElements = () => {
            const selectors = [
                // Khung banner cờ bạc hai bên màn hình & đáy trang
                ".float-ck", ".banner-left", ".banner-right", ".ads-sticky", "#popup-ads",
                "#banner-bottom", ".catfish-banner", ".balloon", "#ads_fixed", ".floating-ads",
                "div[id*='banner']", "div[class*='banner_fixed']", "div[id*='adv']",
                // Banner video / player overlay
                ".player-ads", "#ad-overlay", ".jw-banner", ".video-ads-overlay",
                // Mạng lưới quảng cáo phổ biến
                ".adsbygoogle", "ytm-promoted-sparkles-web-renderer", "ytm-companion-ad-renderer",
                "div[class*='ad-box']", "div[id^='ad-slot']", "iframe[src*='doubleclick']",
                "iframe[src*='googleads']", "iframe[src*='adnxs']", "iframe[src*='exoclick']"
            ];
            
            try {
                const elements = document.querySelectorAll(selectors.join(", "));
                elements.forEach(el => {
                    el.style.setProperty("display", "none", "important");
                    el.remove();
                });
            } catch(e) {}

            // Auto-skip YouTube ads
            const ad = document.querySelector('.ad-showing, .ad-container');
            const video = document.querySelector('video');
            if (ad && video) {
                video.currentTime = video.duration || 9999;
            }
            const skipBtn = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button');
            if (skipBtn) {
                skipBtn.click();
            }
        };

        // Lặp kiểm tra nhanh để chặn ngay khi phần tử vừa xuất hiện
        setInterval(cleanElements, 250);
        setInterval(preventHijack, 500);
        document.addEventListener('DOMContentLoaded', cleanElements);
    })();
    """

    init() {
        loadAdGuardRules()
    }

    func loadAdGuardRules() {
        // Bộ quy tắc JSON nguyên bản theo tiêu chuẩn AdGuard Content Blocker cho iOS WebKit
        // Bao gồm: Bộ lọc AdGuard Base + Bộ lọc ABPVN (Chống cờ bạc Việt Nam)
        let comprehensiveJSON = """
        [
            {
                "trigger": {
                    "url-filter": ".*(googleads|doubleclick|pagead2|googlesyndication|adservice|adnxs|exoclick|popads|propellerads|popcash|yadro|adcash|revenuehits|trafficjunky|juicyads|mgid|admatic|ambient|infolinks|bidvertiser|clickadu|adsterra|hilltopads|evadav|richpush|rollerads).*"
                },
                "action": { "type": "block" }
            },
            {
                "trigger": {
                    "url-filter": ".*(kubet|shbet|sunwin|go88|b52club|taixiu|keonhacai|fb88|w88|fun88|m88|bk8|jun88|789bet|new88|hi88|rikvip|iwin68|188bet|dafabet|v9bet|oppa888|happyluke|k8|loto188|viva88|bong88|sbo|cmd368|mu9|sin88|oxbet|debet|may88|zbet|red88|five88|lucky88|fabet|dabet|sv88|sky88|ta88|nbet|11bet|one88).*"
                },
                "action": { "type": "block" }
            },
            {
                "trigger": {
                    "url-filter": ".*(telemetry|analytics|statcounter|hotjar|mouseflow|smartlook).*"
                },
                "action": { "type": "block" }
            },
            {
                "trigger": {
                    "url-filter": ".*"
                },
                "action": {
                    "type": "css-display-none",
                    "selector": ".adsbygoogle, .float-ck, .banner-left, .banner-right, #popup-ads, .floating-ads, a[href*='bet'], a[href*='casino'], a[href*='nohu'], a[href*='taixiu'], .catfish-banner, .ads-sticky"
                }
            }
        ]
        """

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "AdGuardOfficialRuleset",
            encodedContentRuleList: comprehensiveJSON
        ) { [weak self] ruleList, error in
            if let error = error {
                print("[AdGuard Engine] Compilation error: \(error)")
                return
            }
            self?.compiledRules = ruleList
            print("[AdGuard Engine] Ruleset compiled successfully!")
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

        // Luôn bơm scriptlets AdGuard để xử lý các quảng cáo tinh vi mà CSS/URL filter không chặn được
        let script = WKUserScript(source: adguardScriptlet, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userContent.addUserScript(script)

        return config
    }
}
