import SwiftUI

// MARK: - Comic Book Theme System

enum ComicTheme {

    // MARK: - Colors

    enum Colors {
        static let boldBlue = Color(red: 0x1A / 255, green: 0x56 / 255, blue: 0xDB / 255)
        static let crimsonRed = Color(red: 0xDC / 255, green: 0x26 / 255, blue: 0x26 / 255)
        static let goldenYellow = Color(red: 0xF5 / 255, green: 0x9E / 255, blue: 0x0B / 255)
        static let emeraldGreen = Color(red: 0x05 / 255, green: 0x96 / 255, blue: 0x69 / 255)
        static let deepPurple = Color(red: 0x7C / 255, green: 0x3A / 255, blue: 0xED / 255)
        static let hotPink = Color(red: 0xEC / 255, green: 0x48 / 255, blue: 0x99 / 255)

        static let panelBorder = Color(red: 0x1F / 255, green: 0x29 / 255, blue: 0x37 / 255)
        static let panelBorderLight = Color(red: 0xE5 / 255, green: 0xE7 / 255, blue: 0xEB / 255)
        static let warmBackground = Color(red: 0xFF / 255, green: 0xFB / 255, blue: 0xF0 / 255)
    }

    // MARK: - Typography

    enum Typography {
        static func dreamTitle(_ size: CGFloat = 28) -> Font {
            .system(size: size, weight: .black, design: .default)
        }

        static func sectionHeader(_ size: CGFloat = 13) -> Font {
            .system(size: size, weight: .heavy, design: .default)
        }

        static func soundEffect(_ size: CGFloat = 36) -> Font {
            .system(size: size, weight: .black, design: .default).italic()
        }

        static func speechBubble(_ size: CGFloat = 15) -> Font {
            .system(size: size, weight: .medium, design: .default)
        }

        static func comicButton(_ size: CGFloat = 15) -> Font {
            .system(size: size, weight: .bold, design: .default)
        }
    }

    // MARK: - Dimensions

    enum Dimensions {
        static let panelBorderWidth: CGFloat = 3.5
        static let panelCornerRadius: CGFloat = 10
        static let gutterWidth: CGFloat = 12
        static let cardShadowRadius: CGFloat = 4
        static let buttonBorderWidth: CGFloat = 2.5
        static let buttonCornerRadius: CGFloat = 8
    }

    // MARK: - Adaptive Colors

    static func panelBorderColor(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Colors.panelBorderLight : Colors.panelBorder
    }
}

// MARK: - Comic Button Styles

struct ComicPrimaryButtonStyle: ButtonStyle {
    var color: Color = ComicTheme.Colors.boldBlue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ComicTheme.Typography.comicButton())
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius)
                    .stroke(Color.black.opacity(0.3), lineWidth: ComicTheme.Dimensions.buttonBorderWidth)
            )
            .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 2)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

struct ComicSecondaryButtonStyle: ButtonStyle {
    var color: Color = ComicTheme.Colors.boldBlue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ComicTheme.Typography.comicButton(14))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius)
                    .stroke(color, lineWidth: ComicTheme.Dimensions.buttonBorderWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

struct ComicDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ComicTheme.Typography.comicButton(14))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(ComicTheme.Colors.crimsonRed)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius)
                    .stroke(ComicTheme.Colors.crimsonRed, lineWidth: ComicTheme.Dimensions.buttonBorderWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Convenience extensions

extension ButtonStyle where Self == ComicPrimaryButtonStyle {
    static var comicPrimary: ComicPrimaryButtonStyle { .init() }
    static func comicPrimary(color: Color) -> ComicPrimaryButtonStyle { .init(color: color) }
}

extension ButtonStyle where Self == ComicSecondaryButtonStyle {
    static var comicSecondary: ComicSecondaryButtonStyle { .init() }
    static func comicSecondary(color: Color) -> ComicSecondaryButtonStyle { .init(color: color) }
}

extension ButtonStyle where Self == ComicDestructiveButtonStyle {
    static var comicDestructive: ComicDestructiveButtonStyle { .init() }
}
