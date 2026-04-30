import SwiftUI

struct SocialView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.romanGoldDim)
                    VStack(spacing: 8) {
                        Text("SOCIAL")
                            .font(.system(size: 13, weight: .black))
                            .tracking(4)
                            .foregroundStyle(.romanParchment)
                        Text("Friend activity, challenges, and leaderboards\narrive in Phase 3.")
                            .font(.subheadline)
                            .foregroundStyle(.romanParchmentDim)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
            }
            .navigationTitle("SOCIAL")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
