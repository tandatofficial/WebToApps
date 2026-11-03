import SwiftUI

@main
struct QuickWebApp: App {
    var body: some Scene {
        WindowGroup {
            HomeBookmarkView()
                .preferredColorScheme(.dark)
        }
    }
}
