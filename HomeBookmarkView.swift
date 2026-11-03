import SwiftUI

struct HomeBookmarkView: View {
    @StateObject private var store = BookmarkStore()
    @State private var inputTitle: String = ""
    @State private var inputURL: String = ""
    @State private var selectedBookmark: Bookmark? = nil
    @State private var isEditing: Bool = false
    @State private var itemToDelete: Bookmark? = nil
    @State private var showDeleteConfirm: Bool = false
    @State private var showExtensionSettings: Bool = false

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

                    // Nút cài đặt tiện ích AdGuard Extension (như trên PC)
                    Button(action: {
                        showExtensionSettings = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "puzzlepiece.extension.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.18, green: 0.82, blue: 0.35))
                            Text("AdGuard")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 0.18, green: 0.82, blue: 0.35))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.18, green: 0.82, blue: 0.35).opacity(0.15))
                        .cornerRadius(12)
                    }

                    // Nút Sửa / Xóa Bookmark
                    Button(action: {
                        withAnimation(.spring()) {
                            isEditing.toggle()
                        }
                    }) {
                        Text(isEditing ? "Xong" : "Sửa")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                // Input Box
                VStack(spacing: 8) {
                    HStack {
                        TextField("Nhập URL (ví dụ: m.youtube.com, phimmoi)...", text: $inputURL)
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
                                ZStack(alignment: .topTrailing) {
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

                                    // Delete badge (hiển thị khi bấm "Sửa")
                                    if isEditing {
                                        Button(action: {
                                            itemToDelete = item
                                            showDeleteConfirm = true
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.red)
                                                .background(Circle().fill(Color.white).frame(width: 14, height: 14))
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }

                                Text(item.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(white: 0.85))
                                    .lineLimit(1)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !isEditing {
                                    selectedBookmark = item
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        store.deleteBookmark(byId: item.id)
                                    }
                                } label: {
                                    Label("Xóa trang này", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showExtensionSettings) {
            ExtensionSettingsView()
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(
                title: Text("Xác nhận xóa"),
                message: Text("Bạn có muốn xóa bookmark '\(itemToDelete?.title ?? "")' không?"),
                primaryButton: .destructive(Text("Xóa")) {
                    if let target = itemToDelete {
                        withAnimation {
                            store.deleteBookmark(byId: target.id)
                        }
                    }
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
        .fullScreenCover(item: $selectedBookmark) { item in
            if let targetURL = URL(string: item.url) {
                if item.isSpecialApp {
                    YouTubeContainerView(initialURL: targetURL)
                } else {
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

                            Button(action: { showExtensionSettings = true }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "puzzlepiece.extension.fill")
                                    Text("AdGuard")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 0.18, green: 0.82, blue: 0.35))
                            }
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
