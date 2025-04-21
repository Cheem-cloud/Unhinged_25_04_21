import Foundation

/// A service providing operations related to calendar functionality.
///
/// This service handles all calendar-related operations, including checking availability,
/// creating and managing calendar events, and handling authentication.
protocol CalendarOperationsService: CRUDService {
    
    /// Returns the calendar settings for the given user.
    /// - Parameter userID: The ID of the user.
    /// - Returns: The calendar settings for the user.
    func getCalendarSettings(for userID: String) async throws -> CalendarSettings
    
    /// Checks if the user has granted access to the calendar.
    /// - Parameter userID: The ID of the user.
    /// - Returns: A boolean indicating if the user has granted access to the calendar.
    func hasCalendarAccess(for userID: String) async throws -> Bool
    
    /// Checks if the user is available during the given time period.
    /// - Parameters:
    ///   - userId: The ID of the user.
    ///   - startDate: The start date of the time period.
    ///   - endDate: The end date of the time period.
    /// - Returns: A boolean indicating if the user is available during the time period.
    func checkAvailability(userId: String, startDate: Date, endDate: Date) async -> Bool
    
    /// Finds mutual availability for multiple users during a specific time range
    /// - Parameters:
    ///   - userIDs: Array of user IDs to check availability for
    ///   - startRange: The start of the time range to check
    ///   - endRange: The end of the time range to check
    ///   - duration: The duration needed for the meeting/hangout
    /// - Returns: An array of time slots where all users are available
    func findMutualAvailability(userIDs: [String], startRange: Date, endRange: Date, duration: TimeInterval) async -> [DateInterval]
    
    /// Creates a calendar event from a hangout.
    /// - Parameters:
    ///   - hangout: The hangout to create a calendar event for.
    ///   - userIDs: The IDs of the users to add to the event.
    /// - Returns: The ID of the created calendar event.
    func createCalendarEvent(for hangout: Hangout, userIDs: [String]) async throws -> String
    
    /// Initiates the calendar authentication flow for a user
    /// - Parameter userID: The ID of the user to authenticate
    func authenticateCalendarAccess(for userID: String) async throws
} 