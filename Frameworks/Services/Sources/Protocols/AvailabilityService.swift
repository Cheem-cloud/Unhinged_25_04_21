import Foundation

/// Protocol for managing availability and time slots
public protocol AvailabilityService {
    /// Get couple availability for a relationship
    /// - Parameter relationshipID: ID of the relationship
    /// - Returns: The couple's availability preferences
    func getCoupleAvailability(for relationshipID: String) async throws -> CoupleAvailability
    
    /// Save couple availability
    /// - Parameters:
    ///   - availability: The availability settings to save
    ///   - relationshipID: ID of the relationship
    func saveCoupleAvailability(_ availability: CoupleAvailability, for relationshipID: String) async throws
    
    /// Get available time slots for a date range based on couple preferences
    /// - Parameters:
    ///   - relationshipID: ID of the relationship
    ///   - startDate: Start date for the search range
    ///   - endDate: End date for the search range
    ///   - duration: Duration in minutes for each slot
    /// - Returns: Dictionary of dates to available time slots
    func getAvailableTimeSlots(
        for relationshipID: String,
        startDate: Date,
        endDate: Date,
        duration: Int
    ) async throws -> [Date: [AvailabilityTimeSlot]]
    
    /// Get available time slots for a specific day
    /// - Parameters:
    ///   - relationshipID: ID of the relationship
    ///   - date: The date to check
    ///   - duration: Duration in minutes for each slot
    /// - Returns: Array of available time slots
    func getAvailableTimeSlotsForDay(
        for relationshipID: String,
        date: Date,
        duration: Int
    ) async throws -> [AvailabilityTimeSlot]
    
    /// Find mutual availability between users
    /// - Parameters:
    ///   - userIDs: IDs of the users to check
    ///   - startDate: Start date for the search range
    ///   - endDate: End date for the search range
    ///   - duration: Duration in minutes for each slot
    /// - Returns: Dictionary of dates to available time slots
    func findMutualAvailability(
        userIDs: [String],
        startDate: Date,
        endDate: Date,
        duration: Int
    ) async throws -> [Date: [AvailabilityTimeSlot]]
    
    /// Check if a specific time slot is available
    /// - Parameters:
    ///   - relationshipID: ID of the relationship
    ///   - startTime: Start time of the slot
    ///   - endTime: End time of the slot
    /// - Returns: Whether the time slot is available
    func isTimeSlotAvailable(
        for relationshipID: String,
        startTime: Date,
        endTime: Date
    ) async throws -> Bool
    
    /// Add a recurring commitment
    /// - Parameters:
    ///   - commitment: The commitment to add
    ///   - relationshipID: ID of the relationship
    func addRecurringCommitment(_ commitment: RecurringCommitment, for relationshipID: String) async throws
    
    /// Update a recurring commitment
    /// - Parameters:
    ///   - commitment: The commitment to update
    ///   - relationshipID: ID of the relationship
    func updateRecurringCommitment(_ commitment: RecurringCommitment, for relationshipID: String) async throws
    
    /// Delete a recurring commitment
    /// - Parameters:
    ///   - commitmentID: ID of the commitment to delete
    ///   - relationshipID: ID of the relationship
    func deleteRecurringCommitment(_ commitmentID: String, for relationshipID: String) async throws
    
    /// Get a user's availability preferences
    /// - Parameter userID: ID of the user
    /// - Returns: The user's availability preferences
    func getUserAvailabilityPreferences(for userID: String) async throws -> AvailabilityPreferences
    
    /// Save a user's availability preferences
    /// - Parameters:
    ///   - preferences: The preferences to save
    ///   - userID: ID of the user
    func saveUserAvailabilityPreferences(_ preferences: AvailabilityPreferences, for userID: String) async throws
} 