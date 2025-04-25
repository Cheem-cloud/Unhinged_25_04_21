import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth


/// Firebase implementation of the RelationshipService protocol
public class FirebaseRelationshipService: RelationshipService {
    /// Firebase Firestore database
    private let db = Firestore.firestore()
    
    /// Firebase Storage
    private let storage = Storage.storage()
    
    /// Collection reference for relationships
    private var relationshipsCollection: String = "relationships"
    
    /// Collection reference for partner invitations
    private var invitationsCollection: String = "partnerInvitations"
    
    /// NotificationService for sending notifications
    private let notificationService: NotificationService?
    
    /// UserService for user operations
    private let userService: UserService?
    
    public init(notificationService: NotificationService? = nil, userService: UserService? = nil) {
        self.notificationService = notificationService
        self.userService = userService
        print("📱 FirebaseRelationshipService initialized")
    }
    
    public func getCurrentUserRelationship() async throws -> Relationship? {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseRelationshipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        return try await getUserRelationship(userID: currentUserID)
    }
    
    public func getRelationship(id: String) async throws -> Relationship? {
        let document = try await db.collection(relationshipsCollection).document(id).getDocument()
        
        guard document.exists else {
            return nil
        }
        
        var relationship = try FirestoreDecoder().decode(Relationship.self, from: document.data() ?? [:])
        if relationship.id == nil {
            relationship.id = document.documentID
        }
        
        return relationship
    }
    
    public func getUserRelationship(userID: String) async throws -> Relationship? {
        // Query for relationships containing the user ID (either as initiator or partner)
        let query = db.collection(relationshipsCollection)
            .whereFilter(Filter.orFilter([
                Filter.whereField("initiatorID", isEqualTo: userID),
                Filter.whereField("partnerID", isEqualTo: userID)
            ]))
            .whereField("status", isNotEqualTo: RelationshipStatus.terminated.rawValue)
        
        let snapshot = try await query.getDocuments()
        
        if let document = snapshot.documents.first {
            var relationship = try FirestoreDecoder().decode(Relationship.self, from: document.data())
            if relationship.id == nil {
                relationship.id = document.documentID
            }
            return relationship
        }
        
        return nil
    }
    
    public func invitePartner(partnerEmail: String, message: String? = nil) async throws -> PartnerInvitation {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseRelationshipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Check if user already has a relationship
        if let _ = try await getCurrentUserRelationship() {
            throw NSError(domain: "FirebaseRelationshipService", code: 403, userInfo: [NSLocalizedDescriptionKey: "User already has an active relationship"])
        }
        
        // Can't invite yourself
        if let currentUserEmail = Auth.auth().currentUser?.email, currentUserEmail.lowercased() == partnerEmail.lowercased() {
            throw NSError(domain: "FirebaseRelationshipService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot invite yourself"])
        }
        
        // Check if the partner user already exists
        var partnerID: String? = nil
        
