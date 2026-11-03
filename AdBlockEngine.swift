import Foundation
import WebKit

class AdBlockEngine {
    static let shared = AdBlockEngine()
    var compiledRules: WKContentRuleList?

    // 1. CSS diệt banner, watermark và overlay player
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

    // 2. NUCLEAR VIDEO AD KILLER (Can thiệp vào HLS.js, Video Source, và Timer)
    let nuclearVideoAdScript = """
    (function() {
        'use strict';

        // --- CHIÊU ĐỘC 1: CAN THIỆP Hls.js ĐỂ BỎ QUA MỌI PHÂN ĐOẠN QUẢNG CÁO M3U8 ---
        // Hầu hết các web phim hiện đại dùng Hls.js để stream video
        const hookHls = () => {
            if (window.Hls && window.Hls.prototype && !window.Hls.prototype._adHooked) {
                window.Hls.prototype._adHooked = true;
                const originalLoadSource = window.Hls.prototype.loadSource;
                window.Hls.prototype.loadSource = function(url) {
                    if (url && typeof url === 'string') {
                        // Nếu nguồn là link quảng cáo, chặn ngay
                        if (/ad|preroll|vast|bet|casino|promo/i.test(url) && !url.includes('master') && !url.includes('playlist')) {
                            console.log("[Nuclear AdBlock] Chặn Hls.loadSource quảng cáo:", url);
                            return;
                        }
                    }
                    return originalLoadSource.apply(this, arguments);
                };
            }
        };

        // --- CHIÊU ĐỘC 2: TỰ ĐỘNG THAY THẾ LINK VIDEO QUẢNG CÁO BẰNG LINK PHIM CHÍNH ---
        // Khi trang web có 2 video tag (1 cái chạy quảng cáo đè lên 1 cái chạy phim)
        const killAdVideos = () => {
            const videoElements = document.querySelectorAll('video');
            if (videoElements.length > 1) {
                // Nếu có nhiều hơn 1 thẻ video, thường thẻ ở trên cùng là quảng cáo
                videoElements.forEach((vid, index) => {
                    const isTopAd = vid.closest('[class*="ad"]') || vid.closest('[id*="ad"]') || vid.style.zIndex > 10;
                    if (isTopAd || (vid.duration > 0 && vid.duration <= 40)) {
                        console.log("[Nuclear AdBlock] Xóa sổ thẻ video quảng cáo phụ");
                        vid.pause();
                        vid.src = "";
                        vid.remove();
                    }
                });
            } else if (videoElements.length === 1) {
                const vid = videoElements[0];
                const src = vid.currentSrc || vid.src || '';
                const dur = vid.duration;

                // Nếu video đang phát là clip ngắn quảng cáo
                if ((dur > 0 && dur <= 35) || vid.closest('.jw-ads') || vid.closest('.videojs-ads')) {
                    vid.muted = true;
                    // Ép tốc độ lên 16 lần
                    vid.playbackRate = 16.0;
                    // Tua về cuối
                    vid.currentTime = dur || 9999;
                    try {
                        vid.dispatchEvent(new Event('ended'));
                        vid.dispatchEvent(new Event('timeupdate'));
                    } catch(e) {}
                }
            }

            // Click toàn bộ nút Bỏ qua quảng cáo
            document.querySelectorAll(`
                .jw-skip, .videojs-ad-skip, .ytp-ad-skip-button, .ytp-ad-skip-button-modern,
                .dplayer-ad-skip, [class*="skip"], [id*="skip"], button[aria-label*="skip"]
            `).forEach(b => { try { b.click(); } catch(e) {} });
        };

        // Chạy liên tục mỗi 80ms
        setInterval(killAdVideos, 80);
        setInterval(hookHls, 200);
        document.addEventListener('DOMContentLoaded', killAdVideos);
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
            forIdentifier: "AdGuardNuclearRuleset",
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

        // 1. CSS tiêm tức thì
        let cssScript = """
        const style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = `\(aggressiveAdHideCSS)`;
        document.head ? document.head.appendChild(style) : document.documentElement.appendChild(style);
        """
        userContent.addUserScript(WKUserScript(source: cssScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        // 2. Tiêm Nuclear Video Ad Killer vào mọi frame
        userContent.addUserScript(WKUserScript(source: nuclearVideoAdScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        return config
    }
}
