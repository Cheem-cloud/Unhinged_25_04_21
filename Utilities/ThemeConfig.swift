import SwiftUI

/// Reusable theme configuration for components to increase flexibility and reusability
public struct ThemeConfig {
    // MARK: - Spacing Configuration
    
    public struct Spacing {
        public let small: CGFloat
        public let medium: CGFloat
        public let large: CGFloat
        public let extraLarge: CGFloat
        
        public init(
            small: CGFloat = 8,
            medium: CGFloat = 16,
            large: CGFloat = 24,
            extraLarge: CGFloat = 32
        ) {
            self.small = small
            self.medium = medium
            self.large = large
            self.extraLarge = extraLarge
        }
        
        /// Default app spacing configuration
        public static let standard = Spacing(
            small: AppTheme.Layout.paddingSmall,
            medium: AppTheme.Layout.paddingMedium,
            large: AppTheme.Layout.paddingLarge,
            extraLarge: AppTheme.Layout.paddingExtraLarge
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
        
        public init(
            primary: Color = AppTheme.Colors.primary,
            secondary: Color = AppTheme.Colors.secondary,
            accent: Color = AppTheme.Colors.accent,
            background: Color = AppTheme.Colors.background,
            error: Color = AppTheme.Colors.error,
            success: Color = AppTheme.Colors.success
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
            primary: AppTheme.Colors.primary.opacity(0.9),
            secondary: AppTheme.Colors.secondary.opacity(0.9),
            accent: AppTheme.Colors.accent.opacity(0.9),
            background: Color.black,
            error: AppTheme.Colors.error.opacity(0.9),
            success: AppTheme.Colors.success.opacity(0.9)
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
        
        public init(
            title: Font = AppTheme.Typography.title,
            subtitle: Font = AppTheme.Typography.subtitle,
            body: Font = AppTheme.Typography.body,
            caption: Font = AppTheme.Typography.caption
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
            title: AppTheme.Typography.title.size(30),
            subtitle: AppTheme.Typography.subtitle.size(24),
            body: AppTheme.Typography.body.size(20),
            caption: AppTheme.Typography.caption.size(16)
        )
        
        /// Smaller typography for compact UIs
        public static let compact = Typography(
            title: AppTheme.Typography.title.size(20),
            subtitle: AppTheme.Typography.subtitle.size(16),
            body: AppTheme.Typography.body.size(14),
            caption: AppTheme.Typography.caption.size(12)
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