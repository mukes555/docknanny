import SwiftUI

/// The little cloud a tile leaves when dragged off the dock: a ring of dots
/// flying outward and fading. Purely decorative, so it never intercepts a
/// click and never runs under Reduce Motion.
struct PoofBurst: View {
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let dotCount = 8
    private static let reach: CGFloat = 22

    var body: some View {
        ZStack {
            ForEach(0..<Self.dotCount, id: \.self) { index in
                let angle = CGFloat(index) / CGFloat(Self.dotCount) * 2 * .pi
                Circle()
                    .fill(.white.opacity(0.85))
                    .frame(width: 6, height: 6)
                    .offset(
                        x: expanded ? cos(angle) * Self.reach : 0,
                        y: expanded ? sin(angle) * Self.reach : 0
                    )
                    .opacity(expanded ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.4)) { expanded = true }
        }
    }
}
