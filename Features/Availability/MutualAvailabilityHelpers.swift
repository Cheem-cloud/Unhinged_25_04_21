import SwiftUI
// Removed // Removed: import Unhinged.Utilities
// Removed: // Removed: import Unhinged.Components

// MARK: - Helper Components

/// Friend selector component
public struct MutualAvailabilityFriendSelector: View {
    let hasFriendSelected: Bool
    let onTap: () -> Void
    
    public init(hasFriendSelected: Bool, onTap: @escaping () -> Void) {
        self.hasFriendSelected = hasFriendSelected
        self.onTap = onTap
    }
    
    public var body: some View {
        Components.PickerCard(
            icon: "person.2.fill",
            title: "Friend Couple",
            value: hasFriendSelected ? "Selected" : "Choose a friend couple",
            onTap: onTap,
            isSelected: hasFriendSelected
        )
        .padding(.horizontal)
    }
}

/// Date range selector component
public struct MutualAvailabilityDateRangeSelector: View {
    let startDate: Date
    let endDate: Date
    let onTap: () -> Void
    
    public init(startDate: Date, endDate: Date, onTap: @escaping () -> Void) {
        self.startDate = startDate
        self.endDate = endDate
        self.onTap = onTap
    }
    
    private var displayText: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        
        let startText = dateFormatter.string(from: startDate)
        let endText = dateFormatter.string(from: endDate)
        
        return "\(startText) - \(endText)"
    }
    
    public var body: some View {
        Components.PickerCard(
            icon: "calendar",
            title: "Date Range",
            value: displayText,
            onTap: onTap,
            isSelected: true
        )
        .padding(.horizontal)
    }
}

/// Duration selector component
public struct MutualAvailabilityDurationSelector: View {
    let duration: Int
    let onTap: () -> Void
    
    public init(duration: Int, onTap: @escaping () -> Void) {
        self.duration = duration
        self.onTap = onTap
    }
    
    private var displayText: String {
        return "\(duration) minutes"
    }
    
    public var body: some View {
        Components.PickerCard(
            icon: "clock",
            title: "Duration",
            value: displayText,
            onTap: onTap,
            isSelected: true
        )
        .padding(.horizontal)
    }
}

/// Filter header for the results view
public struct MutualAvailabilityFilterHeader: View {
    // Callbacks
    let onFriendPickerShow: () -> Void
    let onDateRangeEdit: () -> Void
    let onDurationEdit: () -> Void
    
    // Styling
    let chipSpacing: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let backgroundColor: Color
    
    public init(
        onFriendPickerShow: @escaping () -> Void,
        onDateRangeEdit: @escaping () -> Void,
        onDurationEdit: @escaping () -> Void,
        chipSpacing: CGFloat = 8,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 8,
        backgroundColor: Color = AppTheme.Colors.background
    ) {
        self.onFriendPickerShow = onFriendPickerShow
        self.onDateRangeEdit = onDateRangeEdit
        self.onDurationEdit = onDurationEdit
        self.chipSpacing = chipSpacing
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.backgroundColor = backgroundColor
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: chipSpacing) {
                    Components.FilterChip(
                        title: "Friends",
                        icon: "person.2.fill",
                        onTap: onFriendPickerShow
                    )
                    
                    Components.FilterChip(
                        title: "Date Range",
                        icon: "calendar",
                        onTap: onDateRangeEdit
                    )
                    
                    Components.FilterChip(
                        title: "Duration",
                        icon: "clock",
                        onTap: onDurationEdit
                    )
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            }
            
            Divider()
        }
        .background(
            backgroundColor
                .edgesIgnoringSafeArea(.horizontal)
        )
    }
}

/// Tip row for the empty state view
internal struct TipRow: View {
    let icon: String
    let text: String
    
    init(icon: String, text: String) {
        self.icon = icon
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// MARK: - Previews

internal struct MutualAvailabilityFriendSelector_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            MutualAvailabilityFriendSelector(
                hasFriendSelected: true,
                onTap: {}
            )
            MutualAvailabilityFriendSelector(
                hasFriendSelected: false,
                onTap: {}
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

internal struct MutualAvailabilityDateRangeSelector_Previews: PreviewProvider {
    static var previews: some View {
        MutualAvailabilityDateRangeSelector(
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            onTap: {}
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

internal struct MutualAvailabilityDurationSelector_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            MutualAvailabilityDurationSelector(
                duration: 30,
                onTap: {}
            )
            MutualAvailabilityDurationSelector(
                duration: 60,
                onTap: {}
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

internal struct MutualAvailabilityFilterHeader_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default styling
            MutualAvailabilityFilterHeader(
                onFriendPickerShow: {},
                onDateRangeEdit: {},
                onDurationEdit: {}
            )
            .previewDisplayName("Default Style")
            
            // Custom styling
            MutualAvailabilityFilterHeader(
                onFriendPickerShow: {},
                onDateRangeEdit: {},
                onDurationEdit: {},
                chipSpacing: 12,
                horizontalPadding: 24,
                verticalPadding: 12,
                backgroundColor: Color(.systemGroupedBackground)
            )
            .previewDisplayName("Custom Style")
        }
        .previewLayout(.sizeThatFits)
    }
}

internal struct TipRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading) {
            TipRow(
                icon: "calendar",
                text: "Try a wider date range"
            )
            TipRow(
                icon: "clock",
                text: "Consider a shorter duration"
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 