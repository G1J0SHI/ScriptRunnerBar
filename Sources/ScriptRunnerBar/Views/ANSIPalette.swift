import AppKit
import ScriptRunnerBarCore
import SwiftUI

/// Terminal styles as text attributes. The 16 basic colours have light and
/// dark variants so each stays readable on the output pane; 256-colour and
/// RGB values are used as given.
enum ANSIPalette {
    static func attributes(for style: ANSIStyle) -> AttributeContainer {
        var container = AttributeContainer()
        guard style != .plain else { return container }

        var foreground = style.foreground.map { color($0, onBackground: style.background != nil) }
        var background = style.background.map(backgroundColor)
        if style.isInverse {
            (foreground, background) = (background ?? Color(nsColor: .textBackgroundColor),
                                        foreground ?? Color(nsColor: .textColor))
        }
        if style.isDim {
            foreground = (foreground ?? Color(nsColor: .textColor)).opacity(0.6)
        }
        container.swiftUI.foregroundColor = foreground
        container.swiftUI.backgroundColor = background

        var intent: InlinePresentationIntent = []
        if style.isBold { intent.insert(.stronglyEmphasized) }
        if style.isItalic { intent.insert(.emphasized) }
        if !intent.isEmpty { container.inlinePresentationIntent = intent }
        if style.isUnderlined { container.swiftUI.underlineStyle = .single }
        if style.isStrikethrough { container.swiftUI.strikethroughStyle = .single }
        return container
    }

    /// On a coloured background (badges like `30;43m`), black and white mean
    /// exactly that; the adaptive variants are for text on the pane itself.
    private static func color(_ color: ANSIColor, onBackground: Bool) -> Color {
        switch color {
        case .palette(0) where onBackground:
            .black
        case .palette(7) where onBackground, .palette(15) where onBackground:
            .white
        case .palette(let index) where index < 16:
            basic[Int(index)]
        default:
            exact(color)
        }
    }

    /// Backgrounds don't adapt: the mid-tone palette works under both black
    /// and white text, while the pale dark-mode text colours wouldn't.
    private static func backgroundColor(_ color: ANSIColor) -> Color {
        if case .palette(let index) = color, index < 16 {
            return rgb(basicRGB[Int(index)].light)
        }
        return exact(color)
    }

    private static func exact(_ color: ANSIColor) -> Color {
        switch color {
        case .palette(let index):
            rgb(xterm256(index))
        case .rgb(let red, let green, let blue):
            rgb((red, green, blue))
        }
    }

    /// Black, red, green, yellow, blue, magenta, cyan, white, then the bright
    /// eight: light-appearance (mid-tone) and dark-appearance (bright) variants.
    private typealias RGB = (UInt8, UInt8, UInt8)
    private static let basicRGB: [(light: RGB, dark: RGB)] = [
        ((0, 0, 0), (110, 110, 110)),
        ((194, 54, 33), (255, 92, 87)),
        ((37, 140, 36), (90, 247, 142)),
        ((150, 128, 0), (243, 249, 157)),
        ((40, 70, 200), (87, 199, 255)),
        ((170, 40, 170), (255, 106, 193)),
        ((20, 135, 155), (154, 237, 254)),
        ((140, 140, 140), (199, 199, 199)),
        ((105, 105, 105), (135, 135, 135)),
        ((230, 60, 50), (255, 110, 103)),
        ((40, 170, 40), (95, 250, 104)),
        ((175, 155, 0), (254, 251, 103)),
        ((60, 100, 240), (125, 160, 255)),
        ((200, 60, 200), (255, 119, 255)),
        ((30, 165, 185), (96, 253, 255)),
        ((60, 60, 60), (255, 255, 255)),
    ]

    private static let basic: [Color] = basicRGB.map { light, dark in
        Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat(rgb.0) / 255, green: CGFloat(rgb.1) / 255, blue: CGFloat(rgb.2) / 255, alpha: 1)
        })
    }

    private static func rgb(_ value: RGB) -> Color {
        Color(.sRGB, red: Double(value.0) / 255, green: Double(value.1) / 255, blue: Double(value.2) / 255)
    }

    /// Indexes 16-231 are a 6x6x6 colour cube, 232-255 a grey ramp.
    private static func xterm256(_ index: UInt8) -> RGB {
        guard index < 232 else {
            let grey = UInt8(8 + (Int(index) - 232) * 10)
            return (grey, grey, grey)
        }
        let cube = Int(index) - 16
        func level(_ step: Int) -> UInt8 { step == 0 ? 0 : UInt8(55 + step * 40) }
        return (level(cube / 36), level(cube / 6 % 6), level(cube % 6))
    }
}
