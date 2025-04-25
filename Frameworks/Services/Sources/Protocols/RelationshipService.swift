import Foundation

/// Protocol for managing user relationships
public protocol RelationshipService {
    /// Get a relationship for a user
    /// - Parameter userID: The user ID
    /// - Returns: The relationship if found
    func getRelationshipForUser(userID: String) async throws -> Relationship?
    
    /// Invite a partner using their email
    /// - Parameters:
    ///   - partnerEmail: The partner's email
    ///   - message: Optional personal message
    func invitePartner(partnerEmail: String, message: String) async throws
    
    /// Accept a partner invitation
    /// - Parameter invitationID: The invitation ID
    func acceptPartnerInvitation(invitationID: String) async throws
    
    /// Decline a partner invitation
    /// - Parameter invitationID: The invitation ID
    func declinePartnerInvitation(invitationID: String) async throws
    
    /// Remove a partner relationship
    /// - Parameter relationshipID: The relationship ID
    func removePartnerRelationship(relationshipID: String) async throws
    
    /// Get partner personas for a relationship
    /// - Parameter relationshipID: The relationship ID
    /// - Returns: Array of partner personas
    func getPartnerPersonas(for relationshipID: String) async throws -> [PartnerPersona]
    
    /// Add a partner persona
    /// - Parameters:
    ///   - persona: The persona to add
    ///   - relationshipID: The relationship ID
    func addPartnerPersona(_ persona: PartnerPersona, for relationshipID: String) async throws
    
    /// Update a partner persona
    /// - Parameters:
    ///   - persona: The updated persona
    ///   - relationshipID: The relationship ID
    func updatePartnerPersona(_ persona: PartnerPersona, for relationshipID: String) async throws
    
    /// Delete a partner persona
    /// - Parameters:
    ///   - personaID: The persona ID
    ///   - relationshipID: The relationship ID
    func deletePartnerPersona(withID personaID: String, for relationshipID: String) async throws
    
    /// Get relationship invitations for a user
    /// - Parameter userID: The user ID
    /// - Returns: Array of invitations
    func getInvitationsForUser(userID: String) async throws -> [RelationshipInvitation]
}

/// Model for relationship invitations
public struct RelationshipInvitation: Identifiable, Codable {
    /// Unique identifier
    public var id: String
    
    /// ID of the user who sent the invitation
    public var senderID: String
    
    /// Email of the recipient
    public var recipientEmail: String
    
    /// Optional recipient ID if user exists
    public var recipientID: String?
    
    /// Optional personal message
    public var message: String?
    
    /// Unique invitation code
    public var invitationCode: String
    
    /// Status of the invitation
    public var status: InvitationStatus
    
    /// Created date
    public var createdAt: Date
    
    /// Updated date
    public var updatedAt: Date
    
    /// Initialize a new invitation
    public init(
        id: String = UUID().uuidString,
        senderID: String,
        recipientEmail: String,
        recipientID: String? = nil,
        message: String? = nil,
        invitationCode: String = UUID().uuidString,
        status: InvitationStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.senderID = senderID
        self.recipientEmail = recipientEmail
        self.recipientID = recipientID
        self.message = message
        self.invitationCode = invitationCode
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Status of a relationship invitation
    public enum InvitationStatus: String, Codable {
        case pending
        case accepted
        case declined
        case canceled
        case expired
    }
} 