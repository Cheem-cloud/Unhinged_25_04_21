import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Error types for relationship operations
enum RelationshipError: Error {
    case userNotAuthenticated
    case userNotFound
    case userAlreadyInRelationship
    case relationshipNotFound
    case cannotInviteSelf
    case invitationNotFound
    case notAuthorized
    case networkError
}

/// Service for managing relationships between partners
class RelationshipService {
    // MARK: - Properties
    
    /// Shared instance (singleton)
    static let shared = RelationshipService()
    
    /// Firebase Firestore database
    private let db = Firestore.firestore()
    
    /// FirestoreService for reuse
    private let firestoreService = FirestoreService.shared
    
    /// NotificationService for sending notifications
    private let notificationService = NotificationService.shared
    
    /// Collection reference for relationships
    private var relationshipsCollection: CollectionReference {
        return db.collection("relationships")
    }
    
    /// Collection reference for partner invitations
    private var invitationsCollection: CollectionReference {
        return db.collection("partnerInvitations")
    }
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Relationship Methods
    
    /// Get the current user's relationship (if exists)
    /// - Returns: The user's relationship or nil if not found
    func getCurrentUserRelationship() async throws -> Relationship? {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw RelationshipError.userNotAuthenticated
        }
        
        let query = relationshipsCollection
            .whereFilter(Filter.orFilter([
                Filter.whereField("initiatorID", isEqualTo: currentUserID),
                Filter.whereField("partnerID", isEqualTo: currentUserID)
            ]))
            .whereField("status", isNotEqualTo: RelationshipStatus.terminated.rawValue)
        
        let snapshot = try await query.getDocuments()
        
        if let doc = snapshot.documents.first {
            return try doc.data(as: Relationship.self)
        }
        
