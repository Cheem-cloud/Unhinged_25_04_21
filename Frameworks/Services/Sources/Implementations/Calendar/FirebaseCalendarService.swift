import Foundation
import Firebase
import FirebaseFirestore


/// Firebase implementation of CalendarService
public class FirebaseCalendarService: CalendarService {
    /// The Firestore database
    private let db = Firestore.firestore()
    
    /// Provider factory for creating calendar providers
    private let providerFactory = CalendarProviderFactory()
    
    /// Calendar settings collection name
    private let settingsCollection = "calendarSettings"
    
    /// Calendar events collection name
    private let eventsCollection = "calendarEvents"
    
    /// Calendar providers collection name
    private let providersCollection = "calendarProviders"
    
    public init() {
        print("📱 FirebaseCalendarService initialized")
    }
    
    // MARK: - Settings & Access
    
    public func getCalendarSettings(for userID: String) async throws -> CalendarSettings {
        let docRef = db.collection(settingsCollection).document(userID)
        let document = try await docRef.getDocument()
        
        if let data = document.data(), !data.isEmpty {
            return try FirestoreDecoder().decode(CalendarSettings.self, from: data)
        } else {
            // Create default settings if none exist
            let defaultSettings = CalendarSettings(
                userID: userID,
                defaultCalendarProvider: .google,
                syncEnabled: true,
                reminderNotificationsEnabled: true,
                defaultReminderTime: 15
            )
            
            try await docRef.setData(FirestoreEncoder().encode(defaultSettings) as! [String: Any])
            return defaultSettings
        }
    }
    
    public func hasCalendarAccess(for userID: String) async throws -> Bool {
        let providers = try await getCalendarProviders(for: userID)
        return !providers.isEmpty && providers.contains(where: { $0.isEnabled })
    }
    
    // MARK: - Provider Management
    
    public func getCalendarProviders(for userID: String) async throws -> [CalendarProvider] {
        let snapshot = try await db.collection(providersCollection)
            .whereField("userID", isEqualTo: userID)
            .getDocuments()
        
        let providers = snapshot.documents.compactMap { document -> CalendarProvider? in
            do {
                var provider = try FirestoreDecoder().decode(CalendarProvider.self, from: document.data())
                provider.id = document.documentID
                return provider
            } catch {
                print("Error decoding calendar provider: \(error.localizedDescription)")
                return nil
            }
        }
        
        return providers
    }
    
    public func updateCalendarProviderStatus(id: String, isEnabled: Bool) async throws {
        try await db.collection(providersCollection).document(id).updateData([
            "isEnabled": isEnabled
        ])
    }
    
    public func addCalendarProvider(_ provider: CalendarProvider) async throws {
        var providerData = try FirestoreEncoder().encode(provider) as! [String: Any]
        
        // Generate ID if not provided
        if provider.id.isEmpty {
            let document = db.collection(providersCollection).document()
            providerData["id"] = document.documentID
            try await document.setData(providerData)
        } else {
            try await db.collection(providersCollection).document(provider.id).setData(providerData)
        }
    }
    
    public func removeCalendarProvider(id: String) async throws {
        try await db.collection(providersCollection).document(id).delete()
    }
    
    // MARK: - Availability Methods
    
    public func checkAvailability(userID: String, startDate: Date, endDate: Date) async throws -> Bool {
        let busyPeriods = try await getBusyTimePeriods(for: userID, startDate: startDate, endDate: endDate)
        
        // User is available if they have no busy periods in the given time range
        return busyPeriods.isEmpty
    }
    
    public func getBusyTimePeriods(for userID: String, startDate: Date, endDate: Date) async throws -> [BusyTimePeriod] {
        let providers = try await getCalendarProviders(for: userID)
        let enabledProviders = providers.filter { $0.isEnabled }
        
        if enabledProviders.isEmpty {
            return []
        }
        
        var allBusyPeriods: [BusyTimePeriod] = []
        
        for provider in enabledProviders {
            let calendarProvider = providerFactory.getProvider(for: provider.providerType)
            
            if let accessToken = provider.accessToken {
                calendarProvider.configure(accessToken: accessToken, refreshToken: provider.refreshToken)
                
                do {
                    let busySlots = try await calendarProvider.getAvailability(
                        userID: userID,
                        startDate: startDate,
                        endDate: endDate
                    )
                    
                    let busyPeriods = busySlots.map { slot in
                        BusyTimePeriod(
                            startTime: slot.startTime,
                            endTime: slot.endTime,
                            title: slot.title,
                            isAllDay: slot.isAllDay
                        )
                    }
                    
                    allBusyPeriods.append(contentsOf: busyPeriods)
                } catch {
                    print("Error getting availability for provider \(provider.providerType): \(error.localizedDescription)")
                    // Continue with other providers instead of failing completely
                }
            }
        }
        
        // Merge overlapping busy periods
        return mergeBusyPeriods(allBusyPeriods)
    }
    
