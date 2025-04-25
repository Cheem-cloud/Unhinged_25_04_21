import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth


/// Firebase implementation of the AvailabilityService protocol
public class FirebaseAvailabilityService: AvailabilityService {
    /// Firebase Firestore database
    private let db = Firestore.firestore()
    
    /// Calendar service for checking calendar availability
    private let calendarService: CalendarService?
    
    /// Relationship service for relationship validation
    private let relationshipService: RelationshipService?
    
    public init(calendarService: CalendarService? = nil, relationshipService: RelationshipService? = nil) {
        self.calendarService = calendarService
        self.relationshipService = relationshipService
        print("📱 FirebaseAvailabilityService initialized")
    }
    
    public func getCoupleAvailability(for relationshipID: String) async throws -> CoupleAvailability {
        let document = try await db.collection("coupleAvailability").document(relationshipID).getDocument()
        
        if let data = document.data(), !data.isEmpty {
            var availability = try FirestoreDecoder().decode(CoupleAvailability.self, from: data)
            if availability.id == nil {
                availability.id = document.documentID
            }
            return availability
        } else {
            // Create default availability if none exists
            let defaultAvailability = CoupleAvailability(relationshipID: relationshipID)
            try await saveCoupleAvailability(defaultAvailability, for: relationshipID)
            return defaultAvailability
        }
    }
    
    public func saveCoupleAvailability(_ availability: CoupleAvailability, for relationshipID: String) async throws {
        var updatedAvailability = availability
        updatedAvailability.relationshipID = relationshipID
        updatedAvailability.updatedAt = Date()
        
        let availabilityData = try FirestoreEncoder().encode(updatedAvailability) as? [String: Any] ?? [:]
        try await db.collection("coupleAvailability").document(relationshipID).setData(availabilityData, merge: true)
    }
    
    public func getAvailableTimeSlots(
        for relationshipID: String,
        startDate: Date,
        endDate: Date,
        duration: Int
    ) async throws -> [Date: [AvailabilityTimeSlot]] {
        // Get the couple's availability preferences
        let coupleAvailability = try await getCoupleAvailability(for: relationshipID)
        
        // Validate the time range
        if endDate <= startDate {
            throw AvailabilityError(errorType: .invalidTimeRange)
        }
        
        if duration < 15 || duration > 12 * 60 {
            throw AvailabilityError(errorType: .invalidDuration)
        }
        
        // Get the calendar busy times if using calendars
        var busyTimesByDate: [Date: [BusyTimeSlot]] = [:]
        
        if coupleAvailability.useCalendars, let calendarService = calendarService, let relationship = try await validateRelationship(relationshipID) {
            let userIDs = [relationship.initiatorID, relationship.partnerID]
            
            // Create a dictionary to store busy times by date
            let calendar = Calendar.current
            
            // Get busy times for each user and merge them
            for userID in userIDs {
                if let busyTimes = try? await getBusyTimesForUser(userID, startDate: startDate, endDate: endDate) {
                    for (date, slots) in busyTimes {
                        let dateKey = calendar.startOfDay(for: date)
                        if busyTimesByDate[dateKey] == nil {
                            busyTimesByDate[dateKey] = []
                        }
                        busyTimesByDate[dateKey]?.append(contentsOf: slots)
                    }
                }
            }
        }
        
        // Calculate available slots based on preferences and busy times
        return try await calculateAvailableSlots(
            coupleAvailability: coupleAvailability,
            busyTimesByDate: busyTimesByDate,
            startDate: startDate,
            endDate: endDate,
            duration: duration
        )
    }
    
    public func getAvailableTimeSlotsForDay(
        for relationshipID: String,
        date: Date,
        duration: Int
    ) async throws -> [AvailabilityTimeSlot] {
        // Get the couple's availability preferences
        let coupleAvailability = try await getCoupleAvailability(for: relationshipID)
        
        // Validate the duration
        if duration < 15 || duration > 12 * 60 {
            throw AvailabilityError(errorType: .invalidDuration)
        }
        
        // Calculate the day's start and end
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Get busy times for the day if using calendars
        var busyTimes: [BusyTimeSlot] = []
        
        if coupleAvailability.useCalendars, let calendarService = calendarService, let relationship = try await validateRelationship(relationshipID) {
            let userIDs = [relationship.initiatorID, relationship.partnerID]
            
            // Get busy times for each user and merge them
            for userID in userIDs {
                if let userBusyTimes = try? await getBusyTimesForUser(userID, startDate: startOfDay, endDate: endOfDay) {
                    if let dayBusyTimes = userBusyTimes[startOfDay] {
                        busyTimes.append(contentsOf: dayBusyTimes)
                    }
                }
            }
        }
        
        // Calculate available slots for the day
        let availableSlotsDict = try await calculateAvailableSlots(
            coupleAvailability: coupleAvailability,
            busyTimesByDate: [startOfDay: busyTimes],
            startDate: startOfDay,
            endDate: endOfDay,
            duration: duration
        )
        
        // Return the slots for the requested day
        return availableSlotsDict[startOfDay] ?? []
    }
    
