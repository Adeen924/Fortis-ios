import SwiftUI

struct SocialView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "person.2.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange.opacity(0.7))
                VStack(spacing: 8) {
                    Text("Social — Coming Soon")
                        .font(.title3.bold())
                    Text("Friend activity feed, challenges,\nand leaderboards arrive in Phase 3.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .navigationTitle("Social")
        }
    }
}
