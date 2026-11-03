import SwiftUI

struct HomeBookmarkView: View {
    @StateObject private var store = BookmarkStore()
    @State private var inputTitle: String = ""
    @State private var inputURL: String = ""
    @State private var selectedBookmark: Bookmark? = nil
    @State private var showBrowser: Bool = false

    let columns = [
        GridItem(.adaptive(minimum: 74), spacing: 14)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                // Top Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iOS 15.4 • TROLLSTORE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                        Text("QuickWeb")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(red: 0.18, green: 0.82, blue: 0.35))
                            .frame(width: 6, height: 6)
                        Text("AdBlock Pro")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.18, green: 0.82, blue: 0.35))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.18, green: 0.82, blue: 0.35).opacity(0.12))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                // Input Box
                VStack(spacing: 8) {
                    HStack {
                        TextField("Nhập URL (ví dụ: m.youtube.com)...", text: $inputURL)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        Button(action: addAction) {
                            Text("Thêm")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(12)
                .background(Color(white: 0.12).opacity(0.85))
                .cornerRadius(16)
                .padding(.horizontal, 16)

                // Grid of icons
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(store.bookmarks) { item in
                            VStack(spacing: 6) {
                                ZStack(alignment: .bottomTrailing) {
                                    if item.isSpecialApp {
                                        // YouTube Icon
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(LinearGradient(colors: [Color(red: 0.25, green: 0, blue: 0), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 60, height: 60)
                                            .overlay(
                                                Image(systemName: "play.rectangle.fill")
                                                    .foregroundColor(.red)
                                                    .font(.system(size: 26))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                            )
                                    } else {
                                        // Standard Web Icon
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.white.opacity(0.08))
                                            .frame(width: 60, height: 60)
                                            .overlay(
                                                AsyncImage(url: item.faviconURL) { phase in
                                                    if let image = phase.image {
                                                        image.resizable().scaledToFit().frame(width: 32, height: 32)
                                                    } else {
                                                        Image(systemName: "globe")
                                                            .font(.system(size: 24))
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                            )
                                    }

                                    // Shield Dot
                                    Circle()
                                        .fill(Color(red: 0.18, green: 0.82, blue: 0.35))
                                        .frame(width: 9, height: 9)
                                        .padding(3)
                                }

                                Text(item.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(white: 0.85))
                                    .lineLimit(1)
                            }
                            .onTapGesture {
                                selectedBookmark = item
                                showBrowser = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }

                Spacer()
            }
        }
        .fullScreenCover(item: $selectedBookmark) { item in
            if let targetURL = URL(string: item.url) {
                if item.isSpecialApp {
                    YouTubeContainerView(initialURL: targetURL)
                } else {
                    // Standard In-App Browser with Adblock
                    VStack(spacing: 0) {
                        HStack {
                            Button("Đóng") {
                                selectedBookmark = nil
                            }
                            .foregroundColor(.blue)
                            .font(.system(size: 15, weight: .medium))

                            Spacer()
                            Text(item.domain)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()

                            Image(systemName: "shield.fill")
                                .foregroundColor(Color(red: 0.18, green: 0.82, blue: 0.35))
                                .font(.system(size: 14))
                        }
                        .padding()
                        .background(Color(white: 0.1))

                        WebBrowserView(url: targetURL, isYouTube: false)
                    }
                    .background(Color.black.ignoresSafeArea())
                }
            }
        }
    }

    func addAction() {
        guard !inputURL.isEmpty else { return }
        store.addBookmark(title: inputTitle, urlString: inputURL)
        inputTitle = ""
        inputURL = ""
    }
}
