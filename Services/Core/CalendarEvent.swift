import Foundation

/// Additional properties for a calendar event
public struct CalendarEventProperties: Codable {
    public var participants: [String]?
    public var startTimeZone: String?
    public var endTimeZone: String?
    public var isAllDay: Bool
    public var reminders: [Reminder]?
    
    public init(
        participants: [String]? = nil,
        startTimeZone: String? = nil,
        endTimeZone: String? = nil,
        isAllDay: Bool = false,
        reminders: [Reminder]? = nil
    ) {
        self.participants = participants
        self.startTimeZone = startTimeZone
        self.endTimeZone = endTimeZone
        self.isAllDay = isAllDay
        self.reminders = reminders
    }
    
    /// Reminder for an event
    public struct Reminder: Codable {
        public var minutes: Int
        public var method: String
        
        public init(minutes: Int, method: String = "popup") {
            self.minutes = minutes
            self.method = method
        }
    }
}

/// The canonical model for calendar events across the app
public struct CalendarEvent: Codable {
    public let id: String
    public let provider: String
    public let providerEventId: String
    public let calendarId: String
    public let userId: String
    public let title: String
    public let description: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?
    public let properties: CalendarEventProperties
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        provider: String,
        providerEventId: String,
        calendarId: String,
        userId: String,
        title: String,
        description: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        properties: CalendarEventProperties = CalendarEventProperties(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.provider = provider
        self.providerEventId = providerEventId
        self.calendarId = calendarId
        self.userId = userId
        self.title = title
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.properties = properties
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// Add a typealias for backward compatibility with CalendarEventModel
public typealias CalendarEventModel = CalendarEvent 