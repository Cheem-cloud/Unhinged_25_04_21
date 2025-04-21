import Foundation
import FirebaseFirestore

/// Enum representing possible errors when working with availability
enum AvailabilityError: LocalizedError {
    case invalidTimeRange
    case invalidDuration
    case calendarSyncFailed(String)
    case relationshipNotFound
    case preferenceConflict
    case unavailableTimePeriod
    case concurrentUpdateConflict
    case excessiveRecurringCommitments
    case incompatibleCalendarSettings
    case networkTimeout
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidTimeRange:
            return "The specified time range is invalid. End time must be after start time."
        case .invalidDuration:
            return "Invalid duration specified. Duration must be between 15 minutes and 12 hours."
        case .calendarSyncFailed(let details):
            return "Failed to sync with calendar: \(details)"
        case .relationshipNotFound:
            return "The specified relationship could not be found."
        case .preferenceConflict:
            return "Conflict detected between partner preferences. Please coordinate settings with your partner."
        case .unavailableTimePeriod:
            return "The requested time period has no available slots based on your preferences."
        case .concurrentUpdateConflict:
            return "Another user updated these preferences. Please refresh and try again."
        case .excessiveRecurringCommitments:
            return "Too many recurring commitments may be limiting available time slots."
        case .incompatibleCalendarSettings:
            return "Calendar integration settings are incompatible between partners."
        case .networkTimeout:
            return "Request timed out. Please check your network connection and try again."
        case .permissionDenied:
            return "You don't have permission to modify these availability settings."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidTimeRange:
            return "Please ensure the end time is after the start time."
        case .invalidDuration:
            return "Choose a duration between 15 minutes and 12 hours."
        case .calendarSyncFailed:
            return "Check your calendar permissions or try manually setting availability."
        case .relationshipNotFound:
            return "Return to the relationships screen and try again."
        case .preferenceConflict:
            return "Discuss and align on availability preferences with your partner."
        case .unavailableTimePeriod:
            return "Try extending the date range or adjusting your weekly availability settings."
        case .concurrentUpdateConflict:
            return "Refresh the page to see the latest changes, then try again."
        case .excessiveRecurringCommitments:
            return "Consider reviewing and removing some recurring commitments to open more time slots."
        case .incompatibleCalendarSettings:
            return "Both partners should check calendar integration settings and ensure they're properly configured."
        case .networkTimeout:
            return "Check your internet connection and try again. If the problem persists, try again later."
        case .permissionDenied:
            return "This action requires both partners to agree on changes to settings."
        }
    }
}

/// Represents a couple's availability preferences and settings
struct CoupleAvailability: Codable, Identifiable {
    /// Firestore document ID
    @DocumentID var id: String?
    
    /// Reference to the relationship ID
    var relationshipID: String
    
    /// Whether to use calendar data for availability
    var useCalendars: Bool = true
    
    /// Whether to require both partners to be free
    var requireBothFree: Bool = true
    
    /// Minimum advance notice required in hours (e.g., 2 hours before event)
    var minimumAdvanceNotice: Int = 2
    
    /// Maximum days in advance to allow scheduling (e.g., 90 days)
    var maximumAdvanceDays: Int = 90
    
    /// Preferred hangout duration in minutes (default: 120 minutes / 2 hours)
    var preferredHangoutDuration: Int = 120
    
    /// Availability by day of week
    var dayAvailability: [DayAvailability] = []
    
    /// Recurring commitments that block time slots
    var recurringCommitments: [RecurringCommitment] = []
    
    /// Last updated timestamp
    var updatedAt: Date = Date()
    
    /// Initialize with a relationship ID
    init(relationshipID: String) {
        self.relationshipID = relationshipID
        self.updatedAt = Date()
        
        // Default to all days available with standard hours
        self.dayAvailability = Unhinged.Weekday.allCases.map { weekday in
            let timeRanges = [TimeRange(startHour: 9, startMinute: 0, endHour: 21, endMinute: 0)]
            return DayAvailability(day: weekday, timeRanges: timeRanges)
        }
    }
    
