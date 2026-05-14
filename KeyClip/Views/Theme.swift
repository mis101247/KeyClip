import AppKit
import SwiftUI

enum Theme {

    // MARK: - Keyo Brand Colors

    static let sky             = color(0xb8d8f0)
    static let mist            = color(0xd6ecf8)
    static let sun             = color(0xfff3c0)
    static let honey           = color(0xffdf90)
    static let lotus           = color(0xffd6dc)
    static let leaf            = color(0xd8edd8)
    static let canvas          = color(0xfafbfc)
    static let quartz          = color(0xe2eaf0)
    static let ink             = color(0x3a6080)

    static let cream           = color(0xf7f1e6)
    static let meadow          = color(0x7fb65a)
    static let grove           = color(0x3f6b3a)
    static let butter          = color(0xf6c94c)
    static let sunset          = color(0xf79a2e)
    static let tomato          = color(0xe94832)
    static let coral           = color(0xf47c6b)
    static let blush           = color(0xf3b8c8)
    static let daySky          = color(0x77b8e8)
    static let fjord           = color(0x9ed6d2)
    static let snowLilac       = color(0xd8c8f4)
    static let wood            = color(0xb98e63)

    // MARK: - Semantic Colors

    static let bg              = canvas
    static let surface         = mist.opacity(0.82)
    static let surface2        = cream.opacity(0.78)
    static let surfaceOffset   = leaf.opacity(0.62)
    static let divider         = quartz.opacity(0.72)
    static let border          = quartz

    static let text            = ink
    static let textMuted       = ink.opacity(0.72)
    static let textFaint       = ink.opacity(0.46)

    static let primary         = daySky
    static let primarySoft     = sky.opacity(0.34)
    static let accent          = honey
    static let memoryPoint     = tomato

    static let contentBackground = LinearGradient(
        colors: [
            color(0xfafbfc),
            color(0xf3f9fd),
            color(0xf8f4ec)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sidebarBackground = LinearGradient(
        colors: [
            color(0xeaf7fb),
            color(0xeff8ef),
            color(0xfafbfc)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let selectedBackground = LinearGradient(
        colors: [
            color(0xfff4cc),
            color(0xe9f5fc),
            color(0xffedf0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Type icon tints
    static let iconCode        = snowLilac
    static let iconText        = textMuted
    static let iconRichText    = coral
    static let iconImage       = daySky
    static let iconLink        = fjord
    static let iconEmail       = sunset
    static let iconPhone       = meadow
    static let iconColor       = blush
    static let iconEmoji       = butter
    static let iconFile        = wood

    // MARK: - Spacing
    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16

    // MARK: - Radius
    static let radiusSm: CGFloat = 8
    static let radiusMd: CGFloat = 12
    static let radiusFull: CGFloat = 9999

    // MARK: - Type scale
    static let headingSm: Font = serifFont(size: 14, weight: .bold)
    static let headingTracking: CGFloat = 0.7
    static let textXs: Font  = sansFont(size: 12, weight: .regular)
    static let textXsMedium: Font = sansFont(size: 12, weight: .medium)
    static let textSm: Font  = sansFont(size: 13, weight: .regular)
    static let textSmEmphasis: Font = sansFont(size: 13, weight: .semibold)
    static let textMono: Font = .system(size: 12, weight: .regular, design: .monospaced)
    static let textCodePreview: Font = .system(size: 13, weight: .regular, design: .monospaced)

    // MARK: - Shadows
    static let softShadow = ink.opacity(0.10)
    static let softShadowLight = ink.opacity(0.08)

    // MARK: - Helpers

    private static func color(_ value: UInt32) -> Color {
        Color(nsColor: hex(value))
    }

    private static func serifFont(size: CGFloat, weight: Font.Weight) -> Font {
        if hasFontFamily("Noto Serif TC") {
            return .custom("Noto Serif TC", size: size).weight(weight)
        }

        return .custom("Georgia", size: size).weight(weight)
    }

    private static func sansFont(size: CGFloat, weight: Font.Weight) -> Font {
        if hasFontFamily("Noto Sans TC") {
            return .custom("Noto Sans TC", size: size).weight(weight)
        }

        return .system(size: size, weight: weight, design: .default)
    }

    private static func hasFontFamily(_ familyName: String) -> Bool {
        NSFontManager.shared.availableFontFamilies.contains(familyName)
    }

    private static func hex(_ value: UInt32) -> NSColor {
        let r = CGFloat((value >> 16) & 0xff) / 255
        let g = CGFloat((value >> 8) & 0xff) / 255
        let b = CGFloat(value & 0xff) / 255
        return NSColor(red: r, green: g, blue: b, alpha: 1)
    }
}

extension ContentType {
    var themeTint: Color {
        switch self {
        case .code: return Theme.iconCode
        case .text: return Theme.iconText
        case .richText: return Theme.iconRichText
        case .image: return Theme.iconImage
        case .link: return Theme.iconLink
        case .email: return Theme.iconEmail
        case .phone: return Theme.iconPhone
        case .color: return Theme.iconColor
        case .emoji: return Theme.iconEmoji
        case .file, .files: return Theme.iconFile
        }
    }
}
