import Foundation
import EventKit
import SwiftUI
import UIKit
import Firebase
import FirebaseFirestore

/// Service responsible for fetching calendar data including events and availability
class CalendarDataFetchService {
    // Dependencies
    private let calendarService: CRUDService
    private let calendarOpsService: CalendarOperationsService
    private let firestoreService: FirestoreService
    private let eventStore: EKEventStore
    
    init(
        calendarService: CRUDService,
        calendarOpsService: CalendarOperationsService,
        firestoreService: FirestoreService
    ) {
        self.calendarService = calendarService
        self.calendarOpsService = calendarOpsService
        self.firestoreService = firestoreService
        self.eventStore = EKEventStore()
    }
    
    // MARK: - Event Fetching
    
    /// Fetches all events for a user across all their connected calendar providers
    /// - Parameter userId: User ID
    /// - Returns: Array of calendar events
    func fetchAllEvents(for userId: String) async throws -> [CalendarEventModel] {
        // Get user's calendar settings
        guard let settings = try await calendarOpsService.getCalendarSettings(for: userId) else {
            return []
        }
        
        // Fetch events from each connected provider
        var allEvents: [CalendarEventModel] = []
        
        for provider in settings.connectedProviders {
            do {
                let events = try await fetchEvents(for: userId, provider: provider)
                allEvents.append(contentsOf: events)
            } catch {
                print("Error fetching events for provider \(provider): \(error.localizedDescription)")
                // Continue with other providers
            }
        }
        
        return allEvents
    }
    
    /// Fetches events from a specific calendar provider
    /// - Parameters:
    ///   - userId: User ID
    ///   - provider: Calendar provider (Google, Outlook, Apple)
    /// - Returns: Array of calendar events
    func fetchEvents(for userId: String, provider: CalendarProvider) async throws -> [CalendarEventModel] {
        // Get current date range (default to next 30 days)
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate) ?? startDate
        
