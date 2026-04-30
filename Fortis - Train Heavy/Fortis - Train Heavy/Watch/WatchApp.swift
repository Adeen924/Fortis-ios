#if os(watchOS)
import SwiftUI

@main
struct FortisWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}
#endif