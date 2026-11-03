import Foundation
import WebKit

class AdBlockEngine {
    static let shared = AdBlockEngine()
    var compiledRules: WKContentRuleList?

    // MARK: - ULTIMATE ADGUARD ENGINE (CSS STYLESHEET + DOM DESTROYER + PROTOTYPE HIJACK)
    // Hoạt động trên cả trang chính LẪN tất cả các <iframe> lồng nhau (embed video player)
    
    // 1. CSS ép tàng hình toàn bộ banner ngay từ tầng render đầu tiên (không kịp nhấp nháy)
    let aggressiveAdHideCSS = """
    /* Banner cờ bạc, floating, sticky, popup */
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

    // 2. Script can thiệp trực tiếp vào HTMLMediaElement Prototype (cấp trình phát Video)
    let deepVideoAdKillerScript = """
    (function() {
        'use strict';

        // --- A. BẺ GÃY HÀNH VI TỰ CHÈN VIDEO QUẢNG CÁO QUA HTMLVideoElement PROTOTYPE ---
        // Bắt mọi video cố tình nạp link quảng cáo qua .src hoặc setAttribute('src')
        const isAdUrl = (url) => {
            if (!url || typeof url !== 'string') return false;
            return /(vast|vpaid|ima3|doubleclick|googleads|gmsg|pagead|preroll|midroll|ads\\.xml|ad\\.m3u8|sponsor|promo|bet88|kubet|sunwin|nohu|casino)/i.test(url);
        };

        const originalSrcDescriptor = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'src');
        if (originalSrcDescriptor && originalSrcDescriptor.set) {
            Object.defineProperty(HTMLMediaElement.prototype, 'src', {
                set: function(val) {
                    if (isAdUrl(val)) {
                        console.log("[AdGuard Deep Shield] Chặn gán src video quảng cáo:", val);
                        return; // Vứt bỏ, không cho player nạp video quảng cáo
                    }
                    return originalSrcDescriptor.set.call(this, val);
                },
                get: function() {
                    return originalSrcDescriptor.get.call(this);
                }
            });
        }

        // Khống chế HTMLVideoElement.play(): Nếu video đang phát là video quảng cáo ngắn (<= 35s), tua sạch ngay
        const originalPlay = HTMLMediaElement.prototype.play;
        HTMLMediaElement.prototype.play = function() {
            const video = this;
            const src = video.currentSrc || video.src || '';
            const duration = video.duration;

            // Kiểm tra nếu là video quảng cáo
            if (isAdUrl(src) || (duration > 0 && duration <= 35 && (video.closest('[class*="ad"]') || video.closest('[id*="ad"]')))) {
                console.log("[AdGuard Deep Shield] Ép tua sạch quảng cáo đang phát:", src);
                video.muted = true;
                video.currentTime = duration || 9999;
                return Promise.resolve();
            }
            return originalPlay.apply(this, arguments);
        };

        // --- B. VÔ HIỆU HÓA FETCH & XHR CHỨA QUẢNG CÁO (KỂ CẢ TRONG IFRAME EMBED) ---
        const originalFetch = window.fetch;
        window.fetch = function() {
            const url = arguments[0];
            if (typeof url === 'string' && isAdUrl(url)) {
                return Promise.reject(new Error("Blocked by AdGuard Video Shield"));
            }
            return originalFetch.apply(this, arguments);
        };

        const originalXHROpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function(method, url) {
            if (typeof url === 'string' && isAdUrl(url)) {
                return;
            }
            return originalXHROpen.apply(this, arguments);
        };

        // --- C. HỦY DIỆT MỌI CỬA SỔ POPUP & CLICKJACKING ---
        window.open = function() {
            console.log("[AdGuard Deep Shield] Chặn window.open popup!");
            return null;
        };

        // --- D. MUTATION OBSERVER QUÉT LIÊN TỤC VÀ TIÊU DIỆT TẬN GỐC TỪNG ELEMENT QUẢNG CÁO ---
        const removeAdsFromDocument = (doc) => {
            if (!doc) return;
            const badSelectors = [
                ".float-ck", ".banner-left", ".banner-right", ".ads-sticky", "#popup-ads",
                "#banner-bottom", ".catfish-banner", ".balloon", "#ads_fixed", ".floating-ads",
                "a[href*='bet']", "a[href*='casino']", "a[href*='nohu']", "a[href*='taixiu']",
                "a[href*='kubet']", "a[href*='shbet']", "a[href*='sunwin']", "a[href*='go88']",
                ".adsbygoogle", "ytm-promoted-sparkles-web-renderer", "div[id^='ad_']",
                ".jw-ads", ".jw-ad", ".player-ads", "#ad-overlay"
            ];

            try {
                const nodes = doc.querySelectorAll(badSelectors.join(','));
                nodes.forEach(n => {
                    n.remove();
                });
            } catch(e) {}

            // Click nút skip tự động
            const skipBtns = doc.querySelectorAll('.ytp-ad-skip-button, .jw-skip, .videojs-ad-skip, [class*="skip"]');
            skipBtns.forEach(btn => { try { btn.click(); } catch(e) {} });
        };

        // Quét trên toàn bộ Shadow DOM và nested iframes
        setInterval(() => {
            removeAdsFromDocument(document);
            document.querySelectorAll('iframe').forEach(frame => {
                try {
                    removeAdsFromDocument(frame.contentDocument);
                } catch(e) {} // Cross-origin frames đã được bảo vệ bởi script bơm độc lập
            });
        }, 150);

        document.addEventListener('DOMContentLoaded', () => removeAdsFromDocument(document));
    })();
    """

    init() {
        compileRules()
    }

    func compileRules() {
        // Danh sách chặn cấp WebKit Network (chặn trước khi request rời khỏi máy)
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
            forIdentifier: "AdGuardUltimateRules",
            encodedContentRuleList: blockJSON
        ) { [weak self] ruleList, error in
            if let error = error {
                print("[AdGuard] Compilation error: \(error)")
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

        // 1. Tiêm CSS diệt banner ngay từ đầu (chạy trên CẢ Frame chính lẫn IFrame phụ)
        let cssScript = """
        const style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = `\(aggressiveAdHideCSS)`;
        document.head ? document.head.appendChild(style) : document.documentElement.appendChild(style);
        """
        let userCSS = WKUserScript(source: cssScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userContent.addUserScript(userCSS)

        // 2. Tiêm Prototype Hijacker diệt Video Ads ngay từ thời điểm Document Start trên MỌI FRAME
        let userJS = WKUserScript(source: deepVideoAdKillerScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userContent.addUserScript(userJS)

        return config
    }
}
