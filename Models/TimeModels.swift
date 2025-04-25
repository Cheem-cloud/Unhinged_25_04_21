import Foundation
import Services

// MARK: - Time Models

/// Time slot representing a period of availability
public struct TimeSlot: Identifiable, Hashable, Codable {
    public var id = UUID()
    public var startTime: Date
    public var endTime: Date
    
    public init(startTime: Date, endTime: Date) {
        self.startTime = startTime
        self.endTime = endTime
    }
    
    /// Calculate the duration in minutes
    public var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }
    
    /// Check if this time slot overlaps with another
    public func overlaps(with other: TimeSlot) -> Bool {
        // Overlaps if either start or end time falls within the other slot
        return (startTime < other.endTime && endTime > other.startTime)
    }
}

// Use typealias to make BusyTimeSlot from Services available here
public typealias BusyTimeSlot = Services.BusyTimeSlot
public typealias BusyTimePeriod = Services.BusyTimePeriod
public typealias AvailabilityRating = Services.AvailabilityRating

// MARK: - Weekday Enum

extension Unhinged {
    /// Day of the week enum
    public enum Weekday: Int, Codable, CaseIterable, Identifiable, Hashable {
        case sunday = 1
        case monday = 2 
        case tuesday = 3
        case wednesday = 4
        case thursday = 5
        case friday = 6
        case saturday = 7
        
        public var id: Int {
            return self.rawValue
        }
        
        public var shortName: String {
            switch self {
            case .sunday: return "Sun"
            case .monday: return "Mon"
            case .tuesday: return "Tue"
            case .wednesday: return "Wed"
            case .thursday: return "Thu"
            case .friday: return "Fri"
            case .saturday: return "Sat"
            }
        }
        
        public var fullName: String {
            switch self {
            case .sunday: return "Sunday"
            case .monday: return "Monday"
            case .tuesday: return "Tuesday"
            case .wednesday: return "Wednesday"
            case .thursday: return "Thursday"
            case .friday: return "Friday"
            case .saturday: return "Saturday"
            }
        }
        
        /// Get the weekday for a given date
        public static func from(date: Date) -> Weekday {
            let calendar = Calendar.current
            let weekdayValue = calendar.component(.weekday, from: date)
            return Weekday(rawValue: weekdayValue) ?? .sunday
        }
    }
}