import Foundation

/// Protocol defining the calendar service adapter interface
public protocol CalendarServiceAdapter {
    /// Get busy time periods for a user within a date range
    /// - Parameters:
    ///   - userID: The user ID
    ///   - startDate: Start date of the range
    ///   - endDate: End date of the range
    /// - Returns: Array of busy time periods
    func getBusyTimePeriods(for userID: String, startDate: Date, endDate: Date) async throws -> [BusyTimePeriod]
    
    /// Add an event to the user's calendar
    /// - Parameters:
    ///   - userID: The user ID
    ///   - event: The calendar event to add
    /// - Returns: The created event ID
    func addEvent(for userID: String, event: CalendarEvent) async throws -> String
    
    /// Update an existing calendar event
    /// - Parameters:
    ///   - userID: The user ID
    ///   - eventID: The event ID
    ///   - event: The updated event data
    func updateEvent(for userID: String, eventID: String, event: CalendarEvent) async throws
    
    /// Delete a calendar event
    /// - Parameters:
    ///   - userID: The user ID
    ///   - eventID: The event ID to delete
    func deleteEvent(for userID: String, eventID: String) async throws
    
    /// Get events for a user within a date range
    /// - Parameters:
    ///   - userID: The user ID
    ///   - startDate: Start date of the range
    ///   - endDate: End date of the range
    /// - Returns: Array of calendar events
    func getEvents(for userID: String, startDate: Date, endDate: Date) async throws -> [CalendarEvent]
    
    /// Get a specific event by ID
    /// - Parameters:
    ///   - userID: The user ID
    ///   - eventID: The event ID
    /// - Returns: The calendar event if found
    func getEvent(for userID: String, eventID: String) async throws -> CalendarEvent?
    
    /// Check if a user has calendar access
    /// - Parameter userID: The user ID
    /// - Returns: Whether the user has calendar access
    func hasCalendarAccess(for userID: String) async throws -> Bool
    
    /// Get calendar settings for a user
    /// - Parameter userID: The user ID
    /// - Returns: The user's calendar settings
    func getCalendarSettings(for userID: String) async throws -> CalendarSettings
    
    /// Save calendar settings for a user
    /// - Parameters:
    ///   - settings: The calendar settings
    ///   - userID: The user ID
    func saveCalendarSettings(_ settings: CalendarSettings, for userID: String) async throws
}

/// A calendar event model
public struct CalendarEvent: Identifiable, Codable {
    public var id: String
    public var title: String
    public var description: String?
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var location: String?
    public var calendarId: String?
    public var organizerEmail: String?
    public var attendees: [String]
    public var reminderMinutes: Int
    public var recurringRule: String?
    public var color: String?
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        calendarId: String? = nil,
        organizerEmail: String? = nil,
        attendees: [String] = [],
        reminderMinutes: Int = 15,
        recurringRule: String? = nil,
        color: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.calendarId = calendarId
        self.organizerEmail = organizerEmail
        self.attendees = attendees
        self.reminderMinutes = reminderMinutes
        self.recurringRule = recurringRule
        self.color = color
    }
} 