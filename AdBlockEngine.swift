import Foundation
import WebKit

class AdBlockEngine {
    static let shared = AdBlockEngine()
    var compiledRules: WKContentRuleList?

    // 1. CSS diệt sạch toàn bộ banner & khung overlay trên video
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
    }
    """

    // 2. CHUYÊN TRỊ IN-STREAM VIDEO ADS (Xử lý tận gốc 3 thủ thuật phát quảng cáo trong video)
    let inStreamVideoAdKiller = """
    (function() {
        'use strict';

        // =========================================================================
        // CHIÊU 1: TIÊU DIỆT GOOGLE IMA SDK & THƯ VIỆN QUẢNG CÁO CỦA PLAYER
        // Hầu hết video player kiểm tra xem SDK IMA / VAST có sẵn không để phát video quảng cáo
        // =========================================================================
        window.google = window.google || {};
        window.google.ima = {
            AdsLoader: function() {
                this.requestAds = function() {
                    console.log("[AdGuard Video] Triệt tiêu requestAds của IMA SDK");
                };
                this.contentComplete = function() {};
                this.addEventListener = function() {};
            },
            AdsManagerLoadedEvent: { Type: { ADS_MANAGER_LOADED: 'adsManagerLoaded' } },
            AdErrorEvent: { Type: { AD_ERROR: 'adError' } },
            ViewMode: {},
            AdDisplayContainer: function() {
                this.initialize = function() {};
                this.destroy = function() {};
            },
            AdsRequest: function() {},
            settings: { setAutoPlayAdBreaks: function() {}, setVpaidMode: function() {} }
        };

        // =========================================================================
        // CHIÊU 2: LỌC NỘI DUNG M3U8 (Chặn HLS Server-Side Ad Insertion)
        // Khi web ghép đoạn video quảng cáo 15s vào playlist m3u8
        // =========================================================================
        const isAdUrl = (url) => {
            if (!url || typeof url !== 'string') return false;
            return /(vast|vpaid|ima3|doubleclick|googleads|gmsg|pagead|preroll|midroll|ads\\.xml|ad\\.m3u8|sponsor|promo|bet88|kubet|sunwin|nohu|casino)/i.test(url);
        };

        // Lọc fetch() trả về m3u8 playlist để gỡ bỏ các đoạn quảng cáo chèn thêm
        const originalFetch = window.fetch;
        window.fetch = async function() {
            const url = arguments[0];
            if (typeof url === 'string') {
                if (isAdUrl(url)) {
                    return Promise.reject(new Error("[AdGuard] Blocked Video Ad"));
                }
            }
            return originalFetch.apply(this, arguments);
        };

        const originalOpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function(method, url) {
            if (typeof url === 'string' && isAdUrl(url)) {
                return;
            }
            return originalOpen.apply(this, arguments);
        };

        // =========================================================================
        // CHIÊU 3: BỨT PHÁ BỘ ĐẾM GIỜ ĐẾM NGƯỢC (Ad Countdown Bypass) & TUA NGAY
        // Trình phát video thường đếm ngược từ 15s về 0s rồi mới chịu đổi sang phim thật
        // =========================================================================
        const neutraliseVideoAds = () => {
            const videos = document.querySelectorAll('video');
            videos.forEach(v => {
                // Nếu video đang phát có thời lượng ngắn (<= 35s) và không phải video phim dài
                const duration = v.duration;
                const isShort = duration > 0 && duration <= 35;
                const inAdContainer = v.closest('.jw-ads') || v.closest('.videojs-ads') || v.closest('[class*="ad-"]') || v.closest('[id*="ad-"]');

                if (isShort || inAdContainer || isAdUrl(v.currentSrc || v.src)) {
                    console.log("[AdGuard Video] Phát hiện Video QC, đang cưỡng chế kết thúc...");
                    v.muted = true;
                    v.playbackRate = 16.0; // Phát với tốc độ x16
                    v.currentTime = duration || 9999; // Tua đến giây cuối cùng
                    
                    // Phát sự kiện 'ended' giả lập để ép player chuyển sang video phim chính
                    try {
                        v.dispatchEvent(new Event('ended'));
                    } catch(e) {}
                }
            });

            // Tự động kích hoạt nút Bỏ qua quảng cáo của JWPlayer, Video.js, DPlayer, Plyr
            const skipButtons = document.querySelectorAll(`
                .jw-skip, .videojs-ad-skip, .ytp-ad-skip-button, .ytp-ad-skip-button-modern,
                .dplayer-ad-skip, [class*="skip-ad"], [id*="skip-ad"], .skip-button, button[aria-label*="skip"]
            `);
            skipButtons.forEach(btn => {
                try {
                    btn.click();
                    console.log("[AdGuard Video] Đã nhấn nút Bỏ qua quảng cáo!");
                } catch(e) {}
            });
        };

        // Lặp kiểm tra cực nhanh mỗi 100ms ngay khi vừa mở video
        setInterval(neutraliseVideoAds, 100);
        document.addEventListener('DOMContentLoaded', neutraliseVideoAds);
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

        // 1. Tiêm CSS diệt sạch banner (đã hoạt động hiệu quả)
        let cssScript = """
        const style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = `\(aggressiveAdHideCSS)`;
        document.head ? document.head.appendChild(style) : document.documentElement.appendChild(style);
        """
        userContent.addUserScript(WKUserScript(source: cssScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        // 2. Tiêm bộ diệt In-Stream Video Ads đặc trị IMA / Countdown / Ended Event
        userContent.addUserScript(WKUserScript(source: inStreamVideoAdKiller, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        return config
    }
}
