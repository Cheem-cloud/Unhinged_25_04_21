import Foundation

// MARK: - Hangout Types
public enum HangoutType: String, CaseIterable, Identifiable {
    case coffee = "Coffee"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case movie = "Movie"
    case workout = "Workout"
    case shopping = "Shopping"
    case other = "Other"
    
    public var id: String { self.rawValue }
    
    public var description: String {
        switch self {
        case .coffee:
            return "A casual coffee meet-up at a cafe or coffee shop."
        case .lunch:
            return "A midday meal together at a restaurant."
        case .dinner:
            return "An evening meal at a restaurant or home cooking."
        case .movie:
            return "Watching a film together at a theater or at home."
        case .workout:
            return "Exercise together at a gym, park, or other location."
        case .shopping:
            return "Browse stores or malls together for fun or essentials."
        case .other:
            return "Something different - you can specify the details."
        }
    }
    
    public var icon: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .lunch: return "fork.knife"
        case .dinner: return "wineglass.fill"
        case .movie: return "film.fill"
        case .workout: return "figure.run"
        case .shopping: return "bag.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Duration
public enum Duration: Int, CaseIterable, Identifiable {
    case veryShort = 15
    case short = 30
    case medium = 60
    case long = 120
    case extended = 180
    // Add oneHour as an alias for medium
    public static var oneHour: Duration { return .medium }
    
    public var id: Int { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .veryShort: return "Quick Chat (15 minutes)"
        case .short: return "Short (30 minutes)"
        case .medium: return "Standard (1 hour)"
        case .long: return "Extended (2 hours)"
        case .extended: return "Long (3 hours)"
        }
    }
    
    public var description: String {
        switch self {
        case .veryShort: return "A brief check-in, perfect for a quick virtual chat."
        case .short: return "A brief catch-up, perfect for coffee or a quick check-in."
        case .medium: return "The standard length for a casual meal or most activities."
        case .long: return "Enough time for a movie, extended meal, or more involved activity."
        case .extended: return "For activities that need more time, like a day trip or special event."
        }
    }
}

// MARK: - Hangout Status
// Commenting out to avoid redeclaration with Hangout.swift
/* 
enum HangoutStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case canceled = "canceled"
    case completed = "completed"
}
*/

// Custom wrapper for HangoutType to include custom text for "other" type
public struct CustomHangoutType {
    public var type: HangoutType
    public var customDescription: String?
    
    public var displayName: String {
        if type == .other && !(customDescription?.isEmpty ?? true) {
            return customDescription!
        }
        return type.rawValue
    }
    
    public var description: String {
        if type == .other && !(customDescription?.isEmpty ?? true) {
            return customDescription!
        }
        return type.description
    }
    
    public var iconName: String {
        return type.icon
    }
    
    public var id: String {
        return type.id
    }
    
    public init(type: HangoutType, customDescription: String? = nil) {
        self.type = type
        self.customDescription = customDescription
    }
}

// MARK: - Time Slots
// Commenting out to avoid redeclaration with TimeSelectionViewModel.swift
/*
public struct TimeSlot: Identifiable, Equatable {
    public let id = UUID()
    public let start: Date
    public let end: Date
    
    public var dateTimeString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: start)
    }
    
    public var timeRangeString: String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return "\(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))"
    }
    
    public var dayString: String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE, MMM d"
        return dayFormatter.string(from: start)
    }
    
    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}
*/ 