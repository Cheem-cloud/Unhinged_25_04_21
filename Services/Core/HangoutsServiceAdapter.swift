import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Service for managing hangouts
class HangoutsServiceAdapter {
    // MARK: - Properties
    
    /// CRUD service for database operations
    private let crudService: CRUDService
    
    /// Firestore collection for hangouts
    private let hangoutsCollection = "hangouts"
    
    // MARK: - Initialization
    
    init(crudService: CRUDService = ServiceManager.shared.getService(CRUDService.self)) {
        self.crudService = crudService
        print("📱 HangoutsServiceAdapter initialized")
    }
    
    // MARK: - Public Methods
    
    /// Create a new hangout
    /// - Parameter hangout: The hangout to create
    /// - Returns: The ID of the created hangout
    func createHangout(_ hangout: Hangout) async throws -> String {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw ServiceError.unauthorized("User is not authenticated")
        }
        
        // Create a copy with creation metadata
        var newHangout = hangout
        newHangout.creatorID = currentUserID
        newHangout.createdDate = Date()
        newHangout.updatedDate = Date()
        
        // Add the creator as a participant
        if newHangout.participants == nil {
            newHangout.participants = []
        }
        newHangout.participants?.append(HangoutParticipant(userID: currentUserID, status: .accepted))
        
        // Add invitees as participants with pending status
        if let invitees = newHangout.invitees {
            for invitee in invitees {
                newHangout.participants?.append(HangoutParticipant(userID: invitee, status: .pending))
            }
        }
        
        // Encode and save the hangout
        var hangoutData = try FirestoreEncoder().encode(newHangout) as? [String: Any] ?? [:]
        hangoutData["collection"] = hangoutsCollection
        
        let path = try await crudService.create(hangoutData)
        
        // Extract the ID from the path
        let components = path.components(separatedBy: "/")
        guard components.count >= 2 else {
            throw ServiceError.operationFailed("Invalid path returned from create operation")
        }
        
        return components.last ?? ""
    }
    
    /// Get a hangout by ID
    /// - Parameter id: The hangout ID
    /// - Returns: The hangout if found, nil otherwise
    func getHangout(_ id: String) async throws -> Hangout? {
        let hangoutData = try await crudService.read("\(hangoutsCollection)/\(id)")
        
        guard let hangoutData = hangoutData else {
            return nil
        }
        
        var hangout = try FirestoreDecoder().decode(Hangout.self, from: hangoutData)
        if hangout.id == nil {
            hangout.id = id
        }
        
        return hangout
    }
    
    /// Update a hangout
    /// - Parameter hangout: The hangout to update
    func updateHangout(_ hangout: Hangout) async throws {
        guard let hangoutID = hangout.id else {
            throw ServiceError.invalidOperation("Hangout ID is required for updates")
        }
        
        // Verify current user is authorized to update this hangout
        try await validateUserCanModifyHangout(hangoutID: hangoutID)
        
        // Set updated timestamp
        var updatedHangout = hangout
        updatedHangout.updatedDate = Date()
        
        // Update the hangout in Firestore
        let hangoutData = try FirestoreEncoder().encode(updatedHangout) as? [String: Any] ?? [:]
        try await crudService.update("\(hangoutsCollection)/\(hangoutID)", with: hangoutData)
    }
    
    /// Delete a hangout
    /// - Parameter id: The ID of the hangout to delete
    func deleteHangout(_ id: String) async throws {
        // Verify current user is authorized to delete this hangout
        try await validateUserCanModifyHangout(hangoutID: id)
        
        // Delete the hangout
        try await crudService.delete("\(hangoutsCollection)/\(id)")
    }
    
    /// Get hangouts for a user
    /// - Parameter userId: The user ID
    /// - Returns: Array of hangouts
    func getHangoutsForUser(userId: String) async throws -> [Hangout] {
        // First, get hangouts where the user is the creator
        let creatorFilter: [String: Any] = [
            "collection": hangoutsCollection,
            "creatorID": userId
        ]
        
        let creatorResults = try await crudService.list(filter: creatorFilter)
        
        // Next, get hangouts where the user is a participant
        let participantFilter: [String: Any] = [
            "collection": hangoutsCollection,
            "participants": [
                "arrayContains": [
                    "userID": userId
                ]
            ]
        ]
        
        let participantResults = try await crudService.list(filter: participantFilter)
        
        // Combine the results and convert to Hangout objects
        let combinedResults = Set(creatorResults + participantResults)
        var hangouts: [Hangout] = []
        
        for hangoutData in combinedResults {
            var hangout = try FirestoreDecoder().decode(Hangout.self, from: hangoutData)
            if hangout.id == nil, let id = hangoutData["id"] as? String {
                hangout.id = id
            }
            hangouts.append(hangout)
        }
        
        return hangouts
    }
    
    // MARK: - Private Helper Methods
    
    /// Validate that the current user can modify a hangout
    /// - Parameter hangoutID: The hangout ID to validate
    private func validateUserCanModifyHangout(hangoutID: String) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw ServiceError.unauthorized("User is not authenticated")
        }
        
        // Get the hangout
        guard let hangout = try await getHangout(hangoutID) else {
            throw ServiceError.notFound("Hangout not found")
        }
        
        // Check if user is creator
        if hangout.creatorID == currentUserID {
            return
        }
        
        // Or check if user is an accepted participant with admin rights
        if let participants = hangout.participants,
           let userParticipant = participants.first(where: { $0.userID == currentUserID }),
           userParticipant.status == .accepted,
           userParticipant.isAdmin {
            return
        }
        
        throw ServiceError.unauthorized("You don't have permission to modify this hangout")
    }
} 