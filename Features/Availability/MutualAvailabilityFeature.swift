import SwiftUI
// Removed // Removed: import Unhinged.Utilities
// Removed: // Removed: import Unhinged.Components
// Removed: // Removed: import Unhinged.TimeSlotComponents

/// Main container component for displaying and managing mutual availability between couples
public struct MutualAvailabilityFeature: View {
    // State
    let state: MutualAvailabilityViewModel.State
    let selectedTimeSlot: TimeSlot?
    let availableTimes: [TimeSlot]
    let startDate: Date
    let endDate: Date
    let duration: Int
    let friendRelationshipID: String?
    let error: Error?
    
    // Callbacks
    let onSelectTimeSlot: (TimeSlot) -> Void
    let onFindAvailableTimes: () -> Void
    let onRetry: () -> Void
    let onCreateHangout: (String, String, String, HangoutType) -> Void
    let onHangoutCreated: (String) -> Void
    
    public init(
        state: MutualAvailabilityViewModel.State,
        selectedTimeSlot: TimeSlot?,
        availableTimes: [TimeSlot],
        startDate: Date,
        endDate: Date,
        duration: Int,
        friendRelationshipID: String?,
        error: Error?,
        onSelectTimeSlot: @escaping (TimeSlot) -> Void,
        onFindAvailableTimes: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onCreateHangout: @escaping (String, String, String, HangoutType) -> Void,
        onHangoutCreated: @escaping (String) -> Void
    ) {
        self.state = state
        self.selectedTimeSlot = selectedTimeSlot
        self.availableTimes = availableTimes
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.friendRelationshipID = friendRelationshipID
        self.error = error
        self.onSelectTimeSlot = onSelectTimeSlot
        self.onFindAvailableTimes = onFindAvailableTimes
        self.onRetry = onRetry
        self.onCreateHangout = onCreateHangout
        self.onHangoutCreated = onHangoutCreated
    }
    
    public var body: some View {
        VStack {
            switch state {
            case .success(let hangoutID):
                MutualAvailabilitySuccessView(
                    selectedTimeSlot: selectedTimeSlot,
                    onViewDetails: {
                        onHangoutCreated(hangoutID)
                    },
                    onFindAnother: onFindAvailableTimes
                )
                
            case .loading(let progress):
                MutualAvailabilityLoadingView(progress: progress)
                
            case .error:
                if let error = error {
                    MutualAvailabilityErrorView(
                        error: error,
                        onDateRangeEdit: { NotificationManager.shared.showDateRangePicker() },
                        onDurationEdit: { NotificationManager.shared.showDurationPicker() },
                        onFriendPickerShow: { NotificationManager.shared.showFriendPicker() },
                        onRetry: onRetry,
                        onDismissError: {
                            // Reset state and clear error
                            NotificationManager.shared.resetError()
                        }
                    )
                } else {
                    Components.EmptyState(
                        icon: "exclamationmark.triangle",
                        title: "Unknown Error",
                        message: "Something went wrong. Please try again.",
                        actionTitle: "Retry",
                        action: onRetry
                    )
                }
                
            case .empty:
                MutualAvailabilityEmptyView(
                    friendSelected: friendRelationshipID != nil,
                    startDate: startDate,
                    endDate: endDate,
                    duration: duration,
                    onFriendPickerTap: { NotificationManager.shared.showFriendPicker() },
                    onDateRangeTap: { NotificationManager.shared.showDateRangePicker() },
                    onDurationTap: { NotificationManager.shared.showDurationPicker() },
                    onSearch: onFindAvailableTimes
                )
                
            case .results:
                MutualAvailabilityResultsView(
                    timeSlots: availableTimes,
                    selectedTimeSlot: selectedTimeSlot,
                    onFriendPickerShow: { NotificationManager.shared.showFriendPicker() },
                    onDateRangeEdit: { NotificationManager.shared.showDateRangePicker() },
                    onDurationEdit: { NotificationManager.shared.showDurationPicker() },
                    onTimeSlotSelect: onSelectTimeSlot,
                    onCreateHangout: { NotificationManager.shared.showCreateHangout() }
                )
            }
        }
    }
}

// MARK: - Preview

internal struct MutualAvailabilityFeature_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Empty state
            MutualAvailabilityFeature(
                state: .empty,
                selectedTimeSlot: nil,
                availableTimes: [],
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
                duration: 60,
                friendRelationshipID: nil,
                error: nil,
                onSelectTimeSlot: { _ in },
                onFindAvailableTimes: { },
                onRetry: { },
                onCreateHangout: { _, _, _, _ in },
                onHangoutCreated: { _ in }
            )
            .previewDisplayName("Empty State")
            
            // Loading state
            MutualAvailabilityFeature(
                state: .loading(progress: 0.5),
                selectedTimeSlot: nil,
                availableTimes: [],
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
                duration: 60,
                friendRelationshipID: "friend-id",
                error: nil,
                onSelectTimeSlot: { _ in },
                onFindAvailableTimes: { },
                onRetry: { },
                onCreateHangout: { _, _, _, _ in },
                onHangoutCreated: { _ in }
            )
            .previewDisplayName("Loading State")
            
            // Results state
            MutualAvailabilityFeature(
                state: .results,
                selectedTimeSlot: nil,
                availableTimes: [
                    TimeSlot(
                        id: "1",
                        day: "Monday",
                        date: Date(),
                        startTime: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!,
                        endTime: Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date())!
                    ),
                    TimeSlot(
                        id: "2",
                        day: "Monday",
                        date: Date(),
                        startTime: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!,
                        endTime: Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
                    )
                ],
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
                duration: 60,
                friendRelationshipID: "friend-id",
                error: nil,
                onSelectTimeSlot: { _ in },
                onFindAvailableTimes: { },
                onRetry: { },
                onCreateHangout: { _, _, _, _ in },
                onHangoutCreated: { _ in }
            )
            .previewDisplayName("Results State")
        }
    }
} 