    /// Validates that the time range specified is valid
    func validateTimeRange(startDate: Date, endDate: Date, duration: Int) -> Result<Bool, AvailabilityError> {
        // Check that end date is after start date
        if endDate <= startDate {
            return .failure(.invalidTimeRange)
        }
        
        // Check that duration is reasonable
        if duration < 15 || duration > 12 * 60 {
            return .failure(.invalidDuration)
        }
        
        return .success(true)
    }
    
    /// Convert a Firestore document to a CoupleAvailability
    static func fromFirestore(_ document: QueryDocumentSnapshot) -> CoupleAvailability? {
        do {
            var availability = try document.data(as: CoupleAvailability.self)
            availability.id = document.documentID
            return availability
        } catch {
            print("Error decoding CoupleAvailability: \(error.localizedDescription)")
            return nil
        }
    }
    
    mutating func initializeDefaultAvailability() {
        self.dayAvailability = Unhinged.Weekday.allCases.map { weekday in
            let timeRanges = [TimeRange(startHour: 9, startMinute: 0, endHour: 21, endMinute: 0)]
            return DayAvailability(day: weekday, timeRanges: timeRanges)
        }
    }
}

/// Represents availability for a day of the week
struct DayAvailability: Codable, Hashable {
    var id = UUID()
    var day: Unhinged.Weekday
    var timeRanges: [TimeRange]
    
    init(day: Unhinged.Weekday, timeRanges: [TimeRange] = []) {
        self.day = day
        self.timeRanges = timeRanges
    }
}

/// Represents a recurring commitment that blocks availability
struct RecurringCommitment: Codable, Hashable {
    var id = UUID()
    var title: String
    var day: Unhinged.Weekday
    var startTime: Date
    var endTime: Date
    var isSharedWithPartner: Bool
    
    init(title: String, day: Unhinged.Weekday, startTime: Date, endTime: Date, isSharedWithPartner: Bool = true) {
        self.title = title
        self.day = day
        self.startTime = startTime
        self.endTime = endTime
        self.isSharedWithPartner = isSharedWithPartner
    }
}

/// Extension to handle error recovery suggestions
extension CoupleAvailability {
    /// Get alternative suggestions when no mutual availability is found
    func suggestAlternatives(startDate: Date, endDate: Date, duration: Int) -> [TimeSlot] {
        var suggestedSlots: [TimeSlot] = []
        
        // If duration is long, try a shorter duration
        if duration > 60 {
            // Try with half the duration
            let halfDuration = max(30, duration / 2)
            
            // Code to generate slots with shorter duration would go here
            // This is a placeholder
            let calendar = Calendar.current
            var currentDate = startDate
            
            while currentDate < endDate {
                let endTime = calendar.date(byAdding: .minute, value: halfDuration, to: currentDate) ?? currentDate
                suggestedSlots.append(TimeSlot(startTime: currentDate, endTime: endTime))
                
                // Move to next day
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                    currentDate = calendar.startOfDay(for: nextDay)
                } else {
                    break
                }
            }
        }
        
        // If date range is short, try a wider range
        if let extendedEndDate = Calendar.current.date(byAdding: .day, value: 14, to: endDate) {
            // Code to check extended date range would go here
            // This is a placeholder
            let calendar = Calendar.current
            var currentDate = endDate
            
            while currentDate < extendedEndDate {
                let endTime = calendar.date(byAdding: .minute, value: duration, to: currentDate) ?? currentDate
                suggestedSlots.append(TimeSlot(startTime: currentDate, endTime: endTime))
                
                // Move to next day
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                    currentDate = calendar.startOfDay(for: nextDay)
                } else {
                    break
                }
            }
        }
        
        return suggestedSlots
    }
} 