    public func findMutualAvailability(userIDs: [String], startRange: Date, endRange: Date, duration: TimeInterval) async throws -> [DateInterval] {
        var allBusyPeriods: [BusyTimePeriod] = []
        
        // Get busy periods for each user
        for userID in userIDs {
            let userBusyPeriods = try await getBusyTimePeriods(
                for: userID,
                startDate: startRange,
                endDate: endRange
            )
            allBusyPeriods.append(contentsOf: userBusyPeriods)
        }
        
        // Merge all busy periods
        let mergedBusyPeriods = mergeBusyPeriods(allBusyPeriods)
        
        // Convert to availability slots
        let availabilitySlots = try await findAvailableTimeSlots(
            startDate: startRange,
            endDate: endRange,
            duration: Int(duration / 60),
            busyPeriods: mergedBusyPeriods
        )
        
        // Convert to DateInterval format
        return availabilitySlots.map { slot in
            DateInterval(start: slot.startTime, duration: TimeInterval(slot.durationMinutes * 60))
        }
    }
    
    public func findAvailableTimeSlots(startDate: Date, endDate: Date, duration: Int, busyPeriods: [BusyTimePeriod]) async throws -> [AvailabilitySlot] {
        // Ensure busy periods are merged and sorted
        let mergedBusyPeriods = mergeBusyPeriods(busyPeriods).sorted { $0.startTime < $1.startTime }
        
        var availableSlots: [AvailabilitySlot] = []
        var currentStart = startDate
        
        // Process each busy period
        for busyPeriod in mergedBusyPeriods {
            // If there's time before this busy period, it's available
            if currentStart < busyPeriod.startTime {
                let slotEndTime = busyPeriod.startTime
                let slotDuration = Int(slotEndTime.timeIntervalSince(currentStart) / 60)
                
                // Only add if the slot is long enough for the requested duration
                if slotDuration >= duration {
                    availableSlots.append(AvailabilitySlot(startTime: currentStart, durationMinutes: slotDuration))
                }
            }
            
            // Move current start to after this busy period
            currentStart = busyPeriod.endTime
        }
        
        // Check if there's available time after the last busy period
        if currentStart < endDate {
            let finalSlotDuration = Int(endDate.timeIntervalSince(currentStart) / 60)
            
            if finalSlotDuration >= duration {
                availableSlots.append(AvailabilitySlot(startTime: currentStart, durationMinutes: finalSlotDuration))
            }
        }
        
        return availableSlots
    }
    
    // MARK: - Event Management
    
    public func createCalendarEvent(_ event: CalendarEventModel) async throws -> String {
        // Generate a document ID if not provided
        let eventID = event.id.isEmpty ? UUID().uuidString : event.id
        var eventWithID = event
        eventWithID.id = eventID
        
        // Save to Firestore
        let eventData = try FirestoreEncoder().encode(eventWithID) as! [String: Any]
        try await db.collection(eventsCollection).document(eventID).setData(eventData)
        
        return eventID
    }
    
    public func createCalendarEvent(for hangout: Hangout, userIDs: [String]) async throws -> String {
        guard let startDate = hangout.startDate, let endDate = hangout.endDate else {
            throw NSError(domain: "FirebaseCalendarService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Hangout must have start and end dates"])
        }
        
        let event = CalendarEventModel(
            id: UUID().uuidString,
            title: hangout.title ?? "Hangout",
            description: hangout.description ?? "",
            startDate: startDate,
            endDate: endDate,
            location: hangout.location,
            hangoutId: hangout.id
        )
        
        // Save to Firestore
        let eventID = try await createCalendarEvent(event)
        
        // Add the event to each user's calendar
        for userID in userIDs {
            try await addEventToUserCalendars(eventID: eventID, userID: userID, event: event)
        }
        
