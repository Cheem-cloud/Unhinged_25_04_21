import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

// MARK: - CustomTheme Definition

/// Central theme definition for the application
public enum CustomTheme {
    // MARK: - Layout
    
    public enum Layout {
        public static let paddingSmall: CGFloat = 8
        public static let paddingMedium: CGFloat = 16
        public static let paddingLarge: CGFloat = 24
        public static let paddingExtraLarge: CGFloat = 32
    }
    
    // MARK: - Colors
    
    public enum Colors {
        public static let button: Color = .primary
        public static let textSecondary: Color = .gray
        public static let accent: Color = .blue
        
        #if os(iOS)
        public static let background: Color = Color(UIColor.systemBackground)
        #elseif os(macOS)
        public static let background: Color = Color(NSColor.windowBackgroundColor)
        #else
        public static let background: Color = .white
        #endif
        
        public static let error: Color = .red
        public static let success: Color = .green
        public static let successGradient: [Color] = [.green, Color(hex: "#90EE90")]
    }
    
    // MARK: - Typography
    
    public enum Typography {
        public static let title: Font = .title
        public static let headline: Font = .headline
        public static let body: Font = .body
        public static let caption: Font = .caption
    }
    
    // MARK: - App Colors
    
    // Primary Colors
    #if os(iOS)
    public static let primaryRed: Color = Color(UIColor.systemRed)
    public static let primaryBlue: Color = Color(UIColor.systemBlue)
    public static let primaryGreen: Color = Color(UIColor.systemGreen)
    public static let primaryOrange: Color = Color(UIColor.systemOrange)
    #elseif os(macOS)
    public static let primaryRed: Color = Color(NSColor.systemRed)
    public static let primaryBlue: Color = Color(NSColor.systemBlue)
    public static let primaryGreen: Color = Color(NSColor.systemGreen)
    public static let primaryOrange: Color = Color(NSColor.systemOrange)
    #else
    public static let primaryRed: Color = .red
    public static let primaryBlue: Color = .blue
    public static let primaryGreen: Color = .green
    public static let primaryOrange: Color = .orange
    #endif
    
    // Secondary Colors
    public static let secondaryGold: Color = Color(hex: "#FFD700")
    
    #if os(iOS)
    public static let secondaryPurple: Color = Color(UIColor.systemPurple)
    public static let secondaryTeal: Color = Color(UIColor.systemTeal)
    public static let secondaryPink: Color = Color(UIColor.systemPink)
    #elseif os(macOS)
    public static let secondaryPurple: Color = Color(NSColor.systemPurple)
    public static let secondaryTeal: Color = Color(NSColor.systemBlue)
    public static let secondaryPink: Color = Color(NSColor.systemPink)
    #else
    public static let secondaryPurple: Color = .purple
    public static let secondaryTeal: Color = .blue
    public static let secondaryPink: Color = .pink
    #endif
    
    // App Colors
    public static let deepRed: Color = Color(hex: "#990000")
    public static let mutedGold: Color = Color(hex: "#D4AF37")
    public static let vibrantBlue: Color = Color(hex: "#0066CC")
    public static let softGreen: Color = Color(hex: "#90EE90")
}

// Helper extension for creating colors from hex values
public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Theme Configuration

// If you need to modify theme colors, update the CustomTheme enum defined above
// This ThemeConfig struct serves as a configuration layer built on top of CustomTheme

/// Reusable theme configuration for components to increase flexibility and reusability
public struct ThemeConfig {
    // MARK: - Spacing Configuration
    
    public struct Spacing {
        public let small: CGFloat
        public let medium: CGFloat
        public let large: CGFloat
        public let extraLarge: CGFloat
        
        // Static default values
        public static let defaultSmall: CGFloat = CustomTheme.Layout.paddingSmall
        public static let defaultMedium: CGFloat = CustomTheme.Layout.paddingMedium
        public static let defaultLarge: CGFloat = CustomTheme.Layout.paddingLarge
        public static let defaultExtraLarge: CGFloat = CustomTheme.Layout.paddingExtraLarge
        
        public init(
            small: CGFloat = Spacing.defaultSmall,
            medium: CGFloat = Spacing.defaultMedium,
            large: CGFloat = Spacing.defaultLarge,
            extraLarge: CGFloat = Spacing.defaultExtraLarge
        ) {
            self.small = small
            self.medium = medium
            self.large = large
            self.extraLarge = extraLarge
        }
        
        /// Default app spacing configuration
        public static let standard = Spacing(
            small: CustomTheme.Layout.paddingSmall,
            medium: CustomTheme.Layout.paddingMedium,
            large: CustomTheme.Layout.paddingLarge,
            extraLarge: CustomTheme.Layout.paddingExtraLarge
        )
        
        /// Compact spacing for dense UI
        public static let compact = Spacing(
            small: 4,
            medium: 8,
            large: 12,
            extraLarge: 16
        )
        
        /// Expanded spacing for more breathable UI
        public static let expanded = Spacing(
            small: 12,
            medium: 24,
            large: 36,
            extraLarge: 48
        )
    }
    
    // MARK: - Color Configuration
    