        // Use UserService if available, otherwise use direct Firestore query
        if let userService = userService {
            let users = try await userService.getUsersByEmail(email: partnerEmail)
            if let existingUser = users.first {
                partnerID = existingUser.id
                
                // Check if partner already has a relationship
                if let _ = try await getUserRelationship(userID: partnerID!) {
                    throw NSError(domain: "FirebaseRelationshipService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Partner already has an active relationship"])
                }
            }
        } else {
            // Direct Firestore query as fallback
            let usersQuery = db.collection("users").whereField("email", isEqualTo: partnerEmail.lowercased())
            let usersSnapshot = try await usersQuery.getDocuments()
            
            if let userDoc = usersSnapshot.documents.first {
                partnerID = userDoc.documentID
                
                // Check if partner already has a relationship
                if let _ = try await getUserRelationship(userID: partnerID!) {
                    throw NSError(domain: "FirebaseRelationshipService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Partner already has an active relationship"])
                }
            }
        }
        
        // Create the invitation
        let invitation = PartnerInvitation(
            senderID: currentUserID,
            recipientEmail: partnerEmail,
            message: message
        )
        
        // Save the invitation
        let invitationData = try FirestoreEncoder().encode(invitation) as? [String: Any] ?? [:]
        let invitationRef = try await db.collection(invitationsCollection).addDocument(data: invitationData)
        
        // If partner exists, send them a notification
        if let partnerID = partnerID, let notificationService = notificationService {
            var senderName = "Unknown"
            if let userService = userService {
                if let sender = try await userService.getUser(id: currentUserID) {
                    senderName = sender.displayName ?? "Unknown"
                }
            } else {
                // Fetch directly if no UserService
                let senderDoc = try await db.collection("users").document(currentUserID).getDocument()
                senderName = senderDoc.data()?["displayName"] as? String ?? "Unknown"
            }
            
            try await notificationService.sendPartnerInvitationNotification(
                to: partnerID,
                from: senderName,
                invitationID: invitationRef.documentID
            )
        }
        
        // Return the created invitation with the ID
        var createdInvitation = invitation
        createdInvitation.id = invitationRef.documentID
        return createdInvitation
    }
    
    public func acceptPartnerInvitation(invitationID: String) async throws -> Relationship {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseRelationshipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the invitation
        let invitationRef = db.collection(invitationsCollection).document(invitationID)
        let invitationDoc = try await invitationRef.getDocument()
        
        guard let invitationData = invitationDoc.data(), invitationDoc.exists else {
            throw NSError(domain: "FirebaseRelationshipService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invitation not found"])
        }
        
        var invitation = try FirestoreDecoder().decode(PartnerInvitation.self, from: invitationData)
        
        // Verify this invitation is for the current user
        guard let currentUserEmail = Auth.auth().currentUser?.email,
              currentUserEmail.lowercased() == invitation.recipientEmail.lowercased() else {
            throw NSError(domain: "FirebaseRelationshipService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to accept this invitation"])
        }
        
        // Check if user already has a relationship
        if let _ = try await getCurrentUserRelationship() {
            throw NSError(domain: "FirebaseRelationshipService", code: 403, userInfo: [NSLocalizedDescriptionKey: "User already has an active relationship"])
        }
        
        // Create relationship
        var relationship = Relationship(
            initiatorID: invitation.senderID,
            partnerID: currentUserID
        )
        relationship.status = .active
        relationship.establishedDate = Date()
        
        // Save relationship
        let relationshipData = try FirestoreEncoder().encode(relationship) as? [String: Any] ?? [:]
        let relationshipRef = try await db.collection(relationshipsCollection).addDocument(data: relationshipData)
        
        // Update invitation status
        invitation.accept(recipientID: currentUserID)
        let updatedInvitationData = try FirestoreEncoder().encode(invitation) as? [String: Any] ?? [:]
        try await invitationRef.setData(updatedInvitationData)
        
        // Send notification to initiator
        if let notificationService = notificationService {
            var currentUserName = "Unknown"
            if let userService = userService {
                if let currentUser = try await userService.getUser(id: currentUserID) {
                    currentUserName = currentUser.displayName ?? "Unknown"
                }
            } else {
                // Fetch directly if no UserService
                let currentUserDoc = try await db.collection("users").document(currentUserID).getDocument()
                currentUserName = currentUserDoc.data()?["displayName"] as? String ?? "Unknown"
            }
            
            try await notificationService.sendPartnerInvitationAcceptedNotification(
                to: invitation.senderID,
                from: currentUserName,
                relationshipID: relationshipRef.documentID
            )
        }
        
        // Return the created relationship with the ID
        var createdRelationship = relationship
        createdRelationship.id = relationshipRef.documentID
        return createdRelationship
    }
    
    public func declinePartnerInvitation(invitationID: String) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseRelationshipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the invitation
        let invitationRef = db.collection(invitationsCollection).document(invitationID)
        let invitationDoc = try await invitationRef.getDocument()
        
        guard let invitationData = invitationDoc.data(), invitationDoc.exists else {
            throw NSError(domain: "FirebaseRelationshipService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invitation not found"])
        }
        
        var invitation = try FirestoreDecoder().decode(PartnerInvitation.self, from: invitationData)
        
        // Verify this invitation is for the current user
        guard let currentUserEmail = Auth.auth().currentUser?.email,
              currentUserEmail.lowercased() == invitation.recipientEmail.lowercased() else {
            throw NSError(domain: "FirebaseRelationshipService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to decline this invitation"])
        }
        
        // Update invitation status
        invitation.decline()
        let updatedInvitationData = try FirestoreEncoder().encode(invitation) as? [String: Any] ?? [:]
        try await invitationRef.setData(updatedInvitationData)
        
        // Send notification to initiator
        if let notificationService = notificationService {
            var currentUserName = "Unknown"
            if let userService = userService {
                if let currentUser = try await userService.getUser(id: currentUserID) {
                    currentUserName = currentUser.displayName ?? "Unknown"
                }
            } else {
                // Fetch directly if no UserService
                let currentUserDoc = try await db.collection("users").document(currentUserID).getDocument()
                currentUserName = currentUserDoc.data()?["displayName"] as? String ?? "Unknown"
            }
            
            try await notificationService.sendPartnerInvitationDeclinedNotification(
                to: invitation.senderID,
                from: currentUserName
            )
        }
    }
    
    public func cancelPartnerInvitation(invitationID: String) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseRelationshipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the invitation
        let invitationRef = db.collection(invitationsCollection).document(invitationID)
        let invitationDoc = try await invitationRef.getDocument()
        
        guard let invitationData = invitationDoc.data(), invitationDoc.exists else {
            throw NSError(domain: "FirebaseRelationshipService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invitation not found"])
        }
        
        var invitation = try FirestoreDecoder().decode(PartnerInvitation.self, from: invitationData)
        
        // Verify the current user is the sender
        guard invitation.senderID == currentUserID else {
            throw NSError(domain: "FirebaseRelationshipService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to cancel this invitation"])
        }
        
        // Update invitation status
        invitation.cancel()
        let updatedInvitationData = try FirestoreEncoder().encode(invitation) as? [String: Any] ?? [:]
        try await invitationRef.setData(updatedInvitationData)
    }
    
    public func getPendingPartnerInvitation() async throws -> PartnerInvitation? {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseRelationshipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let query = db.collection(invitationsCollection)
            .whereField("recipientEmail", isEqualTo: currentUser.email?.lowercased() ?? "")
            .whereField("status", isEqualTo: PartnerInvitationStatus.pending.rawValue)
        
        let snapshot = try await query.getDocuments()
        
        if let doc = snapshot.documents.first {
            var invitation = try FirestoreDecoder().decode(PartnerInvitation.self, from: doc.data())
            if invitation.id == nil {
                invitation.id = doc.documentID
            }
            return invitation
        }
        
        return nil
    }
    
    public func getSentPendingInvitations() async throws -> [PartnerInvitation] {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseRelationshipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let query = db.collection(invitationsCollection)
            .whereField("senderID", isEqualTo: currentUserID)
            .whereField("status", isEqualTo: PartnerInvitationStatus.pending.rawValue)
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { doc -> PartnerInvitation? in
            do {
                var invitation = try FirestoreDecoder().decode(PartnerInvitation.self, from: doc.data())
                if invitation.id == nil {
                    invitation.id = doc.documentID
                }
                return invitation
            } catch {
                print("Error decoding invitation: \(error.localizedDescription)")
                return nil
            }
        }
    }
    
    public func terminateRelationship(relationshipID: String) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseRelationshipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the relationship
        let relationshipRef = db.collection(relationshipsCollection).document(relationshipID)
        let relationshipDoc = try await relationshipRef.getDocument()
        
        guard let relationshipData = relationshipDoc.data(), relationshipDoc.exists else {
            throw NSError(domain: "FirebaseRelationshipService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Relationship not found"])
        }
        
        var relationship = try FirestoreDecoder().decode(Relationship.self, from: relationshipData)
        
        // Verify the current user is part of the relationship
        guard relationship.includesUser(userID: currentUserID) else {
            throw NSError(domain: "FirebaseRelationshipService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to terminate this relationship"])
        }
        
        // Update relationship status
        relationship.status = .terminated
        relationship.updatedDate = Date()
        let updatedRelationshipData = try FirestoreEncoder().encode(relationship) as? [String: Any] ?? [:]
        try await relationshipRef.setData(updatedRelationshipData)
        
        // Notify the partner
        if let notificationService = notificationService {
            guard let partnerID = relationship.getPartnerID(for: currentUserID) else {
                return
            }
            
            var currentUserName = "Unknown"
            if let userService = userService {
                if let currentUser = try await userService.getUser(id: currentUserID) {
                    currentUserName = currentUser.displayName ?? "Unknown"
                }
            } else {
                // Fetch directly if no UserService
                let currentUserDoc = try await db.collection("users").document(currentUserID).getDocument()
                currentUserName = currentUserDoc.data()?["displayName"] as? String ?? "Unknown"
            }
            
            try await notificationService.sendRelationshipTerminatedNotification(
                to: partnerID,
                from: currentUserName
            )
        }
    }
    
    public func getInvitationByCode(_ code: String) async throws -> PartnerInvitation? {
        let query = db.collection(invitationsCollection).whereField("invitationCode", isEqualTo: code)
        let snapshot = try await query.getDocuments()
        
        if let document = snapshot.documents.first {
            var invitation = try FirestoreDecoder().decode(PartnerInvitation.self, from: document.data())
            if invitation.id == nil {
                invitation.id = document.documentID
            }
            return invitation
        }
        
        return nil
    }
    
    public func acceptPartnerInvitationByCode(_ code: String) async throws -> Relationship {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseRelationshipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Find the invitation by code
        let query = db.collection(invitationsCollection).whereField("invitationCode", isEqualTo: code)
        let snapshot = try await query.getDocuments()
        
        guard let document = snapshot.documents.first else {
            throw NSError(domain: "FirebaseRelationshipService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invitation not found"])
        }
        
        var invitation = try FirestoreDecoder().decode(PartnerInvitation.self, from: document.data())
        
        // Check if the invitation is still pending
        guard invitation.status == .pending else {
            throw NSError(domain: "FirebaseRelationshipService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invitation is no longer pending"])
        }
        
        // Check if user already has a relationship
        if let _ = try await getCurrentUserRelationship() {
            throw NSError(domain: "FirebaseRelationshipService", code: 403, userInfo: [NSLocalizedDescriptionKey: "User already has an active relationship"])
        }
        
        // Create relationship
        var relationship = Relationship(
            initiatorID: invitation.senderID,
            partnerID: currentUserID
        )
        relationship.status = .active
        relationship.establishedDate = Date()
        
        // Save relationship
        let relationshipData = try FirestoreEncoder().encode(relationship) as? [String: Any] ?? [:]
        let relationshipRef = try await db.collection(relationshipsCollection).addDocument(data: relationshipData)
        
        // Update invitation status
        invitation.accept(recipientID: currentUserID)
        let updatedInvitationData = try FirestoreEncoder().encode(invitation) as? [String: Any] ?? [:]
        try await db.collection(invitationsCollection).document(document.documentID).setData(updatedInvitationData)
        
        // If the user has an email that doesn't match the invitation, update the invitation
        if let userEmail = Auth.auth().currentUser?.email,
           userEmail != invitation.recipientEmail {
            try await db.collection(invitationsCollection).document(document.documentID).updateData([
                "recipientEmail": userEmail
            ])
        }
        
        // Send notification to initiator
        if let notificationService = notificationService {
            var currentUserName = "Unknown"
            if let userService = userService {
                if let currentUser = try await userService.getUser(id: currentUserID) {
                    currentUserName = currentUser.displayName ?? "Unknown"
                }
            } else {
                // Fetch directly if no UserService
                let currentUserDoc = try await db.collection("users").document(currentUserID).getDocument()
                currentUserName = currentUserDoc.data()?["displayName"] as? String ?? "Unknown"
            }
            
            try await notificationService.sendPartnerInvitationAcceptedNotification(
                to: invitation.senderID,
                from: currentUserName,
                relationshipID: relationshipRef.documentID
            )
        }
        
        // Return the created relationship with the ID
        var createdRelationship = relationship
        createdRelationship.id = relationshipRef.documentID
        return createdRelationship
    }
} 