import Foundation

struct FilterListConfig: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var url: String
    var isEnabled: Bool
    var ruleCount: Int = 0
}

struct UserScriptConfig: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var code: String
    var isEnabled: Bool
}

class ExtensionStore: ObservableObject {
    static let shared = ExtensionStore()
    private let filterKey = "quickweb_adguard_filters"
    private let scriptKey = "quickweb_userscripts"

    @Published var filters: [FilterListConfig] = []
    @Published var userScripts: [UserScriptConfig] = []

    init() {
        loadSettings()
        if filters.isEmpty {
            // Danh sách các bộ lọc Extension chính thức của AdGuard & ABPVN
            filters = [
                FilterListConfig(name: "AdGuard Base Filter", url: "https://filters.adtidy.org/ios/filters/2_optimized.txt", isEnabled: true, ruleCount: 42100),
                FilterListConfig(name: "AdGuard Mobile Ads", url: "https://filters.adtidy.org/ios/filters/11_optimized.txt", isEnabled: true, ruleCount: 15400),
                FilterListConfig(name: "AdGuard Tracking Protection", url: "https://filters.adtidy.org/ios/filters/3_optimized.txt", isEnabled: true, ruleCount: 18200),
                FilterListConfig(name: "ABPVN Filter (Chống cờ bạc VN)", url: "https://raw.githubusercontent.com/abpvn/abpvn/master/filter/abpvn.txt", isEnabled: true, ruleCount: 9800),
                FilterListConfig(name: "AdGuard Annoyances (Chặn Popup/Cookie)", url: "https://filters.adtidy.org/ios/filters/14_optimized.txt", isEnabled: true, ruleCount: 24000)
            ]
            saveFilters()
        }

        if userScripts.isEmpty {
            // Scriptlets Extension tương tự Tampermonkey / AdGuard Extra trên PC
            userScripts = [
                UserScriptConfig(
                    name: "AdGuard Extra (Anti-Adblock Defuser)",
                    code: """
                    window.canRunAds = true;
                    window.isAdBlockActive = false;
                    Object.defineProperty(navigator, 'webdriver', {get: () => undefined});
                    """,
                    isEnabled: true
                ),
                UserScriptConfig(
                    name: "Video In-Stream Ad Killer",
                    code: """
                    // Kill VAST / VPAID & Auto-skip native video ads
                    setInterval(() => {
                        document.querySelectorAll('video').forEach(v => {
                            if (v.duration <= 35 && (v.closest('.ad-container') || v.src.includes('ad'))) {
                                v.muted = true;
                                v.currentTime = v.duration || 9999;
                            }
                        });
                        document.querySelectorAll('.ytp-ad-skip-button, .jw-skip, .videojs-ad-skip').forEach(b => b.click());
                    }, 200);
                    """,
                    isEnabled: true
                )
            ]
            saveScripts()
        }
    }

    func toggleFilter(id: UUID) {
        if let idx = filters.firstIndex(where: { $0.id == id }) {
            filters[idx].isEnabled.toggle()
            saveFilters()
            AdBlockEngine.shared.compileRules()
        }
    }

    func addCustomFilter(name: String, url: String) {
        let newFilter = FilterListConfig(name: name, url: url, isEnabled: true, ruleCount: 1000)
        filters.append(newFilter)
        saveFilters()
        AdBlockEngine.shared.compileRules()
    }

    func deleteFilter(at offsets: IndexSet) {
        filters.remove(atOffsets: offsets)
        saveFilters()
        AdBlockEngine.shared.compileRules()
    }

    func toggleScript(id: UUID) {
        if let idx = userScripts.firstIndex(where: { $0.id == id }) {
            userScripts[idx].isEnabled.toggle()
            saveScripts()
        }
    }

    func addUserScript(name: String, code: String) {
        let script = UserScriptConfig(name: name, code: code, isEnabled: true)
        userScripts.append(script)
        saveScripts()
    }

    private func saveFilters() {
        if let data = try? JSONEncoder().encode(filters) {
            UserDefaults.standard.set(data, forKey: filterKey)
        }
    }

    private func saveScripts() {
        if let data = try? JSONEncoder().encode(userScripts) {
            UserDefaults.standard.set(data, forKey: scriptKey)
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: filterKey),
           let list = try? JSONDecoder().decode([FilterListConfig].self, from: data) {
            filters = list
        }
        if let data = UserDefaults.standard.data(forKey: scriptKey),
           let list = try? JSONDecoder().decode([UserScriptConfig].self, from: data) {
            userScripts = list
        }
    }
}
