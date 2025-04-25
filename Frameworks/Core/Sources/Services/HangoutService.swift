import Foundation

/// Protocol for services that manage hangouts
public protocol HangoutService: CRUDService {
    /// The type of entity being managed
    associatedtype Entity = Hangout
    
    /// Get all hangouts for a user
    /// - Parameter userID: ID of the user
    /// - Returns: Array of hangouts
    func getHangouts(forUserID userID: String) async throws -> [Hangout]
    
    /// Get pending hangouts for a user
    /// - Parameter userID: ID of the user
    /// - Returns: Array of pending hangouts
    func getPendingHangouts(forUserID userID: String) async throws -> [Hangout]
    
    /// Get accepted hangouts for a user
    /// - Parameter userID: ID of the user
    /// - Returns: Array of accepted hangouts
    func getAcceptedHangouts(forUserID userID: String) async throws -> [Hangout]
    
    /// Create a new hangout
    /// - Parameter hangout: Hangout to create
    /// - Returns: The created hangout
    func createHangout(_ hangout: Hangout) async throws -> Hangout
    
    /// Update a hangout
    /// - Parameter hangout: Hangout to update
    /// - Returns: The updated hangout
    func updateHangout(_ hangout: Hangout) async throws -> Hangout
    
    /// Accept a hangout invitation
    /// - Parameter hangoutID: ID of the hangout to accept
    /// - Returns: The updated hangout
    func acceptHangout(hangoutID: String) async throws -> Hangout
    
    /// Decline a hangout invitation
    /// - Parameter hangoutID: ID of the hangout to decline
    /// - Returns: The updated hangout
    func declineHangout(hangoutID: String) async throws -> Hangout
    
    /// Cancel a hangout
    /// - Parameter hangoutID: ID of the hangout to cancel
    /// - Returns: The updated hangout
    func cancelHangout(hangoutID: String) async throws -> Hangout
    
    /// Complete a hangout
    /// - Parameter hangoutID: ID of the hangout to complete
    /// - Returns: The updated hangout
    func completeHangout(hangoutID: String) async throws -> Hangout
} 