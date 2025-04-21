import Foundation

/// Represents a time slot for hangouts, availability and calendar events
public struct TimeSlot: Identifiable, Equatable, Hashable {
    public let id = UUID()
    public let startTime: Date
    public let endTime: Date
    
    // Properties for backward compatibility
    public var start: Date { return startTime }
    public var end: Date { return endTime }
    
    // Formatted strings
    public var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: startTime)
    }
    
    public var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    public var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: startTime)
    }
    
    public var dateTimeString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: startTime)
    }
    
    // Initializers
    public init(startTime: Date, endTime: Date) {
        self.startTime = startTime
        self.endTime = endTime
    }
    
    public init(start: Date, end: Date) {
        self.startTime = start
        self.endTime = end
    }
    
    // Equatable
    public static func == (lhs: TimeSlot, rhs: TimeSlot) -> Bool {
        return lhs.startTime == rhs.startTime && lhs.endTime == rhs.endTime
    }
    
    // Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(startTime)
        hasher.combine(endTime)
    }
}

/// Represents a range of time without specific dates
public struct TimeRange: Codable, Equatable, Hashable, Identifiable {
    public var id: String = UUID().uuidString
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int
    
    public var formattedString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = startHour
        components.minute = startMinute
        let startDate = calendar.date(from: components) ?? Date()
        
        components.hour = endHour
        components.minute = endMinute
        let endDate = calendar.date(from: components) ?? Date()
        
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    public init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }
    
    public static func == (lhs: TimeRange, rhs: TimeRange) -> Bool {
        return lhs.startHour == rhs.startHour &&
               lhs.startMinute == rhs.startMinute &&
               lhs.endHour == rhs.endHour &&
               lhs.endMinute == rhs.endMinute
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(startHour)
        hasher.combine(startMinute)
        hasher.combine(endHour)
        hasher.combine(endMinute)
    }
}

// Create a namespace for the Unhinged app
public enum Unhinged {
    public enum Weekday: String, Codable, CaseIterable {
        case monday = "Monday"
        case tuesday = "Tuesday"
        case wednesday = "Wednesday"
        case thursday = "Thursday"
        case friday = "Friday"
        case saturday = "Saturday"
        case sunday = "Sunday"
        
        public var shortName: String {
            switch self {
            case .monday: return "Mon"
            case .tuesday: return "Tue"
            case .wednesday: return "Wed"
            case .thursday: return "Thu"
            case .friday: return "Fri"
            case .saturday: return "Sat"
            case .sunday: return "Sun"
            }
        }
        
        public var calendarValue: Int {
            switch self {
            case .sunday: return 1
            case .monday: return 2
            case .tuesday: return 3
            case .wednesday: return 4
            case .thursday: return 5
            case .friday: return 6
            case .saturday: return 7
            }
        }
        
        /// Convert a Calendar weekday integer (1=Sunday, 2=Monday, etc.) to the corresponding Weekday enum case
        public static func fromCalendarWeekday(_ calendarWeekday: Int) -> Weekday? {
            switch calendarWeekday {
            case 1: return .sunday
            case 2: return .monday
            case 3: return .tuesday
            case 4: return .wednesday
            case 5: return .thursday
            case 6: return .friday
            case 7: return .saturday
            default: return nil
            }
        }
    }
} 