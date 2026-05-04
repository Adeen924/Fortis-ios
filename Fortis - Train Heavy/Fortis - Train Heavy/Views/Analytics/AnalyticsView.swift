import SwiftUI

struct AnalyticsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 56))
                        .foregroundStyle(.romanGoldDim)
                    Text("ANALYTICS")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(.romanParchment)
                    Text("Analytics will be arriving in Phase 2.")
                        .font(.subheadline)
                        .foregroundStyle(.romanParchmentDim)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .navigationTitle("ANALYTICS")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    AnalyticsView()
}
