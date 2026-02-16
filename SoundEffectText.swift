import SwiftUI

struct SoundEffectText: View {
    let text: String
    var rotation: Double = -5
    var fillColor: Color = ComicTheme.Colors.goldenYellow
    var strokeColor: Color = ComicTheme.Colors.panelBorder
    var fontSize: CGFloat = 36

    @State private var isAnimated = false

    var body: some View {
        Text(text)
            .font(ComicTheme.Typography.soundEffect(fontSize))
            .foregroundStyle(fillColor)
            .shadow(color: strokeColor, radius: 0, x: 2, y: 2)
            .shadow(color: strokeColor, radius: 0, x: -1, y: -1)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(isAnimated ? 1.0 : 0.3)
            .opacity(isAnimated ? 1.0 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    isAnimated = true
                }
            }
    }
}
