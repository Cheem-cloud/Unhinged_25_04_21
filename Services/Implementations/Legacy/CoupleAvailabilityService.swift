import Foundation
import Firebase
import FirebaseFirestore
import Combine
import FirebaseAuth

/// Service for managing couple availability preferences
class CoupleAvailabilityService {
    /// Shared instance (singleton)
    static let shared = CoupleAvailabilityService()
    
    /// Firestore instance
    private let db = Firestore.firestore()
    
    /// Firestore service
    private let firestoreService = FirestoreService.shared
    
    /// Relationship service
    private let relationshipService = RelationshipService.shared
    
    /// Calendar service
    private let calendarService: CalendarServiceAdapter
    private let calendarAuthService = CalendarAuthService.shared
    
    /// Collection name for couple availability
    private let availabilityCollection = "coupleAvailability"
    
    /// Initialize the service
    private init() {
        // Get CalendarServiceAdapter from ServiceManager
        self.calendarService = ServiceManager.shared.getService(CRUDService.self) as! CalendarServiceAdapter
    }
    
    /// Get a couple's availability preferences
    /// - Parameter relationshipID: The relationship ID
    /// - Returns: The couple's availability preferences, or nil if not found
    func getAvailability(relationshipID: String) async throws -> CoupleAvailability? {
        do {
            let query = db.collection(availabilityCollection)
                .whereField("relationshipID", isEqualTo: relationshipID)
                .limit(to: 1)
            
            let snapshot = try await query.getDocuments()
            
            if let document = snapshot.documents.first {
                return CoupleAvailability.fromFirestore(document)
            }
            
            return nil
        } catch {
            print("Error fetching availability: \(error.localizedDescription)")
            if let nsError = error as NSError?, nsError.domain == FirestoreErrorDomain {
                switch nsError.code {
                case FirestoreErrorCode.unavailable.rawValue:
                    throw AvailabilityError.networkTimeout
                case FirestoreErrorCode.permissionDenied.rawValue:
                    throw AvailabilityError.permissionDenied
                default:
                    throw error
                }
            } else {
                throw error
            }
        }
    }
    
    /// Create or update a couple's availability preferences
    /// - Parameter availability: The availability to save
    /// - Returns: The saved availability with its ID
    func saveAvailability(_ availability: CoupleAvailability) async throws -> CoupleAvailability {
        var updatedAvailability = availability
        updatedAvailability.updatedAt = Date()
        
        do {
            // Check if availability exists for this relationship
            let existingAvailability = try await getAvailability(relationshipID: availability.relationshipID)
            
            // Validate relationship exists
            do {
                _ = try await relationshipService.getRelationship(id: availability.relationshipID)
            } catch {
                throw AvailabilityError.relationshipNotFound
            }
            
            if let existingID = existingAvailability?.id {
                // Update existing document
                let docRef = db.collection(availabilityCollection).document(existingID)
                
                // Use transaction to prevent concurrent updates
                try await db.runTransaction { transaction, errorPointer in
                    do {
                        let snapshot = try transaction.getDocument(docRef)
                        guard let existingData = snapshot.data(),
                              let lastUpdated = existingData["updatedAt"] as? Timestamp else {
                            throw AvailabilityError.concurrentUpdateConflict
                        }
                        
                        // Check for concurrent updates
                        if lastUpdated.dateValue() > existingAvailability?.updatedAt ?? Date(timeIntervalSince1970: 0) {
                            throw AvailabilityError.concurrentUpdateConflict
                        }
                        
                        try transaction.setData(from: updatedAvailability, forDocument: docRef)
                        return nil
                    } catch {
                        errorPointer?.pointee = error as NSError
                        return nil
                    }
                }
                
                updatedAvailability.id = existingID
            } else {
                // Create new document
                let docRef = try db.collection(availabilityCollection).addDocument(from: updatedAvailability)
                updatedAvailability.id = docRef.documentID
            }
            
            return updatedAvailability
        } catch {
            print("Error saving availability: \(error.localizedDescription)")
            if let availError = error as? AvailabilityError {
                throw availError
            } else if let nsError = error as NSError?, nsError.domain == FirestoreErrorDomain {
                switch nsError.code {
                case FirestoreErrorCode.unavailable.rawValue:
                    throw AvailabilityError.networkTimeout
                case FirestoreErrorCode.permissionDenied.rawValue:
                    throw AvailabilityError.permissionDenied
                default:
                    throw error
                }
            } else {
                throw error
            }
        }
    }
    