        return try await fetchEvents(for: userId, provider: provider, startDate: startDate, endDate: endDate)
    }
    
    /// Fetches events for a specific date range
    /// - Parameters:
    ///   - userId: User ID
    ///   - startDate: Start date for the range
    ///   - endDate: End date for the range
    /// - Returns: Array of calendar events within the date range
    func fetchEvents(for userId: String, startDate: Date, endDate: Date) async throws -> [CalendarEventModel] {
        // Get user's calendar settings
        guard let settings = try await calendarOpsService.getCalendarSettings(for: userId) else {
            return []
        }
        
        // Fetch events from each connected provider
        var allEvents: [CalendarEventModel] = []
        
        for provider in settings.connectedProviders {
            do {
                let events = try await fetchEvents(for: userId, provider: provider, startDate: startDate, endDate: endDate)
                allEvents.append(contentsOf: events)
            } catch {
                print("Error fetching events for provider \(provider): \(error.localizedDescription)")
                // Continue with other providers
            }
        }
        
        return allEvents
    }
    
    /// Fetches events for a specific date range from a specific provider
    /// - Parameters:
    ///   - userId: User ID
    ///   - provider: Calendar provider
    ///   - startDate: Start date for the range
    ///   - endDate: End date for the range
    /// - Returns: Array of calendar events within the date range from the specified provider
    func fetchEvents(for userId: String, provider: CalendarProvider, startDate: Date, endDate: Date) async throws -> [CalendarEventModel] {
        // Get token for the provider
        let token = try await calendarOpsService.getCalendarToken(for: userId, provider: provider)
        
        // Use the appropriate method based on provider
        switch provider {
        case .google:
            return try await fetchGoogleCalendarEvents(accessToken: token ?? "", startDate: startDate, endDate: endDate)
        case .outlook:
            return try await fetchOutlookCalendarEvents(accessToken: token ?? "", startDate: startDate, endDate: endDate)
        case .apple:
            return try await fetchAppleCalendarEvents(startDate: startDate, endDate: endDate)
        }
    }
    
    // MARK: - Availability Fetching
    
    /// Calculates available time slots for a user based on their calendar events
    /// - Parameters:
    ///   - userId: User ID
    ///   - startDate: Start date for availability calculation
    ///   - endDate: End date for availability calculation
    ///   - timeBlockDuration: Duration in minutes for each availability block
    /// - Returns: Array of availability time slots
    func fetchAvailableTimeSlots(
        for userId: String,
        startDate: Date,
        endDate: Date,
        timeBlockDuration: Int = 30
    ) async throws -> [AvailabilityTimeSlot] {
        // Fetch all events for the user in the time range
        let events = try await fetchEvents(for: userId, startDate: startDate, endDate: endDate)
        
        // Convert events to busy times
        let busyTimes = events.map { event -> BusyTimePeriod in
            BusyTimePeriod(
                start: event.startDate,
                end: event.endDate,
                title: event.title
            )
        }
        
        // Create a timeline of all possible slots
        let calendar = Calendar.current
        var allSlots: [AvailabilityTimeSlot] = []
        
        // Get user's availability preferences
        let preferences = try await getUserAvailabilityPreferences(userId: userId)
        
        // Starting from startDate, create time slots until endDate
        var currentDate = calendar.startOfDay(for: startDate)
        
        while currentDate < endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            
            // Only create slots for preferred days
            if preferences.preferredDays.contains(weekday) {
                // Parse preferred start/end times
                let dayComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
                
                // Create start time for this day
                var startComponents = DateComponents()
                startComponents.year = dayComponents.year
                startComponents.month = dayComponents.month
                startComponents.day = dayComponents.day
                
                let startTimeParts = preferences.preferredDayStartTime.split(separator: ":")
                if startTimeParts.count == 2,
                   let hour = Int(startTimeParts[0]),
                   let minute = Int(startTimeParts[1]) {
                    startComponents.hour = hour
                    startComponents.minute = minute
                } else {
                    startComponents.hour = 9 // Default 9am
                    startComponents.minute = 0
                }
                
                // Create end time for this day
                var endComponents = DateComponents()
                endComponents.year = dayComponents.year
                endComponents.month = dayComponents.month
                endComponents.day = dayComponents.day
                
                let endTimeParts = preferences.preferredDayEndTime.split(separator: ":")
                if endTimeParts.count == 2,
                   let hour = Int(endTimeParts[0]),
                   let minute = Int(endTimeParts[1]) {
                    endComponents.hour = hour
                    endComponents.minute = minute
                } else {
                    endComponents.hour = 17 // Default 5pm
                    endComponents.minute = 0
                }
                
                guard let dayStart = calendar.date(from: startComponents),
                      let dayEnd = calendar.date(from: endComponents) else {
                    // Move to next day
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
                    continue
                }
                
                // Create time slots for this day
                var slotStart = dayStart
                let slotDuration = TimeInterval(timeBlockDuration * 60) // Convert minutes to seconds
                
                while slotStart.addingTimeInterval(slotDuration) <= dayEnd {
                    let slotEnd = slotStart.addingTimeInterval(slotDuration)
                    
                    // Check if this slot overlaps with any busy time
                    let isAvailable = !busyTimes.contains { busyTime in
                        max(slotStart, busyTime.start) < min(slotEnd, busyTime.end)
                    }
                    
                    if isAvailable {
                        allSlots.append(AvailabilityTimeSlot(
                            startTime: slotStart,
                            endTime: slotEnd,
                            isAvailable: true
                        ))
                    }
                    
                    // Move to next slot
                    slotStart = slotEnd
                }
            }
            
            // Move to next day
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                currentDate = nextDay
            } else {
                break
            }
        }
        
        return allSlots
    }
    
    /// Calculates mutual available time slots for multiple users
    /// - Parameters:
    ///   - userIds: Array of user IDs
    ///   - startDate: Start date for availability calculation
    ///   - endDate: End date for availability calculation
    ///   - timeBlockDuration: Duration in minutes for each availability block
    /// - Returns: Array of mutually available time slots
    func fetchMutualAvailableTimeSlots(
        for userIds: [String],
        startDate: Date,
        endDate: Date,
        timeBlockDuration: Int = 30
    ) async throws -> [AvailabilityTimeSlot] {
        var allUserSlots: [[AvailabilityTimeSlot]] = []
        
        // Get available slots for each user
        for userId in userIds {
            let slots = try await fetchAvailableTimeSlots(
                for: userId,
                startDate: startDate,
                endDate: endDate,
                timeBlockDuration: timeBlockDuration
            )
            allUserSlots.append(slots)
        }
        
        // Find intersection of all users' available slots
        guard let firstUserSlots = allUserSlots.first else {
            return []
        }
        
        // Start with first user's slots and find mutual availability
        var mutualSlots = firstUserSlots
        
        for userSlots in allUserSlots.dropFirst() {
            // Keep only slots that are also in this user's available slots
            mutualSlots = mutualSlots.filter { slot in
                userSlots.contains { userSlot in
                    // Slots match if they have the same start and end times
                    slot.startTime == userSlot.startTime && slot.endTime == userSlot.endTime
                }
            }
        }
        
        return mutualSlots
    }
    
    /// Retrieves free/busy information for a user
    /// - Parameters:
    ///   - userId: User ID
    ///   - startDate: Start date for the query
    ///   - endDate: End date for the query
    /// - Returns: Array of busy time periods
    func fetchFreeBusyInfo(
        for userId: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [BusyTimePeriod] {
        // Fetch all events for the user in the time range
        let events = try await fetchEvents(for: userId, startDate: startDate, endDate: endDate)
        
        // Convert events to busy times
        return events.map { event -> BusyTimePeriod in
            BusyTimePeriod(
                start: event.startDate,
                end: event.endDate,
                title: event.title
            )
        }
    }
    
    // MARK: - Query Helpers
    
    /// Queries calendar events based on various filter criteria
    /// - Parameters:
    ///   - userId: User ID
    ///   - filters: Dictionary of filter criteria
    /// - Returns: Array of calendar events matching the filters
    func queryEvents(
        for userId: String,
        filters: [String: Any]
    ) async throws -> [CalendarEventModel] {
        var events = try await fetchAllEvents(for: userId)
        
        // Apply filters
        if let startDate = filters["startDate"] as? Date {
            events = events.filter { $0.startDate >= startDate }
        }
        
        if let endDate = filters["endDate"] as? Date {
            events = events.filter { $0.endDate <= endDate }
        }
        
        if let provider = filters["provider"] as? CalendarProvider {
            events = events.filter { $0.provider == provider }
        }
        
        if let titleContains = filters["titleContains"] as? String {
            events = events.filter { $0.title.localizedCaseInsensitiveContains(titleContains) }
        }
        
        if let descriptionContains = filters["descriptionContains"] as? String {
            events = events.filter { $0.description.localizedCaseInsensitiveContains(descriptionContains) }
        }
        
        return events
    }
    
    /// Fetch calendar events from all connected providers
    /// - Parameters:
    ///   - userId: The user ID
    ///   - startDate: Start date for fetching events
    ///   - endDate: End date for fetching events
    /// - Returns: Array of calendar events grouped by provider
    func fetchAllCalendarEvents(for userId: String, startDate: Date, endDate: Date) async throws -> [CalendarProvider: [CalendarEventModel]] {
        // Get user's calendar settings
        guard let calendarSettings = try await calendarOpsService.getCalendarSettings(for: userId) else {
            throw CalendarError.settingsNotFound
        }
        
        var allEvents: [CalendarProvider: [CalendarEventModel]] = [:]
        
        // Process each connected provider
        for provider in calendarSettings.connectedProviders {
            do {
                var events: [CalendarEventModel] = []
                
                switch provider {
                case .google:
                    if let token = try await calendarOpsService.getCalendarToken(for: userId, provider: .google) {
                        events = try await fetchCalendarEvents(provider: .google, accessToken: token, startDate: startDate, endDate: endDate)
                    }
                case .outlook:
                    if let token = try await calendarOpsService.getCalendarToken(for: userId, provider: .outlook) {
                        events = try await fetchCalendarEvents(provider: .outlook, accessToken: token, startDate: startDate, endDate: endDate)
                    }
                case .apple:
                    // Apple calendar uses local access
                    events = try await fetchAppleCalendarEvents(startDate: startDate, endDate: endDate)
                }
                
                allEvents[provider] = events
                
            } catch {
                print("Error fetching events for provider \(provider): \(error.localizedDescription)")
                // Continue with other providers even if one fails
                allEvents[provider] = []
            }
        }
        
        return allEvents
    }
    
    /// Fetch calendar events from a specific provider
    /// - Parameters:
    ///   - provider: The calendar provider
    ///   - accessToken: OAuth access token
    ///   - startDate: Start date for fetching events
    ///   - endDate: End date for fetching events
    /// - Returns: Array of calendar events
    func fetchCalendarEvents(provider: CalendarProvider, accessToken: String, startDate: Date, endDate: Date) async throws -> [CalendarEventModel] {
        switch provider {
        case .google:
            return try await fetchGoogleCalendarEvents(accessToken: accessToken, startDate: startDate, endDate: endDate)
        case .outlook:
            return try await fetchOutlookCalendarEvents(accessToken: accessToken, startDate: startDate, endDate: endDate)
        case .apple:
            return try await fetchAppleCalendarEvents(startDate: startDate, endDate: endDate)
        }
    }
    
    // MARK: - Private Methods
    
    /// Gets a user's availability preferences from Firestore
    private func getUserAvailabilityPreferences(userId: String) async throws -> AvailabilityPreferences {
        // Try to get from calendar settings
        if let settings = try? await calendarOpsService.getCalendarSettings(for: userId) {
            return settings.availabilityPreferences
        }
        
        // If not found, return default preferences
        return AvailabilityPreferences()
    }
    
    /// Calculates mutual availability for a group of users
    /// - Parameters:
    ///   - userIds: Array of user IDs to check
    ///   - startDate: Start date for the calculation
    ///   - endDate: End date for the calculation
    ///   - minimumHours: Minimum continuous available hours required
    /// - Returns: Array of available time slots
    func calculateMutualAvailability(
        for userIds: [String],
        startDate: Date,
        endDate: Date,
        minimumHours: Int = 1
    ) async throws -> [AvailabilitySlot] {
        // Fetch all users' events
        var allUserEvents: [String: [CalendarEventModel]] = [:]
        
        for userId in userIds {
            do {
                let providerEvents = try await fetchAllCalendarEvents(for: userId, startDate: startDate, endDate: endDate)
                
                // Combine events from all providers
                var combinedEvents: [CalendarEventModel] = []
                for (_, events) in providerEvents {
                    combinedEvents.append(contentsOf: events)
                }
                
                allUserEvents[userId] = combinedEvents
            } catch {
                print("Error fetching events for user \(userId): \(error.localizedDescription)")
                // Use empty array if we can't get events
                allUserEvents[userId] = []
            }
        }
        
        // Create a timeline of availability
        let availabilityCalculator = AvailabilityCalculator()
        return availabilityCalculator.calculateMutualAvailability(
            userEvents: allUserEvents,
            startDate: startDate,
            endDate: endDate,
            minimumHours: minimumHours
        )
    }
} 