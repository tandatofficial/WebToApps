import Foundation
import WebKit

class AdBlockEngine {
    static let shared = AdBlockEngine()
    var compiledRules: WKContentRuleList?

    // 1. CSS triệt tiêu toàn bộ banner & popup nổi đặc thù của web NSFW
    let aggressiveAdHideCSS = """
    /* Banner mạng ExoClick, TrafficJunky, JuicyAds, cờ bạc */
    .float-ck, .banner-left, .banner-right, .ads-sticky, #popup-ads,
    #banner-bottom, .catfish-banner, .balloon, #ads_fixed, .floating-ads,
    div[id*='banner'], div[class*='banner'], div[id*='adv'], div[class*='adv'],
    .player-ads, #ad-overlay, .jw-banner, .jw-ads, .jw-ad, .video-ads-overlay,
    .adsbygoogle, ytm-promoted-sparkles-web-renderer,
    div[class*='ad-box'], div[id^='ad-slot'], div[class*='advertisement'],
    a[href*='bet'], a[href*='casino'], a[href*='nohu'], a[href*='taixiu'],
    a[href*='kubet'], a[href*='shbet'], a[href*='sunwin'], a[href*='go88'], a[href*='b52'],
    div[id*='spot_id'], div[class*='spot_id'], [data-ad], [data-zone],
    .ad-container, .ad-player, .ad-placeholder, .exo-native-widget,
    iframe[src*='exoclick'], iframe[src*='trafficjunky'], iframe[src*='juicyads'],
    iframe[src*='trafficfactory'], iframe[src*='ero-advertising'],
    div[style*='z-index: 999999'], div[style*='z-index: 2147483647'] {
        display: none !important;
        visibility: hidden !important;
        opacity: 0 !important;
        pointer-events: none !important;
        height: 0 !important;
        width: 0 !important;
    }
    """

