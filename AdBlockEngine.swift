import Foundation
import WebKit

class AdBlockEngine {
    static let shared = AdBlockEngine()
    var compiledRules: WKContentRuleList?

    // MARK: - AdGuard Video Stream Interceptor & VAST/VPAID Killer
    // Xử lý triệt để loại quảng cáo nhúng trực tiếp vào Trình phát video (AVPlayer / HTML5 Video của iOS)
    let advancedVideoAdInterceptor = """
    (function() {
        'use strict';

        // 1. CHẶN VAST / VPAID / IMA SDK (Google Interactive Media Ads) TỪ TRỨNG NƯỚC
        // Hầu hết video player (JWPlayer, VideoJS, Clappr, Plyr, DPlayer) đều nạp file XML VAST để phát quảng cáo trước video
        const originalFetch = window.fetch;
        window.fetch = function() {
            const url = arguments[0];
            if (typeof url === 'string') {
                if (/vast|vpaid|ima3|doubleclick|googleads|gmsg|pagead|preroll|midroll|postroll|ads\\.xml|ad\\.m3u8/i.test(url)) {
                    console.log("[AdGuard Video Shield] Đã chặn VAST XML/Ad Stream:", url);
                    return Promise.reject(new Error("Blocked by AdGuard Video Shield"));
                }
            }
            return originalFetch.apply(this, arguments);
        };

        const originalXHROpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function(method, url) {
            if (typeof url === 'string') {
                if (/vast|vpaid|ima3|doubleclick|googleads|gmsg|pagead|preroll|midroll|postroll|ads\\.xml|ad\\.m3u8/i.test(url)) {
                    console.log("[AdGuard Video Shield] Đã chặn XHR Video Ad:", url);
                    return; // Hủy không gửi request quảng cáo
                }
            }
            return originalXHROpen.apply(this, arguments);
        };

        // 2. KHỐNG CHẾ TRỰC TIẾP ELEMENT <VIDEO> NATIVE CỦA IOS
        // Nếu web cố tình nhét 1 file video quảng cáo 15s-30s vào thẻ <video> trước khi phát phim thật:
        const monitorNativeVideos = () => {
            const videos = document.querySelectorAll('video');
            videos.forEach(video => {
                if (video._adguardHooked) return;
                video._adguardHooked = true;

                // Hook sự kiện khi video bắt đầu nạp metadata
                video.addEventListener('loadedmetadata', function() {
                    const src = video.currentSrc || video.src || '';
                    const duration = video.duration;

                    // Nhận diện video quảng cáo: thời lượng ngắn <= 35s hoặc URL chứa từ khóa ad
                    const isAdUrl = /ad|preroll|sponsor|promo|bet|casino|sunwin|kubet/i.test(src);
                    const isShortAd = duration > 0 && duration <= 35 && (video.closest('.ad-container') || video.closest('.ad-showing') || isAdUrl);

                    if (isShortAd || isAdUrl) {
                        console.log("[AdGuard Video Shield] Phát hiện Video QC chạy ngầm, tự động tua đến cuối:", src);
                        video.muted = true;
                        video.playbackRate = 16.0; // Tăng tốc tối đa
                        video.currentTime = duration || 9999; // Tua hết sạch quảng cáo ngay lập tức
                    }
                });

                // Tự động click nút 'Bỏ qua quảng cáo' (Skip Ads) của mọi player
                video.addEventListener('timeupdate', function() {
                    const skipButtons = document.querySelectorAll(
                        '.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button, ' +
                        '.jw-skip, .videojs-ad-skip, .dplayer-ad-skip, .ad-skip-btn, [class*="skip-ad"], [id*="skip-ad"]'
                    );
                    skipButtons.forEach(btn => {
                        try { btn.click(); } catch(e) {}
                    });
                });
            });
        };

        // 3. VÔ HIỆU HÓA GOOGLE IMA & CÁC THƯ VIỆN QUẢNG CÁO TRONG PLAYER
        Object.defineProperty(window, 'google', {
            get: function() { return { ima: { AdsLoader: function(){}, AdsManagerLoadedEvent: {}, AdErrorEvent: {} } }; },
            set: function() {}
        });

        // 4. DEFUSE POPUNDER KHI CHẠM VÀO PLAYER
        const originalOpen = window.open;
        window.open = function(url) {
            if (!url || /(bet|casino|nohu|kubet|shbet|sunwin|go88|b52|taixiu|fb88|w88)/i.test(url)) {
                return null;
            }
            return originalOpen.apply(this, arguments);
        };

        setInterval(monitorNativeVideos, 200);
        document.addEventListener('DOMContentLoaded', monitorNativeVideos);
    })();
    """

    init() {
        loadAdGuardRules()
    }

    func loadAdGuardRules() {
        let comprehensiveJSON = """
        [
            {
                "trigger": {
                    "url-filter": ".*(vast|vpaid|ima3|doubleclick|googleads|pagead|exoclick|popads|propellerads|popcash|adnxs|trafficjunky|adsterra|hilltopads|clickadu).*"
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
                "trigger": {
                    "url-filter": ".*"
                },
                "action": {
                    "type": "css-display-none",
                    "selector": ".jw-ads, .jw-ad, .videojs-ads, .ad-container, .adsbygoogle, .float-ck, .banner-left, .banner-right, #popup-ads, .floating-ads, a[href*='bet'], a[href*='casino'], .catfish-banner, .player-ads, #ad-overlay"
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

        // Bơm script chặn Video Pre-roll Ads & VAST ngay khi trang vừa bắt đầu nạp (atDocumentStart)
        let script = WKUserScript(source: advancedVideoAdInterceptor, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userContent.addUserScript(script)

        return config
    }
}
