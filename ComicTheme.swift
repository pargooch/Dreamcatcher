import SwiftUI

// MARK: - Comic Book Theme System

enum ComicTheme {

    // MARK: - Modifiable Color Palette

    /// Raw color values — change these to reskin the entire app.
    enum Palette {
        // Vintage comic primaries
        static let inkBlack     = Color(red: 0x1A/255, green: 0x1A/255, blue: 0x1E/255)
        static let heroBlue     = Color(red: 0x05/255, green: 0x8C/255, blue: 0xD7/255)
        static let crimson      = Color(red: 0xFD/255, green: 0x5A/255, blue: 0x46/255)
        static let goldenYellow = Color(red: 0xFF/255, green: 0xC5/255, blue: 0x67/255)
        static let emerald      = Color(red: 0x00/255, green: 0x99/255, blue: 0x5E/255)
        static let deepPurple   = Color(red: 0x7C/255, green: 0x3A/255, blue: 0xED/255)
        static let hotPink      = Color(red: 0xFB/255, green: 0x7D/255, blue: 0xA8/255)

        // Art Deco metallic accents
        static let antiqueBrass   = Color(red: 0xB0/255, green: 0x8D/255, blue: 0x57/255)
        static let champagneGold  = Color(red: 0xD4/255, green: 0xAF/255, blue: 0x6A/255)

        // Paper & surface tones (vintage, never pure white)
        static let agedPaper       = Color(red: 0xF5/255, green: 0xE6/255, blue: 0xCA/255)
        static let agedPaperDark   = Color(red: 0x2A/255, green: 0x24/255, blue: 0x1E/255)
        static let panelSurface    = Color(red: 0xFB/255, green: 0xF2/255, blue: 0xDB/255)
        static let panelSurfaceDark = Color(red: 0x33/255, green: 0x2C/255, blue: 0x24/255)

        // Per-page background tints (light mode only)
        static let bgNewDream      = Color(red: 0xF4/255, green: 0xBE/255, blue: 0xAE/255)
        static let bgDreams        = Color(red: 0xEF/255, green: 0xCE/255, blue: 0x7B/255)
        static let bgAnalysis      = Color(red: 0x93/255, green: 0xD3/255, blue: 0xAE/255)
        static let bgSettings      = Color(red: 0xFA/255, green: 0xEC/255, blue: 0xD0/255)
        static let bgNotifications = Color(red: 0xE8/255, green: 0xCC/255, blue: 0xAD/255)
        static let bgAccount       = Color(red: 0xF1/255, green: 0xF3/255, blue: 0xD0/255)
    }

    // MARK: - Semantic Colors (what each color means)

    enum Semantic {
        // Actions
        static let primaryAction     = Palette.heroBlue
        static let secondaryAction   = Palette.deepPurple
        static let destructiveAction = Palette.crimson
        static let successAction     = Palette.emerald
        static let warningAction     = Palette.goldenYellow
        static let specialAction     = Palette.hotPink

        // Surfaces
        static func background(_ cs: ColorScheme) -> Color {
            cs == .dark ? Palette.agedPaperDark : Palette.agedPaper
        }
        static func cardSurface(_ cs: ColorScheme) -> Color {
            cs == .dark ? Palette.panelSurfaceDark : Palette.panelSurface
        }

        // Borders — Art Deco gold tones
        static func panelBorder(_ cs: ColorScheme) -> Color {
            cs == .dark ? Palette.champagneGold : Palette.antiqueBrass
        }
        static func frameBorderInner(_ cs: ColorScheme) -> Color {
            cs == .dark ? Palette.champagneGold.opacity(0.5) : Palette.antiqueBrass.opacity(0.6)
        }
        static func cornerOrnament(_ cs: ColorScheme) -> Color {
            cs == .dark ? Palette.champagneGold : Palette.antiqueBrass
        }
    }

    // MARK: - Legacy Color Aliases (backward compatibility)

    enum Colors {
        static let boldBlue     = Palette.heroBlue
        static let crimsonRed   = Palette.crimson
        static let goldenYellow = Palette.goldenYellow
        static let emeraldGreen = Palette.emerald
        static let deepPurple   = Palette.deepPurple
        static let hotPink      = Palette.hotPink
        static let panelBorder  = Palette.inkBlack
        static let panelBorderLight = Color(red: 0xE5/255, green: 0xE7/255, blue: 0xEB/255)
        static let warmBackground   = Palette.agedPaper
    }

