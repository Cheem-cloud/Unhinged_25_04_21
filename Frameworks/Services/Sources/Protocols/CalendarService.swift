import Foundation

/// Protocol defining a service for calendar operations, including event management and availability checking
public protocol CalendarService {
    /// Get calendar settings for a user
    /// - Parameter userID: ID of the user
    /// - Returns: The user's calendar settings
    func getCalendarSettings(for userID: String) async throws -> CalendarSettings
    
    /// Check if user has granted calendar access
    /// - Parameter userID: ID of the user
    /// - Returns: Whether the user has granted calendar access
    func hasCalendarAccess(for userID: String) async throws -> Bool
    
    /// Get all calendar providers for a user
    /// - Parameter userID: ID of the user
    /// - Returns: Array of calendar providers
    func getCalendarProviders(for userID: String) async throws -> [CalendarProvider]
    
    /// Enable or disable a specific calendar provider
    /// - Parameters:
    ///   - id: ID of the provider
    ///   - isEnabled: Whether the provider should be enabled
    func updateCalendarProviderStatus(id: String, isEnabled: Bool) async throws
    
    /// Add a new calendar provider for a user
    /// - Parameter provider: The calendar provider to add
    func addCalendarProvider(_ provider: CalendarProvider) async throws
    
    /// Remove a calendar provider
    /// - Parameter id: ID of the provider to remove
    func removeCalendarProvider(id: String) async throws
    
    /// Check if a user is available during a time period
    /// - Parameters:
    ///   - userID: ID of the user
    ///   - startDate: Start of the time period
    ///   - endDate: End of the time period
    /// - Returns: Whether the user is available
    func checkAvailability(userID: String, startDate: Date, endDate: Date) async throws -> Bool
    
    /// Get busy time periods for a user in a date range
    /// - Parameters:
    ///   - userID: ID of the user
    ///   - startDate: Start of the date range
    ///   - endDate: End of the date range
    /// - Returns: Array of busy time periods
    func getBusyTimePeriods(for userID: String, startDate: Date, endDate: Date) async throws -> [BusyTimePeriod]
    
    /// Find mutual availability for multiple users
    /// - Parameters:
    ///   - userIDs: Array of user IDs to check
    ///   - startRange: Start of the date range
    ///   - endRange: End of the date range
    ///   - duration: Duration needed for the meeting
    /// - Returns: Array of date intervals where all users are available
    func findMutualAvailability(userIDs: [String], startRange: Date, endRange: Date, duration: TimeInterval) async throws -> [DateInterval]
    
    /// Find available time slots based on busy periods
    /// - Parameters:
    ///   - startDate: Start of the date range
    ///   - endDate: End of the date range
    ///   - duration: Duration needed in minutes
    ///   - busyPeriods: Array of busy periods to avoid
    /// - Returns: Array of available time slots
    func findAvailableTimeSlots(startDate: Date, endDate: Date, duration: Int, busyPeriods: [BusyTimePeriod]) async throws -> [AvailabilitySlot]
    
    /// Create a calendar event
    /// - Parameter event: The event to create
    /// - Returns: ID of the created event
    func createCalendarEvent(_ event: CalendarEventModel) async throws -> String
    
    /// Create a calendar event for a hangout
    /// - Parameters:
    ///   - hangout: The hangout to create an event for
    ///   - userIDs: IDs of users to add to the event
    /// - Returns: ID of the created event
    func createCalendarEvent(for hangout: Hangout, userIDs: [String]) async throws -> String
    
    /// Get a calendar event by ID
    /// - Parameter id: ID of the event
    /// - Returns: The calendar event
    func getCalendarEvent(_ id: String) async throws -> CalendarEventModel
    
    /// Update a calendar event
    /// - Parameters:
    ///   - id: ID of the event to update
    ///   - event: Updated event data
    func updateCalendarEvent(_ id: String, with event: CalendarEventModel) async throws
    
    /// Delete a calendar event
    /// - Parameter id: ID of the event to delete
    func deleteCalendarEvent(_ id: String) async throws
    
    /// Authenticate calendar access for a user
    /// - Parameter userID: ID of the user
    func authenticateCalendarAccess(for userID: String) async throws
    
    /// Authenticate calendar access for a user with a specific provider
    /// - Parameters:
    ///   - userID: ID of the user
    ///   - providerType: Type of calendar provider
    func authenticateCalendarAccess(for userID: String, providerType: CalendarProviderType) async throws
    
    /// Synchronize calendar events from providers to the app
    /// - Parameter userID: ID of the user
    /// - Returns: Number of events synchronized
    func synchronizeCalendarEvents(for userID: String) async throws -> Int
} 