import Foundation
import WebKit

class AdBlockEngine {
    static let shared = AdBlockEngine()
    var compiledRules: WKContentRuleList?

    // 1. CSS diệt banner và ẩn triệt để mọi popup Anti-Adblock
    let aggressiveAdHideCSS = """
    /* Chặn triệt để lớp phủ Anti-Adblock của Nguồn C (StreamGuard / StreamC) */
    .stream-guard, .stream-guard-card, .stream-guard-notice, .stream-guard-diagnostics,
    #nc-player-apple-fallback, [id*='guard-modal'], [class*='guard-modal'],
    
    /* Banner cờ bạc, floating, sticky, popup */
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

    // 2. DEFUSER & ANTI-ADBLOCK BYPASS CHO NGUỒN C, STREAMC & CÁC TRANG PHIM VIỆT NAM
    let antiAdblockDefuserScript = """
    (function() {
        'use strict';

        // =========================================================================
        // A. TRIỆT TIÊU STREAMGUARD (Nguồn C / StreamC / Phim Mới / OPhim)
        // Hệ thống phát hiện adblock trong embed3.streamc.xyz / phim.nguonc.com
        // =========================================================================
        try {
            window.streamGuard = {
                version: "guard-7",
                status: function() {
                    return {
                        version: "guard-7",
                        devtoolsBuild: "iframe-local-5",
                        devtoolsLocal: "Tắt",
                        devtoolsRedirect: false,
                        redirectStarted: false,
                        blockShortcuts: false,
                        antiAdblock: false,
                        detectDevtools: false,
                        devtoolsSessionLocked: false,
                        devtoolsRetainedLock: false,
                        action: "none",
                        css: "Phần tử mẫu hiển thị",
                        network: "Script mẫu hiển thị",
                        devtools: "Tắt trong admin",
                        lastKey: "Chưa nhận phím kiểm tra",
                        frame: "Embed độc lập",
                        parentVersion: "guard-5",
                        parentAds: "Tắt trong admin",
                        adResources: "Tài nguyên quảng cáo đã tải/phát được",
                        uncertainNetwork: false,
                        blocked: false
                    };
                },
                ready: Promise.resolve(),
                isBlocked: function() { return false; },
                reportAdResource: function() {},
                waitForAccess: function() { return Promise.resolve(); },
                registerPlayer: function(player) {
                    console.log("[QuickWeb] Defused StreamGuard: registerPlayer bypassed");
                }
            };
            window.streamAdsLoaded = true;
        } catch(e) {}

        // =========================================================================
        // B. GIẢ LẬP BIẾN ADGUARD VÀ DEFUSE CÁC HÀM PHÁT HIỆN AD-BLOCK TOÀN DIỆN
        // =========================================================================
        window.canRunAds = true;
        window.isAdBlockActive = false;
        window.adblock = false;

        // Vô hiệu hóa Google IMA SDK
        window.google = window.google || {};
        window.google.ima = {
            AdsLoader: function() {
                this.requestAds = function() {};
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
        // C. TỰ ĐỘNG GỠ BỎ MODAL THÔNG BÁO VÀ TIẾP TỤC PHÁT VIDEO NẾU BỊ TẠM DỪNG
        // =========================================================================
        const unpauseVideoAndRemoveModals = () => {
            // Xóa phần tử StreamGuard thông báo
            const guardModals = document.querySelectorAll('.stream-guard, .stream-guard-card, .stream-guard-notice');
            guardModals.forEach(el => el.remove());

            // Tự động nhấn nút tiếp tục / unpause nếu video bị chặn
            const videos = document.querySelectorAll('video');
            videos.forEach(v => {
                if (v.paused && v.duration > 60 && !v.ended) {
                    // Nếu là video phim dài và bị pause do guard
                    const playPromise = v.play();
                    if (playPromise !== undefined) {
                        playPromise.catch(() => {});
                    }
                }

                // Nếu là video quảng cáo ngắn (<= 35s), tua sạch
                const src = (v.currentSrc || v.src || '').toLowerCase();
                const dur = v.duration;
                if ((dur > 0 && dur <= 35) || src.includes('preroll') || src.includes('vast') || src.includes('bet')) {
                    v.muted = true;
                    v.playbackRate = 16.0;
                    v.currentTime = dur || 9999;
                    try { v.dispatchEvent(new Event('ended')); } catch(e) {}
                }
            });

            // Tự động click nút 'Kiểm tra lại' hoặc các nút skip nếu có
            document.querySelectorAll('.jw-skip, .videojs-ad-skip, .ytp-ad-skip-button, button[aria-label*="skip"]').forEach(b => {
                try { b.click(); } catch(e) {}
            });
        };

        setInterval(unpauseVideoAndRemoveModals, 100);
        document.addEventListener('DOMContentLoaded', unpauseVideoAndRemoveModals);
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
                "trigger": {
                    "url-filter": ".*"
                },
                "action": {
                    "type": "css-display-none",
                    "selector": ".stream-guard, .stream-guard-card, .float-ck, .banner-left, .banner-right, #popup-ads, .floating-ads, a[href*='bet'], a[href*='casino'], .catfish-banner, .ads-sticky, .jw-ads, .jw-ad, .player-ads, #ad-overlay, .ad-container, [data-ad]"
                }
            }
        ]
        """

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "AdGuardDefuserRuleset",
            encodedContentRuleList: blockJSON
        ) { [weak self] ruleList, error in
            if let error = error {
                print("[AdBlockEngine] Error: \(error)")
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

        // 1. Tiêm CSS diệt sạch banner và lớp phủ StreamGuard
        let cssScript = """
        const style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = `\(aggressiveAdHideCSS)`;
        document.head ? document.head.appendChild(style) : document.documentElement.appendChild(style);
        """
        userContent.addUserScript(WKUserScript(source: cssScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        // 2. Tiêm Anti-Adblock Defuser Script chuyên trị Nguồn C / StreamGuard vào TẤT CẢ CÁC FRAME
        userContent.addUserScript(WKUserScript(source: antiAdblockDefuserScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        // 3. UserScripts từ ExtensionStore
        for script in ExtensionStore.shared.userScripts where script.isEnabled {
            let userScript = WKUserScript(source: script.code, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            userContent.addUserScript(userScript)
        }

        return config
    }
}
