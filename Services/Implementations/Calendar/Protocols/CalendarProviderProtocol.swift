import Foundation

/// Protocol that defines the common operations for all calendar providers
protocol CalendarProviderProtocol {
    /// The type of calendar provider
    var providerType: CalendarProviderType { get }
    
    /// Get the availability (free/busy) for a user between start and end dates
    /// - Parameters:
    ///   - userID: The user ID
    ///   - startDate: The start date to check
    ///   - endDate: The end date to check
    /// - Returns: Array of busy time slots
    func getAvailability(userID: String, startDate: Date, endDate: Date) async throws -> [BusyTimeSlot]
    
    /// Create a calendar event
    /// - Parameters:
    ///   - event: The event to create
    ///   - userID: The user ID
    /// - Returns: The ID of the created event
    func createEvent(event: CalendarEventModel, userID: String) async throws -> String
    
    /// Update an existing calendar event
    /// - Parameters:
    ///   - eventID: The ID of the event to update
    ///   - event: The updated event data
    ///   - userID: The user ID
    func updateEvent(eventID: String, event: CalendarEventModel, userID: String) async throws
    
    /// Delete a calendar event
    /// - Parameters:
    ///   - eventID: The ID of the event to delete
    ///   - userID: The user ID
    func deleteEvent(eventID: String, userID: String) async throws
    
    /// Fetch authorization URL for OAuth flow
    /// - Returns: URL to redirect the user for authorization
    func getAuthorizationURL() -> URL?
    
    /// Handle OAuth callback and exchange code for tokens
    /// - Parameter url: The callback URL with authorization code
    /// - Returns: The access and refresh tokens
    func handleAuthCallback(url: URL) async throws -> (accessToken: String, refreshToken: String)
    
    /// Refresh the access token using a refresh token
    /// - Parameter refreshToken: The refresh token
    /// - Returns: The new access token and expiration date
    func refreshAccessToken(refreshToken: String) async throws -> (accessToken: String, expirationDate: Date)
    
    /// Configure the provider with access and refresh tokens
    /// - Parameters:
    ///   - accessToken: The OAuth access token
    ///   - refreshToken: The OAuth refresh token (optional)
    func configure(accessToken: String, refreshToken: String?)
} 