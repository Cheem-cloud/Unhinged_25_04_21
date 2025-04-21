import Foundation
import FirebaseFirestore
import Combine

/// Service responsible for synchronizing calendar data between different providers and the app
class CalendarSynchronizationService {
    // MARK: - Properties
    private let calendarAdapter: CalendarServiceAdapter
    private let calendarAuthService = CalendarAuthService.shared
    private let firestoreService: FirestoreService
    private let calendarOpsService: CalendarOperationsService
    private let calendarDataFetchService: CalendarDataFetchService
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        firestoreService: FirestoreService,
        calendarOpsService: CalendarOperationsService,
        calendarDataFetchService: CalendarDataFetchService
    ) {
        self.firestoreService = firestoreService
        self.calendarOpsService = calendarOpsService
        self.calendarDataFetchService = calendarDataFetchService
        self.calendarAdapter = ServiceManager.shared.getService(CRUDService.self) as! CalendarServiceAdapter
    }
    
    // MARK: - Synchronization Methods
    
    /// Synchronizes calendar events from all connected providers to Firestore
    /// - Parameter userId: The user ID
    /// - Returns: Number of events synchronized
    func synchronizeAllCalendars(for userId: String) async throws -> Int {
        // Get user's calendar settings
        guard let calendarSettings = try await calendarOpsService.getCalendarSettings(for: userId) else {
            throw CalendarError.settingsNotFound
        }
        
        var totalSyncedEvents = 0
        
        // Synchronize each connected provider
        for provider in calendarSettings.connectedProviders {
            do {
                let syncCount = try await synchronizeCalendar(for: userId, provider: provider)
                totalSyncedEvents += syncCount
                print("Successfully synchronized \(syncCount) events from \(provider)")
            } catch {
                print("Error synchronizing \(provider) calendar: \(error.localizedDescription)")
                // Continue with other providers even if one fails
            }
        }
        
        return totalSyncedEvents
    }
    
    /// Synchronizes calendar events from a specific provider to Firestore
    /// - Parameters:
    ///   - userId: The user ID
    ///   - provider: The calendar provider to synchronize
    /// - Returns: Number of events synchronized
    func synchronizeCalendar(for userId: String, provider: CalendarProvider) async throws -> Int {
        // Get token for provider
        guard let token = try await calendarOpsService.getCalendarToken(for: userId, provider: provider) else {
            throw CalendarError.authenticationFailed
        }
        
        // Calculate date range for synchronization (default: next 30 days)
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate)!
        
        // Fetch events from provider
        let events: [CalendarEventModel]
        if provider == .apple {
            events = try await calendarDataFetchService.fetchAppleCalendarEvents(startDate: startDate, endDate: endDate)
        } else {
            events = try await calendarDataFetchService.fetchCalendarEvents(
                provider: provider,
                accessToken: token,
                startDate: startDate,
                endDate: endDate
            )
        }
        
        // Store events in Firestore
        let syncCount = try await storeEventsInFirestore(userId: userId, events: events, provider: provider)
        
        return syncCount
    }
    
    /// Stores calendar events in Firestore
    /// - Parameters:
    ///   - userId: The user ID
    ///   - events: The events to store
    ///   - provider: The calendar provider
    /// - Returns: Number of events stored
    private func storeEventsInFirestore(userId: String, events: [CalendarEventModel], provider: CalendarProvider) async throws -> Int {
        let eventsCollection = firestoreService.db.collection("users/\(userId)/calendarEvents")
        
        // First, get existing events for this provider
        let snapshot = try await eventsCollection
            .whereField("provider", isEqualTo: provider.rawValue)
            .getDocuments()
        
        // Create a dictionary of existing events by ID for quick lookup
        var existingEvents = [String: DocumentSnapshot]()
        for document in snapshot.documents {
            if let eventId = document.data()["eventId"] as? String {
                existingEvents[eventId] = document
            }
        }
        
        var storedCount = 0
        
        // Process each event
        for event in events {
            do {
                let eventData: [String: Any] = [
                    "eventId": event.id,
                    "title": event.title,
                    "description": event.description ?? "",
                    "startDate": event.startDate,
                    "endDate": event.endDate,
                    "isAllDay": event.isAllDay,
                    "location": event.location ?? "",
                    "colorHex": event.colorHex,
                    "calendarID": event.calendarID,
                    "calendarName": event.calendarName,
                    "provider": provider.rawValue,
                    "availabilityStatus": event.availability.rawValue,
                    "eventStatus": event.status.rawValue,
                    "lastSyncTime": Timestamp(date: Date())
                ]
                
                // Check if event already exists
                if let existingDoc = existingEvents[event.id] {
                    // Update existing event
                    try await existingDoc.reference.updateData(eventData)
                } else {
                    // Create new event document
                    try await eventsCollection.addDocument(data: eventData)
                }
                
                storedCount += 1
            } catch {
                print("Error storing event \(event.id): \(error.localizedDescription)")
                // Continue with other events even if one fails
            }
        }
        
        // Remove events that no longer exist on the provider
        var deletedCount = 0
        for (eventId, document) in existingEvents {
            if !events.contains(where: { $0.id == eventId }) {
                do {
                    try await document.reference.delete()
                    deletedCount += 1
                } catch {
                    print("Error deleting obsolete event \(eventId): \(error.localizedDescription)")
                }
            }
        }
        
        print("Synchronized \(storedCount) events, deleted \(deletedCount) obsolete events for provider \(provider)")
        
        return storedCount
    }
    
    // MARK: - Scheduling and Automation
    
    /// Schedules periodic synchronization for a user
    /// - Parameters:
    ///   - userId: The user ID
    ///   - interval: Synchronization interval in hours (default: 6)
    func schedulePeriodicSync(for userId: String, interval: TimeInterval = 6 * 3600) {
        // Cancel any existing sync timers for this user
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        // Create a timer publisher for periodic sync
        Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    do {
                        let syncCount = try await self?.synchronizeAllCalendars(for: userId) ?? 0
                        print("Periodic sync completed for user \(userId): \(syncCount) events")
                    } catch {
                        print("Error during periodic sync for user \(userId): \(error.localizedDescription)")
                    }
                }
            }
            .store(in: &cancellables)
        
        // Run initial sync immediately
        Task {
            do {
                let syncCount = try await synchronizeAllCalendars(for: userId)
                print("Initial sync completed for user \(userId): \(syncCount) events")
            } catch {
                print("Error during initial sync for user \(userId): \(error.localizedDescription)")
            }
        }
    }
    
    /// Stops periodic synchronization for a user
    func stopPeriodicSync() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolves conflicts between events from different calendar providers
    /// - Parameter userId: The user ID
    /// - Returns: Number of conflicts resolved
    func resolveCalendarConflicts(for userId: String) async throws -> Int {
        // Get user's calendar settings
        guard let calendarSettings = try await calendarOpsService.getCalendarSettings(for: userId) else {
            throw CalendarError.settingsNotFound
        }
        
        // Calculate date range for conflict resolution (default: next 30 days)
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate)!
        
        // Fetch all events from all providers
        var allEvents: [CalendarEventModel] = []
        
        for provider in calendarSettings.connectedProviders {
            do {
                let providerEvents = try await calendarDataFetchService.fetchEvents(
                    for: userId,
                    provider: provider,
                    startDate: startDate,
                    endDate: endDate
                )
                allEvents.append(contentsOf: providerEvents)
            } catch {
                print("Error fetching events from \(provider): \(error.localizedDescription)")
                // Continue with other providers even if one fails
            }
        }
        
        // Sort events by start date
        allEvents.sort { $0.startDate < $1.startDate }
        
        // Find overlapping events
        var conflicts = 0
        var resolvedConflicts = 0
        
        for i in 0..<allEvents.count {
            for j in (i+1)..<allEvents.count {
                let event1 = allEvents[i]
                let event2 = allEvents[j]
                
                // Skip if events are from the same provider (they'll handle their own conflicts)
                if event1.provider == event2.provider {
                    continue
                }
                
                // Check for time overlap
                if event1.endDate > event2.startDate && event1.startDate < event2.endDate {
                    conflicts += 1
                    
                    // Apply conflict resolution strategy based on event properties
                    if tryResolveConflict(event1: event1, event2: event2, userId: userId) {
                        resolvedConflicts += 1
                    }
                }
            }
        }
        
        print("Found \(conflicts) conflicts, resolved \(resolvedConflicts)")
        return resolvedConflicts
    }
    
    /// Attempts to resolve a conflict between two events
    /// - Parameters:
    ///   - event1: First conflicting event
    ///   - event2: Second conflicting event
    ///   - userId: The user ID
    /// - Returns: Whether the conflict was resolved
    private func tryResolveConflict(event1: CalendarEventModel, event2: CalendarEventModel, userId: String) -> Bool {
        // Simple conflict resolution strategy:
        // 1. If one event has .free availability, no action needed
        // 2. If one event is .tentative and the other is .busy, mark the tentative one
        
        if event1.availability == .free || event2.availability == .free {
            // No conflict if one event has free availability
            return true
        }
        
        // Store conflict for review if both are busy
        if event1.availability == .busy && event2.availability == .busy {
            Task {
                try? await storeConflictForReview(
                    userId: userId,
                    event1: event1,
                    event2: event2
                )
            }
            return false
        }
        
        // Apply other resolution strategies as needed
        return false
    }
    
    /// Stores a calendar conflict for later review
    /// - Parameters:
    ///   - userId: The user ID
    ///   - event1: First conflicting event
    ///   - event2: Second conflicting event
    private func storeConflictForReview(userId: String, event1: CalendarEventModel, event2: CalendarEventModel) async throws {
        let conflictsCollection = firestoreService.db.collection("users/\(userId)/calendarConflicts")
        
        let conflictData: [String: Any] = [
            "createdAt": Timestamp(date: Date()),
            "resolved": false,
            "event1": [
                "id": event1.id,
                "title": event1.title,
                "startDate": event1.startDate,
                "endDate": event1.endDate,
                "provider": event1.provider.rawValue
            ],
            "event2": [
                "id": event2.id,
                "title": event2.title,
                "startDate": event2.startDate,
                "endDate": event2.endDate,
                "provider": event2.provider.rawValue
            ]
        ]
        
        try await conflictsCollection.addDocument(data: conflictData)
    }
} 