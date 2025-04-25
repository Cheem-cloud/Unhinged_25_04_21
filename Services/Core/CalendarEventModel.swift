import Foundation

/// Model representing a calendar event
public struct CalendarEventModel: Identifiable, Codable {
    public var id: String
    public var title: String
    public var description: String
    public var startDate: Date
    public var endDate: Date
    public var location: String?
    public var notes: String?
    public var attendees: [String]?
    public var isAllDay: Bool
    public var calendarId: String?
    public var hangoutId: String?
    public var provider: CalendarProviderType?
    public var providerEventId: String?
    public var recurrenceRule: String?
    public var isRecurring: Bool
    public var color: String?
    
    public init(id: String = UUID().uuidString,
                title: String,
                description: String = "",
                startDate: Date,
                endDate: Date,
                location: String? = nil,
                notes: String? = nil,
                attendees: [String]? = nil,
                isAllDay: Bool = false,
                calendarId: String? = nil,
                hangoutId: String? = nil,
                provider: CalendarProviderType? = nil,
                providerEventId: String? = nil,
                recurrenceRule: String? = nil,
                isRecurring: Bool = false,
                color: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.attendees = attendees
        self.isAllDay = isAllDay
        self.calendarId = calendarId
        self.hangoutId = hangoutId
        self.provider = provider
        self.providerEventId = providerEventId
        self.recurrenceRule = recurrenceRule
        self.isRecurring = isRecurring
        self.color = color
    }
    
    /// Convert a CalendarEventModel to a Hangout
    public func toHangout(creatorID: String, creatorPersonaID: String, 
                         inviteeID: String, inviteePersonaID: String) -> Hangout {
        return Hangout(
            id: hangoutId,
            title: title,
            description: description,
            startDate: startDate,
            endDate: endDate,
            location: location,
            creatorID: creatorID,
            creatorPersonaID: creatorPersonaID,
            inviteeID: inviteeID,
            inviteePersonaID: inviteePersonaID,
            calendarEventID: id
        )
    }
}

/// View model for calendar events
public class CalendarEventViewModel: Identifiable, ObservableObject {
    public var id: String
    @Published public var title: String
    @Published public var description: String
    @Published public var startDate: Date
    @Published public var endDate: Date
    @Published public var location: String?
    @Published public var notes: String?
    @Published public var attendees: [String]?
    @Published public var isAllDay: Bool
    @Published public var calendarId: String?
    @Published public var provider: CalendarProviderType?
    @Published public var recurrenceRule: String?
    @Published public var isRecurring: Bool
    @Published public var color: String?
    
    public init(event: CalendarEventModel) {
        self.id = event.id
        self.title = event.title
        self.description = event.description
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.location = event.location
        self.notes = event.notes
        self.attendees = event.attendees
        self.isAllDay = event.isAllDay
        self.calendarId = event.calendarId
        self.provider = event.provider
        self.recurrenceRule = event.recurrenceRule
        self.isRecurring = event.isRecurring
        self.color = event.color
    }
    
    public init(id: String = UUID().uuidString,
                title: String = "",
                description: String = "",
                startDate: Date = Date(),
                endDate: Date = Date().addingTimeInterval(3600),
                location: String? = nil,
                notes: String? = nil,
                attendees: [String]? = nil,
                isAllDay: Bool = false,
                calendarId: String? = nil,
                provider: CalendarProviderType? = nil,
                recurrenceRule: String? = nil,
                isRecurring: Bool = false,
                color: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.attendees = attendees
        self.isAllDay = isAllDay
        self.calendarId = calendarId
        self.provider = provider
        self.recurrenceRule = recurrenceRule
        self.isRecurring = isRecurring
        self.color = color
    }
    
    public func toModel() -> CalendarEventModel {
        return CalendarEventModel(
            id: id,
            title: title,
            description: description,
            startDate: startDate,
            endDate: endDate,
            location: location,
            notes: notes,
            attendees: attendees,
            isAllDay: isAllDay,
            calendarId: calendarId,
            provider: provider,
            recurrenceRule: recurrenceRule,
            isRecurring: isRecurring,
            color: color
        )
    }
} 