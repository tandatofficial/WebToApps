import Foundation

struct Bookmark: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var url: String
    var domain: String
    var isSpecialApp: Bool = false

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
                Bookmark(title: "VnExpress", url: "https://vnexpress.net", domain: "vnexpress.net"),
                Bookmark(title: "Google", url: "https://google.com", domain: "google.com"),
                Bookmark(title: "Reddit", url: "https://reddit.com", domain: "reddit.com")
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

    func deleteBookmark(byId id: UUID) {
        bookmarks.removeAll { $0.id == id }
        save()
    }

    func deleteBookmark(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
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
