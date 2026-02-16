import SwiftUI

struct HalftoneBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var dotSpacing: CGFloat = 14
    var opacity: Double = 0.05

    var body: some View {
        Canvas { context, size in
            let dotColor: Color = colorScheme == .dark ? .white : .black
            let dotSize: CGFloat = 2.5

            for x in stride(from: CGFloat(0), to: size.width, by: dotSpacing) {
                for y in stride(from: CGFloat(0), to: size.height, by: dotSpacing) {
                    let offset: CGFloat = Int(y / dotSpacing) % 2 == 0 ? dotSpacing / 2 : 0
                    let center = CGPoint(x: x + offset, y: y)
                    let rect = CGRect(
                        x: center.x - dotSize / 2,
                        y: center.y - dotSize / 2,
                        width: dotSize, height: dotSize
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(dotColor.opacity(opacity))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    func halftoneBackground() -> some View {
        self.background(HalftoneBackground())
    }
}
