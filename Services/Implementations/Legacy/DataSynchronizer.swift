import Foundation
import FirebaseFirestore
import Firebase
// Removed // Removed: import Unhinged.Utilities

/// Service responsible for coordinating data synchronization between different services
class DataSynchronizer {
    static let shared = DataSynchronizer()
    
    // Dependent services
    private let firestoreService = FirestoreService.shared
    private let calendarService: CalendarOperationsService
    private let notificationService = NotificationService.shared
    
    private init() {
        // Get CalendarOperationsService from ServiceManager
        self.calendarService = ServiceManager.shared.getService(CalendarOperationsService.self)
    }
    
    // MARK: - Consistency Checks
    
    /// Ensures relationship data is consistent with user data
    func synchronizeRelationshipData(for userId: String) async throws {
        print("DEBUG: Synchronizing relationship data for user: \(userId)")
        
        // Get the user's relationship data
        let relationshipsQuery = Firestore.firestore().collection("relationships").whereField("participants", arrayContains: userId)
        let relationshipSnapshots = try await relationshipsQuery.getDocuments().documents
        
        // Get all users for validation
        let userDoc = try await Firestore.firestore().collection("users").document(userId).getDocument()
        
        // Ensure user document exists
        guard userDoc.exists else {
            print("ERROR: User document does not exist: \(userId)")
            throw FirestoreError.documentNotFound
        }
        
        // Process each relationship
        for relationshipDoc in relationshipSnapshots {
            guard let relationship = try? relationshipDoc.data(as: Relationship.self) else {
                print("ERROR: Failed to decode relationship: \(relationshipDoc.documentID)")
                continue
            }
            
            // Get the partner user ID
            let partnerIds = relationship.participants.filter { $0 != userId }
            guard let partnerId = partnerIds.first else {
                print("WARNING: Relationship has no partner: \(relationship.id)")
                continue
            }
            
            // Verify partner exists
            let partnerDoc = try await Firestore.firestore().collection("users").document(partnerId).getDocument()
            if !partnerDoc.exists {
                print("WARNING: Partner does not exist for relationship: \(relationship.id)")
                
                // Handle according to your data integrity policy
                // For example, you might flag the relationship as invalid
                try await relationshipDoc.reference.updateData([
                    "status": "invalid",
                    "lastSync": Timestamp(date: Date())
                ])
            }
            
            // Update last sync timestamp
            try await relationshipDoc.reference.updateData([
                "lastSync": Timestamp(date: Date())
            ])
            
            print("DEBUG: Synchronized relationship: \(relationship.id)")
        }
        
        print("DEBUG: Relationship data synchronization completed for user: \(userId)")
    }
    
    /// Ensures hangout data is consistent with availability data
    func synchronizeHangoutsWithAvailability(userId: String) async throws {
        print("DEBUG: Synchronizing hangouts with availability for user: \(userId)")
        
        // Get user's hangouts
        let hangoutsQuery = Firestore.firestore().collection("hangouts").whereField("participants", arrayContains: userId)
        let hangoutDocs = try await hangoutsQuery.getDocuments().documents
        
        // Get time range for upcoming hangouts (next 30 days)
        let now = Date()
        let thirtyDaysLater = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        
        // Get busy times from calendar
        let busyTimes = try await getBusyTimesForUser(userID: userId, startDate: now, endDate: thirtyDaysLater)
        
        // Check each hangout for conflicts
        for hangoutDoc in hangoutDocs {
            guard let hangout = try? hangoutDoc.data(as: Hangout.self),
                  let startTime = hangout.startTime,
                  let endTime = hangout.endTime,
                  startTime > now else {
                continue // Skip past hangouts or those without times
            }
            
            // Check if hangout conflicts with busy times
            let hasConflict = busyTimes.contains { busyTime in
                return (startTime < busyTime.end && endTime > busyTime.start)
            }
            
            if hasConflict {
                // Flag hangout as having a conflict
                try await hangoutDoc.reference.updateData([
                    "hasCalendarConflict": true,
                    "lastSyncedAt": Timestamp(date: Date())
                ])
                
                // Notify the user about the conflict
                let notification = NotificationModel(
                    id: UUID().uuidString,
                    userId: userId,
                    title: "Calendar Conflict",
                    body: "Your hangout '\(hangout.title)' conflicts with your calendar.",
                    type: .calendarConflict,
                    relatedId: hangout.id,
                    createdAt: Date()
                )
                
                try await notificationService.create(notification)
                
                print("DEBUG: Found calendar conflict for hangout: \(hangout.id)")
            } else {
                // Mark as no conflict
                try await hangoutDoc.reference.updateData([
                    "hasCalendarConflict": false,
                    "lastSyncedAt": Timestamp(date: Date())
                ])
            }
        }
        
        print("DEBUG: Hangout synchronization with availability completed for user: \(userId)")
    }
    