    // 2. ADULT & NSFW IN-STREAM VIDEO AD DESTROYER
    // Xử lý triệt để ExoClick, TrafficJunky, JuicyAds, TrafficFactory & VAST Pre-roll
    let nsfwVideoAdKiller = """
    (function() {
        'use strict';

        // --- A. BỘ LỌC CÁC MẠNG QUẢNG CÁO VIDEO NSFW ---
        const nsfwAdKeywords = [
            'exoclick', 'trafficjunky', 'juicyads', 'trafficfactory',
            'tsyndicate', 'delivery.trafficjunky', 'adserver.juicyads',
            'preroll', 'vast', 'vpaid', 'spot_id', 'zone_id', 'campaign',
            'ad_id', 'popads', 'adsterra', 'clickadu', 'hilltopads',
            'stripchat', 'cam4', 'bongacams', 'livejasmin', 'camsoda',
            'bet88', 'kubet', 'sunwin', 'b52', 'casino'
        ];

        const isNsfwAdUrl = (url) => {
            if (!url || typeof url !== 'string') return false;
            const lower = url.toLowerCase();
            return nsfwAdKeywords.some(keyword => lower.includes(keyword));
        };

        // --- B. CHẶN FETCH & XHR CỦA TRÌNH PHÁT VIDEO ĐẾN SERVER QUẢNG CÁO ---
        const originalFetch = window.fetch;
        window.fetch = function() {
            const url = arguments[0];
            if (typeof url === 'string' && isNsfwAdUrl(url)) {
                console.log("[NSFW Shield] Đã chặn Request quảng cáo video:", url);
                return Promise.reject(new Error("Blocked by NSFW Shield"));
            }
            return originalFetch.apply(this, arguments);
        };

        const originalXHROpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function(method, url) {
            if (typeof url === 'string' && isNsfwAdUrl(url)) {
                console.log("[NSFW Shield] Đã chặn XHR quảng cáo video:", url);
                return;
            }
            return originalXHROpen.apply(this, arguments);
        };

        // --- C. TRIỆT TIÊU BIẾN CẤU HÌNH PREROLL TRONG PLAYER OBJECT ---
        // Các trình phát NSFW lưu link quảng cáo trong flashvars, player.options hoặc video_preroll
        const cleanPlayerConfig = () => {
            const killProps = ['preroll', 'video_preroll', 'ad_url', 'vast', 'vpaid', 'vast_url', 'adTag'];
            killProps.forEach(prop => {
                try {
                    if (window.flashvars && window.flashvars[prop]) window.flashvars[prop] = '';
                    if (window.playerConfig && window.playerConfig[prop]) window.playerConfig[prop] = '';
                    if (window.video_preroll) window.video_preroll = null;
                } catch(e) {}
            });
        };

        // --- D. KHỐNG CHẾ THẺ <VIDEO> VÀ CƯỠNG CHẾ BỎ QUA ĐOẠN QUẢNG CÁO ---
        const autoSkipInStream = () => {
            cleanPlayerConfig();

            const videos = document.querySelectorAll('video');
            videos.forEach(v => {
                const src = (v.currentSrc || v.src || '').toLowerCase();
                const duration = v.duration;

                // 1. Nếu src chứa domain quảng cáo hoặc là clip ngắn <= 35s
                const isShort = duration > 0 && duration <= 35;
                const isAdSource = isNsfwAdUrl(src);

                if (isShort || isAdSource || v.closest('[class*="ad"]') || v.closest('[id*="ad"]')) {
                    console.log("[NSFW Shield] Đang tua sạch Video QC...");
                    v.muted = true;
                    v.playbackRate = 16.0;
                    v.currentTime = duration || 9999;
                    try {
                        v.dispatchEvent(new Event('ended'));
                        v.dispatchEvent(new Event('timeupdate'));
                    } catch(e) {}
                }
            });

            // Tự động click mọi nút Skip / Close / Bỏ qua quảng cáo của player
            const skipBtns = document.querySelectorAll(`
                .jw-skip, .videojs-ad-skip, .ad-skip, [class*="skip"], [id*="skip"],
                .close-ad, .skip-ad, button[aria-label*="skip"], .mg-skip-button,
                .mg-player-ad-skip, .vjs-skip-button
            `);
            skipBtns.forEach(btn => { try { btn.click(); } catch(e) {} });
        };

        // Quét liên tục mỗi 80ms
        setInterval(autoSkipInStream, 80);
        document.addEventListener('DOMContentLoaded', autoSkipInStream);
    })();
    """

    init() {
        compileRules()
    }

    func compileRules() {
        // Danh sách chặn toàn bộ mạng quảng cáo NSFW hàng đầu thế giới ở cấp độ mạng WebKit
        let blockJSON = """
        [
            {
                "trigger": {
                    "url-filter": ".*(exoclick|trafficjunky|juicyads|trafficfactory|tsyndicate|adsterra|clickadu|hilltopads|propellerads|popads|popcash|ero-advertising|stripchat|bongacams|livejasmin|camsoda|chaturbate|vast|vpaid|preroll|midroll|bet88|kubet|sunwin).*"
                },
                "action": { "type": "block" }
            },
            {
                "trigger": {
                    "url-filter": ".*"
                },
                "action": {
                    "type": "css-display-none",
                    "selector": ".float-ck, .banner-left, .banner-right, #popup-ads, .floating-ads, a[href*='bet'], a[href*='casino'], .catfish-banner, .ads-sticky, .jw-ads, .jw-ad, .player-ads, #ad-overlay, .ad-container, [data-ad]"
                }
            }
        ]
        """

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "AdGuardNSFWRuleset",
            encodedContentRuleList: blockJSON
        ) { [weak self] ruleList, error in
            if let error = error {
                print("[NSFW Shield] Error: \(error)")
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

        // 2. Tiêm bộ diệt In-Stream Video Ads đặc trị web NSFW vào MỌI FRAME
        userContent.addUserScript(WKUserScript(source: nsfwVideoAdKiller, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        return config
    }
}
