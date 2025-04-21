import Foundation
import SwiftUI
import Combine

/// View model for calendar event creation and management
class CalendarEventViewModel: ObservableObject {
    // MARK: - Properties
    
    /// The calendar event model
    @Published var event: CalendarEvent
    
    /// Loading state
    @Published var isLoading = false
    
    /// Error message
    @Published var errorMessage: String?
    
    /// Success message
    @Published var successMessage: String?
    
    /// Calendar operations service
    private let calendarService: CalendarOperationsService
    
    // MARK: - Initialization
    
    /// Initialize with an event
    /// - Parameter event: The calendar event
    init(event: CalendarEvent? = nil) {
        self.event = event ?? CalendarEvent(
            title: "",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            attendees: [],
            associatedHangout: Hangout()
        )
        
        // Get the CalendarOperationsService
        self.calendarService = ServiceManager.shared.getService(CalendarOperationsService.self)
    }
    
    // MARK: - Methods
    
    /// Save the calendar event
    func saveEvent() async {
        guard validate() else { return }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            if !event.id.isEmpty {
                // Update existing event
                try await updateEvent()
            } else {
                // Create new event
                try await createEvent()
            }
            
            await MainActor.run {
                successMessage = "Event saved successfully"
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save event: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    /// Delete the calendar event
    func deleteEvent() async {
        guard !event.id.isEmpty else {
            errorMessage = "No event ID to delete"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            // Delete via CalendarOperationsService
            try await calendarService.delete(event.id)
            
            await MainActor.run {
                successMessage = "Event deleted successfully"
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete event: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    /// Load events for a date range
    /// - Parameters:
    ///   - startDate: The start date
    ///   - endDate: The end date
    /// - Returns: Array of calendar events
    func loadEvents(from startDate: Date, to endDate: Date) async -> [CalendarEvent] {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get all events from CalendarOperationsService
            let events = try await calendarService.list()
            
            // Filter events by date range
            let filteredEvents = events.filter { event in
                return event.startDate >= startDate && event.startDate <= endDate
            }
            
            await MainActor.run {
                isLoading = false
            }
            
            return filteredEvents
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load events: \(error.localizedDescription)"
                isLoading = false
            }
            return []
        }
    }
    
    // MARK: - Private Methods
    
    /// Validate the event data
    /// - Returns: Whether the event is valid
    private func validate() -> Bool {
        // Title is required
        if event.title.isEmpty {
            errorMessage = "Event title is required"
            return false
        }
        
        // End date must be after start date
        if event.endDate <= event.startDate {
            errorMessage = "End time must be after start time"
            return false
        }
        
        return true
    }
    
    /// Create a new event
    private func createEvent() async throws {
        // Create via CalendarOperationsService
        let createdEvent = try await calendarService.create(event)
        
        // Update our event with the new ID
        await MainActor.run {
            self.event = createdEvent
        }
    }
    
    /// Update an existing event
    private func updateEvent() async throws {
        guard !event.id.isEmpty else {
            throw NSError(domain: "com.cheemhang.calendar", code: 400, userInfo: [NSLocalizedDescriptionKey: "No event ID to update"])
        }
        
        // Update via CalendarOperationsService
        let updatedEvent = try await calendarService.update(event)
        
        // Update our local event
        await MainActor.run {
            self.event = updatedEvent
        }
    }
} 