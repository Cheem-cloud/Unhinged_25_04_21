import Foundation

/// Calendar event entity for use with the new CalendarOperationsService
struct CalendarEvent {
    /// The unique identifier for the event
    var id: String = ""
    
    /// The title of the event
    let title: String
    
    /// Optional description of the event
    var description: String?
    
    /// The start date and time of the event
    let startDate: Date
    
    /// The end date and time of the event
    let endDate: Date
    
    /// Whether the event is all day
    var isAllDay: Bool = false
    
    /// Optional location of the event
    var location: String?
    
    /// IDs of users attending the event
    let attendees: [String]
    
    /// The hangout associated with this event
    let associatedHangout: Hangout
    
    /// Optional URL for the event
    var eventUrl: String?
    
    /// Create a new calendar event
    /// - Parameters:
    ///   - id: The event ID (optional, will be set after creation)
    ///   - title: The title of the event
    ///   - description: Optional description of the event
    ///   - startDate: The start date and time
    ///   - endDate: The end date and time
    ///   - isAllDay: Whether the event is all day
    ///   - location: Optional location
    ///   - attendees: IDs of users attending
    ///   - associatedHangout: The hangout associated with this event
    ///   - eventUrl: Optional URL for the event
    init(
        id: String = "",
        title: String,
        description: String? = nil,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        attendees: [String],
        associatedHangout: Hangout,
        eventUrl: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.attendees = attendees
        self.associatedHangout = associatedHangout
        self.eventUrl = eventUrl
    }
} 