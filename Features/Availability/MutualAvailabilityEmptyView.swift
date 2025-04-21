import SwiftUI
// Removed // Removed: import Unhinged.Utilities
// Removed: // Removed: import Unhinged.Components

/// Empty view when no available time slots are found or at initial state
public struct MutualAvailabilityEmptyView: View {
    let friendSelected: Bool
    let startDate: Date
    let endDate: Date
    let duration: Int
    let onFriendPickerTap: () -> Void
    let onDateRangeTap: () -> Void
    let onDurationTap: () -> Void
    let onSearch: () -> Void
    
    public init(
        friendSelected: Bool,
        startDate: Date,
        endDate: Date,
        duration: Int,
        onFriendPickerTap: @escaping () -> Void,
        onDateRangeTap: @escaping () -> Void,
        onDurationTap: @escaping () -> Void,
        onSearch: @escaping () -> Void
    ) {
        self.friendSelected = friendSelected
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.onFriendPickerTap = onFriendPickerTap
        self.onDateRangeTap = onDateRangeTap
        self.onDurationTap = onDurationTap
        self.onSearch = onSearch
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header illustration
                if !friendSelected {
                    // Show graphic for select friends state
                    Components.EmptyStateHeader(
                        icon: "person.2.badge.plus",
                        title: "Find Time Together",
                        message: "Select a friend couple to find mutual availability",
                        color: .blue
                    )
                } else {
                    // Show graphic for no availability state
                    Components.EmptyStateHeader(
                        icon: "calendar.badge.exclamationmark",
                        title: "No Mutual Availability",
                        message: "Try adjusting your date range or duration",
                        color: .orange
                    )
                }
                
                // Friend relationship selection
                MutualAvailabilityFriendSelector(
                    hasFriendSelected: friendSelected,
                    onTap: onFriendPickerTap
                )
                
                // Date range selection
                MutualAvailabilityDateRangeSelector(
                    startDate: startDate,
                    endDate: endDate,
                    onTap: onDateRangeTap
                )
                
                // Duration selection
                MutualAvailabilityDurationSelector(
                    duration: duration,
                    onTap: onDurationTap
                )
                
                // Search button
                Components.PrimaryButton(
                    title: "Find Available Times",
                    icon: "magnifyingglass",
                    action: onSearch,
                    isDisabled: !friendSelected
                )
                .padding(.horizontal)
                
                // Tips section if no availability was found
                if friendSelected {
                    Components.TipsCard(tips: [
                        "Try a wider date range",
                        "Consider a shorter duration",
                        "Check your availability settings"
                    ])
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                Spacer(minLength: 30)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Preview

internal struct MutualAvailabilityEmptyView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Initial state without friend selected
            MutualAvailabilityEmptyView(
                friendSelected: false,
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
                duration: 60,
                onFriendPickerTap: {},
                onDateRangeTap: {},
                onDurationTap: {},
                onSearch: {}
            )
            .previewDisplayName("Initial State")
            
            // State with friend selected but no availability
            MutualAvailabilityEmptyView(
                friendSelected: true,
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
                duration: 60,
                onFriendPickerTap: {},
                onDateRangeTap: {},
                onDurationTap: {},
                onSearch: {}
            )
            .previewDisplayName("No Availability")
        }
    }
} 