    /// Find mutual availability for two couples based on their preferences and calendars
    /// - Parameters:
    ///   - relationship1ID: First relationship ID
    ///   - relationship2ID: Second relationship ID
    ///   - startDate: Start date to check
    ///   - endDate: End date to check
    ///   - duration: Desired duration in minutes
    /// - Returns: Array of available time slots
    func findMutualAvailability(
        relationship1ID: String,
        relationship2ID: String,
        startDate: Date,
        endDate: Date,
        duration: Int
    ) async throws -> [TimeSlot] {
        do {
            // Validate parameters
            if endDate <= startDate {
                throw AvailabilityError.invalidTimeRange
            }
            
            if duration < 15 || duration > 12 * 60 {
                throw AvailabilityError.invalidDuration
            }
        
            // Get availability preferences for both relationships
            let avail1 = try await getAvailability(relationshipID: relationship1ID) ?? CoupleAvailability(relationshipID: relationship1ID)
            let avail2 = try await getAvailability(relationshipID: relationship2ID) ?? CoupleAvailability(relationshipID: relationship2ID)
            
            // Get relationship details to access user IDs
            let relationship1 = try await relationshipService.getRelationship(id: relationship1ID)
            let relationship2 = try await relationshipService.getRelationship(id: relationship2ID)
            
            // Check for compatibility issues between the two couples' settings
            if (avail1.requireBothFree && !avail2.requireBothFree) ||
               (avail1.useCalendars && !avail2.useCalendars) {
                print("Warning: Couples have different availability settings preferences")
                // Not throwing an error here, but could warn the user in the UI
            }
            
            // Generate potential time slots based on preferences
            let potentialSlots = try await generatePotentialTimeSlots(
                coupleAvailability: avail1,
                startDate: startDate,
                endDate: endDate,
                duration: duration
            )
            
            if potentialSlots.isEmpty {
                throw AvailabilityError.unavailableTimePeriod
            }
            
            // Filter slots based on second couple's preferences
            let filteredSlots = filterSlotsByPreferences(
                slots: potentialSlots,
                coupleAvailability: avail2
            )
            
            if filteredSlots.isEmpty {
                throw AvailabilityError.preferenceConflict
            }
            
            // Check calendar availability for all users if enabled
            var availableSlots = filteredSlots
            
            if avail1.useCalendars || avail2.useCalendars {
                do {
                    availableSlots = try await filterSlotsByCalendars(
                        slots: filteredSlots,
                        relationship1: relationship1,
                        relationship2: relationship2,
                        requireAllFree: avail1.requireBothFree || avail2.requireBothFree
                    )
                } catch {
                    print("Calendar sync error: \(error.localizedDescription)")
                    throw AvailabilityError.calendarSyncFailed(error.localizedDescription)
                }
            }
            
            // If no slots available after all filtering, throw specific error
            if availableSlots.isEmpty {
                // Check if it's due to recurring commitments
                if !filteredSlots.isEmpty {
                    // We had slots after preference filtering but not after calendar filtering
                    throw AvailabilityError.calendarSyncFailed("No mutual availability found in calendars")
                } else if !potentialSlots.isEmpty {
                    // We had slots after initial generation but not after preference filtering
                    throw AvailabilityError.preferenceConflict
                } else {
                    // No slots even after initial generation
                    throw AvailabilityError.unavailableTimePeriod
                }
            }
            
            return availableSlots
        } catch {
            print("Error finding mutual availability: \(error.localizedDescription)")
            if let availError = error as? AvailabilityError {
                throw availError
            } else if let nsError = error as NSError?, nsError.domain == FirestoreErrorDomain {
                switch nsError.code {
                case FirestoreErrorCode.unavailable.rawValue:
                    throw AvailabilityError.networkTimeout
                case FirestoreErrorCode.permissionDenied.rawValue:
                    throw AvailabilityError.permissionDenied
                default:
                    throw error
                }
            } else {
                throw error
            }
        }
    }
    
