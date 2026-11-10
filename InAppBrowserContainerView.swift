import SwiftUI

struct InAppBrowserContainerView: View {
    @ObservedObject var store: BookmarkStore
    @Binding var bookmark: Bookmark
    var onDismiss: () -> Void

    @State private var webViewID: UUID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Browser Header Bar
            HStack(spacing: 12) {
                // Nút Đóng
                Button(action: onDismiss) {
                    Text("Đóng")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.blue)
                }

                Spacer()

                // Tên miền trang web
                VStack(spacing: 2) {
                    Text(bookmark.domain)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(bookmark.shieldSettings.adBlockEnabled ? "Khiên đang BẬT" : "Khiên đã TẮT")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(bookmark.shieldSettings.adBlockEnabled ? Color(red: 0.18, green: 0.82, blue: 0.35) : Color.gray)
                }

                Spacer()

                // MARK: - Menu Khiên Bật/Tắt Gạt Nút Trực Tiếp (Không bị lỗi đơ)
                Menu {
                    // 1. Nút bấm gạt công tắc nhanh BẬT / TẮT khiên
                    Button {
                        bookmark.shieldSettings.adBlockEnabled.toggle()
                        saveAndReload()
                    } label: {
                        Label(
                            bookmark.shieldSettings.adBlockEnabled ? "Tắt khiên bảo vệ" : "Bật khiên bảo vệ",
                            systemImage: bookmark.shieldSettings.adBlockEnabled ? "shield.slash.fill" : "shield.fill"
                        )
                    }

                    Divider()

                    // 2. Tùy chọn gạt nút từng tính năng chi tiết
                    Button {
                        bookmark.shieldSettings.blockPopups.toggle()
                        saveAndReload()
                    } label: {
                        Label(
                            "Chặn nhảy tab Popup: \(bookmark.shieldSettings.blockPopups ? "BẬT" : "TẮT")",
                            systemImage: bookmark.shieldSettings.blockPopups ? "checkmark.circle.fill" : "circle"
                        )
                    }

                    Button {
                        bookmark.shieldSettings.antiAdblockDefuser.toggle()
                        saveAndReload()
                    } label: {
                        Label(
                            "Chống Anti-Adblock: \(bookmark.shieldSettings.antiAdblockDefuser ? "BẬT" : "TẮT")",
                            systemImage: bookmark.shieldSettings.antiAdblockDefuser ? "checkmark.circle.fill" : "circle"
                        )
                    }

                    Button {
                        bookmark.shieldSettings.autoSkipVideoAds.toggle()
                        saveAndReload()
                    } label: {
                        Label(
                            "Tua video quảng cáo: \(bookmark.shieldSettings.autoSkipVideoAds ? "BẬT" : "TẮT")",
                            systemImage: bookmark.shieldSettings.autoSkipVideoAds ? "checkmark.circle.fill" : "circle"
                        )
                    }

                    Divider()

                    Button {
                        webViewID = UUID() // Tải lại trang web
                    } label: {
                        Label("Tải lại trang web", systemImage: "arrow.clockwise")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: bookmark.shieldSettings.adBlockEnabled ? "shield.fill" : "shield.slash.fill")
                            .font(.system(size: 13))
                        Text(bookmark.shieldSettings.adBlockEnabled ? "Bật" : "Tắt")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(bookmark.shieldSettings.adBlockEnabled ? Color(red: 0.18, green: 0.82, blue: 0.35) : Color.gray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        (bookmark.shieldSettings.adBlockEnabled ? Color(red: 0.18, green: 0.82, blue: 0.35) : Color.gray)
                            .opacity(0.18)
                    )
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(white: 0.1))

            // MARK: - Trình duyệt Web tải với cấu hình đã gạt
            if let targetURL = URL(string: bookmark.url) {
                WebBrowserView(url: targetURL, isYouTube: false, settings: bookmark.shieldSettings)
                    .id(webViewID) // Reload tức thì khi thay đổi cấu hình
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func saveAndReload() {
        store.updateSettings(for: bookmark.id, newSettings: bookmark.shieldSettings)
        webViewID = UUID() // Áp dụng ngay bộ lọc mới vào trang web
    }
}
