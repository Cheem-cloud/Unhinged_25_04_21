import Foundation
import FirebaseFirestore

/// Represents the status of a relationship between two users
public enum RelationshipStatus: String, Codable {
    /// Relationship is pending acceptance
    case pending
    /// Relationship is active
    case active
    /// Relationship has been terminated
    case terminated
}

/// Represents a relationship between two users (partners)
struct Relationship: Identifiable, Codable {
    /// Firebase document ID
    @DocumentID var id: String?
    
    /// ID of the user who initiated the relationship
    var initiatorID: String
    
    /// ID of the user who was invited to the relationship
    var partnerID: String
    
    /// The current status of the relationship
    var status: RelationshipStatus = .pending
    
    /// Optional display name for the relationship
    var displayName: String?
    
    /// Date when the relationship was established (becomes active)
    var establishedDate: Date?
    
    /// Date when the relationship was first created (invitation sent)
    var createdDate: Date = Date()
    
    /// Date when the relationship was last updated
    var updatedDate: Date = Date()
    
    /// CodingKeys for Codable conformance
    enum CodingKeys: String, CodingKey {
        case id
        case initiatorID
        case partnerID
        case status
        case displayName
        case establishedDate
        case createdDate
        case updatedDate
    }
    
    /// Initialize a relationship with required fields
    init(initiatorID: String, partnerID: String) {
        self.initiatorID = initiatorID
        self.partnerID = partnerID
        self.createdDate = Date()
        self.updatedDate = Date()
    }
    
    /// Initialize a new pending relationship
    static func createPending(initiatorID: String, partnerID: String) -> Relationship {
        var relationship = Relationship(initiatorID: initiatorID, partnerID: partnerID)
        relationship.status = .pending
        return relationship
    }
    
    /// Get the ID of the partner for a given user ID
    func getPartnerID(for userID: String) -> String? {
        if userID == initiatorID {
            return partnerID
        } else if userID == partnerID {
            return initiatorID
        }
        return nil
    }
    
    /// Check if a user is part of this relationship
    func includesUser(userID: String) -> Bool {
        return userID == initiatorID || userID == partnerID
    }
} 