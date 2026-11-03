# QuickWeb - TrollStore iOS 15.4 Build & Packaging Guide

App Bookmark + Favicon Auto-Grab + Native AdBlock (YouTube & Web) cho iOS 15.4 chạy qua TrollStore.

---

### Cấu trúc project:
- [QuickWebApp.swift](file:///c:/Users/TanDat/OneDrive%20-%20amicalv1/M%C3%A1y%20t%C3%ADnh/pr%20ma/QuickWeb/QuickWebApp.swift): Điểm khởi chạy app SwiftUI.
- [BookmarkStore.swift](file:///c:/Users/TanDat/OneDrive%20-%20amicalv1/M%C3%A1y%20t%C3%ADnh/pr%20ma/QuickWeb/BookmarkStore.swift): Model & lưu trữ danh sách bookmark + tự động phân giải Favicon.
- [AdBlockEngine.swift](file:///c:/Users/TanDat/OneDrive%20-%20amicalv1/M%C3%A1y%20t%C3%ADnh/pr%20ma/QuickWeb/AdBlockEngine.swift): Bộ quy tắc chặn quảng cáo native WebKit + auto-skip video ads cho YouTube.
- [WebBrowserView.swift](file:///c:/Users/TanDat/OneDrive%20-%20amicalv1/M%C3%A1y%20t%C3%ADnh/pr%20ma/QuickWeb/WebBrowserView.swift): WKWebView tối ưu mượt mà 120Hz ProMotion trên iOS 15.4.
- [YouTubeContainerView.swift](file:///c:/Users/TanDat/OneDrive%20-%20amicalv1/M%C3%A1y%20t%C3%ADnh/pr%20ma/QuickWeb/YouTubeContainerView.swift): Giao diện thanh bar Native YouTube siêu gọn gàng (Chevron back + logo + AdBlock pill).
- [HomeBookmarkView.swift](file:///c:/Users/TanDat/OneDrive%20-%20amicalv1/M%C3%A1y%20t%C3%ADnh/pr%20ma/QuickWeb/HomeBookmarkView.swift): Màn hình chính lưới icon bookmarks chuẩn iOS.
- [Info.plist](file:///c:/Users/TanDat/OneDrive%20-%20amicalv1/M%C3%A1y%20t%C3%ADnh/pr%20ma/QuickWeb/Info.plist): Metadata app và quyền hạn iOS.
- [entitlements.plist](file:///c:/Users/TanDat/OneDrive%20-%20amicalv1/M%C3%A1y%20t%C3%ADnh/pr%20ma/QuickWeb/entitlements.plist): Entitlements bypass sandbox cho TrollStore.

---

### Cách Build file IPA (Bằng Xcode hoặc Theos/CLI):

#### Cách 1: Dùng Xcode trên macOS
1. Tạo 1 project iOS SwiftUI mới trong Xcode tên `QuickWeb`.
2. Kéo toàn bộ các file `.swift`, `Info.plist`, `entitlements.plist` trong thư mục `QuickWeb` vào project.
3. Chọn build scheme: **Any iOS Device (arm64)**.
4. Đặt Deployment Target là **iOS 15.0**.
5. Nhấn `Product -> Build` (Release).
6. Lấy file `QuickWeb.app` trong thư mục Products / DerivedData.
7. Đóng gói thành `.ipa`:
   ```bash
   mkdir -p Payload
   cp -r QuickWeb.app Payload/
   zip -r QuickWeb_TrollStore.ipa Payload
   ```

#### Cách 2: Ký bằng ldid với entitlements TrollStore
```bash
ldid -Sentitlements.plist QuickWeb.app/QuickWeb
```

Sau đó copy file `QuickWeb_TrollStore.ipa` qua iPhone (AirDrop / Telegram / Drive) và chọn **Open in TrollStore** để cài đặt. App sẽ chạy mượt mà, vĩnh viễn không hết hạn chứng chỉ.