    public func findMutualAvailability(
        userIDs: [String],
        startDate: Date,
        endDate: Date,
        duration: Int
    ) async throws -> [Date: [AvailabilityTimeSlot]] {
        if userIDs.isEmpty {
            throw AvailabilityError(errorType: .invalidTimeRange)
        }
        
        // Validate the time range
        if endDate <= startDate {
            throw AvailabilityError(errorType: .invalidTimeRange)
        }
        
        if duration < 15 || duration > 12 * 60 {
            throw AvailabilityError(errorType: .invalidDuration)
        }
        
        // Create a dictionary to store busy times by date
        let calendar = Calendar.current
        var busyTimesByDate: [Date: [BusyTimeSlot]] = [:]
        
        // Get busy times for each user and merge them
        for userID in userIDs {
            if let busyTimes = try? await getBusyTimesForUser(userID, startDate: startDate, endDate: endDate) {
                for (date, slots) in busyTimes {
                    let dateKey = calendar.startOfDay(for: date)
                    if busyTimesByDate[dateKey] == nil {
                        busyTimesByDate[dateKey] = []
                    }
                    busyTimesByDate[dateKey]?.append(contentsOf: slots)
                }
            }
        }
        
        // Create a default couple availability with common preferences
        let defaultAvailability = CoupleAvailability(relationshipID: "temp")
        
        // Calculate available slots based on busy times
        return try await calculateAvailableSlots(
            coupleAvailability: defaultAvailability,
            busyTimesByDate: busyTimesByDate,
            startDate: startDate,
            endDate: endDate,
            duration: duration
        )
    }
    
    public func isTimeSlotAvailable(
        for relationshipID: String,
        startTime: Date,
        endTime: Date
    ) async throws -> Bool {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: startTime)
        let duration = Int(endTime.timeIntervalSince(startTime) / 60)
        
        let availableSlots = try await getAvailableTimeSlotsForDay(
            for: relationshipID, 
            date: startDate, 
            duration: duration
        )
        
        // Check if any available slot contains the requested time
        for slot in availableSlots {
            if slot.startTime <= startTime && slot.endTime >= endTime {
                return true
            }
        }
        
