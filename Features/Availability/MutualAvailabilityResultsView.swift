import SwiftUI
// Removed // Removed: import Unhinged.Utilities
// Removed: // Removed: import Unhinged.Components
// Removed: // Removed: import Unhinged.TimeSlotComponents

/// Results view showing available time slots
public struct MutualAvailabilityResultsView: View {
    let timeSlots: [TimeSlot]
    let selectedTimeSlot: TimeSlot?
    let onFriendPickerShow: () -> Void
    let onDateRangeEdit: () -> Void
    let onDurationEdit: () -> Void
    let onTimeSlotSelect: (TimeSlot) -> Void
    let onCreateHangout: () -> Void
    
    public init(
        timeSlots: [TimeSlot],
        selectedTimeSlot: TimeSlot?,
        onFriendPickerShow: @escaping () -> Void,
        onDateRangeEdit: @escaping () -> Void,
        onDurationEdit: @escaping () -> Void,
        onTimeSlotSelect: @escaping (TimeSlot) -> Void,
        onCreateHangout: @escaping () -> Void
    ) {
        self.timeSlots = timeSlots
        self.selectedTimeSlot = selectedTimeSlot
        self.onFriendPickerShow = onFriendPickerShow
        self.onDateRangeEdit = onDateRangeEdit
        self.onDurationEdit = onDurationEdit
        self.onTimeSlotSelect = onTimeSlotSelect
        self.onCreateHangout = onCreateHangout
    }
    
    private var timeSlotsByDay: [String: [TimeSlot]] {
        Dictionary(grouping: timeSlots) { timeSlot in
            timeSlot.formattedDate
        }
    }
    
    private var sortedDays: [String] {
        timeSlotsByDay.keys.sorted { day1, day2 in
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            if let date1 = formatter.date(from: day1),
               let date2 = formatter.date(from: day2) {
                return date1 < date2
            }
            return day1 < day2
        }
    }
    
    public var body: some View {
        VStack {
            // Header with filter options
            MutualAvailabilityFilterHeader(
                onFriendPickerShow: onFriendPickerShow,
                onDateRangeEdit: onDateRangeEdit,
                onDurationEdit: onDurationEdit
            )
            
            // List of available time slots grouped by day
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(sortedDays, id: \.self) { day in
                        if let slots = timeSlotsByDay[day] {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(day)
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(slots) { slot in
                                    TimeSlotComponents.TimeSlotCell(
                                        timeSlot: slot,
                                        isSelected: selectedTimeSlot?.id == slot.id,
                                        onSelect: {
                                            onTimeSlotSelect(slot)
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            
            // Footer with create button if a time slot is selected
            if selectedTimeSlot != nil {
                VStack {
                    Divider()
                    
                    Components.PrimaryButton(
                        title: "Create Hangout",
                        icon: "calendar.badge.plus",
                        action: onCreateHangout
                    )
                    .padding()
                }
            }
        }
    }
}

// MARK: - Preview

internal struct MutualAvailabilityResultsView_Previews: PreviewProvider {
    static var previews: some View {
        MutualAvailabilityResultsView(
            timeSlots: [
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
            selectedTimeSlot: nil,
            onFriendPickerShow: {},
            onDateRangeEdit: {},
            onDurationEdit: {},
            onTimeSlotSelect: { _ in },
            onCreateHangout: {}
        )
    }
} 