import Foundation
import Firebase
import FirebaseFirestore


/// Service for fetching calendar-related data
public class CalendarDataFetchService {
    /// Shared instance of the service
    public static let shared = CalendarDataFetchService()
    
    /// Firestore database reference
    private let db = Firestore.firestore()
    
    /// CRUD service for database operations
    private let crudService: CRUDService
    
    /// Initialize the service
    public init() {
        self.crudService = ServiceManager.shared.getService(CRUDService.self)
        print("📆 CalendarDataFetchService initialized")
    }
    
    /// Get busy time periods for a user
    /// - Parameters:
    ///   - userID: The user ID
    ///   - startDate: Start date of the range
    ///   - endDate: End date of the range
    /// - Returns: Array of busy time periods
    public func getBusyTimePeriods(for userID: String, startDate: Date, endDate: Date) async throws -> [BusyTimePeriod] {
        // Get all calendar events for the user in the date range
        let events = try await getCalendarEvents(for: userID, startDate: startDate, endDate: endDate)
        
        // Convert events to busy periods
        return events.map { event in
            BusyTimePeriod(
                start: event.startDate,
                end: event.endDate,
                title: event.title,
                isAllDay: event.isAllDay
            )
        }
    }
    
    /// Get calendar events for a user
    /// - Parameters:
    ///   - userID: The user ID
    ///   - startDate: Start date of the range
    ///   - endDate: End date of the range
    /// - Returns: Array of calendar events
    public func getCalendarEvents(for userID: String, startDate: Date, endDate: Date) async throws -> [CalendarEvent] {
        // Query the events collection
        let events: [CalendarEvent] = try await crudService.queryWhere("calendarEvents", conditions: [
            "userID": userID,
            "startDate": FieldValue.arrayContains([startDate, endDate])
        ])
        
        return events
    }
    
    /// Get available time slots for a relationship
    /// - Parameters:
    ///   - relationshipID: The relationship ID
    ///   - startDate: Start date of the range
    ///   - endDate: End date of the range
    ///   - duration: Duration in minutes for each slot
    /// - Returns: Dictionary mapping dates to available time slots
    public func getAvailableTimeSlots(
        for relationshipID: String,
        startDate: Date,
        endDate: Date,
        duration: Int
    ) async throws -> [Date: [AvailabilityTimeSlot]] {
        // Get the relationship document to find user IDs
        let relationship: [String: Any]? = try await crudService.read(relationshipID, from: "relationships")
        
        guard let relationship = relationship,
              let userIDs = relationship["userIDs"] as? [String],
              userIDs.count == 2 else {
            throw NSError(domain: "CalendarDataFetchService", code: 404, 
                          userInfo: [NSLocalizedDescriptionKey: "Relationship not found or invalid"])
        }
        
        // Get busy times for both users
        var allBusySlots: [Date: [BusyTimeSlot]] = [:]
        
        for userID in userIDs {
            let busyPeriods = try await getBusyTimePeriods(for: userID, startDate: startDate, endDate: endDate)
            
            // Group by date
            let calendar = Calendar.current
            for period in busyPeriods {
                let dateKey = calendar.startOfDay(for: period.startTime)
                
                if allBusySlots[dateKey] == nil {
                    allBusySlots[dateKey] = []
                }
                
                allBusySlots[dateKey]?.append(BusyTimeSlot(
                    startTime: period.startTime,
                    endTime: period.endTime,
                    title: period.title,
                    isAllDay: period.isAllDay
                ))
            }
        }
        
        // Calculate available slots
        return calculateAvailableSlots(
            busyTimesByDate: allBusySlots,
            startDate: startDate,
            endDate: endDate,
            duration: duration
        )
    }
    
    /// Calculate available time slots based on busy times
    /// - Parameters:
    ///   - busyTimesByDate: Dictionary of busy times by date
    ///   - startDate: Start date of the range
    ///   - endDate: End date of the range
    ///   - duration: Duration in minutes for each slot
    /// - Returns: Dictionary mapping dates to available time slots
    private func calculateAvailableSlots(
        busyTimesByDate: [Date: [BusyTimeSlot]],
        startDate: Date,
        endDate: Date,
        duration: Int
    ) -> [Date: [AvailabilityTimeSlot]] {
        let calendar = Calendar.current
        let durationInSeconds = TimeInterval(duration * 60)
        var availableSlots: [Date: [AvailabilityTimeSlot]] = [:]
        
        // Get user preferences (default for now)
        let preferences = AvailabilityPreferences()
        
        // Iterate through each day in the range
        var currentDate = calendar.startOfDay(for: startDate)
        let endDateDay = calendar.startOfDay(for: endDate)
        
        while currentDate <= endDateDay {
            let busyTimes = busyTimesByDate[currentDate] ?? []
            
            // Skip weekends if excluded in preferences
            if preferences.excludeWeekends {
                let weekday = calendar.component(.weekday, from: currentDate)
                if weekday == 1 || weekday == 7 { // Sunday = 1, Saturday = 7
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                    continue
                }
            }
            
            // Skip days not in preferred days of week
            let weekday = calendar.component(.weekday, from: currentDate)
            if !preferences.preferredDaysOfWeek.contains(weekday) {
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                continue
            }
            
            // Use default time range if no preferences set
            let timeRanges = preferences.preferredTimeRanges.isEmpty ? 
                [TimeRange(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)] : 
                preferences.preferredTimeRanges
            
            var daySlots: [AvailabilityTimeSlot] = []
            
            // For each preferred time range in the day
            for range in timeRanges {
                // Create date components for start and end of range
                var startComps = calendar.dateComponents([.year, .month, .day], from: currentDate)
                startComps.hour = range.startHour
                startComps.minute = range.startMinute
                
                var endComps = calendar.dateComponents([.year, .month, .day], from: currentDate)
                endComps.hour = range.endHour
                endComps.minute = range.endMinute
                
                // Create the actual date objects
                guard let rangeStart = calendar.date(from: startComps),
                      let rangeEnd = calendar.date(from: endComps) else {
                    continue
                }
                
                // Skip if end is before start
                if rangeEnd <= rangeStart {
                    continue
                }
                
                // Create slots within this time range
                var slotStart = rangeStart
                
                while slotStart.addingTimeInterval(durationInSeconds) <= rangeEnd {
                    let slotEnd = slotStart.addingTimeInterval(durationInSeconds)
                    
                    // Check if this slot conflicts with any busy times
                    let isAvailable = !busyTimes.contains { busyTime in
                        max(slotStart, busyTime.startTime) < min(slotEnd, busyTime.endTime)
                    }
                    
                    if isAvailable {
                        daySlots.append(AvailabilityTimeSlot(
                            startTime: slotStart,
                            endTime: slotEnd
                        ))
                    }
                    
                    // Move to next slot (30-minute intervals)
                    slotStart = slotStart.addingTimeInterval(30 * 60)
                }
            }
            
            // Store slots for this day
            if !daySlots.isEmpty {
                availableSlots[currentDate] = daySlots
            }
            
            // Move to next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return availableSlots
    }
} 