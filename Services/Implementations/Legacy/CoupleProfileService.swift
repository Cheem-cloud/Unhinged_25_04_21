import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Service for managing couple profiles
class CoupleProfileService {
    // MARK: - Properties
    
    /// Firebase Firestore database
    private let db = Firestore.firestore()
    
    /// FirestoreService for reuse
    private let firestoreService = FirestoreService.shared
    
    /// RelationshipService for relationship operations
    private let relationshipService = RelationshipService()
    
    /// Firestore collection for couple profiles
    private var coupleProfilesCollection: CollectionReference {
        return db.collection("coupleProfiles")
    }
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Get the current user's couple profile
    /// - Returns: The couple profile if found, nil otherwise
    func getCurrentCoupleProfile() async throws -> CoupleProfile? {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw RelationshipError.userNotAuthenticated
        }
        
        // First get the user's relationship
        guard let relationship = try await relationshipService.getCurrentUserRelationship(),
              relationship.status == .active,
              let relationshipID = relationship.id else {
            // No active relationship, so no couple profile
            return nil
        }
        
        // Query for the couple profile with this relationship ID
        let query = coupleProfilesCollection
            .whereField("relationshipID", isEqualTo: relationshipID)
        
        let snapshot = try await query.getDocuments()
        
        if let doc = snapshot.documents.first {
            return try doc.data(as: CoupleProfile.self)
        }
        
        // No existing profile found, create a new one
        let partner = try await getPartnerForRelationship(relationship: relationship)
        let currentUser = try await firestoreService.getUser(id: currentUserID)
        
        // Generate display name from both partners
        let displayName = generateDisplayName(user1: currentUser?.displayName ?? "", user2: partner?.displayName ?? "")
        
        // Create a new couple profile
        let newProfile = CoupleProfile(relationshipID: relationshipID, displayName: displayName)
        let profileRef = try coupleProfilesCollection.addDocument(from: newProfile)
        
        // Return the created profile with the ID
        var createdProfile = newProfile
        createdProfile.id = profileRef.documentID
        return createdProfile
    }
    
    /// Update a couple profile
    /// - Parameter profile: The profile to update
    /// - Returns: The updated profile
    func updateCoupleProfile(_ profile: CoupleProfile) async throws -> CoupleProfile {
        guard let profileID = profile.id else {
            throw NSError(domain: "com.cheemhang.coupleProfile",
                          code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Profile ID is required for updates"])
        }
        
        // Make sure the user has permission to update this profile
        try await validateUserCanModifyProfile(profileID: profileID)
        
        // Create an updated copy with the current timestamp
        var updatedProfile = profile
        updatedProfile.updatedDate = Date()
        
        // Update the profile in Firestore
        try coupleProfilesCollection.document(profileID).setData(from: updatedProfile)
        
        return updatedProfile
    }
    
    /// Update the couple's metrics
    /// - Parameters:
    ///   - profileID: The couple profile ID
    ///   - updates: Dictionary of metric updates
    func updateMetrics(profileID: String, updates: [String: Any]) async throws {
        // Make sure the user has permission to update this profile
        try await validateUserCanModifyProfile(profileID: profileID)
        
        // Create the update dictionary with dotted paths
        var metricsUpdates = [String: Any]()
        for (key, value) in updates {
            metricsUpdates["metrics.\(key)"] = value
        }
        metricsUpdates["updatedDate"] = FieldValue.serverTimestamp()
        
        // Update the profile metrics
        try await coupleProfilesCollection.document(profileID).updateData(metricsUpdates)
    }
    
    /// Update the couple's availability preferences
    /// - Parameters:
    ///   - profileID: The couple profile ID
    ///   - availabilityPreferences: The new availability preferences
    func updateAvailabilityPreferences(profileID: String, availabilityPreferences: CoupleAvailabilityPreferences) async throws {
        // Make sure the user has permission to update this profile
        try await validateUserCanModifyProfile(profileID: profileID)
        
        // Update the profile
        try await coupleProfilesCollection.document(profileID).updateData([
            "availabilityPreferences": availabilityPreferences,
            "updatedDate": FieldValue.serverTimestamp()
        ])
    }
    
    /// Update the couple's privacy settings
    /// - Parameters:
    ///   - profileID: The couple profile ID
    ///   - privacySettings: The new privacy settings
    func updatePrivacySettings(profileID: String, privacySettings: CouplePrivacySettings) async throws {
        // Make sure the user has permission to update this profile
        try await validateUserCanModifyProfile(profileID: profileID)
        
        // Update the profile
        try await coupleProfilesCollection.document(profileID).updateData([
            "privacySettings": privacySettings,
            "updatedDate": FieldValue.serverTimestamp()
        ])
    }
    
    /// Set the couple's anniversary date
    /// - Parameters:
    ///   - profileID: The couple profile ID
    ///   - date: The anniversary date
    func setAnniversaryDate(profileID: String, date: Date) async throws {
        // Make sure the user has permission to update this profile
        try await validateUserCanModifyProfile(profileID: profileID)
        
        // Update the profile
        try await coupleProfilesCollection.document(profileID).updateData([
            "anniversaryDate": date,
            "updatedDate": FieldValue.serverTimestamp()
        ])
    }
    
    /// Update the couple's display name
    /// - Parameters:
    ///   - profileID: The couple profile ID
    ///   - displayName: The new display name
    func updateDisplayName(profileID: String, displayName: String) async throws {
        // Make sure the user has permission to update this profile
        try await validateUserCanModifyProfile(profileID: profileID)
        
        // Update the profile
        try await coupleProfilesCollection.document(profileID).updateData([
            "displayName": displayName,
            "updatedDate": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - Private Helper Methods
    
    /// Get the partner user for a relationship
    /// - Parameter relationship: The relationship
    /// - Returns: The partner user
    private func getPartnerForRelationship(relationship: Relationship) async throws -> AppUser? {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw RelationshipError.userNotAuthenticated
        }
        
        // Determine which user is the partner
        let partnerID = relationship.initiatorID == currentUserID ? relationship.partnerID : relationship.initiatorID
        
        // Get the partner user
        return try await firestoreService.getUser(id: partnerID)
    }
    
    /// Generate a display name for the couple
    /// - Parameters:
    ///   - user1: First user's name
    ///   - user2: Second user's name
    /// - Returns: Combined display name
    private func generateDisplayName(user1: String, user2: String) -> String {
        // Get the first names for a more friendly display
        let firstName1 = user1.components(separatedBy: " ").first ?? user1
        let firstName2 = user2.components(separatedBy: " ").first ?? user2
        
        return "\(firstName1) & \(firstName2)"
    }
    
    /// Validate that the current user can modify a profile
    /// - Parameter profileID: The profile ID to validate
    private func validateUserCanModifyProfile(profileID: String) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw RelationshipError.userNotAuthenticated
        }
        
        // Get the profile
        let profileDoc = try await coupleProfilesCollection.document(profileID).getDocument()
        
        guard profileDoc.exists, let profile = try? profileDoc.data(as: CoupleProfile.self) else {
            throw NSError(domain: "com.cheemhang.coupleProfile",
                          code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Couple profile not found"])
        }
        
        // Get the relationship to check if the user is part of it
        let relationship = try await relationshipService.getRelationship(id: profile.relationshipID)
        
        // Verify the user is part of this relationship
        guard relationship.includesUser(userID: currentUserID) else {
            throw NSError(domain: "com.cheemhang.coupleProfile",
                          code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "You don't have permission to modify this profile"])
        }
    }
} 