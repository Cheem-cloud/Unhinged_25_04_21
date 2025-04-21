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
}

struct Hangout: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var startDate: Date
    var endDate: Date
    var location: String?
    var creatorID: String
    var creatorPersonaID: String
    var inviteeID: String
    var inviteePersonaID: String
    var status: HangoutStatus = .pending
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var calendarEventID: String? // Reference to Google Calendar event
    var hasCalendarConflict: Bool = false // Added missing property
    
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
    
    // Implement Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Hangout, rhs: Hangout) -> Bool {
        return lhs.id == rhs.id
    }
} 
