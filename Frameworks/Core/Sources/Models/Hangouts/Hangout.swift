import Foundation

/// Hangout status enum
public enum HangoutStatus: String, Codable {
    case pending
    case accepted
    case declined
    case completed
    case cancelled
    
    // Add another case for canceled (US spelling) for compatibility
    public static var canceled: HangoutStatus { return .cancelled }
    
    // For compatibility with older status names
    public static var confirmed: HangoutStatus { return .accepted }
}

/// Type of hangout
public enum HangoutType: String, Codable, CaseIterable, Identifiable {
    case inPerson = "in_person"
    case virtual = "virtual"
    case hybrid = "hybrid"
    
    public var id: String {
        return self.rawValue
    }
    
    public var displayName: String {
        switch self {
        case .inPerson:
            return "In Person"
        case .virtual:
            return "Virtual"
        case .hybrid:
            return "Hybrid"
        }
    }
    
    public var icon: String {
        switch self {
        case .inPerson:
            return "person.2"
        case .virtual:
            return "video"
        case .hybrid:
            return "person.2.wave.2"
        }
    }
}

/// A hangout between users
public struct Hangout: Identifiable, Codable, Hashable {
    /// Unique identifier
    public var id: String?
    
    /// Title of the hangout
    public var title: String?
    
    /// Description of the hangout
    public var description: String?
    
    /// Start date and time
    public var startDate: Date?
    
    /// End date and time
    public var endDate: Date?
    
    /// Location of the hangout
    public var location: String?
    
    /// ID of the user who created the hangout
    public var creatorID: String
    
    /// ID of the persona used by the creator
    public var creatorPersonaID: String
    
    /// ID of the invited user
    public var inviteeID: String
    
    /// ID of the persona used by the invitee
    public var inviteePersonaID: String
    
    /// Status of the hangout
    public var status: HangoutStatus = .pending
    
    /// Creation date
    public var createdAt: Date = Date()
    
    /// Last update date
    public var updatedAt: Date = Date()
    
    /// Reference to associated calendar event ID
    public var calendarEventID: String?
    
    /// Flag indicating if there's a calendar conflict
    public var hasCalendarConflict: Bool = false
    
    // Convenience computed properties for backward compatibility
    
    /// Date of the hangout (alias for startDate)
    public var date: Date? { return startDate }
    
    /// Notes about the hangout (alias for description)
    public var notes: String? { return description }
    
    /// Participant IDs (creator and invitee)
    public var participants: [String]? { return [creatorID, inviteeID] }
    
    /// Coding keys for Codable conformance
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case startDate
        case endDate
        case location
        case creatorID
        case creatorPersonaID
        case inviteeID
        case inviteePersonaID
        case status
        case createdAt
        case updatedAt
        case calendarEventID
        case hasCalendarConflict
    }
    
    /// Initialize a new hangout
    public init(
        id: String? = nil,
        title: String? = nil,
        description: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        location: String? = nil,
        creatorID: String,
        creatorPersonaID: String,
        inviteeID: String,
        inviteePersonaID: String,
        status: HangoutStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        calendarEventID: String? = nil,
        hasCalendarConflict: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.creatorID = creatorID
        self.creatorPersonaID = creatorPersonaID
        self.inviteeID = inviteeID
        self.inviteePersonaID = inviteePersonaID
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.calendarEventID = calendarEventID
        self.hasCalendarConflict = hasCalendarConflict
    }
    
    // MARK: - Hashable conformance
    
    /// Hash the hangout
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Compare two hangouts for equality
    public static func == (lhs: Hangout, rhs: Hangout) -> Bool {
        return lhs.id == rhs.id
    }
} 