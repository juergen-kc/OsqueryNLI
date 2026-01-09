import SwiftUI

// MARK: - Font Scale

/// User-selectable font size preference
enum FontScale: String, CaseIterable, Identifiable {
    case small = "Small"
    case regular = "Regular"
    case large = "Large"

    var id: String { rawValue }

    /// Scale factor applied to base font sizes
    var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.85
        case .regular: return 1.0
        case .large: return 1.2
        }
    }

    /// Description for settings UI
    var description: String {
        switch self {
        case .small: return "Compact text for more content"
        case .regular: return "Default size"
        case .large: return "Larger text for readability"
        }
    }
}

// MARK: - Scaled Font Modifier

/// Environment key for font scale
private struct FontScaleKey: EnvironmentKey {
    static let defaultValue: FontScale = .regular
}

extension EnvironmentValues {
    var fontScale: FontScale {
        get { self[FontScaleKey.self] }
        set { self[FontScaleKey.self] = newValue }
    }
}

/// View modifier that applies font scaling
struct ScaledFont: ViewModifier {
    @Environment(\.fontScale) private var fontScale
    let baseStyle: Font.TextStyle
    let weight: Font.Weight?
    let design: Font.Design?

    init(_ style: Font.TextStyle, weight: Font.Weight? = nil, design: Font.Design? = nil) {
        self.baseStyle = style
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        let baseSize = baseFontSize(for: baseStyle)
        let scaledSize = baseSize * fontScale.scaleFactor

        var font = Font.system(size: scaledSize, design: design ?? .default)
        if let weight = weight {
            font = font.weight(weight)
        }

        return content.font(font)
    }

    /// Base font sizes for each text style (matching system defaults)
    private func baseFontSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 26
        case .title: return 22
        case .title2: return 17
        case .title3: return 15
        case .headline: return 13
        case .body: return 13
        case .callout: return 12
        case .subheadline: return 11
        case .footnote: return 10
        case .caption: return 10
        case .caption2: return 9
        @unknown default: return 13
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply a scaled font based on the user's font scale preference
    func scaledFont(_ style: Font.TextStyle, weight: Font.Weight? = nil, design: Font.Design? = nil) -> some View {
        modifier(ScaledFont(style, weight: weight, design: design))
    }
}

// MARK: - App Constants

/// Centralized layout constants
enum AppLayout {
    /// Standard spacing values (4pt grid)
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    /// Window size presets
    enum WindowSize {
        static let settingsWidth: CGFloat = 500
        static let settingsHeight: CGFloat = 450
        static let queryMinWidth: CGFloat = 500
        static let queryMinHeight: CGFloat = 400
        static let historyMinWidth: CGFloat = 400
        static let historyMinHeight: CGFloat = 300
        static let popoverWidth: CGFloat = 380
    }

    /// Results display settings
    enum Results {
        static let defaultMaxRows = 1000
        static let columnWidthMin: CGFloat = 60
        static let columnWidthMax: CGFloat = 250
        static let sampleRowsForWidth = 100
    }
}
