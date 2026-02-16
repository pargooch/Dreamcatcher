import SwiftUI

struct ComicPanelCard<Content: View>: View {
    let titleBanner: String?
    let bannerColor: Color
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(
        titleBanner: String? = nil,
        bannerColor: Color = ComicTheme.Colors.boldBlue,
        @ViewBuilder content: () -> Content
    ) {
        self.titleBanner = titleBanner
        self.bannerColor = bannerColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = titleBanner {
                Text(title.uppercased())
                    .font(ComicTheme.Typography.sectionHeader())
                    .tracking(1.5)
                    .foregroundStyle(bannerColor == ComicTheme.Colors.goldenYellow ? .black : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(bannerColor)
            }

            content
                .padding()
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.panelCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ComicTheme.Dimensions.panelCornerRadius)
                .stroke(
                    ComicTheme.panelBorderColor(colorScheme),
                    lineWidth: ComicTheme.Dimensions.panelBorderWidth
                )
        )
        .shadow(
            color: .black.opacity(0.15),
            radius: ComicTheme.Dimensions.cardShadowRadius,
            x: 2, y: 2
        )
    }
}
