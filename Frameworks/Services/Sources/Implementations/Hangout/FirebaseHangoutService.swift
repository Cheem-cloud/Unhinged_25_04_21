import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth


/// Firebase implementation of the HangoutService protocol
public class FirebaseHangoutService: HangoutService {
    /// Firestore database reference
    private let db = Firestore.firestore()
    
    /// Firestore collection for hangouts
    private let hangoutsCollection = "hangouts"
    
    public init() {
        print("📱 FirebaseHangoutService initialized")
    }
    
    public func getHangout(id: String) async throws -> Hangout? {
        let documentSnapshot = try await db.collection(hangoutsCollection).document(id).getDocument()
        
        guard documentSnapshot.exists else {
            return nil
        }
        
        let data = documentSnapshot.data() ?? [:]
        var hangout = try FirestoreDecoder().decode(Hangout.self, from: data)
        
        // Ensure the ID is set
        if hangout.id == nil || hangout.id?.isEmpty == true {
            hangout.id = id
        }
        
        return hangout
    }
    
    public func getHangoutsForUser(userId: String) async throws -> [Hangout] {
        // Query hangouts where user is creator
        let creatorQuery = db.collection(hangoutsCollection)
            .whereField("creatorID", isEqualTo: userId)
        
        // Query hangouts where user is participant
        let participantQuery = db.collection(hangoutsCollection)
            .whereField("participants", arrayContains: ["userID": userId])
        
        // Execute both queries
        let creatorSnapshot = try await creatorQuery.getDocuments()
        let participantSnapshot = try await participantQuery.getDocuments()
        
        // Combine results and remove duplicates
        var hangoutsDict: [String: Hangout] = [:]
        
        // Process creator hangouts
        for document in creatorSnapshot.documents {
            let data = document.data()
            var hangout = try FirestoreDecoder().decode(Hangout.self, from: data)
            if hangout.id == nil || hangout.id?.isEmpty == true {
                hangout.id = document.documentID
            }
            hangoutsDict[document.documentID] = hangout
        }
        
        // Process participant hangouts
        for document in participantSnapshot.documents {
            if hangoutsDict[document.documentID] != nil {
                continue // Skip duplicates
            }
            
            let data = document.data()
            var hangout = try FirestoreDecoder().decode(Hangout.self, from: data)
            if hangout.id == nil || hangout.id?.isEmpty == true {
                hangout.id = document.documentID
            }
            hangoutsDict[document.documentID] = hangout
        }
        
        return Array(hangoutsDict.values)
    }
    
    public func getPendingHangouts(forUserID userID: String) async throws -> [Hangout] {
        // Query hangouts where user is a participant with pending status
        let query = db.collection(hangoutsCollection)
            .whereField("participants", arrayContains: [
                "userID": userID,
                "status": HangoutParticipantStatus.pending.rawValue
            ])
        
        let snapshot = try await query.getDocuments()
        
        return try snapshot.documents.compactMap { document in
            let data = document.data()
            var hangout = try FirestoreDecoder().decode(Hangout.self, from: data)
            if hangout.id == nil || hangout.id?.isEmpty == true {
                hangout.id = document.documentID
            }
            return hangout
        }
    }
    
    public func getAcceptedHangouts(forUserID userID: String) async throws -> [Hangout] {
        // Query hangouts where user is a participant with accepted status
        let query = db.collection(hangoutsCollection)
            .whereField("participants", arrayContains: [
                "userID": userID,
                "status": HangoutParticipantStatus.accepted.rawValue
            ])
        
        let snapshot = try await query.getDocuments()
        
        return try snapshot.documents.compactMap { document in
            let data = document.data()
            var hangout = try FirestoreDecoder().decode(Hangout.self, from: data)
            if hangout.id == nil || hangout.id?.isEmpty == true {
                hangout.id = document.documentID
            }
            return hangout
        }
    }
    
