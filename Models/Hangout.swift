import Foundation
import FirebaseFirestore

public enum HangoutStatus: String, Codable {
    case pending
    case accepted
    case declined
    case completed
    case cancelled
    // Add another case for canceled (US spelling) for compatibility
    static var canceled: HangoutStatus { return .cancelled }
    
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

public struct Hangout: Identifiable, Codable, Hashable {
    // Import HangoutType directly instead of using a circular typealias
    
    @DocumentID public var id: String?
    public var title: String?
    public var description: String?
    public var startDate: Date?
    public var endDate: Date?
    public var location: String?
    public var creatorID: String
    public var creatorPersonaID: String
    public var inviteeID: String
    public var inviteePersonaID: String
    public var status: HangoutStatus = .pending
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var calendarEventID: String? // Reference to Google Calendar event
    public var hasCalendarConflict: Bool = false
    public var date: Date? { return startDate } // For backward compatibility
    public var notes: String? { return description } // For backward compatibility
    public var participants: [String]? { return [creatorID, inviteeID] } // For backward compatibility
    
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
    
    // Implement Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Hangout, rhs: Hangout) -> Bool {
        return lhs.id == rhs.id
    }
} 
