import SwiftUI

struct SiteShieldSettingsSheet: View {
    @Binding var settings: SiteShieldSettings
    let domain: String
    var onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Cài đặt khiên bảo vệ cho: \(domain)")) {
                    Toggle("Chặn quảng cáo & Banner", isOn: $settings.adBlockEnabled)
                    Toggle("Chặn nhảy tab Popup", isOn: $settings.blockPopups)
                    Toggle("Bỏ qua cảnh báo Anti-Adblock", isOn: $settings.antiAdblockDefuser)
                }

                Section(
                    header: Text("Tua nhanh Video quảng cáo"),
                    footer: Text("Nếu trang web bị lỗi tua video liên tục hoặc video bị lặp, hãy TẮT tính năng này.")
                ) {
                    Toggle("Tự động tua video quảng cáo (In-stream)", isOn: $settings.autoSkipVideoAds)
                }
            }
            .navigationTitle("Tùy biến bộ lọc")
            .navigationBarItems(trailing: Button("Lưu") {
                onSave()
                presentationMode.wrappedValue.dismiss()
            })
        }
        .preferredColorScheme(.dark)
    }
}
