// import Utilities
import SwiftUI
import Foundation

// MARK: - Loading View

/// Loading view for mutual availability
struct MutualAvailabilityLoadingView: View {
    let progress: Float
    
    var body: some View {
        VStack(spacing: 20) {
            Components.LoadingIndicator(
                message: "Finding available times...",
                progress: Double(progress)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Empty View

/// Empty state for mutual availability
struct MutualAvailabilityEmptyView: View {
    let friendSelected: Bool
    let startDate: Date
    let endDate: Date
    let duration: Int
    
    let onFriendPickerTap: () -> Void
    let onDateRangeTap: () -> Void
    let onDurationTap: () -> Void
    let onSearch: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.bottom, 16)
            
            Text("Find Mutual Availability")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Search for times when you and your friends are both available")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                // Friend selection
                Button {
                    onFriendPickerTap()
                } label: {
                    HStack {
                        Image(systemName: friendSelected ? "checkmark.circle.fill" : "person.2")
                            .foregroundColor(friendSelected ? .green : .blue)
                        
                        Text(friendSelected ? "Friend Selected" : "Select Friend")
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                
                // Date range
                Button {
                    onDateRangeTap()
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Date Range")
                                .fontWeight(.medium)
                            
                            Text("\(formatDate(startDate)) - \(formatDate(endDate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                
                // Duration
                Button {
                    onDurationTap()
                } label: {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Duration")
                                .fontWeight(.medium)
                            
                            Text(formatDuration(duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
            }
            .padding(.vertical)
            
            Button {
                onSearch()
            } label: {
                Text("Find Available Times")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(friendSelected ? Color.blue : Color.gray)
                    .cornerRadius(30)
            }
            .disabled(!friendSelected)
            .padding(.top, 16)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            
            if remainingMinutes == 0 {
                return "\(hours) \(hours == 1 ? "hour" : "hours")"
            } else {
                return "\(hours) \(hours == 1 ? "hour" : "hours") \(remainingMinutes) min"
            }
        } else {
            return "\(minutes) minutes"
        }
    }
}

// MARK: - Results View

/// View for displaying mutual availability results
struct MutualAvailabilityResultsView: View {
    let timeSlots: [TimeSlot]
    let selectedTimeSlot: TimeSlot?
    
    let onFriendPickerShow: () -> Void
    let onDateRangeEdit: () -> Void
    let onDurationEdit: () -> Void
    let onTimeSlotSelect: (TimeSlot) -> Void
    let onCreateHangout: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Available Times")
                    .font(.headline)
                
                Spacer()
                
                Menu {
                    Button(action: onFriendPickerShow) {
                        Label("Change Friend", systemImage: "person.2")
                    }
                    
                    Button(action: onDateRangeEdit) {
                        Label("Change Date Range", systemImage: "calendar")
                    }
                    
                    Button(action: onDurationEdit) {
                        Label("Change Duration", systemImage: "clock")
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18))
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            if timeSlots.isEmpty {
                Components.EmptyState(
                    icon: "calendar.badge.exclamationmark",
                    title: "No Available Times",
                    message: "No mutual availability found in the selected date range. Try adjusting your filters.",
                    actionTitle: "Adjust Filters",
                    action: onDateRangeEdit
                )
            } else {
                // Group time slots by day
                ScrollView {
                    LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                        let groupedSlots = Dictionary(grouping: timeSlots) { $0.date }
                        let sortedDays = groupedSlots.keys.sorted()
                        
                        ForEach(sortedDays, id: \.self) { date in
                            Section {
                                ForEach(groupedSlots[date] ?? []) { slot in
                                    TimeSlotRow(
                                        timeSlot: slot,
                                        isSelected: selectedTimeSlot?.id == slot.id,
                                        onSelect: { onTimeSlotSelect(slot) }
                                    )
                                    .padding(.horizontal)
                                }
                            } header: {
                                dayHeader(date)
                            }
                        }
                    }
                    .padding(.vertical)
                }
                
                // Bottom button to create hangout
                VStack {
                    Divider()
                    
                    Button {
                        onCreateHangout()
                    } label: {
                        Text("Create Hangout")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(selectedTimeSlot != nil ? Color.blue : Color.gray)
                            .cornerRadius(16)
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                    }
                    .disabled(selectedTimeSlot == nil)
                }
                .background(Color(.systemBackground))
            }
        }
    }
    
    private func dayHeader(_ date: Date) -> some View {
        HStack {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE, MMMM d"
            let formatted = dateFormatter.string(from: date)
            
            Text(formatted)
                .font(.headline)
                .padding(.horizontal)
                .padding(.vertical, 8)
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

/// Row for displaying a time slot
struct TimeSlotRow: View {
    let timeSlot: TimeSlot
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(timeSlot.formattedStartTime)
                        .font(.headline)
                    
                    Text("to \(timeSlot.formattedEndTime)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(timeSlot.durationMinutes) min")
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .padding(.leading, 4)
                }
            }
            .contentShape(Rectangle())
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Error View

/// View for displaying availability errors
struct MutualAvailabilityErrorView: View {
    let error: Error
    
    let onDateRangeEdit: () -> Void
    let onDurationEdit: () -> Void
    let onFriendPickerShow: () -> Void
    let onRetry: () -> Void
    let onDismissError: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: errorIcon)
                .font(.system(size: 60))
                .foregroundColor(.red)
                .padding(.bottom, 16)
            
            Text(errorTitle)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(errorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                if let mutualError = error as? MutualAvailabilityViewModel.MutualAvailabilityError {
                    switch mutualError {
                    case .noFriendCoupleSelected:
                        Components.IconButton(
                            icon: "person.2",
                            text: "Select Friend",
                            color: .blue,
                            action: onFriendPickerShow
                        )
                        
                    case .noMutualAvailabilityFound, .searchRangeTooNarrow:
                        Components.IconButton(
                            icon: "calendar",
                            text: "Adjust Date Range",
                            color: .blue,
                            action: onDateRangeEdit
                        )
                        
                        Components.IconButton(
                            icon: "clock",
                            text: "Adjust Duration",
                            color: .blue,
                            action: onDurationEdit
                        )
                        
                    case .calendarPermissionRequired:
                        Components.IconButton(
                            icon: "gear",
                            text: "Open Settings",
                            color: .blue,
                            action: {
                                PlatformUtilities.openSettings()
                            }
                        )
                        
                    case .networkError, .internalError:
                        Components.IconButton(
                            icon: "arrow.clockwise",
                            text: "Try Again",
                            color: .blue,
                            action: onRetry
                        )
                    }
                } else {
                    Components.IconButton(
                        icon: "arrow.clockwise",
                        text: "Try Again",
                        color: .blue,
                        action: onRetry
                    )
                }
                
                Button {
                    onDismissError()
                } label: {
                    Text("Dismiss")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var errorTitle: String {
        if let appError = error as? AppError {
            return appError.errorTitle
        } else if let mutualError = error as? MutualAvailabilityViewModel.MutualAvailabilityError {
            switch mutualError {
            case .noFriendCoupleSelected:
                return "Select a Friend"
            case .noMutualAvailabilityFound:
                return "No Available Times"
            case .calendarPermissionRequired:
                return "Calendar Access Required"
            case .searchRangeTooNarrow:
                return "Adjust Time Range"
            case .internalError:
                return "Error"
            case .networkError:
                return "Network Error"
            }
        } else {
            return "Error"
        }
    }
    
    private var errorMessage: String {
        return error.localizedDescription
    }
    
    private var errorIcon: String {
        if let mutualError = error as? MutualAvailabilityViewModel.MutualAvailabilityError {
            switch mutualError {
            case .noFriendCoupleSelected:
                return "person.2.slash"
            case .noMutualAvailabilityFound:
                return "calendar.badge.exclamationmark"
            case .calendarPermissionRequired:
                return "lock.shield"
            case .searchRangeTooNarrow:
                return "calendar.badge.minus"
            case .internalError:
                return "exclamationmark.triangle"
            case .networkError:
                return "wifi.slash"
            }
        } else {
            return "exclamationmark.triangle"
        }
    }
}

// MARK: - Success View

/// View for success state after creating a hangout
struct MutualAvailabilitySuccessView: View {
    let selectedTimeSlot: TimeSlot?
    let onViewDetails: () -> Void
    let onFindAnother: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: CustomTheme.Colors.successGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, 16)
            
            Text("Hangout Created!")
                .font(.title)
                .fontWeight(.bold)
            
            if let slot = selectedTimeSlot {
                VStack(spacing: 8) {
                    Text(slot.formattedDate)
                        .font(.headline)
                    
                    Text("\(slot.formattedStartTime) to \(slot.formattedEndTime)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
            }
            
            Text("Your hangout has been created successfully. You can view the details or find another time.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                Button {
                    onViewDetails()
                } label: {
                    Text("View Details")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(16)
                }
                
                Button {
                    onFindAnother()
                } label: {
                    Text("Find Another Time")
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            .padding(.top, 16)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
} 