#if os(watchOS)
import SwiftUI

struct WatchContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Fortis")
                .font(.headline)
            Text("Waiting for workout task…")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
    }
}
#endif