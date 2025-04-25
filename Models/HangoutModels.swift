import Foundation
import SwiftUI

// MARK: - Hangout Type reference
// Using the top-level HangoutType definition directly

/// Compatibility with existing HangoutType references
public typealias HangoutTypes = HangoutType

/// Models for creating and editing hangouts
public struct HangoutForm: Codable, Equatable {
    public var title: String
    public var description: String
    public var startDate: Date
    public var endDate: Date
    public var location: String
    public var participantIDs: [String]
    public var type: HangoutType
    
    // Explicit Codable conformance implementation
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case startDate
        case endDate
        case location
        case participantIDs
        case type
    }
    
    // Custom encode implementation
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(location, forKey: .location)
        try container.encode(participantIDs, forKey: .participantIDs)
        try container.encode(type, forKey: .type)
    }
    
    // Custom decode implementation
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        location = try container.decode(String.self, forKey: .location)
        participantIDs = try container.decode([String].self, forKey: .participantIDs)
        type = try container.decode(HangoutType.self, forKey: .type)
    }
    
    public init(
        title: String = "",
        description: String = "",
        startDate: Date = Date().addingTimeInterval(3600),
        endDate: Date = Date().addingTimeInterval(7200),
        location: String = "",
        participantIDs: [String] = [],
        type: HangoutType = .inPerson
    ) {
        self.title = title
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.participantIDs = participantIDs
        self.type = type
    }
    
    // Equatable implementation
    public static func == (lhs: HangoutForm, rhs: HangoutForm) -> Bool {
        return lhs.title == rhs.title &&
               lhs.description == rhs.description &&
               lhs.startDate == rhs.startDate &&
               lhs.endDate == rhs.endDate &&
               lhs.location == rhs.location &&
               lhs.participantIDs == rhs.participantIDs &&
               lhs.type == rhs.type
    }
    
    /// Convert a HangoutForm to a Hangout model
    public func toHangout(
        creatorID: String,
        creatorPersonaID: String,
        inviteeID: String,
        inviteePersonaID: String
    ) -> Hangout {
        return Hangout(
            title: title,
            description: description,
            startDate: startDate,
            endDate: endDate,
            location: location,
            creatorID: creatorID,
            creatorPersonaID: creatorPersonaID,
            inviteeID: inviteeID,
            inviteePersonaID: inviteePersonaID
        )
    }
}

/// Helper extension for UI purposes
public extension HangoutType {
    var icon: String {
        switch self {
        case .inPerson:
            return "person.2"
        case .virtual:
            return "video"
        case .hybrid:
            return "person.2.wave.2"
        }
    }
    
    var displayText: String {
        switch self {
        case .inPerson:
            return "In Person"
        case .virtual:
            return "Virtual"
        case .hybrid:
            return "Hybrid"
        }
    }
    
    var color: Color {
        switch self {
        case .inPerson:
            return .blue
        case .virtual:
            return .green
        case .hybrid:
            return .purple
        }
    }
}

// MARK: - Activity Types (Renamed from second HangoutType)
public enum ActivityType: String, CaseIterable, Identifiable {
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

// MARK: - Custom wrapper for ActivityType
public struct CustomHangoutType {
    public var type: ActivityType
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
    
    public init(type: ActivityType, customDescription: String? = nil) {
        self.type = type
        self.customDescription = customDescription
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