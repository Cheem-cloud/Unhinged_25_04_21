import Foundation
import Firebase
import FirebaseFirestore

/// Service for managing couple referrals
class ReferralService {
    /// Shared instance (singleton)
    static let shared = ReferralService()
    
    /// Firestore instance
    private let db = Firestore.firestore()
    
    /// Firestore service
    private let firestoreService = FirestoreService.shared
    
    /// Collection name for referrals
    private let referralsCollection = "coupleReferrals"
    
    /// Initialize the service
    private init() {}
    
    /// Create a new couple referral
    /// - Parameters:
    ///   - referringRelationshipID: The relationship ID of the referring couple
    ///   - inviteeEmail: Email of the person being invited
    ///   - inviteeName: Name of the person being invited (optional)
    ///   - inviteePartnerEmail: Email of the partner being invited (optional)
    ///   - inviteePartnerName: Name of the partner being invited (optional)
    ///   - message: Custom message from the referring couple (optional)
    ///   - includesPerks: Whether to include special perks (optional)
    /// - Returns: The created referral
    func createReferral(
        referringRelationshipID: String,
        inviteeEmail: String,
        inviteeName: String? = nil,
        inviteePartnerEmail: String? = nil,
        inviteePartnerName: String? = nil,
        message: String? = nil,
        includesPerks: Bool = false
    ) async throws -> CoupleReferral {
        // Create the referral object
        var referral = CoupleReferral(
            referringRelationshipID: referringRelationshipID,
            inviteeEmail: inviteeEmail
        )
        
        // Set optional fields
        referral.inviteeName = inviteeName
        referral.inviteePartnerEmail = inviteePartnerEmail
        referral.inviteePartnerName = inviteePartnerName
        referral.message = message
        referral.includesPerks = includesPerks
        
        // Save to Firestore
        let docRef = try db.collection(referralsCollection).addDocument(from: referral)
        referral.id = docRef.documentID
        
        return referral
    }
    
    /// Get referrals created by a relationship
    /// - Parameters:
    ///   - relationshipID: The relationship ID of the referring couple
    ///   - status: Filter by referral status (optional)
    /// - Returns: Array of referrals
    func getReferralsByRelationship(relationshipID: String, status: CoupleReferralStatus? = nil) async throws -> [CoupleReferral] {
        var query: Query = db.collection(referralsCollection)
            .whereField("referringRelationshipID", isEqualTo: relationshipID)
        
        // Filter by status if provided
        if let status = status {
            query = query.whereField("status", isEqualTo: status.rawValue)
        }
        
        // Sort by creation date, newest first
        query = query.order(by: "createdAt", descending: true)
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { document in
            CoupleReferral.fromFirestore(document)
        }
    }
    
    /// Find a referral by its unique code
    /// - Parameter code: The referral code
    /// - Returns: The referral if found, nil otherwise
    func findReferralByCode(_ code: String) async throws -> CoupleReferral? {
        let query = db.collection(referralsCollection)
            .whereField("referralCode", isEqualTo: code)
            .limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        
        if let document = snapshot.documents.first {
            return CoupleReferral.fromFirestore(document)
        }
        
        return nil
    }
    
    /// Update a referral's status
    /// - Parameters:
    ///   - referralID: The ID of the referral to update
    ///   - status: The new status
    func updateReferralStatus(referralID: String, status: CoupleReferralStatus) async throws {
        let docRef = db.collection(referralsCollection).document(referralID)
        
        try await docRef.updateData([
            "status": status.rawValue,
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    /// Set the referred relationship ID for a referral
    /// - Parameters:
    ///   - referralID: The ID of the referral to update
    ///   - relationshipID: The relationship ID of the new couple
    func setReferredRelationship(referralID: String, relationshipID: String) async throws {
        let docRef = db.collection(referralsCollection).document(referralID)
        
        try await docRef.updateData([
            "referredRelationshipID": relationshipID,
            "status": CoupleReferralStatus.accepted.rawValue,
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    /// Delete a referral
    /// - Parameter referralID: The ID of the referral to delete
    func deleteReferral(referralID: String) async throws {
        let docRef = db.collection(referralsCollection).document(referralID)
        try await docRef.delete()
    }
    
    /// Get a referral by ID
    /// - Parameter referralID: The ID of the referral
    /// - Returns: The referral if found, nil otherwise
    func getReferral(referralID: String) async throws -> CoupleReferral? {
        let docRef = db.collection(referralsCollection).document(referralID)
        let document = try await docRef.getDocument()
        
        return CoupleReferral.fromFirestore(document)
    }
    
    /// Check if an email has already been invited
    /// - Parameter email: The email to check
    /// - Returns: Whether the email has pending invitations
    func hasActiveInvitation(email: String) async throws -> Bool {
        let query = db.collection(referralsCollection)
            .whereField("inviteeEmail", isEqualTo: email)
            .whereField("status", isEqualTo: CoupleReferralStatus.pending.rawValue)
            .limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        return !snapshot.documents.isEmpty
    }
    
    /// Find a referral for a specific email
    /// - Parameters:
    ///   - email: The email to check
    ///   - status: The referral status to filter by (optional)
    /// - Returns: The referral if found, nil otherwise
    func findReferralForEmail(email: String, status: CoupleReferralStatus? = nil) async throws -> CoupleReferral? {
        var query: Query = db.collection(referralsCollection)
            .whereField("inviteeEmail", isEqualTo: email)
        
        // Filter by status if provided
        if let status = status {
            query = query.whereField("status", isEqualTo: status.rawValue)
        }
        
        query = query.limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        
        if let document = snapshot.documents.first {
            return CoupleReferral.fromFirestore(document)
        }
        
        return nil
    }
    
    /// Get statistics for a relationship's referrals
    /// - Parameter relationshipID: The relationship ID
    /// - Returns: Dictionary with referral statistics
    func getReferralStats(relationshipID: String) async throws -> [String: Int] {
        let referrals = try await getReferralsByRelationship(relationshipID: relationshipID)
        
        var stats: [String: Int] = [
            "total": referrals.count,
            "pending": 0,
            "accepted": 0,
            "expired": 0,
            "revoked": 0
        ]
        
        // Count by status
        for referral in referrals {
            switch referral.status {
            case .pending:
                stats["pending"] = (stats["pending"] ?? 0) + 1
            case .accepted:
                stats["accepted"] = (stats["accepted"] ?? 0) + 1
            case .expired:
                stats["expired"] = (stats["expired"] ?? 0) + 1
            case .revoked:
                stats["revoked"] = (stats["revoked"] ?? 0) + 1
            }
        }
        
        return stats
    }
} 