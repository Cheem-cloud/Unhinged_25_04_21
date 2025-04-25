import Foundation
import EventKit
import UIKit
import Combine

// We need CalendarProviderType from the protocol file
// Assuming CalendarProviderProtocol is in the same module/target

/// Implementation of CalendarProviderProtocol for Apple Calendar (EventKit)
class AppleCalendarProvider: CalendarProviderProtocol {
    /// The EventKit event store for accessing calendar data
    private let eventStore = EKEventStore()
    
    /// Flag to track if we have calendar access
    private var hasCalendarAccess = false
    
    /// Provider type
    var providerType: CalendarProviderType {
        return .apple
    }
    
    /// Initialize the provider
    init() {
        // Check existing permission status
        checkPermissionStatus()
    }
    
    /// Configure the provider with access and refresh tokens
    /// Not needed for EventKit, but required by protocol
    func configure(accessToken: String, refreshToken: String?) {
        // No-op for Apple Calendar
    }
    
    /// Check current permission status
    private func checkPermissionStatus() {
        // Check and store current permission status
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized:
            hasCalendarAccess = true
        case .notDetermined, .denied, .restricted:
            hasCalendarAccess = false
        @unknown default:
            hasCalendarAccess = false
        }
    }
    
    /// Get the current authorization status for calendar access
    /// - Returns: The current EKAuthorizationStatus
    func checkAuthorizationStatus() -> EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(for: .event)
    }
    
    /// Request access to calendar
    /// - Returns: Boolean indicating if access was granted
    func requestAccess() async -> Bool {
        // First check if we already have access
        if hasCalendarAccess {
            return true
        }
        
        // Use the new async API in iOS 15+
        if #available(iOS 15.0, *) {
            do {
                let granted = try await eventStore.requestAccess(to: .event)
                hasCalendarAccess = granted
                return granted
            } catch {
                print("Error requesting calendar access: \(error.localizedDescription)")
                return false
            }
        } else {
            // Fall back to the older callback-based API
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        print("Error requesting calendar access: \(error.localizedDescription)")
                    }
                    self.hasCalendarAccess = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    /// Add a local BusyTimeSlot struct to match the protocol requirement
    struct BusyTimeSlot {
        let startTime: Date
        let endTime: Date
        let title: String?
        let isAllDay: Bool
        
        init(startTime: Date, endTime: Date, title: String? = nil, isAllDay: Bool = false) {
            self.startTime = startTime
            self.endTime = endTime
            self.title = title
            self.isAllDay = isAllDay
        }
    }
    
    /// Get user's availability by checking their Apple Calendar
    /// - Parameters:
    ///   - userID: The user ID (not used for local calendar)
    ///   - startDate: The start date to check
    ///   - endDate: The end date to check
    /// - Returns: Array of busy time slots
    func getAvailability(userID: String, startDate: Date, endDate: Date) async throws -> [BusyTimeSlot] {
        // Ensure we have calendar access
        let hasAccess = await requestAccess()
        
        guard hasAccess else {
            throw CalendarError.authorizationFailed
        }
        
        // Get all calendars
        let calendars = eventStore.calendars(for: .event)
        
        // Create predicate for the date range
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        
        // Fetch events
        let events = eventStore.events(matching: predicate)
        
        // Convert to busy time slots
        return events.map { event in
            BusyTimeSlot(
                startTime: event.startDate,
                endTime: event.endDate,
                title: event.title,
                isAllDay: event.isAllDay
            )
        }
    }
    
    /// Create a calendar event in Apple Calendar
    /// - Parameters:
    ///   - event: The event to create
    ///   - userID: The user ID (not used for local calendar)
    /// - Returns: The ID of the created event
    func createEvent(event: CalendarEventModel, userID: String) async throws -> String {
        // Ensure we have calendar access
        let hasAccess = await requestAccess()
        
        guard hasAccess else {
            throw CalendarError.authorizationFailed
        }
        
        // Create a new event
        let newEvent = EKEvent(eventStore: eventStore)
        
        // Set event properties
        newEvent.title = event.title
        newEvent.notes = event.description
        newEvent.startDate = event.startDate
        newEvent.endDate = event.endDate
        newEvent.isAllDay = event.isAllDay
        
        if let location = event.location {
            newEvent.location = location
        }
        
        // Get the default calendar
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw NSError(domain: "com.cheemhang.calendar", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "No default calendar found"
            ])
        }
        
        newEvent.calendar = calendar
        
        // Save the event
        do {
            try eventStore.save(newEvent, span: .thisEvent)
            return newEvent.eventIdentifier
        } catch {
            throw error
        }
    }
    
    /// Update an existing calendar event
    /// - Parameters:
    ///   - eventID: The ID of the event to update
    ///   - event: The updated event data
    ///   - userID: The user ID (not used for local calendar)
    func updateEvent(eventID: String, event: CalendarEventModel, userID: String) async throws {
        // Ensure we have calendar access
        let hasAccess = await requestAccess()
        
        guard hasAccess else {
            throw CalendarError.authorizationFailed
        }
        
        // Fetch the existing event
        guard let existingEvent = eventStore.event(withIdentifier: eventID) else {
            throw NSError(domain: "com.cheemhang.calendar", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Event not found"
            ])
        }
        
        // Update event properties
        existingEvent.title = event.title
        existingEvent.notes = event.description
        existingEvent.startDate = event.startDate
        existingEvent.endDate = event.endDate
        existingEvent.isAllDay = event.isAllDay
        
        if let location = event.location {
            existingEvent.location = location
        }
        
        // Save the updated event
        do {
            try eventStore.save(existingEvent, span: .thisEvent)
        } catch {
            throw error
        }
    }
    
    /// Delete a calendar event
    /// - Parameters:
    ///   - eventID: The ID of the event to delete
    ///   - userID: The user ID (not used for local calendar)
    func deleteEvent(eventID: String, userID: String) async throws {
        // Ensure we have calendar access
        let hasAccess = await requestAccess()
        
        guard hasAccess else {
            throw CalendarError.authorizationFailed
        }
        
        // Fetch the existing event
        guard let existingEvent = eventStore.event(withIdentifier: eventID) else {
            throw NSError(domain: "com.cheemhang.calendar", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Event not found"
            ])
        }
        
        // Delete the event
        do {
            try eventStore.remove(existingEvent, span: .thisEvent)
        } catch {
            throw error
        }
    }
    
    /// Get authorization URL for Apple Calendar
    /// Not needed for EventKit, but required by protocol
    /// - Returns: Always nil since EventKit doesn't use OAuth
    func getAuthorizationURL() -> URL? {
        // Not applicable for EventKit
        return nil
    }
    
    /// Handle OAuth callback for Apple Calendar
    /// Not needed for EventKit, but required by protocol
    /// - Parameter url: The callback URL
    /// - Returns: Empty tokens
    func handleAuthCallback(url: URL) async throws -> (accessToken: String, refreshToken: String) {
        // Not applicable for EventKit
        throw CalendarError.notImplemented
    }
    
    /// Refresh access token for Apple Calendar
    /// Not needed for EventKit, but required by protocol
    /// - Parameter refreshToken: The refresh token
    /// - Returns: Empty token and expiration date
    func refreshAccessToken(refreshToken: String) async throws -> (accessToken: String, expirationDate: Date) {
        // Not applicable for EventKit
        throw CalendarError.notImplemented
    }
} 