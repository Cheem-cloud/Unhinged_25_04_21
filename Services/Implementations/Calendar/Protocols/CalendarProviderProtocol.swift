import Foundation

// Replace module imports with direct imports of the specific files we need
// Since we can't properly import the modules, we'll need to handle types directly
// We'll add a local typealias for CalendarProviderType

/// Simple enum matching the one defined in Services/Core/CalendarProvider.swift
public enum CalendarProviderType: String, Codable, CaseIterable, Identifiable {
    case google
    case apple
    case outlook
    
    public var id: String {
        return self.rawValue
    }
}

/// Protocol that all calendar providers must implement
public protocol CalendarProviderProtocol {
    /// The provider type
    var providerType: CalendarProviderType { get }
    
    /// Configure the provider with access and refresh tokens
    /// - Parameters:
    ///   - accessToken: The access token
    ///   - refreshToken: The refresh token (optional)
    func configure(accessToken: String, refreshToken: String?)
    
    /// Get user's availability by checking their calendar
    /// - Parameters:
    ///   - userID: The user ID
    ///   - startDate: The start date for availability search
    ///   - endDate: The end date for availability search
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
    ///   - event: The updated event
    ///   - userID: The user ID
    func updateEvent(eventID: String, event: CalendarEventModel, userID: String) async throws
    
    /// Delete a calendar event
    /// - Parameters:
    ///   - eventID: The ID of the event to delete
    ///   - userID: The user ID
    func deleteEvent(eventID: String, userID: String) async throws
    
    /// Get authorization URL for the calendar provider
    /// - Returns: The authorization URL
    func getAuthorizationURL() -> URL?
    
    /// Handle OAuth callback for the calendar provider
    /// - Parameter url: The callback URL
    /// - Returns: Access token and refresh token
    func handleAuthCallback(url: URL) async throws -> (accessToken: String, refreshToken: String)
    
    /// Refresh access token for the calendar provider
    /// - Parameter refreshToken: The refresh token
    /// - Returns: New access token and expiration date
    func refreshAccessToken(refreshToken: String) async throws -> (accessToken: String, expirationDate: Date)
}

/// Helper struct for busy time slots that matches BusyTimeSlot in CalendarProvider
public struct BusyTimeSlot {
    /// Start time of the busy slot
    public let startTime: Date
    
    /// End time of the busy slot
    public let endTime: Date
    
    /// Optional title of the calendar event
    public let title: String?
    
    /// Whether this is an all-day event
    public let isAllDay: Bool
    
    public init(startTime: Date, endTime: Date, title: String? = nil, isAllDay: Bool = false) {
        self.startTime = startTime
        self.endTime = endTime
        self.title = title
        self.isAllDay = isAllDay
    }
} 