    public struct Colors {
        public let primary: Color
        public let secondary: Color
        public let accent: Color
        public let background: Color
        public let error: Color
        public let success: Color
        
        // Static default values
        public static let defaultPrimary: Color = CustomTheme.Colors.button
        public static let defaultSecondary: Color = CustomTheme.Colors.textSecondary
        public static let defaultAccent: Color = CustomTheme.Colors.accent
        public static let defaultBackground: Color = CustomTheme.Colors.background
        public static let defaultError: Color = CustomTheme.Colors.error
        public static let defaultSuccess: Color = CustomTheme.Colors.success
        
        public init(
            primary: Color = Colors.defaultPrimary,
            secondary: Color = Colors.defaultSecondary,
            accent: Color = Colors.defaultAccent,
            background: Color = Colors.defaultBackground,
            error: Color = Colors.defaultError,
            success: Color = Colors.defaultSuccess
        ) {
            self.primary = primary
            self.secondary = secondary
            self.accent = accent
            self.background = background
            self.error = error
            self.success = success
        }
        
        /// Default app color scheme
        public static let standard = Colors()
        
        /// Dark mode optimized colors
        public static let dark = Colors(
            primary: CustomTheme.Colors.button.opacity(0.9),
            secondary: CustomTheme.Colors.textSecondary.opacity(0.9),
            accent: CustomTheme.Colors.accent.opacity(0.9),
            background: Color.black,
            error: CustomTheme.Colors.error.opacity(0.9),
            success: CustomTheme.Colors.success.opacity(0.9)
        )
        
        /// High contrast colors for accessibility
        public static let highContrast = Colors(
            primary: .white,
            secondary: .gray,
            accent: .yellow,
            background: .black,
            error: .red,
            success: .green
        )
    }
    
    // MARK: - Typography Configuration
    
    public struct Typography {
        public let title: Font
        public let subtitle: Font
        public let body: Font
        public let caption: Font
        
        // Static default values
        public static let defaultTitle: Font = CustomTheme.Typography.title
        public static let defaultSubtitle: Font = CustomTheme.Typography.headline
        public static let defaultBody: Font = CustomTheme.Typography.body
        public static let defaultCaption: Font = CustomTheme.Typography.caption
        
        public init(
            title: Font = Typography.defaultTitle,
            subtitle: Font = Typography.defaultSubtitle,
            body: Font = Typography.defaultBody,
            caption: Font = Typography.defaultCaption
        ) {
            self.title = title
            self.subtitle = subtitle
            self.body = body
            self.caption = caption
        }
        
        /// Default app typography
        public static let standard = Typography()
        
        /// Larger typography for accessibility
        public static let large = Typography(
            title: Font.system(size: 30),
            subtitle: Font.system(size: 24),
            body: Font.system(size: 20),
            caption: Font.system(size: 16)
        )
        
        /// Smaller typography for compact UIs
        public static let compact = Typography(
            title: Font.system(size: 20),
            subtitle: Font.system(size: 16),
            body: Font.system(size: 14),
            caption: Font.system(size: 12)
        )
    }
    
    // MARK: - Instance Properties
    
    public let spacing: Spacing
    public let colors: Colors
    public let typography: Typography
    
    public init(
        spacing: Spacing = .standard,
        colors: Colors = .standard,
        typography: Typography = .standard
    ) {
        self.spacing = spacing
        self.colors = colors
        self.typography = typography
    }
    
    // MARK: - Predefined Configurations
    
    /// Default app theme configuration
    public static let standard = ThemeConfig()
    
    /// Compact theme for dense UIs
    public static let compact = ThemeConfig(
        spacing: .compact,
        colors: .standard,
        typography: .compact
    )
    
    /// Accessible theme with larger text and high contrast
    public static let accessible = ThemeConfig(
        spacing: .expanded,
        colors: .highContrast,
        typography: .large
    )
    
    /// Dark mode theme
    public static let dark = ThemeConfig(
        spacing: .standard,
        colors: .dark,
        typography: .standard
    )
}

// MARK: - Theme Constants

// Forwarding to CustomTheme static properties
extension Color {
    // Primary Colors
    public static var primaryRed: Color { return CustomTheme.primaryRed }
    public static var primaryBlue: Color { return CustomTheme.primaryBlue }
    public static var primaryGreen: Color { return CustomTheme.primaryGreen }
    public static var primaryOrange: Color { return CustomTheme.primaryOrange }
    
    // Secondary Colors
    public static var secondaryGold: Color { return CustomTheme.secondaryGold }
    public static var secondaryPurple: Color { return CustomTheme.secondaryPurple }
    public static var secondaryTeal: Color { return CustomTheme.secondaryTeal }
    public static var secondaryPink: Color { return CustomTheme.secondaryPink }
    
    // App Colors
    public static var deepRed: Color { return CustomTheme.deepRed }
    public static var mutedGold: Color { return CustomTheme.mutedGold }
    public static var vibrantBlue: Color { return CustomTheme.vibrantBlue }
    public static var softGreen: Color { return CustomTheme.softGreen }
}

// MARK: - AppTheme for Backward Compatibility

/// Alias AppTheme to CustomTheme for backward compatibility
public typealias AppTheme = CustomTheme 