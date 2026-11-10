import Foundation

struct SiteShieldSettings: Codable, Equatable {
    var adBlockEnabled: Bool = true        // Chặn banner, tracking, cờ bạc
    var autoSkipVideoAds: Bool = false      // Tự động tua video quảng cáo (mặc định TẮT để không bị tua nhầm video chính)
    var blockPopups: Bool = true           // Chặn nhảy tab popup
    var antiAdblockDefuser: Bool = true    // Bỏ qua cảnh báo phát hiện adblock
}

struct Bookmark: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var url: String
    var domain: String
    var isSpecialApp: Bool = false
    var shieldSettings: SiteShieldSettings = SiteShieldSettings()

    var faviconURL: URL? {
        if isSpecialApp && domain.contains("youtube") {
            return nil
        }
        return URL(string: "https://icons.duckduckgo.com/ip3/\(domain).ico")
    }
}

class BookmarkStore: ObservableObject {
    @Published var bookmarks: [Bookmark] = []
    private let key = "quickweb_bookmarks_key"

    init() {
        load()
        if bookmarks.isEmpty {
            bookmarks = [
                Bookmark(title: "YouTube", url: "https://m.youtube.com", domain: "youtube.com", isSpecialApp: true),
                Bookmark(title: "Phim NguonC", url: "https://phim.nguonc.com", domain: "phim.nguonc.com"),
                Bookmark(title: "VnExpress", url: "https://vnexpress.net", domain: "vnexpress.net"),
                Bookmark(title: "Google", url: "https://google.com", domain: "google.com")
            ]
            save()
        }
    }

    func addBookmark(title: String, urlString: String) {
        var clean = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.hasPrefix("http://") && !clean.hasPrefix("https://") {
            clean = "https://" + clean
        }
        guard let url = URL(string: clean), let host = url.host else { return }

        let name = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? host.replacingOccurrences(of: "www.", with: "").capitalized
            : title

        let isYT = host.contains("youtube.com") || host.contains("youtu.be")
        let item = Bookmark(title: name, url: clean, domain: host, isSpecialApp: isYT)
        bookmarks.append(item)
        save()
    }

    func updateSettings(for id: UUID, newSettings: SiteShieldSettings) {
        if let idx = bookmarks.firstIndex(where: { $0.id == id }) {
            bookmarks[idx].shieldSettings = newSettings
            save()
        }
    }

    func deleteBookmark(byId id: UUID) {
        bookmarks.removeAll { $0.id == id }
        save()
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) {
            bookmarks = decoded
        }
    }
}