        return nil
    }
    
    /// Get a specific relationship by ID
    /// - Parameter id: The relationship ID
    /// - Returns: The relationship
    func getRelationship(id: String) async throws -> Relationship {
        let docRef = relationshipsCollection.document(id)
        let snapshot = try await docRef.getDocument()
        
        guard snapshot.exists else {
            throw RelationshipError.relationshipNotFound
        }
        
        return try snapshot.data(as: Relationship.self)
    }
    
    /// Invite a user to become a partner
    /// - Parameters:
    ///   - partnerEmail: Email of the user to invite
    ///   - message: Optional message to include with the invitation
    /// - Returns: The created invitation
    func invitePartner(partnerEmail: String, message: String? = nil) async throws -> PartnerInvitation {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw RelationshipError.userNotAuthenticated
        }
        
        // Check if user already has a relationship
        if let _ = try await getCurrentUserRelationship() {
            throw RelationshipError.userAlreadyInRelationship
        }
        
        // Can't invite yourself
        if let currentUserEmail = Auth.auth().currentUser?.email, currentUserEmail.lowercased() == partnerEmail.lowercased() {
            throw RelationshipError.cannotInviteSelf
        }
        
        // Check if the partner user already exists
        var partnerID: String? = nil
        let users = try await getUsersByEmail(email: partnerEmail)
        if let existingUser = users.first {
            partnerID = existingUser.id
            
            // Check if partner already has a relationship
            let query = relationshipsCollection
                .whereFilter(Filter.orFilter([
                    Filter.whereField("initiatorID", isEqualTo: partnerID!),
                    Filter.whereField("partnerID", isEqualTo: partnerID!)
                ]))
                .whereField("status", isNotEqualTo: RelationshipStatus.terminated.rawValue)
            
            let snapshot = try await query.getDocuments()
            if !snapshot.documents.isEmpty {
                throw RelationshipError.userAlreadyInRelationship
            }
        }
        
        // Create the invitation
        let invitation = PartnerInvitation(
            senderID: currentUserID,
            recipientEmail: partnerEmail,
            message: message
        )
        
        // Save the invitation
        let invitationRef = try invitationsCollection.addDocument(from: invitation)
        
        // If partner exists, send them a notification
        if let partnerID = partnerID {
            let sender = try await firestoreService.getUser(id: currentUserID)
            try await notificationService.sendPartnerInvitationNotification(
                to: partnerID,
                from: sender?.displayName ?? "Unknown",
                invitationID: invitationRef.documentID
            )
        }
        
        // Return the created invitation with the ID
        var createdInvitation = invitation
        createdInvitation.id = invitationRef.documentID
        return createdInvitation
    }
    
    /// Accept a partner invitation and create a relationship
    /// - Parameter invitationID: ID of the invitation to accept
    /// - Returns: The created relationship
    func acceptPartnerInvitation(invitationID: String) async throws -> Relationship {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw RelationshipError.userNotAuthenticated
        }
        
        // Get the invitation
        let invitationRef = invitationsCollection.document(invitationID)
        let invitationDoc = try await invitationRef.getDocument()
        
        guard invitationDoc.exists, var invitation = try? invitationDoc.data(as: PartnerInvitation.self) else {
            throw RelationshipError.invitationNotFound
        }
        
        // Verify this invitation is for the current user
        guard let currentUserEmail = Auth.auth().currentUser?.email, 
              currentUserEmail.lowercased() == invitation.recipientEmail.lowercased() else {
            throw RelationshipError.notAuthorized
        }
        
        // Check if user already has a relationship
        if let _ = try await getCurrentUserRelationship() {
            throw RelationshipError.userAlreadyInRelationship
        }
        
        // Create relationship
        var relationship = Relationship(
            initiatorID: invitation.senderID,
            partnerID: currentUserID
        )
        relationship.status = .active
        relationship.establishedDate = Date()
        
        // Save relationship
        let relationshipRef = try relationshipsCollection.addDocument(from: relationship)
        
        // Update invitation status
        invitation.accept(recipientID: currentUserID)
        try invitationRef.setData(from: invitation)
        
        // Send notification to initiator
        let currentUser = try await firestoreService.getUser(id: currentUserID)
        try await notificationService.sendPartnerInvitationAcceptedNotification(
            to: invitation.senderID,
            from: currentUser?.displayName ?? "Unknown",
            relationshipID: relationshipRef.documentID
        )
        
        // Return the created relationship with the ID
        var createdRelationship = relationship
        createdRelationship.id = relationshipRef.documentID
        return createdRelationship
    }
    
    /// Decline a partner invitation
    /// - Parameter invitationID: ID of the invitation to decline
    func declinePartnerInvitation(invitationID: String) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw RelationshipError.userNotAuthenticated
        }
        
        // Get the invitation
        let invitationRef = invitationsCollection.document(invitationID)
        let invitationDoc = try await invitationRef.getDocument()
        
        guard invitationDoc.exists, var invitation = try? invitationDoc.data(as: PartnerInvitation.self) else {
            throw RelationshipError.invitationNotFound
        }
        
        // Verify this invitation is for the current user
        guard let currentUserEmail = Auth.auth().currentUser?.email,
              currentUserEmail.lowercased() == invitation.recipientEmail.lowercased() else {
            throw RelationshipError.notAuthorized
        }
        
        // Update invitation status
        invitation.decline()
        try invitationRef.setData(from: invitation)
        
        // Send notification to initiator
        let currentUser = try await firestoreService.getUser(id: currentUserID)
        try await notificationService.sendPartnerInvitationDeclinedNotification(
            to: invitation.senderID,
            from: currentUser?.displayName ?? "Unknown"
        )
    }
    
    /// Cancel a partner invitation that the current user sent
    /// - Parameter invitationID: ID of the invitation to cancel
    func cancelPartnerInvitation(invitationID: String) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw RelationshipError.userNotAuthenticated
        }
        
        // Get the invitation
        let invitationRef = invitationsCollection.document(invitationID)
        let invitationDoc = try await invitationRef.getDocument()
        
        guard invitationDoc.exists, var invitation = try? invitationDoc.data(as: PartnerInvitation.self) else {
            throw RelationshipError.invitationNotFound
        }
        
        // Verify the current user is the sender
        guard invitation.senderID == currentUserID else {
            throw RelationshipError.notAuthorized
        }
        
        // Update invitation status
        invitation.cancel()
        try invitationRef.setData(from: invitation)
    }
    
    /// Get pending invitation for the current user
    /// - Returns: The pending invitation if any
    func getPendingPartnerInvitation() async throws -> PartnerInvitation? {
        guard let currentUser = Auth.auth().currentUser else {
            throw RelationshipError.userNotAuthenticated
        }
        
        let query = invitationsCollection
            .whereField("recipientEmail", isEqualTo: currentUser.email?.lowercased() ?? "")
            .whereField("status", isEqualTo: PartnerInvitationStatus.pending.rawValue)
        
        let snapshot = try await query.getDocuments()
        
        if let doc = snapshot.documents.first {
            return try doc.data(as: PartnerInvitation.self)
        }
        
        return nil
    }
    
    /// Get all pending invitations sent by the current user
    /// - Returns: Array of pending invitations
    func getSentPendingInvitations() async throws -> [PartnerInvitation] {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw RelationshipError.userNotAuthenticated
        }
        
        let query = invitationsCollection
            .whereField("senderID", isEqualTo: currentUserID)
            .whereField("status", isEqualTo: PartnerInvitationStatus.pending.rawValue)
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: PartnerInvitation.self)
        }
    }
    
    /// Terminate a relationship between partners
    /// - Parameter relationshipID: ID of the relationship to terminate
    func terminateRelationship(relationshipID: String) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw RelationshipError.userNotAuthenticated
        }
        
        // Get the relationship
        let relationshipRef = relationshipsCollection.document(relationshipID)
        let relationshipDoc = try await relationshipRef.getDocument()
        
        guard relationshipDoc.exists, var relationship = try? relationshipDoc.data(as: Relationship.self) else {
            throw RelationshipError.relationshipNotFound
        }
        
        // Verify the current user is part of the relationship
        guard relationship.includesUser(userID: currentUserID) else {
            throw RelationshipError.notAuthorized
        }
        
        // Update relationship status
        relationship.status = .terminated
        relationship.updatedDate = Date()
        try relationshipRef.setData(from: relationship)
        
        // Notify the partner
        let partnerID = relationship.getPartnerID(for: currentUserID)!
        let currentUser = try await firestoreService.getUser(id: currentUserID)
        try await notificationService.sendRelationshipTerminatedNotification(
            to: partnerID,
            from: currentUser?.displayName ?? "Unknown"
        )
    }
    
    /// Get all active relationships
    /// - Returns: Array of active relationships
    func getAllRelationships() async throws -> [Relationship] {
        let query = relationshipsCollection
            .whereField("status", isEqualTo: RelationshipStatus.active.rawValue)
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? document.data(as: Relationship.self)
        }
    }
    
    /// Get a relationship for a specific user
    /// - Parameter userID: The user ID to look for
    /// - Returns: The user's relationship if found
    func getRelationshipForUser(userID: String) async throws -> Relationship {
        let query = relationshipsCollection
            .whereFilter(Filter.orFilter([
                Filter.whereField("initiatorID", isEqualTo: userID),
                Filter.whereField("partnerID", isEqualTo: userID)
            ]))
            .whereField("status", isEqualTo: RelationshipStatus.active.rawValue)
        
        let snapshot = try await query.getDocuments()
        
        guard let document = snapshot.documents.first else {
            throw RelationshipError.relationshipNotFound
        }
        
        return try document.data(as: Relationship.self)
    }
    
    /// Get users by email
    /// - Parameter email: Email address to search for
    /// - Returns: Array of users with the specified email
    func getUsersByEmail(email: String) async throws -> [AppUser] {
        let usersRef = db.collection("users")
        let query = usersRef.whereField("email", isEqualTo: email.lowercased())
        
        let querySnapshot = try await query.getDocuments()
        return querySnapshot.documents.compactMap { try? $0.data(as: AppUser.self) }
    }
    
    /// Create a direct relationship between two users
    /// - Parameter relationship: The relationship to create
    /// - Returns: The created relationship
    func createRelationship(_ relationship: Relationship) async throws -> Relationship {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw RelationshipError.userNotAuthenticated
        }
        
        // Ensure the current user is part of this relationship
        guard relationship.initiatorID == currentUserID || relationship.partnerID == currentUserID else {
            throw RelationshipError.notAuthorized
        }
        
        // Verify neither user has an existing relationship
        let userIDs = [relationship.initiatorID, relationship.partnerID]
        
        for userID in userIDs {
            if let _ = try await getUserRelationship(userID: userID) {
                throw RelationshipError.userAlreadyInRelationship
            }
        }
        
        // Create an active relationship
        var activeRelationship = relationship
        activeRelationship.status = .active
        activeRelationship.establishedDate = Date()
        
        // Save to Firestore
        let relationshipRef = try relationshipsCollection.addDocument(from: activeRelationship)
        
        // Get user names for notifications
        let initiator = try await firestoreService.getUser(id: relationship.initiatorID)
        let partner = try await firestoreService.getUser(id: relationship.partnerID)
        
        // Send notifications to both users
        try await notificationService.sendRelationshipCreatedNotification(
            to: relationship.initiatorID,
            partnerName: partner?.displayName ?? "Unknown"
        )
        
        try await notificationService.sendRelationshipCreatedNotification(
            to: relationship.partnerID,
            partnerName: initiator?.displayName ?? "Unknown"
        )
        
        // Return the created relationship with the ID
        var createdRelationship = activeRelationship
        createdRelationship.id = relationshipRef.documentID
        return createdRelationship
    }
    
    /// Get relationship for a specific user by their ID
    /// - Parameter userID: ID of the user to check
    /// - Returns: The relationship if exists, or nil
    func getUserRelationship(userID: String) async throws -> Relationship? {
        // Query for relationships containing the user ID (either as initiator or partner)
        let query = relationshipsCollection
            .whereFilter(Filter.orFilter([
                Filter.whereField("initiatorID", isEqualTo: userID),
                Filter.whereField("partnerID", isEqualTo: userID)
            ]))
            .whereField("status", isNotEqualTo: RelationshipStatus.terminated.rawValue)
        
        let snapshot = try await query.getDocuments()
        
        if let document = snapshot.documents.first {
            return try? document.data(as: Relationship.self)
        }
        
        return nil
    }
    
    // MARK: - Invitation Methods
    
    /// Get an invitation by its unique invitation code
    /// - Parameter code: The invitation code to look up
    /// - Returns: The invitation if found, nil otherwise
    func getInvitationByCode(_ code: String) async throws -> PartnerInvitation? {
        let query = invitationsCollection.whereField("invitationCode", isEqualTo: code)
        let snapshot = try await query.getDocuments()
        
        if let document = snapshot.documents.first {
            return try document.data(as: PartnerInvitation.self)
        }
        
        return nil
    }
    
    /// Accept a partner invitation using its code
    /// - Parameter code: The invitation code to accept
    /// - Returns: The created relationship
    func acceptPartnerInvitationByCode(_ code: String) async throws -> Relationship {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw RelationshipError.userNotAuthenticated
        }
        
        // Find the invitation by code
        let query = invitationsCollection.whereField("invitationCode", isEqualTo: code)
        let snapshot = try await query.getDocuments()
        
        guard let document = snapshot.documents.first,
              var invitation = try? document.data(as: PartnerInvitation.self) else {
            throw RelationshipError.invitationNotFound
        }
        
        // Check if the invitation is still pending
        guard invitation.status == .pending else {
            throw RelationshipError.invitationNotFound
        }
        
        // Check if user already has a relationship
        if let _ = try await getCurrentUserRelationship() {
            throw RelationshipError.userAlreadyInRelationship
        }
        
        // Create relationship
        var relationship = Relationship(
            initiatorID: invitation.senderID,
            partnerID: currentUserID
        )
        relationship.status = .active
        relationship.establishedDate = Date()
        
        // Save relationship
        let relationshipRef = try relationshipsCollection.addDocument(from: relationship)
        
        // Update invitation status
        invitation.accept(recipientID: currentUserID)
        try invitationsCollection.document(document.documentID).setData(from: invitation)
        
        // If the user has an email that doesn't match the invitation, update the invitation
        if let userEmail = Auth.auth().currentUser?.email,
           userEmail != invitation.recipientEmail {
            try await invitationsCollection.document(document.documentID).updateData([
                "recipientEmail": userEmail
            ])
        }
        
        // Send notification to initiator
        let currentUser = try await firestoreService.getUser(id: currentUserID)
        try await notificationService.sendPartnerInvitationAcceptedNotification(
            to: invitation.senderID,
            from: currentUser?.displayName ?? "Unknown",
            relationshipID: relationshipRef.documentID
        )
        
        // Return the created relationship with the ID
        var createdRelationship = relationship
        createdRelationship.id = relationshipRef.documentID
        return createdRelationship
    }
    
    /// Invite a partner by email
    /// - Parameters:
    ///   - partnerEmail: The email address of the partner to invite
    ///   - message: Optional personal message
    /// - Returns: The created invitation
    func invitePartner(partnerEmail: String, message: String? = nil) async throws -> PartnerInvitation {
        // ... existing code ...
    }
} 