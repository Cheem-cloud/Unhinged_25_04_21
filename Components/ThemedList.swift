import SwiftUI

/// A list component that uses the current theme
public struct ThemedList<Data: RandomAccessCollection, RowContent: View, EmptyContent: View>: View 
where Data.Element: Identifiable {
    private let data: Data
    private let rowContent: (Data.Element) -> RowContent
    private let emptyContent: () -> EmptyContent
    private let title: String?
    private let showDividers: Bool
    private let isLoading: Bool
    private let loadingText: String
    
    /// Creates a themed list with consistent styling
    /// - Parameters:
    ///   - title: Optional list title
    ///   - data: Collection of data to display
    ///   - showDividers: Whether to show dividers between items
    ///   - isLoading: Whether the list is in a loading state
    ///   - loadingText: Text to display when loading
    ///   - rowContent: View builder for each row
    ///   - emptyContent: View to display when the list is empty
    public init(
        title: String? = nil,
        data: Data,
        showDividers: Bool = true,
        isLoading: Bool = false,
        loadingText: String = "Loading...",
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent,
        @ViewBuilder emptyContent: @escaping () -> EmptyContent
    ) {
        self.title = title
        self.data = data
        self.showDividers = showDividers
        self.isLoading = isLoading
        self.loadingText = loadingText
        self.rowContent = rowContent
        self.emptyContent = emptyContent
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title if provided
            if let title = title {
                HStack {
                    ThemedText(title, style: .subtitle)
                    
                    Spacer()
                    
                    // Item count
                    if !isLoading {
                        Text("\(data.count) items")
                            .font(Font.themedCaption)
                            .foregroundColor(Color.themedSecondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)
            }
            
            if isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.themedPrimary))
                    
                    ThemedText(loadingText, style: .caption)
                        .foregroundColor(Color.themedSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .padding()
            } else if data.isEmpty {
                // Empty state
                emptyContent()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                // List content
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(data) { item in
                        rowContent(item)
                            .if(showDividers) { view in
                                view.overlay(
                                    VStack {
                                        Spacer()
                                        Divider()
                                            .background(Color.themedPrimary.opacity(0.1))
                                    }
                                )
                            }
                    }
                }
            }
        }
        .background(Color.themedBackground.opacity(0.5))
        .cornerRadius(12)
    }
}

/// Standard row for simple text lists
public struct ThemedListRow: View {
    private let title: String
    private let subtitle: String?
    private let leadingIcon: String?
    private let trailingIcon: String?
    private let showChevron: Bool
    private let action: (() -> Void)?
    
    public init(
        title: String,
        subtitle: String? = nil,
        leadingIcon: String? = nil,
        trailingIcon: String? = nil,
        showChevron: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.showChevron = showChevron
        self.action = action
    }
    
    public var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 16) {
                // Leading icon if provided
                if let iconName = leadingIcon {
                    Image(systemName: iconName)
                        .font(.system(size: 20))
                        .foregroundColor(Color.themedPrimary)
                        .frame(width: 24, height: 24)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    ThemedText(title, style: .body)
                    
                    if let subtitle = subtitle {
                        ThemedText(subtitle, style: .caption)
                            .foregroundColor(Color.themedSecondary)
                    }
                }
                
                Spacer()
                
                // Trailing icon if provided
                if let iconName = trailingIcon {
                    Image(systemName: iconName)
                        .font(.system(size: 18))
                        .foregroundColor(Color.themedSecondary)
                }
                
                // Chevron for navigation
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(Color.themedSecondary)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Empty state view for lists
public struct ThemedEmptyState: View {
    private let title: String
    private let message: String
    private let iconName: String
    private let actionTitle: String?
    private let action: (() -> Void)?
    
    public init(
        title: String,
        message: String,
        iconName: String = "rectangle.on.rectangle.angled",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.iconName = iconName
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundColor(Color.themedSecondary.opacity(0.5))
            
            ThemedText(title, style: .subtitle)
            
            ThemedText(message, style: .caption)
                .foregroundColor(Color.themedSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let actionTitle = actionTitle {
                ThemedButton(actionTitle, isPrimary: false) {
                    action?()
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

/// Example of usage and preview
struct ThemedList_Previews: PreviewProvider {
    // Sample item for preview
    struct SampleItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
    }
    
    // Sample items
    static let items = [
        SampleItem(title: "Item 1", subtitle: "Description for item 1"),
        SampleItem(title: "Item 2", subtitle: "Description for item 2"),
        SampleItem(title: "Item 3", subtitle: "Description for item 3")
    ]
    
    static var previews: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Standard list with items
                ThemedList(
                    title: "Standard List",
                    data: items
                ) { item in
                    ThemedListRow(
                        title: item.title,
                        subtitle: item.subtitle,
                        leadingIcon: "circle.fill",
                        showChevron: true
                    ) {
                        print("Tapped \(item.title)")
                    }
                } emptyContent: {
                    ThemedEmptyState(
                        title: "No Items",
                        message: "There are no items to display"
                    )
                }
                
                // Empty list
                ThemedList(
                    title: "Empty List",
                    data: [SampleItem]()
                ) { item in
                    ThemedListRow(title: item.title)
                } emptyContent: {
                    ThemedEmptyState(
                        title: "No Items",
                        message: "Add some items to get started",
                        iconName: "plus.square",
                        actionTitle: "Add Item"
                    ) {
                        print("Add item tapped")
                    }
                }
                
                // Loading list
                ThemedList(
                    title: "Loading State",
                    data: [SampleItem](),
                    isLoading: true
                ) { item in
                    ThemedListRow(title: item.title)
                } emptyContent: {
                    EmptyView()
                }
                
                // Customized list
                ThemedList(
                    title: "Custom List",
                    data: items,
                    showDividers: false
                ) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            ThemedText(item.title, style: .subtitle)
                            ThemedText(item.subtitle, style: .caption)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "star.fill")
                            .foregroundColor(Color.themedAccent)
                    }
                    .padding()
                    .background(Color.themedBackground.opacity(0.3))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                } emptyContent: {
                    ThemedEmptyState(
                        title: "No Items",
                        message: "There are no items to display"
                    )
                }
            }
            .padding()
        }
        .background(Color.themedBackground.opacity(0.2))
        .edgesIgnoringSafeArea(.all)
        .withCurrentTheme()
    }
} 