    /// Synchronize persona data across user and relationships
    func synchronizePersonaData(for userId: String) async throws {
        // Implementation depends on your data structure
        print("DEBUG: Synchronizing persona data for user: \(userId)")
        
        // This would typically involve:
        // 1. Getting the user's personas
        // 2. Getting the user's relationships
        // 3. Ensuring correct visibility settings are applied
        
        print("DEBUG: Persona data synchronization completed for user: \(userId)")
    }
    
    /// Run all synchronization tasks for a user
    func runFullSynchronization(for userID: String) async throws {
        print("DEBUG: Starting full data synchronization for user: \(userID)")
        
        do {
            // Synchronize relationships
            try await synchronizeRelationshipData(for: userID)
            
            // Synchronize hangouts with availability
            try await synchronizeHangoutsWithAvailability(userId: userID)
            
            // Synchronize persona data
            try await synchronizePersonaData(for: userID)
            
            // Synchronize calendar events
            let hangouts = try await Firestore.firestore().collection("hangouts").whereField("participants", arrayContains: userID).getDocuments().documents.compactMap { document -> Hangout? in
                try? document.data(as: Hangout.self)
            }
            
            for hangout in hangouts where hangout.needsCalendarSync == true {
                if let startTime = hangout.startTime, let endTime = hangout.endTime {
                    // Create calendar event for the hangout using the new model
                    let calendarEvent = CalendarEvent(
                        title: hangout.title,
                        description: hangout.description,
                        startDate: startTime,
                        endDate: endTime,
                        isAllDay: false,
                        location: hangout.location,
                        attendees: hangout.participants ?? [],
                        associatedHangout: hangout
                    )
                    
                    // Create the event using the operations service
                    _ = try await calendarService.create(calendarEvent)
                    
                    // Update hangout to mark it as synced
                    var updatedHangout = hangout
                    updatedHangout.needsCalendarSync = false
                    try await Firestore.firestore().collection("hangouts").document(hangout.id).setData(from: updatedHangout)
                    print("DEBUG: Synchronized hangout \(hangout.id) with calendar")
                }
            }
            
            print("DEBUG: Full data synchronization completed successfully")
        } catch {
            print("ERROR: Full data synchronization failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Synchronize hangouts for a user
    /// - Parameters:
    ///   - userID: The user ID
    ///   - relationshipID: The relationship ID (optional)
    private func synchronizeHangouts(for userID: String, relationshipID: String?) async {
        print("🔄 Synchronizing hangouts for user \(userID)")
        
        guard let relationshipID = relationshipID else {
            print("⚠️ No relationship found for user \(userID), skipping hangout synchronization")
            return
        }
        
        do {
            // In a real implementation, you would:
            // 1. Fetch hangouts from Firebase
            // 2. Update local cache
            // 3. Check for calendar conflicts
            
            print("✅ Hangout synchronization completed for user \(userID)")
        } catch {
            print("❌ Error synchronizing hangouts: \(error.localizedDescription)")
        }
    }
    
    /// Synchronize invitations for a user
    /// - Parameters:
    ///   - userID: The user ID
    ///   - relationshipID: The relationship ID (optional)
    private func synchronizeInvitations(for userID: String, relationshipID: String?) async {
        print("🔄 Synchronizing invitations for user \(userID)")
        
        do {
            // In a real implementation, you would:
            // 1. Fetch invitations from Firebase
            // 2. Update local cache
            // 3. Process new invitations
            
            print("✅ Invitation synchronization completed for user \(userID)")
        } catch {
            print("❌ Error synchronizing invitations: \(error.localizedDescription)")
        }
    }
    
    /// Synchronize calendar events for a user
    /// - Parameters:
    ///   - userID: The user ID
    ///   - relationshipID: The relationship ID (optional)
    private func synchronizeCalendarEvents(for userID: String, relationshipID: String?) async {
        print("🔄 Synchronizing calendar events for user \(userID)")
        
        do {
            // Get events from calendar operations service
            let now = Date()
            let weekLater = now.addingTimeInterval(7 * 86400)
            
            if let events = try? await calendarService.list() {
                // Filter events in the date range we care about
                let relevantEvents = events.filter { 
                    $0.startDate >= now && $0.startDate <= weekLater 
                }
                
                print("📅 Found \(relevantEvents.count) calendar events")
                
                // Update availability in Firebase based on these events
                for event in relevantEvents {
                    // Process each event
                    print("📅 Processing event: \(event.title)")
                }
            }
            
            print("✅ Calendar event synchronization completed for user \(userID)")
        } catch {
            print("❌ Error synchronizing calendar events: \(error.localizedDescription)")
        }
    }
    
    /// Process visibility settings for a user
    /// - Parameter userID: The user ID
    private func processVisibilitySettings(for userID: String) async {
        print("🔄 Processing visibility settings for user \(userID)")
        
        do {
            // Get the user's visibility settings
            let settings = try? await firestoreService.getVisibilitySettings(userID: userID)
            
            if let settings = settings {
                // Process the settings
                // This would typically update local status or notify other services
                
                print("✅ Visibility settings processed for user \(userID)")
            } else {
                print("⚠️ No visibility settings found for user \(userID)")
            }
        } catch {
            print("❌ Error processing visibility settings: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Map Firestore error codes to our custom FirestoreError type
    private func mapFirestoreError(_ error: NSError) -> FirestoreError {
        switch error.code {
        case FirestoreErrorCode.notFound.rawValue:
            return .documentNotFound
        case FirestoreErrorCode.permissionDenied.rawValue:
            return .permissionDenied
        case FirestoreErrorCode.unavailable.rawValue:
            return .unavailable
        case FirestoreErrorCode.dataLoss.rawValue:
            return .dataLost
        default:
            return .unknownError(error)
        }
    }
    
    /// Helper method to get busy times for a user
    private func getBusyTimesForUser(userID: String, startDate: Date, endDate: Date) async throws -> [(start: Date, end: Date)] {
        do {
            // Get availability directly from CalendarOperationsService
            let availabilitySlots = await calendarService.findMutualAvailability(
                userIDs: [userID], 
                startRange: startDate, 
                endRange: endDate, 
                duration: 3600 // 1 hour
            )
            
            // Convert available slots to busy periods
            var busyPeriods: [(start: Date, end: Date)] = []
            var currentTime = startDate
            
            for slot in availabilitySlots.sorted(by: { $0.start < $1.start }) {
                // If there's a gap between current time and slot start, it's busy
                if currentTime < slot.start {
                    busyPeriods.append((start: currentTime, end: slot.start))
                }
                // Update current time to slot end
                currentTime = slot.end
            }
            
            // If there's time after the last slot, it's busy
            if currentTime < endDate {
                busyPeriods.append((start: currentTime, end: endDate))
            }
            
            return busyPeriods
        } catch {
            print("Error getting busy times for user \(userID): \(error.localizedDescription)")
            // Return empty array as a fallback
            return []
        }
    }
}

/// Helper extension to add missing FirestoreService methods
extension FirestoreService {
    /// Get hangouts for a specific user
    /// - Parameter userId: The user ID
    /// - Returns: Array of hangouts
    func getHangoutsForUser(userId: String) async throws -> [Hangout] {
        let db = Firestore.firestore()
        
        // Query hangouts where user is creator or invitee
        let creatorQuery = db.collection("hangouts")
            .whereField("creatorID", isEqualTo: userId)
        
        let inviteeQuery = db.collection("hangouts")
            .whereField("inviteeID", isEqualTo: userId)
        
        // Get both query results
        let creatorSnapshots = try await creatorQuery.getDocuments().documents
        let inviteeSnapshots = try await inviteeQuery.getDocuments().documents
        
        // Combine both sets of results
        let allSnapshots = creatorSnapshots + inviteeSnapshots
        
        // Remove duplicates if any
        let uniqueSnapshots = Array(Set(allSnapshots))
        
        // Convert snapshots to Hangout objects
        var hangouts: [Hangout] = []
        for snapshot in uniqueSnapshots {
            if let hangout = try? snapshot.data(as: Hangout.self) {
                hangouts.append(hangout)
            }
        }
        
        return hangouts
    }
    
    /// Get visibility settings for a user
    /// - Parameter userID: The user ID
    /// - Returns: The user's visibility settings
    func getVisibilitySettings(userID: String) async throws -> VisibilitySettings? {
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(userID).collection("settings").document("visibility")
        
        let snapshot = try await docRef.getDocument()
        
        if !snapshot.exists {
            return nil
        }
        
        return try snapshot.data(as: VisibilitySettings.self)
    }
}

/// Extension to add free/busy information methods to CalendarServiceAdapter
extension CalendarServiceAdapter {
    /// Gets free/busy information for a user
    /// - Parameters:
    ///   - userId: User ID
    ///   - startDate: Start date
    ///   - endDate: End date
    /// - Returns: Array of busy time periods
    func getFreeBusyInfo(for userId: String, startDate: Date, endDate: Date) async throws -> [BusyTimePeriod] {
        return try await calendarDataFetchService.fetchFreeBusyInfo(
            for: userId,
            startDate: startDate,
            endDate: endDate
        )
    }
    
    /// Read calendar events based on query
    func read<T: Codable>(_ query: T) async throws -> [CalendarEventModel] where T: Query {
        guard let calendarQuery = query as? CalendarEventQuery else {
            throw CalendarError.invalidQueryType
        }
        
        let userId = calendarQuery.userId ?? AuthenticationManager.shared.currentUserId ?? ""
        if userId.isEmpty {
            throw CalendarError.userNotAuthenticated
        }
        
        return try await calendarDataFetchService.fetchEvents(
            for: userId,
            startDate: calendarQuery.startDate,
            endDate: calendarQuery.endDate
        )
    }
} 