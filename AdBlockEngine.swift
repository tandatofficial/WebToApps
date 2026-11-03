import Foundation
import WebKit

class AdBlockEngine {
    static let shared = AdBlockEngine()
    var compiledRules: WKContentRuleList?

    // Script bảo vệ nâng cao chuẩn AdGuard:
    // 1. Chặn clickjacking, redirect nhảy tab sang trang cờ bạc (88, bet, kubet, shbet, sunwin, go88,...)
    // 2. Chặn các banner nổi (floating/sticky), overlay mờ ép click
    // 3. Vô hiệu hóa window.open() trá hình
    // 4. Auto-skip video ads YouTube
    let smartShieldScript = """
    (function() {
        // --- 1. Chặn window.open() lén nhảy sang trang cờ bạc / cá cược ---
        const originalOpen = window.open;
        window.open = function(url, target, features) {
            const gamblingRegex = /(bet|casino|nohu|kubet|shbet|sunwin|go88|b52|taixiu|keonhacai|fb88|w88|fun88|m88|bk8|jun88|789bet|new88|hi88)/i;
            if (url && gamblingRegex.test(url)) {
                console.log("[AdGuard Shield] Chặn popup cờ bạc:", url);
                return null;
            }
            return originalOpen.apply(this, arguments);
        };

        // --- 2. Bộ lọc DOM thời gian thực (MutationObserver) chặn banner cờ bạc ghim 2 bên màn hình ---
        const removeGamblingAndAds = () => {
            // Danh sách các selector quảng cáo & banner cờ bạc phổ biến trên các web phim lậu / truyện tranh
            const badSelectors = [
                // Banner cờ bạc, cá cược nổi tiếng tại VN
                "a[href*='bet']", "a[href*='casino']", "a[href*='kubet']", "a[href*='sunwin']",
                "a[href*='go88']", "a[href*='b52']", "a[href*='shbet']", "a[href*='nohu']",
                "img[src*='bet']", "img[src*='casino']", "img[src*='nohu']", "img[src*='taixiu']",
                // Khung popup / sticky banners 2 bên sườn
                ".float-ck", ".banner-left", ".banner-right", ".ads-sticky", "#popup-ads",
                "#banner-bottom", ".catfish-banner", ".balloon", "#ads_fixed", ".floating-ads",
                // Mạng quảng cáo thông thường
                ".adsbygoogle", "ytm-promoted-sparkles-web-renderer", "ytm-companion-ad-renderer",
                ".ad-banner", ".ad-container", "div[id^='ad_']", "div[class*='advertisement']"
            ];

            badSelectors.forEach(sel => {
                try {
                    const elements = document.querySelectorAll(sel);
                    elements.forEach(el => {
                        // Kiểm tra nếu là banner hoặc link ra ngoài
                        if (el.tagName === 'A' || el.tagName === 'IMG' || el.classList.contains('banner-left') || el.classList.contains('banner-right')) {
                            el.style.display = 'none';
                            el.remove();
                        } else if (el.offsetHeight > 0 && (el.style.position === 'fixed' || el.style.position === 'sticky')) {
                            // Chặn các banner che màn hình
                            el.style.display = 'none';
                            el.remove();
                        }
                    });
                } catch(e) {}
            });

            // Tự động tua & skip video ads YouTube
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

        // Chạy ngay khi tải xong và theo dõi DOM liên tục
        setInterval(removeGamblingAndAds, 350);
        document.addEventListener('DOMContentLoaded', removeGamblingAndAds);
    })();
    """

    init() {
        compileRules()
    }

    func compileRules() {
        // Danh sách domain chặn cấp độ mạng (DNS & WebKit Network layer) chuẩn AdGuard
        let rulesJSON = """
        [
            {
                "trigger": {
                    "url-filter": ".*(googleads|doubleclick|pagead2|googlesyndication|adservice|adnxs|exoclick|popads|propellerads|popcash|yadro|adcash|revenuehits).*"
                },
                "action": { "type": "block" }
            },
            {
                "trigger": {
                    "url-filter": ".*(kubet|shbet|sunwin|go88|b52club|taixiu|keonhacai|fb88|w88|fun88|m88|bk8|jun88|789bet|new88|hi88|rikvip|iwin68).*"
                },
                "action": { "type": "block" }
            },
            {
                "trigger": { "url-filter": ".*" },
                "action": {
                    "type": "css-display-none",
                    "selector": ".ad, .ads, .ad-banner, .adsbygoogle, .float-ck, .banner-left, .banner-right, #popup-ads, .floating-ads, a[href*='bet'], a[href*='casino']"
                }
            }
        ]
        """

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "QuickWebAdGuardRules",
            encodedContentRuleList: rulesJSON
        ) { [weak self] ruleList, error in
            if let error = error {
                print("AdGuard compilation error: \(error)")
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

        // Luôn bơm script bảo vệ AdGuard Smart Shield cho mọi trang web
        let script = WKUserScript(source: smartShieldScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        userContent.addUserScript(script)

        return config
    }
}
