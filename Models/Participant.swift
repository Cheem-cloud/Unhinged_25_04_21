import Foundation
import FirebaseFirestore

/// Represents a participant in a hangout or event
public struct Participant: Identifiable, Codable, Hashable {
    /// Unique identifier for the participant
    public var id: String = UUID().uuidString
    
    /// User ID of the participant
    public var userID: String
    
    /// Persona ID used by the participant
    public var personaID: String
    
    /// Display name for the participant
    public var name: String
    
    /// Profile image URL
    public var imageURL: String?
    
    /// RSVP status for the event
    public var status: RSVPStatus = .pending
    
    /// Date when the invitation was sent
    public var invitedDate: Date = Date()
    
    /// Date when the participant responded
    public var respondedDate: Date?
    
    /// Optional notes from the participant
    public var notes: String?
    
    /// RSVP status enum
    public enum RSVPStatus: String, Codable, CaseIterable {
        case pending
        case accepted
        case declined
        case tentative
        case none
        
        public var displayText: String {
            switch self {
            case .pending:
                return "Pending"
            case .accepted:
                return "Accepted"
            case .declined:
                return "Declined"
            case .tentative:
                return "Maybe"
            case .none:
                return "No Response"
            }
        }
        
        public var color: String {
            switch self {
            case .pending:
                return "orange"
            case .accepted:
                return "green"
            case .declined:
                return "red"
            case .tentative:
                return "blue"
            case .none:
                return "gray"
            }
        }
    }
    
    /// Create a new participant
    public init(
        id: String = UUID().uuidString,
        userID: String,
        personaID: String,
        name: String,
        imageURL: String? = nil,
        status: RSVPStatus = .pending,
        invitedDate: Date = Date(),
        respondedDate: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.userID = userID
        self.personaID = personaID
        self.name = name
        self.imageURL = imageURL
        self.status = status
        self.invitedDate = invitedDate
        self.respondedDate = respondedDate
        self.notes = notes
    }
    
    // Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Participant, rhs: Participant) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Extension for Firestore serialization
extension Participant: FirestoreSerializable {
    public func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "userID": userID,
            "personaID": personaID,
            "name": name,
            "status": status.rawValue,
            "invitedDate": Timestamp(date: invitedDate)
        ]
        
        if let imageURL = imageURL {
            data["imageURL"] = imageURL
        }
        
        if let respondedDate = respondedDate {
            data["respondedDate"] = Timestamp(date: respondedDate)
        }
        
        if let notes = notes {
            data["notes"] = notes
        }
        
        return data
    }
}

/// Extension for Firestore deserialization
extension Participant: FirestoreConvertible {
    public static func fromFirestore(_ data: [String: Any]) -> Participant? {
        guard let id = data["id"] as? String,
              let userID = data["userID"] as? String,
              let personaID = data["personaID"] as? String,
              let name = data["name"] as? String,
              let statusRaw = data["status"] as? String,
              let status = RSVPStatus(rawValue: statusRaw),
              let invitedTimestamp = data["invitedDate"] as? Timestamp else {
            return nil
        }
        
        var participant = Participant(
            id: id,
            userID: userID,
            personaID: personaID,
            name: name,
            imageURL: data["imageURL"] as? String,
            status: status,
            invitedDate: invitedTimestamp.dateValue(),
            notes: data["notes"] as? String
        )
        
        if let respondedTimestamp = data["respondedDate"] as? Timestamp {
            participant.respondedDate = respondedTimestamp.dateValue()
        }
        
        return participant
    }
} 