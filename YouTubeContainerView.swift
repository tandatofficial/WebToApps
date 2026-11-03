import SwiftUI

struct YouTubeContainerView: View {
    @Environment(\.presentationMode) var presentationMode
    let initialURL: URL

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Ultra Compact Native Header
            HStack(spacing: 8) {
                // Back Button
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.trailing, 4)
                }

                // YouTube Logo + Clean Adblock Pill
                HStack(spacing: 6) {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 20))

                    Text("YouTube")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 3) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 0.18, green: 0.82, blue: 0.35))
                        Text("AdBlock")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(red: 0.18, green: 0.82, blue: 0.35))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.18, green: 0.82, blue: 0.35).opacity(0.15))
                    .cornerRadius(6)
                }

                Spacer()

                // Right Profile Icon
                Circle()
                    .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Text("T")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .padding(.horizontal, 14)
            .padding(.top, 44) // iOS 15 notch offset
            .padding(.bottom, 8)
            .background(Color.black)

            // MARK: - WKWebView Loading YouTube Mobile
            WebBrowserView(url: initialURL, isYouTube: true)
                .edgesIgnoringSafeArea(.bottom)
        }
        .background(Color.black.ignoresSafeArea())
    }
}
