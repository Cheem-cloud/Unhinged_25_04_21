import Foundation

/// Adapter for calendar services that implements the CRUDService protocol
public class CalendarServiceAdapter: CRUDService {
    private let calendarDataFetchService: CalendarDataFetchService
    private let calendarAuthService: CalendarAuthService
    private let calendarSyncService: CalendarSynchronizationService
    
    public required init() {
        self.calendarDataFetchService = CalendarDataFetchService()
        self.calendarAuthService = CalendarAuthService()
        self.calendarSyncService = CalendarSynchronizationService()
    }
    
    public required init(identifier: String) {
        self.calendarDataFetchService = CalendarDataFetchService()
        self.calendarAuthService = CalendarAuthService()
        self.calendarSyncService = CalendarSynchronizationService()
    }
    
    // MARK: - Event Creation
    
    /// Create a calendar event across providers
    public func create(_ model: CalendarEventModel) async throws -> String {
        return try await calendarDataFetchService.createCalendarEvent(model)
    }
    
    /// Create a calendar event for a hangout
    public func createCalendarEvent(for hangout: Hangout, userIDs: [String]) async throws -> String {
        let event = CalendarEventModel(
            id: UUID().uuidString,
            title: hangout.title ?? "Hangout",
            description: hangout.description ?? "",
            startDate: hangout.startDate ?? Date(),
            endDate: hangout.endDate ?? Date().addingTimeInterval(3600),
            location: hangout.location,
            hangoutId: hangout.id
        )
        
        return try await calendarDataFetchService.createCalendarEvent(event, for: userIDs)
    }
    
    // MARK: - Provider Management
    
    /// Get all calendar providers for a user
    public func getCalendarProviders(for userId: String) async throws -> [CalendarProvider] {
        return try await calendarAuthService.getCalendarProviders(for: userId)
    }
    
    /// Enable or disable a calendar provider
    public func updateCalendarProviderStatus(id: String, isEnabled: Bool) async throws {
        try await calendarAuthService.updateCalendarProviderStatus(id: id, isEnabled: isEnabled)
    }
    
    /// Add a new calendar provider
    public func addCalendarProvider(_ provider: CalendarProvider) async throws {
        try await calendarAuthService.addCalendarProvider(provider)
    }
    
    /// Remove a calendar provider
    public func removeCalendarProvider(id: String) async throws {
        try await calendarAuthService.removeCalendarProvider(id: id)
    }
    
    // MARK: - Availability Methods
    
    /// Find available time slots based on busy periods
    public func findAvailableTimeSlots(startDate: Date, endDate: Date, duration: Int, 
                                      busyPeriods: [BusyTimePeriod]) async throws -> [AvailabilitySlot] {
        return try await calendarDataFetchService.findAvailableTimeSlots(
            startDate: startDate, 
            endDate: endDate, 
            duration: duration, 
            busyPeriods: busyPeriods
        )
    }
    
    /// Get busy time periods for a user in a date range
    public func getBusyTimePeriods(for userId: String, startDate: Date, endDate: Date) async throws -> [BusyTimePeriod] {
        return try await calendarDataFetchService.getBusyTimePeriods(
            for: userId, 
            startDate: startDate, 
            endDate: endDate
        )
    }
    
    // MARK: - CRUDService Protocol
    
    public func read<T>(_ id: String) async throws -> T where T : Decodable, T : Encodable, T : Identifiable {
        guard let result = try await calendarDataFetchService.getCalendarEvent(id) as? T else {
            throw ServiceError.invalidModelType
        }
        return result
    }
    
    public func update<T>(_ model: T) async throws where T : Decodable, T : Encodable, T : Identifiable {
        guard let event = model as? CalendarEventModel else {
            throw ServiceError.invalidModelType
        }
        try await calendarDataFetchService.updateCalendarEvent(event)
    }
    
    public func delete<T>(_ model: T) async throws where T : Decodable, T : Encodable, T : Identifiable {
        guard let event = model as? CalendarEventModel else {
            throw ServiceError.invalidModelType
        }
        try await calendarDataFetchService.deleteCalendarEvent(event.id)
    }
    
    public func list<T>() async throws -> [T] where T : Decodable, T : Encodable, T : Identifiable {
        guard T.self == CalendarEventModel.self else {
            throw ServiceError.invalidModelType
        }
        let events = try await calendarDataFetchService.getAllCalendarEvents()
        return events as! [T]
    }
}

/// Basic service error types
public enum ServiceError: Error {
    case invalidModelType
    case notFound
    case unauthorized
    case networkError
    case serverError
    case decodingError
    case encodingError
    case unknownError
} 