    // MARK: - Typography

    enum Typography {
        static func dreamTitle(_ size: CGFloat = 28) -> Font {
            .system(size: size, weight: .black)
        }

        static func sectionHeader(_ size: CGFloat = 13) -> Font {
            .system(size: size, weight: .semibold)
        }

        static func soundEffect(_ size: CGFloat = 36) -> Font {
            .system(size: size, weight: .black)
        }

        static func speechBubble(_ size: CGFloat = 15) -> Font {
            .system(size: size, weight: .medium)
        }

        static func comicButton(_ size: CGFloat = 15) -> Font {
            .system(size: size, weight: .bold)
        }

        static func caption(_ size: CGFloat = 11) -> Font {
            .system(size: size, weight: .semibold)
        }

        static func bodyText(_ size: CGFloat = 15) -> Font {
            .system(size: size, weight: .regular)
        }
    }

    // MARK: - Dimensions

    enum Dimensions {
        static let panelBorderWidth: CGFloat = 1.5
        static let panelInnerBorderWidth: CGFloat = 0.75
        static let panelBorderGap: CGFloat = 3
        static let panelCornerRadius: CGFloat = 4
        static let cornerOrnamentSize: CGFloat = 14
        static let gutterWidth: CGFloat = 16
        static let cardShadowRadius: CGFloat = 0
        static let buttonBorderWidth: CGFloat = 1.5
        static let buttonCornerRadius: CGFloat = 6
        static let speechBubbleBorderWidth: CGFloat = 1.0
        static let speechBubbleCornerRadius: CGFloat = 12
        static let badgeCornerRadius: CGFloat = 4
    }

    // MARK: - Adaptive Colors (legacy helper)

    static func panelBorderColor(_ colorScheme: ColorScheme) -> Color {
        Semantic.panelBorder(colorScheme)
    }
}

// MARK: - Comic Shadow Modifier

struct ComicShadow: ViewModifier {
    var intensity: Intensity = .medium

    enum Intensity {
        case light, medium, heavy
    }

    func body(content: Content) -> some View {
        switch intensity {
        case .light:
            content
                .shadow(color: .black.opacity(0.25), radius: 0, x: 2, y: 2)
                .shadow(color: .black.opacity(0.10), radius: 1, x: 3, y: 3)
        case .medium:
            content
                .shadow(color: .black.opacity(0.30), radius: 0, x: 2, y: 2)
                .shadow(color: .black.opacity(0.15), radius: 1, x: 3, y: 3)
                .shadow(color: .black.opacity(0.08), radius: 3, x: 4, y: 5)
        case .heavy:
            content
                .shadow(color: .black.opacity(0.40), radius: 0, x: 3, y: 3)
                .shadow(color: .black.opacity(0.20), radius: 1, x: 4, y: 4)
                .shadow(color: .black.opacity(0.10), radius: 2, x: 5, y: 6)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 6, y: 8)
        }
    }
}

extension View {
    func comicShadow(_ intensity: ComicShadow.Intensity = .medium) -> some View {
        modifier(ComicShadow(intensity: intensity))
    }
}

// MARK: - Retro Art Deco Button Styles

struct ComicPrimaryButtonStyle: ButtonStyle {
    var color: Color = ComicTheme.Semantic.primaryAction

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ComicTheme.Typography.comicButton())
            .textCase(.uppercase)
            .tracking(1.5)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.6), lineWidth: 1.5)
            )
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.15), lineWidth: 0.75)
                    .padding(4)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ComicSecondaryButtonStyle: ButtonStyle {
    var color: Color = ComicTheme.Semantic.primaryAction
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ComicTheme.Typography.comicButton(14))
            .textCase(.uppercase)
            .tracking(1.5)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(ComicTheme.Semantic.cardSurface(colorScheme))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.5), lineWidth: 1.5)
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.12), lineWidth: 0.75)
                    .padding(4)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ComicDestructiveButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let color = ComicTheme.Semantic.destructiveAction
        configuration.label
            .font(ComicTheme.Typography.comicButton(14))
            .textCase(.uppercase)
            .tracking(1.5)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(ComicTheme.Semantic.cardSurface(colorScheme))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.5), lineWidth: 1.5)
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.12), lineWidth: 0.75)
                    .padding(4)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