    /// Generate potential time slots based on a couple's availability preferences
    /// - Parameters:
    ///   - coupleAvailability: The couple's availability preferences
    ///   - startDate: Start date to check
    ///   - endDate: End date to check
    ///   - duration: Desired duration in minutes
    /// - Returns: Array of potential time slots
    private func generatePotentialTimeSlots(
        coupleAvailability: CoupleAvailability,
        startDate: Date,
        endDate: Date,
        duration: Int
    ) async throws -> [TimeSlot] {
        var timeSlots: [TimeSlot] = []
        let calendar = Calendar.current
        
        // Ensure start date is not in the past
        let now = Date()
        var currentDate = calendar.startOfDay(for: startDate > now ? startDate : now)
        
        // Add minimum advance notice
        if coupleAvailability.minimumAdvanceNotice > 0 {
            if let advanceDate = calendar.date(byAdding: .hour, value: coupleAvailability.minimumAdvanceNotice, to: now) {
                currentDate = max(currentDate, advanceDate)
            }
        }
        
        // Calculate end date based on maximum advance days
        var maxEndDate = endDate
        if let maxAdvanceDate = calendar.date(byAdding: .day, value: coupleAvailability.maximumAdvanceDays, to: now) {
            maxEndDate = min(endDate, maxAdvanceDate)
        }
        
        // Duration in seconds
        let durationSeconds = TimeInterval(duration * 60)
        
        // Iterate through dates
        while currentDate < maxEndDate {
            // Get weekday for this date
            let calendarWeekday = calendar.component(.weekday, from: currentDate)
            let weekday = Unhinged.Weekday.fromCalendarWeekday(calendarWeekday)
            
            // Find availability for this weekday
            if let weekday = weekday, let dayAvail = coupleAvailability.dayAvailability.first(where: { $0.day == weekday }) {
                // Skip if day is not available (consider it unavailable if there are no time ranges)
                if dayAvail.timeRanges.isEmpty {
                    // Move to next day
                    if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                        currentDate = calendar.startOfDay(for: nextDay)
                    } else {
                        break
                    }
                    continue
                }
                
                // Process each available time range
                for timeRange in dayAvail.timeRanges {
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
                    
                    // If start time is already past for today, skip
                    if rangeStart < now {
                        continue
                    }
                    
                    // Generate time slots at 30-minute intervals within this range
                    var slotStart = rangeStart
                    while slotStart.addingTimeInterval(durationSeconds) <= rangeEnd {
                        let slotEnd = slotStart.addingTimeInterval(durationSeconds)
                        
                        // Check if this slot conflicts with any recurring commitments
                        let hasCommitmentConflict = hasConflictWithCommitments(
                            coupleAvailability: coupleAvailability,
                            startDate: slotStart,
                            endDate: slotEnd
                        )
                        
                        if !hasCommitmentConflict {
                            timeSlots.append(TimeSlot(startTime: slotStart, endTime: slotEnd))
                        }
                        
                        // Move to next slot (30-minute intervals)
                        slotStart = slotStart.addingTimeInterval(30 * 60)
                    }
                }
            }
            
            // Move to next day
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                currentDate = calendar.startOfDay(for: nextDay)
            } else {
                break
            }
        }
        
        return timeSlots
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
        let calendarWeekday = calendar.component(.weekday, from: startDate)
        let weekday = Unhinged.Weekday.fromCalendarWeekday(calendarWeekday)
        
        guard let weekday = weekday else { return false }
        
        // Check each commitment for this weekday
        let commitments = coupleAvailability.recurringCommitments.filter { $0.day == weekday }
        
        for commitment in commitments {
            // Convert commitment time to today's date
            var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
            let commitmentHour = calendar.component(.hour, from: commitment.startTime)
            let commitmentMinute = calendar.component(.minute, from: commitment.startTime)
            startComponents.hour = commitmentHour
            startComponents.minute = commitmentMinute
            
            var endComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
            let endHour = calendar.component(.hour, from: commitment.endTime)
            let endMinute = calendar.component(.minute, from: commitment.endTime)
            endComponents.hour = endHour
            endComponents.minute = endMinute
            
            guard let commitmentStart = calendar.date(from: startComponents),
                  let commitmentEnd = calendar.date(from: endComponents) else {
                continue
            }
            
            // Check for overlap
            if max(startDate, commitmentStart) < min(endDate, commitmentEnd) {
                return true
            }
        }
        
        return false
    }
    
    /// Filter time slots based on a couple's availability preferences
    /// - Parameters:
    ///   - slots: Time slots to filter
    ///   - coupleAvailability: The couple's availability preferences
    /// - Returns: Filtered time slots
    private func filterSlotsByPreferences(
        slots: [TimeSlot],
        coupleAvailability: CoupleAvailability
    ) -> [TimeSlot] {
        let calendar = Calendar.current
        
        return slots.filter { slot in
            // Get weekday for this slot
            let calendarWeekday = calendar.component(.weekday, from: slot.startTime)
            guard let weekday = Unhinged.Weekday.fromCalendarWeekday(calendarWeekday) else {
                return false
            }
            
            // Find availability for this weekday
            guard let dayAvail = coupleAvailability.dayAvailability.first(where: { $0.day == weekday }),
                  !dayAvail.timeRanges.isEmpty else {
                return false
            }
            
            // Check if slot start and end times are within an available time range
            let startHour = calendar.component(.hour, from: slot.startTime)
            let startMinute = calendar.component(.minute, from: slot.startTime)
            let endHour = calendar.component(.hour, from: slot.endTime)
            let endMinute = calendar.component(.minute, from: slot.endTime)
            
            // Check each available time range
            let isInAvailableRange = dayAvail.timeRanges.contains { range in
                let rangeStartMinutes = range.startHour * 60 + range.startMinute
                let rangeEndMinutes = range.endHour * 60 + range.endMinute
                let slotStartMinutes = startHour * 60 + startMinute
                let slotEndMinutes = endHour * 60 + endMinute
                
                return slotStartMinutes >= rangeStartMinutes && slotEndMinutes <= rangeEndMinutes
            }
            
            if !isInAvailableRange {
                return false
            }
            
            // Check if slot conflicts with any recurring commitments
            let hasCommitmentConflict = hasConflictWithCommitments(
                coupleAvailability: coupleAvailability,
                startDate: slot.startTime,
                endDate: slot.endTime
            )
            
            return !hasCommitmentConflict
        }
    }
    
    /// Filter time slots based on calendar availability
    /// - Parameters:
    ///   - slots: Time slots to filter
    ///   - relationship1: First relationship
    ///   - relationship2: Second relationship
    ///   - requireAllFree: Whether all users must be free
    /// - Returns: Filtered time slots
    private func filterSlotsByCalendars(
        slots: [TimeSlot],
        relationship1: Relationship,
        relationship2: Relationship,
        requireAllFree: Bool
    ) async throws -> [TimeSlot] {
        // Combine all user IDs from both relationships
        var userIDs = [relationship1.initiatorID, relationship1.partnerID, relationship2.initiatorID, relationship2.partnerID]
        
        // Remove duplicates and nil values
        userIDs = userIDs.compactMap { $0 }
        userIDs = Array(Set(userIDs))
        
        return try await withThrowingTaskGroup(of: (TimeSlot, Bool).self) { group in
            // Check each slot with all users
            for slot in slots {
                group.addTask {
                    let isAvailable = await self.isSlotAvailableForAllUsers(
                        slot: slot,
                        userIDs: userIDs,
                        requireAllFree: requireAllFree
                    )
                    return (slot, isAvailable)
                }
            }
            
            // Collect results
            var availableSlots: [TimeSlot] = []
            for try await (slot, isAvailable) in group {
                if isAvailable {
                    availableSlots.append(slot)
                }
            }
            
            return availableSlots.sorted { $0.startTime < $1.startTime }
        }
    }
    
    /// Check if a time slot is available for all specified users
    /// - Parameters:
    ///   - slot: The time slot to check
    ///   - userIDs: Array of user IDs to check
    ///   - requireAllFree: Whether all users must be free (true) or just one per couple (false)
    /// - Returns: Whether the slot is available
    private func isSlotAvailableForAllUsers(
        slot: TimeSlot,
        userIDs: [String],
        requireAllFree: Bool
    ) async -> Bool {
        // If we require all users to be free, check each user
        if requireAllFree {
            for userID in userIDs {
                let isAvailable = await calendarService.checkAvailabilityAcrossAllCalendars(
                    userId: userID,
                    startDate: slot.startTime,
                    endDate: slot.endTime
                )
                
                if !isAvailable {
                    return false
                }
            }
            return true
        } else {
            // Otherwise, we just need at least one person from each couple to be free
            // This would require more complex logic with relationship grouping
            // For simplicity, just requiring everyone to be free for now
            return await isSlotAvailableForAllUsers(slot: slot, userIDs: userIDs, requireAllFree: true)
        }
    }
    
    /// Generate alternative time slots when no mutual availability is found
    /// - Parameters:
    ///   - relationship1ID: First relationship ID
    ///   - relationship2ID: Second relationship ID
    ///   - startDate: Original start date
    ///   - endDate: Original end date
    ///   - duration: Original duration
    /// - Returns: Array of alternative time slots to suggest
    func suggestAlternativeTimeSlots(
        relationship1ID: String,
        relationship2ID: String,
        startDate: Date,
        endDate: Date,
        duration: Int
    ) async throws -> [TimeSlot] {
        var alternativeSlots: [TimeSlot] = []
        
        // Strategy 1: Try with a shorter duration
        if duration > 60 {
            let shorterDuration = max(30, duration / 2)
            do {
                let shorterSlots = try await findMutualAvailability(
                    relationship1ID: relationship1ID,
                    relationship2ID: relationship2ID,
                    startDate: startDate,
                    endDate: endDate,
                    duration: shorterDuration
                )
                alternativeSlots.append(contentsOf: shorterSlots.prefix(3))
            } catch {
                // Silently fail, we'll try other alternatives
            }
        }
        
        // Strategy 2: Try with an extended date range
        if let extendedEndDate = Calendar.current.date(byAdding: .day, value: 14, to: endDate) {
            do {
                let extendedSlots = try await findMutualAvailability(
                    relationship1ID: relationship1ID,
                    relationship2ID: relationship2ID,
                    startDate: endDate, // Start from where the original range ended
                    endDate: extendedEndDate,
                    duration: duration
                )
                alternativeSlots.append(contentsOf: extendedSlots.prefix(3))
            } catch {
                // Silently fail, we'll return whatever we found
            }
        }
        
        // Strategy 3: If we have availability preferences, try to get slots when only 1 person from each couple is free
        do {
            let avail1 = try await getAvailability(relationshipID: relationship1ID)
            let avail2 = try await getAvailability(relationshipID: relationship2ID)
            
            if let avail1 = avail1, let avail2 = avail2,
               (avail1.requireBothFree || avail2.requireBothFree) {
                
                // Try with more relaxed constraints
                let relationship1 = try await relationshipService.getRelationship(id: relationship1ID)
                let relationship2 = try await relationshipService.getRelationship(id: relationship2ID)
                
                let allSlots = try await generatePotentialTimeSlots(
                    coupleAvailability: avail1,
                    startDate: startDate,
                    endDate: endDate,
                    duration: duration
                )
                
                let prefFilteredSlots = filterSlotsByPreferences(
                    slots: allSlots,
                    coupleAvailability: avail2
                )
                
                // Check calendar with relaxed constraints (not requiring both free)
                let relaxedSlots = try await filterSlotsByCalendars(
                    slots: prefFilteredSlots,
                    relationship1: relationship1,
                    relationship2: relationship2,
                    requireAllFree: false
                )
                
                alternativeSlots.append(contentsOf: relaxedSlots.prefix(3))
            }
        } catch {
            // Silently fail, we'll return whatever we found
        }
        
        return alternativeSlots
    }
    
    /// Get mutual availability for a couple
    /// - Parameters:
    ///   - userId: Current user ID
    ///   - partnerId: Partner user ID
    ///   - startDate: Start date to check availability
    ///   - endDate: End date to check availability
    /// - Returns: Dictionary mapping dates to available time slots
    func getMutualAvailability(userId: String, partnerId: String, startDate: Date, endDate: Date) async throws -> [Date: [AvailabilityTimeSlot]] {
        // 1. Get both users' calendar settings
        let userSettings = try await calendarService.getCalendarSettings(for: userId)
        let partnerSettings = try await calendarService.getCalendarSettings(for: partnerId)
        
        // 2. Get both users' availability settings
        let userAvailabilitySettings = try await getUserAvailabilitySettings(userId: userId)
        let partnerAvailabilitySettings = try await getUserAvailabilitySettings(userId: partnerId)
        
        // 3. Get busy times from calendars for each user
        let userBusyTimes = try await getBusyTimes(userId: userId, settings: userSettings, startDate: startDate, endDate: endDate)
        let partnerBusyTimes = try await getBusyTimes(userId: partnerId, settings: partnerSettings, startDate: startDate, endDate: endDate)
        
        // 4. Combine busy times
        let combinedBusyTimes = combineBusyTimes(userBusyTimes: userBusyTimes, partnerBusyTimes: partnerBusyTimes)
        
        // 5. Calculate available time slots based on busy times and availability settings
        return calculateAvailableTimeSlots(
            busyTimes: combinedBusyTimes,
            userSettings: userAvailabilitySettings,
            partnerSettings: partnerAvailabilitySettings,
            startDate: startDate,
            endDate: endDate
        )
    }
    
    /// Get user's availability settings
    /// - Parameter userId: User ID
    /// - Returns: Availability settings
    private func getUserAvailabilitySettings(userId: String) async throws -> AvailabilitySettings {
        let docRef = db.collection("users").document(userId).collection("settings").document("availability")
        
        do {
            let document = try await docRef.getDocument()
            
            guard document.exists, let data = document.data() else {
                // Return default settings if none exist
                return AvailabilitySettings.default
            }
            
            // Parse work hours
            var workHoursStart = Date.today(hour: 9)
            var workHoursEnd = Date.today(hour: 17)
            
            if let startTimestamp = data["workHoursStart"] as? Timestamp {
                workHoursStart = startTimestamp.dateValue()
            }
            
            if let endTimestamp = data["workHoursEnd"] as? Timestamp {
                workHoursEnd = endTimestamp.dateValue()
            }
            
            // Parse available days
            var availableDays: Set<Unhinged.Weekday> = []
            if let daysArray = data["availableDays"] as? [String] {
                for dayString in daysArray {
                    if let day = Unhinged.Weekday(rawValue: dayString) {
                        availableDays.insert(day)
                    }
                }
            } else {
                // Default to all days if not specified
                availableDays = Set(Unhinged.Weekday.allCases)
            }
            
            return AvailabilitySettings(
                workHoursStart: workHoursStart,
                workHoursEnd: workHoursEnd,
                availableDays: availableDays
            )
            
        } catch {
            print("Error fetching availability settings: \(error.localizedDescription)")
            // Return default settings if there's an error
            return AvailabilitySettings.default
        }
    }
    
    /// Get busy times from calendars
    /// - Parameters:
    ///   - userId: User ID
    ///   - settings: Calendar provider settings
    ///   - startDate: Start date
    ///   - endDate: End date
    /// - Returns: Dictionary mapping dates to busy time slots
    private func getBusyTimes(userId: String, settings: [CalendarProviderSettings], startDate: Date, endDate: Date) async throws -> [Date: [BusyTimeSlot]] {
        var busyTimesByDate: [Date: [BusyTimeSlot]] = [:]
        
        // For each connected calendar that's used for availability
        for providerSettings in settings {
            // Skip if not used for availability
            if !providerSettings.useForAvailability {
                continue
            }
            
            // Get provider from factory service
            let provider = CalendarServiceFactory.shared.getProviderFromSettings(providerSettings)
            
            do {
                // Get busy times from this provider
                let busyTimes = try await provider.getAvailability(userID: userId, startDate: startDate, endDate: endDate)
                
                // Group by date
                for busyTime in busyTimes {
                    // Get date without time
                    let calendar = Calendar.current
                    let busyDate = calendar.startOfDay(for: busyTime.startTime)
                    
                    // Add to dictionary
                    var existingBusyTimes = busyTimesByDate[busyDate] ?? []
                    existingBusyTimes.append(busyTime)
                    busyTimesByDate[busyDate] = existingBusyTimes
                }
                
            } catch {
                print("Error getting busy times from \(providerSettings.providerType.rawValue): \(error.localizedDescription)")
                // Continue with other providers even if one fails
            }
        }
        
        return busyTimesByDate
    }
    
    /// Combine busy times from both users
    /// - Parameters:
    ///   - userBusyTimes: User's busy times
    ///   - partnerBusyTimes: Partner's busy times
    /// - Returns: Combined busy times
    private func combineBusyTimes(userBusyTimes: [Date: [BusyTimeSlot]], partnerBusyTimes: [Date: [BusyTimeSlot]]) -> [Date: [BusyTimeSlot]] {
        var combinedBusyTimes: [Date: [BusyTimeSlot]] = [:]
        
        // Add all user busy times
        for (date, busyTimes) in userBusyTimes {
            combinedBusyTimes[date] = busyTimes
        }
        
        // Add partner busy times
        for (date, busyTimes) in partnerBusyTimes {
            var existingBusyTimes = combinedBusyTimes[date] ?? []
            existingBusyTimes.append(contentsOf: busyTimes)
            combinedBusyTimes[date] = existingBusyTimes
        }
        
        return combinedBusyTimes
    }
    
    /// Calculate available time slots based on busy times and availability settings
    /// - Parameters:
    ///   - busyTimes: Combined busy times
    ///   - userSettings: User's availability settings
    ///   - partnerSettings: Partner's availability settings
    ///   - startDate: Overall start date
    ///   - endDate: Overall end date
    /// - Returns: Dictionary mapping dates to available time slots
    private func calculateAvailableTimeSlots(busyTimes: [Date: [BusyTimeSlot]], userSettings: AvailabilitySettings, partnerSettings: AvailabilitySettings, startDate: Date, endDate: Date) -> [Date: [AvailabilityTimeSlot]] {
        var availableTimeSlots: [Date: [AvailabilityTimeSlot]] = [:]
        
        // Get calendar for date calculations
        let calendar = Calendar.current
        
        // Create date interval to iterate through
        var currentDate = calendar.startOfDay(for: startDate)
        let lastDate = calendar.startOfDay(for: endDate)
        
        // For each day in the date range
        while currentDate <= lastDate {
            // Get day of week
            let weekday = getDayOfWeek(from: currentDate)
            
            // Check if both users are available on this day of week
            let isUserAvailable = userSettings.availableDays.contains(weekday)
            let isPartnerAvailable = partnerSettings.availableDays.contains(weekday)
            
            if isUserAvailable && isPartnerAvailable {
                // Get work hour boundaries for this day
                let userDayStart = mergeDateWithTime(date: currentDate, time: userSettings.workHoursStart)
                let userDayEnd = mergeDateWithTime(date: currentDate, time: userSettings.workHoursEnd)
                
                let partnerDayStart = mergeDateWithTime(date: currentDate, time: partnerSettings.workHoursStart)
                let partnerDayEnd = mergeDateWithTime(date: currentDate, time: partnerSettings.workHoursEnd)
                
                // Get the intersection of both users' work hours
                let latestStart = max(userDayStart, partnerDayStart)
                let earliestEnd = min(userDayEnd, partnerDayEnd)
                
                // Only proceed if there is an overlap in working hours
                if latestStart < earliestEnd {
                    // Get busy times for this day
                    let dayBusyTimes = busyTimes[currentDate] ?? []
                    
                    // Sort busy times by start time
                    let sortedBusyTimes = dayBusyTimes.sorted { $0.startTime < $1.startTime }
                    
                    // Calculate available slots between busy times
                    var availableSlots = calculateAvailableSlotsForDay(
                        busyTimes: sortedBusyTimes,
                        dayStart: latestStart,
                        dayEnd: earliestEnd
                    )
                    
                    // Only keep slots that are at least 30 minutes
                    availableSlots = availableSlots.filter { slot in
                        let duration = slot.endTime.timeIntervalSince(slot.startTime)
                        return duration >= 30 * 60 // 30 minutes in seconds
                    }
                    
                    if !availableSlots.isEmpty {
                        availableTimeSlots[currentDate] = availableSlots
                    }
                }
            }
            
            // Move to next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return availableTimeSlots
    }
    
    /// Calculate available slots for a day given busy times
    /// - Parameters:
    ///   - busyTimes: Sorted array of busy time slots
    ///   - dayStart: Start of available hours
    ///   - dayEnd: End of available hours
    /// - Returns: Array of available time slots
    private func calculateAvailableSlotsForDay(busyTimes: [BusyTimeSlot], dayStart: Date, dayEnd: Date) -> [AvailabilityTimeSlot] {
        var availableSlots: [AvailabilityTimeSlot] = []
        
        // If no busy times, the whole day is available
        if busyTimes.isEmpty {
            availableSlots.append(AvailabilityTimeSlot(
                startTime: dayStart,
                endTime: dayEnd,
                availabilityRating: .excellent
            ))
            return availableSlots
        }
        
        var currentTime = dayStart
        
        // For each busy period
        for busyTime in busyTimes {
            // If busy time starts after current time, there's an available slot
            if busyTime.startTime > currentTime {
                let slot = AvailabilityTimeSlot(
                    startTime: currentTime,
                    endTime: busyTime.startTime,
                    availabilityRating: .good
                )
                availableSlots.append(slot)
            }
            
            // Update current time to after this busy period
            currentTime = max(currentTime, busyTime.endTime)
        }
        
        // Add final slot if there's time after the last busy period
        if currentTime < dayEnd {
            let slot = AvailabilityTimeSlot(
                startTime: currentTime,
                endTime: dayEnd,
                availabilityRating: .excellent
            )
            availableSlots.append(slot)
        }
        
        return availableSlots
    }
    
    /// Get day of week from a date
    /// - Parameter date: Date to check
    /// - Returns: Weekday enum
    private func getDayOfWeek(from date: Date) -> Unhinged.Weekday {
        let dayNumber = Calendar.current.component(.weekday, from: date)
        
        // Convert from Calendar.weekday (1 = Sunday) to our Weekday enum
        switch dayNumber {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .monday // Fallback
        }
    }
    
    /// Merge a date (day) with a time
    /// - Parameters:
    ///   - date: Date providing the day
    ///   - time: Date providing the time
    /// - Returns: Combined date and time
    private func mergeDateWithTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        dateComponents.second = timeComponents.second
        
        return calendar.date(from: dateComponents) ?? date
    }
}

/// Availability settings for a user
struct AvailabilitySettings {
    /// Start of work hours
    let workHoursStart: Date
    
    /// End of work hours
    let workHoursEnd: Date
    
    /// Days of the week user is available
    let availableDays: Set<Unhinged.Weekday>
    
    /// Default availability settings
    static var `default`: AvailabilitySettings {
        return AvailabilitySettings(
            workHoursStart: Date.today(hour: 9),
            workHoursEnd: Date.today(hour: 17),
            availableDays: Set(Unhinged.Weekday.allCases)
        )
    }
}

/// Represents an available time slot
struct AvailabilityTimeSlot {
    /// Start time of availability
    let startTime: Date
    
    /// End time of availability
    let endTime: Date
    
    /// Rating of how good this availability is
    let availabilityRating: AvailabilityRating
}

/// Rating for availability time slots
enum AvailabilityRating {
    case excellent  // Long, uninterrupted availability
    case good       // Decent availability
    case fair       // Limited availability
    
    var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "#4CAF50" // Green
        case .good: return "#2196F3"      // Blue
        case .fair: return "#FF9800"      // Orange
        }
    }
} 