        return eventID
    }
    
    public func getCalendarEvent(_ id: String) async throws -> CalendarEventModel {
        let document = try await db.collection(eventsCollection).document(id).getDocument()
        
        guard let data = document.data(), !data.isEmpty else {
            throw NSError(domain: "FirebaseCalendarService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Calendar event not found"])
        }
        
        var event = try FirestoreDecoder().decode(CalendarEventModel.self, from: data)
        if event.id.isEmpty {
            event.id = document.documentID
        }
        
        return event
    }
    
    public func updateCalendarEvent(_ id: String, with event: CalendarEventModel) async throws {
        var updatedEvent = event
        updatedEvent.id = id
        
        let eventData = try FirestoreEncoder().encode(updatedEvent) as! [String: Any]
        try await db.collection(eventsCollection).document(id).updateData(eventData)
    }
    
    public func deleteCalendarEvent(_ id: String) async throws {
        try await db.collection(eventsCollection).document(id).delete()
    }
    
    // MARK: - Authentication
    
    public func authenticateCalendarAccess(for userID: String) async throws {
        // Default to Google calendar
        try await authenticateCalendarAccess(for: userID, providerType: .google)
    }
    
    public func authenticateCalendarAccess(for userID: String, providerType: CalendarProviderType) async throws {
        let calendarAuthService = CalendarAuthService.shared
        try await calendarAuthService.authenticateAndSaveCalendarAccess(for: userID, providerType: providerType)
    }
    
    // MARK: - Synchronization
    
    public func synchronizeCalendarEvents(for userID: String) async throws -> Int {
        let providers = try await getCalendarProviders(for: userID)
        let enabledProviders = providers.filter { $0.isEnabled }
        
        if enabledProviders.isEmpty {
            return 0
        }
        
        var syncedEventsCount = 0
        
        for provider in enabledProviders {
            let calendarProvider = providerFactory.getProvider(for: provider.providerType)
            
            if let accessToken = provider.accessToken {
                calendarProvider.configure(accessToken: accessToken, refreshToken: provider.refreshToken)
                
                // Sync logic would go here
                // For now, this is a placeholder that would be implemented
                // based on the specific requirements
                
                syncedEventsCount += 1
            }
        }
        
        return syncedEventsCount
    }
    
    // MARK: - Private Helper Methods
    
    /// Add an event to a user's calendar providers
    /// - Parameters:
    ///   - eventID: The event ID
    ///   - userID: The user ID
    ///   - event: The event to add
    private func addEventToUserCalendars(eventID: String, userID: String, event: CalendarEventModel) async throws {
        let providers = try await getCalendarProviders(for: userID)
        let enabledProviders = providers.filter { $0.isEnabled }
        
        if enabledProviders.isEmpty {
            return
        }
        
        for provider in enabledProviders {
            let calendarProvider = providerFactory.getProvider(for: provider.providerType)
            
            if let accessToken = provider.accessToken {
                calendarProvider.configure(accessToken: accessToken, refreshToken: provider.refreshToken)
                
                do {
                    _ = try await calendarProvider.createEvent(event: event, userID: userID)
                } catch {
                    print("Error creating event in provider \(provider.providerType): \(error.localizedDescription)")
                    // Continue with other providers instead of failing completely
                }
            }
        }
    }
    
    /// Merge overlapping busy periods
    /// - Parameter busyPeriods: Busy periods to merge
    /// - Returns: Merged busy periods
    private func mergeBusyPeriods(_ busyPeriods: [BusyTimePeriod]) -> [BusyTimePeriod] {
        guard !busyPeriods.isEmpty else {
            return []
        }
        
        // Sort by start time
        let sortedPeriods = busyPeriods.sorted { $0.startTime < $1.startTime }
        
        var mergedPeriods: [BusyTimePeriod] = []
        var currentPeriod = sortedPeriods[0]
        
        for i in 1..<sortedPeriods.count {
            let period = sortedPeriods[i]
            
            // Check if periods overlap
            if period.startTime <= currentPeriod.endTime {
                // Merge periods
                currentPeriod = BusyTimePeriod(
                    startTime: currentPeriod.startTime,
                    endTime: max(currentPeriod.endTime, period.endTime),
                    title: currentPeriod.title,
                    isAllDay: currentPeriod.isAllDay || period.isAllDay
                )
            } else {
                // Add current period and start a new one
                mergedPeriods.append(currentPeriod)
                currentPeriod = period
            }
        }
        
        // Add the last period
        mergedPeriods.append(currentPeriod)
        
        return mergedPeriods
    }
}

/// Factory for creating calendar providers
class CalendarProviderFactory {
    /// Get a calendar provider for the specified type
    /// - Parameter type: The type of calendar provider
    /// - Returns: A calendar provider instance
    func getProvider(for type: CalendarProviderType) -> CalendarProviderProtocol {
        switch type {
        case .google:
            return GoogleCalendarProvider()
        case .outlook:
            return OutlookCalendarProvider()
        case .apple:
            return AppleCalendarProvider()
        }
    }
}

/// A time period when a user is busy
public struct BusyTimePeriod {
    /// Start time of the busy period
    public let startTime: Date
    
    /// End time of the busy period
    public let endTime: Date
    
    /// Optional title of the event
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

/// A slot of available time
public struct AvailabilitySlot {
    /// Start time of the available slot
    public let startTime: Date
    
    /// Duration of the available slot in minutes
    public let durationMinutes: Int
    
    public init(startTime: Date, durationMinutes: Int) {
        self.startTime = startTime
        self.durationMinutes = durationMinutes
    }
} 