    public func createHangout(_ hangout: Hangout) async throws -> String {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseHangoutService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
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
        
        // Generate a new document ID
        let newDocRef = db.collection(hangoutsCollection).document()
        
        // Set the ID in the hangout object
        newHangout.id = newDocRef.documentID
        
        // Encode and save the hangout
        let hangoutData = try FirestoreEncoder().encode(newHangout) as? [String: Any] ?? [:]
        try await newDocRef.setData(hangoutData)
        
        return newDocRef.documentID
    }
    
    public func updateHangout(_ hangout: Hangout) async throws {
        guard let hangoutID = hangout.id, !hangoutID.isEmpty else {
            throw NSError(domain: "FirebaseHangoutService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Hangout ID is required for updates"])
        }
        
        // Verify current user is authorized to update this hangout
        try await validateUserCanModifyHangout(hangoutID: hangoutID)
        
        // Set updated timestamp
        var updatedHangout = hangout
        updatedHangout.updatedDate = Date()
        
        // Update the hangout in Firestore
        let hangoutData = try FirestoreEncoder().encode(updatedHangout) as? [String: Any] ?? [:]
        try await db.collection(hangoutsCollection).document(hangoutID).updateData(hangoutData)
    }
    
    public func deleteHangout(id: String) async throws {
        // Verify current user is authorized to delete this hangout
        try await validateUserCanModifyHangout(hangoutID: id)
        
        // Delete the hangout
        try await db.collection(hangoutsCollection).document(id).delete()
    }
    
    public func acceptHangout(hangoutID: String) async throws -> Hangout {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseHangoutService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the hangout
        guard var hangout = try await getHangout(id: hangoutID) else {
            throw NSError(domain: "FirebaseHangoutService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Hangout not found"])
        }
        
        // Update participant status
        if var participants = hangout.participants {
            if let index = participants.firstIndex(where: { $0.userID == currentUserID }) {
                participants[index].status = .accepted
                hangout.participants = participants
                
                // Update the hangout
                try await updateHangout(hangout)
                return hangout
            } else {
                throw NSError(domain: "FirebaseHangoutService", code: 400, userInfo: [NSLocalizedDescriptionKey: "User is not a participant in this hangout"])
            }
        } else {
            throw NSError(domain: "FirebaseHangoutService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Hangout has no participants"])
        }
    }
    
    public func declineHangout(hangoutID: String) async throws -> Hangout {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseHangoutService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the hangout
        guard var hangout = try await getHangout(id: hangoutID) else {
            throw NSError(domain: "FirebaseHangoutService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Hangout not found"])
        }
        
        // Update participant status
        if var participants = hangout.participants {
            if let index = participants.firstIndex(where: { $0.userID == currentUserID }) {
                participants[index].status = .declined
                hangout.participants = participants
                
                // Update the hangout
                try await updateHangout(hangout)
                return hangout
            } else {
                throw NSError(domain: "FirebaseHangoutService", code: 400, userInfo: [NSLocalizedDescriptionKey: "User is not a participant in this hangout"])
            }
        } else {
            throw NSError(domain: "FirebaseHangoutService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Hangout has no participants"])
        }
    }
    
    public func cancelHangout(hangoutID: String) async throws -> Hangout {
        // Get the hangout
        guard var hangout = try await getHangout(id: hangoutID) else {
            throw NSError(domain: "FirebaseHangoutService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Hangout not found"])
        }
        
        // Verify current user is authorized to cancel this hangout
        try await validateUserCanModifyHangout(hangoutID: hangoutID)
        
        // Set hangout status to cancelled
        hangout.status = .cancelled
        
        // Update the hangout
        try await updateHangout(hangout)
        return hangout
    }
    
    // MARK: - Private Helper Methods
    
    /// Validate that the current user can modify a hangout
    /// - Parameter hangoutID: The hangout ID to validate
    private func validateUserCanModifyHangout(hangoutID: String) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseHangoutService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the hangout
        guard let hangout = try await getHangout(id: hangoutID) else {
            throw NSError(domain: "FirebaseHangoutService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Hangout not found"])
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
        
        throw NSError(domain: "FirebaseHangoutService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You don't have permission to modify this hangout"])
    }
} 