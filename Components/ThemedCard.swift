import SwiftUI

/// A reusable card component that uses the current theme
public struct ThemedCard<Content: View>: View {
    private let content: Content
    private let title: String?
    private let subtitle: String?
    private let cornerRadius: CGFloat
    private let hasShadow: Bool
    private let isInteractive: Bool
    private let onTap: (() -> Void)?
    
    /// Creates a themed card with a title and optional subtitle
    /// - Parameters:
    ///   - title: Card title (optional)
    ///   - subtitle: Card subtitle (optional)
    ///   - cornerRadius: Corner radius for the card (defaults to 12)
    ///   - hasShadow: Whether the card has a shadow (defaults to true)
    ///   - isInteractive: Whether the card is interactive/tappable (defaults to false)
    ///   - onTap: Action to perform when the card is tapped (required if isInteractive is true)
    ///   - content: The content of the card
    public init(
        title: String? = nil,
        subtitle: String? = nil,
        cornerRadius: CGFloat = 12,
        hasShadow: Bool = true,
        isInteractive: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.cornerRadius = cornerRadius
        self.hasShadow = hasShadow
        self.isInteractive = isInteractive
        self.onTap = onTap
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.medium) {
            // Title section if provided
            if let title = title {
                VStack(alignment: .leading, spacing: 4) {
                    ThemedText(title, style: .subtitle)
                    
                    if let subtitle = subtitle {
                        ThemedText(subtitle, style: .caption)
                            .foregroundColor(Color.themedSecondary)
                    }
                }
            }
            
            // Card content
            content
        }
        .padding(ThemeManager.shared.spacing.standard)
        .background(Color.themedBackground.opacity(0.5))
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.themedPrimary.opacity(0.1), lineWidth: 1)
        )
        .shadow(
            color: hasShadow ? Color.black.opacity(0.1) : Color.clear, 
            radius: 5, x: 0, y: 2
        )
        .contentShape(Rectangle())
        .if(isInteractive) { view in
            view.onTapGesture {
                onTap?()
            }
        }
    }
}

/// A card with a selectable state
public struct ThemedSelectableCard<Content: View>: View {
    private let content: Content
    private let title: String?
    private let isSelected: Bool
    private let onToggle: () -> Void
    
    public init(
        title: String? = nil,
        isSelected: Bool,
        onToggle: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.isSelected = isSelected
        self.onToggle = onToggle
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.medium) {
            // Header with title and selection indicator
            if let title = title {
                HStack {
                    ThemedText(title, style: .subtitle)
                    
                    Spacer()
                    
                    // Selection indicator
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? Color.themedAccent : Color.themedSecondary)
                        .font(.system(size: 22))
                }
            }
            
            // Card content
            content
        }
        .padding(ThemeManager.shared.spacing.standard)
        .background(isSelected ? Color.themedAccent.opacity(0.1) : Color.themedBackground.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.themedAccent : Color.themedPrimary.opacity(0.1), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

/// Preview for themed cards
struct ThemedCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Standard card
            ThemedCard(title: "Standard Card", subtitle: "With a subtitle") {
                Text("This is the content of a standard card")
                    .font(Font.themedBody)
            }
            
            // Interactive card
            ThemedCard(
                title: "Interactive Card",
                isInteractive: true,
                onTap: { print("Card tapped") }
            ) {
                HStack {
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(Color.themedAccent)
                    
                    Text("Tap me!")
                        .font(Font.themedBody)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            // Selectable card
            ThemedSelectableCard(
                title: "Selectable Card",
                isSelected: true,
                onToggle: { print("Selection toggled") }
            ) {
                Text("This card shows a selected state")
                    .font(Font.themedBody)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 