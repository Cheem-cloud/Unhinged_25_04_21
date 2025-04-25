import Foundation

/// Protocol for hangout management service
public protocol HangoutService {
    /// Get a hangout by ID
    /// - Parameter id: The hangout ID
    /// - Returns: The hangout if found
    func getHangout(id: String) async throws -> Hangout?
    
    /// Create a new hangout
    /// - Parameter hangout: The hangout to create
    /// - Returns: The ID of the created hangout
    func createHangout(_ hangout: Hangout) async throws -> String
    
    /// Update an existing hangout
    /// - Parameter hangout: The hangout to update
    func updateHangout(_ hangout: Hangout) async throws
    
    /// Delete a hangout
    /// - Parameter id: The hangout ID
    func deleteHangout(id: String) async throws
    
    /// Get all hangouts for the current user
    /// - Returns: Array of hangouts
    func getCurrentUserHangouts() async throws -> [Hangout]
    
    /// Get hangouts for a user
    /// - Parameter userID: The user ID
    /// - Returns: Array of hangouts
    func getHangoutsForUser(userID: String) async throws -> [Hangout]
    
    /// Get hangouts for a relationship
    /// - Parameter relationshipID: The relationship ID
    /// - Returns: Array of hangouts
    func getHangoutsForRelationship(relationshipID: String) async throws -> [Hangout]
    
    /// Accept a hangout invitation
    /// - Parameter id: The hangout ID
    func acceptHangout(id: String) async throws
    
    /// Decline a hangout invitation
    /// - Parameter id: The hangout ID
    func declineHangout(id: String) async throws
    
    /// Cancel a hangout
    /// - Parameter id: The hangout ID
    func cancelHangout(id: String) async throws
    
    /// Complete a hangout
    /// - Parameter id: The hangout ID
    func completeHangout(id: String) async throws
}

// Forward declaration of Hangout type for the protocol
// (Actual implementation should be in the module that implements this protocol)
public struct Hangout: Identifiable {
    public var id: String?
} 