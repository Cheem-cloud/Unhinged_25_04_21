import Foundation
import FirebaseFirestore
import Services

// Using the consolidated AvailabilityError from Models/AvailabilityError.swift
// Enum representing possible errors when working with availability
//enum AvailabilityError: LocalizedError {
//    case invalidTimeRange
//    case invalidDuration
//    ...
//}

/// Represents a couple's availability preferences and settings
public struct CoupleAvailability: Codable, Identifiable {
    /// Firestore document ID
    @DocumentID public var id: String?
    
    /// Reference to the relationship ID
    public var relationshipID: String
    
    /// Whether to use calendar data for availability
    public var useCalendars: Bool = true
    
    /// Whether to require both partners to be free
    public var requireBothFree: Bool = true
    
    /// Minimum advance notice required in hours (e.g., 2 hours before event)
    public var minimumAdvanceNotice: Int = 2
    
    /// Maximum days in advance to allow scheduling (e.g., 90 days)
    public var maximumAdvanceDays: Int = 90
    
    /// Preferred hangout duration in minutes (default: 120 minutes / 2 hours)
    public var preferredHangoutDuration: Int = 120
    
    /// Availability by day of week
    public var dayAvailability: [DayAvailability] = []
    
    /// Recurring commitments that block time slots
    public var recurringCommitments: [RecurringCommitment] = []
    
    /// Last updated timestamp
    public var updatedAt: Date = Date()
    
    /// Initialize with a relationship ID
    public init(relationshipID: String) {
        self.relationshipID = relationshipID
        self.updatedAt = Date()
        
        // Default to all days available with standard hours
        self.dayAvailability = Unhinged.Weekday.allCases.map { weekday in
            let timeRanges = [Services.TimeRange(startHour: 9, startMinute: 0, endHour: 21, endMinute: 0)]
            return DayAvailability(day: weekday, timeRanges: timeRanges)
        }
    }
    
    /// Validates that the time range specified is valid
    public func validateTimeRange(startDate: Date, endDate: Date, duration: Int) -> Result<Bool, Error> {
        // Check that end date is after start date
        if endDate <= startDate {
            return .failure(AvailabilityError(errorType: .invalidTimeRange))
        }
        
        // Check that duration is reasonable
        if duration < 15 || duration > 12 * 60 {
            return .failure(AvailabilityError(errorType: .invalidDuration))
        }
        
        return .success(true)
    }
    
    /// Convert a Firestore document to a CoupleAvailability
    public static func fromFirestore(_ document: QueryDocumentSnapshot) -> CoupleAvailability? {
        do {
            var availability = try document.data(as: CoupleAvailability.self)
            availability.id = document.documentID
            return availability
        } catch {
            print("Error decoding CoupleAvailability: \(error.localizedDescription)")
            return nil
        }
    }
    
    public mutating func initializeDefaultAvailability() {
        self.dayAvailability = Unhinged.Weekday.allCases.map { weekday in
            let timeRanges = [Services.TimeRange(startHour: 9, startMinute: 0, endHour: 21, endMinute: 0)]
            return DayAvailability(day: weekday, timeRanges: timeRanges)
        }
    }
}

/// Represents availability for a day of the week
public struct DayAvailability: Codable, Hashable {
    public var id = UUID()
    public var day: Unhinged.Weekday
    public var timeRanges: [Services.TimeRange]
    
    public init(day: Unhinged.Weekday, timeRanges: [Services.TimeRange] = []) {
        self.day = day
        self.timeRanges = timeRanges
    }
}

/// Represents a recurring commitment that blocks availability
public struct RecurringCommitment: Codable, Hashable {
    public var id = UUID()
    public var title: String
    public var day: Unhinged.Weekday
    public var startTime: Date
    public var endTime: Date
    public var isSharedWithPartner: Bool
    
    public init(title: String, day: Unhinged.Weekday, startTime: Date, endTime: Date, isSharedWithPartner: Bool = true) {
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
    public func suggestAlternatives(startDate: Date, endDate: Date, duration: Int) -> [TimeSlot] {
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