        return false
    }
    
    public func addRecurringCommitment(_ commitment: RecurringCommitment, for relationshipID: String) async throws {
        var availability = try await getCoupleAvailability(for: relationshipID)
        
        availability.recurringCommitments.append(commitment)
        
        try await saveCoupleAvailability(availability, for: relationshipID)
    }
    
    public func updateRecurringCommitment(_ commitment: RecurringCommitment, for relationshipID: String) async throws {
        var availability = try await getCoupleAvailability(for: relationshipID)
        
        if let index = availability.recurringCommitments.firstIndex(where: { $0.id == commitment.id }) {
            availability.recurringCommitments[index] = commitment
            try await saveCoupleAvailability(availability, for: relationshipID)
        } else {
            throw AvailabilityError(errorType: .internalError("Commitment not found"))
        }
    }
    
    public func deleteRecurringCommitment(_ commitmentID: String, for relationshipID: String) async throws {
        var availability = try await getCoupleAvailability(for: relationshipID)
        
        let initialCount = availability.recurringCommitments.count
        availability.recurringCommitments.removeAll { $0.id.uuidString == commitmentID }
        
        if availability.recurringCommitments.count == initialCount {
            throw AvailabilityError(errorType: .internalError("Commitment not found"))
        }
        
        try await saveCoupleAvailability(availability, for: relationshipID)
    }
    
    public func getUserAvailabilityPreferences(for userID: String) async throws -> AvailabilityPreferences {
        let document = try await db.collection("users").document(userID).collection("settings").document("availability").getDocument()
        
        if let data = document.data(), !data.isEmpty {
            return try FirestoreDecoder().decode(AvailabilityPreferences.self, from: data)
        } else {
            // Return default preferences
            return AvailabilityPreferences()
        }
    }
    
    public func saveUserAvailabilityPreferences(_ preferences: AvailabilityPreferences, for userID: String) async throws {
        let preferencesData = try FirestoreEncoder().encode(preferences) as? [String: Any] ?? [:]
        try await db.collection("users").document(userID).collection("settings").document("availability").setData(preferencesData, merge: true)
    }
    
    // MARK: - Private Helper Methods
    
    /// Check if a relationship exists and includes both users
    /// - Parameter relationshipID: ID of the relationship to validate
    /// - Returns: The validated relationship
    private func validateRelationship(_ relationshipID: String) async throws -> Relationship? {
        if let relationshipService = relationshipService {
            guard let relationship = try await relationshipService.getRelationship(id: relationshipID),
                  relationship.status == .active else {
                throw AvailabilityError(errorType: .relationshipNotFound)
            }
            return relationship
        }
        
        // If no relationship service, just check if the relationship document exists
        let doc = try await db.collection("relationships").document(relationshipID).getDocument()
        if !doc.exists {
            throw AvailabilityError(errorType: .relationshipNotFound)
        }
        
        return nil
    }
    
    /// Get busy times for a user from their calendar
    /// - Parameters:
    ///   - userID: ID of the user
    ///   - startDate: Start date to check
    ///   - endDate: End date to check
    /// - Returns: Dictionary mapping dates to busy time slots
    private func getBusyTimesForUser(_ userID: String, startDate: Date, endDate: Date) async throws -> [Date: [BusyTimeSlot]] {
        guard let calendarService = calendarService else {
            return [:]
        }
        
        let calendar = Calendar.current
        var busyTimesByDate: [Date: [BusyTimeSlot]] = [:]
        
        // Get busy time periods from the calendar service
        let busyPeriods = try await calendarService.getBusyTimePeriods(for: userID, startDate: startDate, endDate: endDate)
        
        // Organize busy periods by date
        for period in busyPeriods {
            // Convert to BusyTimeSlot
            let busySlot = BusyTimeSlot(
                startTime: period.startTime,
                endTime: period.endTime,
                title: period.title,
                isAllDay: period.isAllDay
            )
            
            // Organize by date
            let dateKey = calendar.startOfDay(for: period.startTime)
            if busyTimesByDate[dateKey] == nil {
                busyTimesByDate[dateKey] = []
            }
            busyTimesByDate[dateKey]?.append(busySlot)
        }
        
        return busyTimesByDate
    }
    
    /// Calculate available time slots based on preferences and busy times
    /// - Parameters:
    ///   - coupleAvailability: The couple's availability preferences
    ///   - busyTimesByDate: Dictionary of busy times by date
    ///   - startDate: Start date of the range
    ///   - endDate: End date of the range
    ///   - duration: Duration in minutes for each slot
    /// - Returns: Dictionary mapping dates to available time slots
    private func calculateAvailableSlots(
        coupleAvailability: CoupleAvailability,
        busyTimesByDate: [Date: [BusyTimeSlot]],
        startDate: Date,
        endDate: Date,
        duration: Int
    ) async throws -> [Date: [AvailabilityTimeSlot]] {
        let calendar = Calendar.current
        var availableSlots: [Date: [AvailabilityTimeSlot]] = [:]
        let durationSeconds = TimeInterval(duration * 60)
        
        var currentDate = calendar.startOfDay(for: startDate)
        let endDateDay = calendar.startOfDay(for: endDate)
        
        // Get the minimum advance notice in seconds
        let minimumAdvanceSeconds = Double(coupleAvailability.minimumAdvanceNotice * 3600)
        let now = Date()
        
        // Loop through each day in the range
        while currentDate <= endDateDay {
            // Get weekday for this date
            let calendarWeekday = calendar.component(.weekday, from: currentDate)
            guard let weekday = Unhinged.Weekday.fromCalendarWeekday(calendarWeekday) else {
                // Move to next day
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDateDay
                continue
            }
            
            // Check if this day has availability preferences
            guard let dayAvailability = coupleAvailability.dayAvailability.first(where: { $0.day == weekday }),
                  !dayAvailability.timeRanges.isEmpty else {
                // Move to next day
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDateDay
                continue
            }
            
            // Get busy times for this day
            let busyTimes = busyTimesByDate[currentDate] ?? []
            
            // Calculate available slots for this day
            var daySlots: [AvailabilityTimeSlot] = []
            
            // For each time range in the day's availability
            for timeRange in dayAvailability.timeRanges {
                // Convert time range to specific dates for this day
                var startComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
                startComponents.hour = timeRange.startHour
                startComponents.minute = timeRange.startMinute
                
                var endComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
                endComponents.hour = timeRange.endHour
                endComponents.minute = timeRange.endMinute
                
                guard let rangeStart = calendar.date(from: startComponents),
                      let rangeEnd = calendar.date(from: endComponents) else {
                    continue
                }
                
                // Skip if the start time has already passed plus minimum advance notice
                if rangeStart < now.addingTimeInterval(minimumAdvanceSeconds) {
                    continue
                }
                
                // Generate time slots at regular intervals within this range
                var slotStart = rangeStart
                while slotStart.addingTimeInterval(durationSeconds) <= rangeEnd {
                    let slotEnd = slotStart.addingTimeInterval(durationSeconds)
                    
                    // Check if this slot conflicts with any busy times
                    let isAvailable = !busyTimes.contains { busyTime in
                        max(slotStart, busyTime.startTime) < min(slotEnd, busyTime.endTime)
                    }
                    
                    // Check if this slot conflicts with any recurring commitments
                    let hasCommitmentConflict = hasConflictWithCommitments(
                        coupleAvailability: coupleAvailability,
                        startDate: slotStart,
                        endDate: slotEnd
                    )
                    
                    if isAvailable && !hasCommitmentConflict {
                        // Calculate rating based on slot position in the day
                        let rating = calculateSlotRating(slotStart: slotStart, slotEnd: slotEnd, busyTimes: busyTimes)
                        
                        daySlots.append(AvailabilityTimeSlot(
                            startTime: slotStart,
                            endTime: slotEnd,
                            availabilityRating: rating
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
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDateDay
        }
        
        return availableSlots
    }
    
    /// Check if a time slot conflicts with any recurring commitments
    /// - Parameters:
    ///   - coupleAvailability: The couple's availability preferences
    ///   - startDate: Start date to check
    ///   - endDate: End date to check
    /// - Returns: True if there's a conflict
    private func hasConflictWithCommitments(
        coupleAvailability: CoupleAvailability,
        startDate: Date,
        endDate: Date
    ) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: startDate)
        guard let uhDay = Unhinged.Weekday.fromCalendarWeekday(weekday) else {
            return false
        }
        
        // Get commitments for this weekday
        let dayCommitments = coupleAvailability.recurringCommitments.filter { $0.day == uhDay }
        
        // Extract hours and minutes from the date
        let startHour = calendar.component(.hour, from: startDate)
        let startMinute = calendar.component(.minute, from: startDate)
        let endHour = calendar.component(.hour, from: endDate)
        let endMinute = calendar.component(.minute, from: endDate)
        
        // Convert to minutes for easier comparison
        let slotStartMinutes = startHour * 60 + startMinute
        let slotEndMinutes = endHour * 60 + endMinute
        
        // Check for conflicts with any commitments
        return dayCommitments.contains { commitment in
            let commitmentStartMinutes = commitment.startHour * 60 + commitment.startMinute
            let commitmentEndMinutes = commitment.endHour * 60 + commitment.endMinute
            
            // Check if there's an overlap
            return max(slotStartMinutes, commitmentStartMinutes) < min(slotEndMinutes, commitmentEndMinutes)
        }
    }
    
    /// Calculate a rating for an availability slot
    /// - Parameters:
    ///   - slotStart: Start time of the slot
    ///   - slotEnd: End time of the slot
    ///   - busyTimes: Array of busy time slots
    /// - Returns: Rating for the slot
    private func calculateSlotRating(
        slotStart: Date,
        slotEnd: Date,
        busyTimes: [BusyTimeSlot]
    ) -> AvailabilityRating {
        // Check if there are busy slots right before or after this slot
        let hasBusyBefore = busyTimes.contains { busyTime in
            abs(busyTime.endTime.timeIntervalSince(slotStart)) < 60 * 30 // 30 minutes
        }
        
        let hasBusyAfter = busyTimes.contains { busyTime in
            abs(slotEnd.timeIntervalSince(busyTime.startTime)) < 60 * 30 // 30 minutes
        }
        
        // Calculate duration
        let duration = slotEnd.timeIntervalSince(slotStart) / 60 // in minutes
        
        // Rate based on duration and surrounding busy times
        if duration >= 120 && !hasBusyBefore && !hasBusyAfter {
            return .excellent
        } else if duration >= 90 || (!hasBusyBefore && !hasBusyAfter) {
            return .good
        } else {
            return .fair
        }
    }
}

// Use the definitions from CalendarModels.swift
// AvailabilityRating and AvailabilityTimeSlot are defined there

/// Busy time slot
public struct BusyTimeSlot: Codable {
    public var startTime: Date
    public var endTime: Date
    public var title: String?
    public var isAllDay: Bool
    
    public init(startTime: Date, endTime: Date, title: String? = nil, isAllDay: Bool = false) {
        self.startTime = startTime
        self.endTime = endTime
        self.title = title
        self.isAllDay = isAllDay
    }
} 