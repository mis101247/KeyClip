import AppKit
import SwiftUI

enum Theme {

    // MARK: - Colors (light / dark dynamic)

    static let bg              = dynamic(light: hex(0xf7f6f2), dark: hex(0x171614))
    static let surface         = dynamic(light: hex(0xf9f8f5), dark: hex(0x1c1b19))
    static let surface2        = dynamic(light: hex(0xfbfbf9), dark: hex(0x201f1d))
    static let surfaceOffset   = dynamic(light: hex(0xf3f0ec), dark: hex(0x22211f))
    static let divider         = dynamic(light: hex(0xdcd9d5), dark: hex(0x262523))
    static let border          = dynamic(light: hex(0xd4d1ca), dark: hex(0x393836))

    static let text            = dynamic(light: hex(0x28251d), dark: hex(0xcdccca))
    static let textMuted       = dynamic(light: hex(0x7a7974), dark: hex(0x797876))
    static let textFaint       = dynamic(light: hex(0xbab9b4), dark: hex(0x5a5957))

    static let primary         = dynamic(light: hex(0x01696f), dark: hex(0x4f98a3))

    // Type icon tints
    static let iconCode        = dynamic(light: hex(0x7c5cff), dark: hex(0xa78bff))
    static let iconText        = dynamic(light: hex(0x8e8c87), dark: hex(0x8a8884))
    static let iconRichText    = dynamic(light: hex(0xd97447), dark: hex(0xe08a5e))
    static let iconImage       = dynamic(light: hex(0x4789d9), dark: hex(0x6aa3e8))
    static let iconLink        = dynamic(light: hex(0x1ea49b), dark: hex(0x3ab8ad))
    static let iconEmail       = dynamic(light: hex(0xc5524a), dark: hex(0xd56b62))
    static let iconPhone       = dynamic(light: hex(0x4ea05c), dark: hex(0x6cba79))
    static let iconColor       = dynamic(light: hex(0xc36ba6), dark: hex(0xd687bd))
    static let iconEmoji       = dynamic(light: hex(0xc99a3a), dark: hex(0xddb050))
    static let iconFile        = dynamic(light: hex(0x7d7c77), dark: hex(0x9b9994))

    // MARK: - Spacing
    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16

    // MARK: - Radius
    static let radiusSm: CGFloat = 6
    static let radiusFull: CGFloat = 9999

    // MARK: - Type scale
    static let textXs: Font  = .system(size: 12, weight: .regular, design: .default)
    static let textXsMedium: Font = .system(size: 12, weight: .medium, design: .default)
    static let textSm: Font  = .system(size: 13, weight: .regular, design: .default)
    static let textSmEmphasis: Font = .system(size: 13, weight: .semibold, design: .default)
    static let textMono: Font = .system(size: 12, weight: .regular, design: .monospaced)
    static let textCodePreview: Font = .system(size: 13, weight: .regular, design: .monospaced)

    // MARK: - Helpers

    private static func hex(_ value: UInt32) -> NSColor {
        let r = CGFloat((value >> 16) & 0xff) / 255
        let g = CGFloat((value >> 8) & 0xff) / 255
        let b = CGFloat(value & 0xff) / 255
        return NSColor(red: r, green: g, blue: b, alpha: 1)
    }

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            return isDark ? dark : light
        })
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
