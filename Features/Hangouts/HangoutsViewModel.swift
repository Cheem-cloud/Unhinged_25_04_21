import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

@MainActor
class HangoutsViewModel: ObservableObject {
    @Published var hangouts: [Hangout] = []
    @Published var personaDetails: [String: Persona] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showError = false
    
    private let firestoreService = FirestoreService()
    private var calendarService: CalendarOperationsService
    
    var pendingHangouts: [Hangout] {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return [] }
        return hangouts.filter { 
            $0.status == .pending && $0.inviteeID == currentUserId 
        }
    }
    
    var upcomingHangouts: [Hangout] {
        let now = Date()
        return hangouts.filter { 
            $0.status == .accepted && $0.startDate > now 
        }
    }
    
    var pastHangouts: [Hangout] {
        let now = Date()
        return hangouts.filter { 
            ($0.status == .accepted || $0.status == .completed) && $0.endDate < now 
        }
    }
    
    var declinedHangouts: [Hangout] {
        return hangouts.filter { $0.status == .declined }
    }
    
    /// All hangouts combined - used for UI display
    var allHangouts: [Hangout] {
        return hangouts
    }
    
    init() {
        self.calendarService = ServiceManager.shared.getService(CalendarOperationsService.self)
        loadHangouts()
    }
    
    // MARK: - Debug function
    func debugCheckPendingHangouts() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { 
            print("❌ DEBUG: No user ID available")
            return 
        }
        
        print("🔍 DEBUG-DIRECT-CHECK: Checking Firestore directly for pending hangouts for user: \(currentUserId)")
        
        let db = Firestore.firestore()
        db.collection("hangouts")
            .whereField("inviteeID", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("❌ DEBUG-DIRECT-CHECK: Error fetching pending hangouts: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("❌ DEBUG-DIRECT-CHECK: No documents found")
                    return
                }
                
                print("✅ DEBUG-DIRECT-CHECK: Found \(documents.count) pending hangouts directly from Firestore")
                
                for document in documents {
                    let data = document.data()
                    print("📄 Hangout ID: \(document.documentID)")
                    print("   Title: \(data["title"] as? String ?? "Unknown")")
                    print("   Creator: \(data["creatorID"] as? String ?? "Unknown")")
                    print("   Invitee: \(data["inviteeID"] as? String ?? "Unknown")")
                    print("   Status: \(data["status"] as? String ?? "Unknown")")
                    
                    if let createdTimestamp = data["createdAt"] as? Timestamp {
                        print("   Created: \(createdTimestamp.dateValue())")
                    }
                }
                
                // Also check for pending hangouts where user is creator
                db.collection("hangouts")
                    .whereField("creatorID", isEqualTo: currentUserId)
                    .whereField("status", isEqualTo: "pending")
                    .getDocuments { (snapshot, error) in
                        if let error = error {
                            print("❌ DEBUG-DIRECT-CHECK: Error fetching pending hangouts as creator: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let documents = snapshot?.documents else {
                            print("❌ DEBUG-DIRECT-CHECK: No documents found for creator")
                            return
                        }
                        
                        print("✅ DEBUG-DIRECT-CHECK: Found \(documents.count) pending hangouts as creator")
                        
                        for document in documents {
                            let data = document.data()
                            print("📄 Hangout ID: \(document.documentID)")
                            print("   Title: \(data["title"] as? String ?? "Unknown")")
                            print("   Creator: \(data["creatorID"] as? String ?? "Unknown")")
                            print("   Invitee: \(data["inviteeID"] as? String ?? "Unknown")")
                            print("   Status: \(data["status"] as? String ?? "Unknown")")
                            
                            if let createdTimestamp = data["createdAt"] as? Timestamp {
                                print("   Created: \(createdTimestamp.dateValue())")
                            }
                        }
                    }
            }
    }
    
    func loadHangouts() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        print("🔄 HangoutsViewModel - Starting loadHangouts() for user: \(currentUserId)")
        
        isLoading = true
        
        Task {
            do {
                let fetchedHangouts = try await firestoreService.getHangouts(for: currentUserId)
                
                // Create a set of all persona IDs involved in hangouts
                var allPersonaIds = Set<String>()
                for hangout in fetchedHangouts {
                    allPersonaIds.insert(hangout.creatorPersonaID)
                    allPersonaIds.insert(hangout.inviteePersonaID)
                }
                
                // Check for recently created hangouts (within the last hour)
                let oneHourAgo = Date().addingTimeInterval(-3600)
                let recentHangouts = fetchedHangouts.filter {
                    $0.createdAt > oneHourAgo
                }
                
                print("🔍 RECENT HANGOUTS (created in the last hour): \(recentHangouts.count)")
                for recent in recentHangouts {
                    print("📝 Recent Hangout: \(recent.title), Status: \(recent.status.rawValue), Creator: \(recent.creatorID), ID: \(recent.id ?? "unknown"), Created: \(recent.createdAt)")
                }
                
                // Check specifically for hangouts where this user is the invitee
                let inviteeHangouts = fetchedHangouts.filter { 
                    $0.inviteeID == currentUserId
                }
                
                print("🔍 HANGOUTS WHERE USER IS INVITEE: \(inviteeHangouts.count)")
                for inviteeHangout in inviteeHangouts {
                    print("📝 Invitee Hangout: \(inviteeHangout.title), Status: \(inviteeHangout.status.rawValue), ID: \(inviteeHangout.id ?? "unknown")")
                }
                
                // Check specifically for pending hangouts for the current user
                let pendingForUser = fetchedHangouts.filter { 
                    $0.status == .pending && $0.inviteeID == currentUserId
                }
                
                print("🔍 PENDING HANGOUTS for user \(currentUserId): \(pendingForUser.count)")
                for pending in pendingForUser {
                    print("📝 Pending Hangout: \(pending.title), Creator: \(pending.creatorID), ID: \(pending.id ?? "unknown")")
                }
                
                // Fetch persona details for all involved personas
                var personaMap = [String: Persona]()
                
                print("🧩 HangoutsViewModel - Need to load \(allPersonaIds.count) personas")
                
                // Fetch all needed personas
                for personaId in allPersonaIds {
                    // Determine the user ID for this persona by checking each hangout
                    for hangout in fetchedHangouts {
                        if hangout.creatorPersonaID == personaId {
                            // This is a creator persona
                            if let persona = try? await firestoreService.getPersona(personaId, for: hangout.creatorID) {
                                personaMap[personaId] = persona
                                print("DEBUG: Loaded creator persona: \(persona.name) for ID \(personaId)")
                                break
                            }
                        } else if hangout.inviteePersonaID == personaId {
                            // This is an invitee persona
                            if let persona = try? await firestoreService.getPersona(personaId, for: hangout.inviteeID) {
                                personaMap[personaId] = persona
                                print("DEBUG: Loaded invitee persona: \(persona.name) for ID \(personaId)")
                                break
                            }
                        }
                    }
                }
                
                print("👤 HangoutsViewModel - Loaded \(personaMap.count) personas")
                
                DispatchQueue.main.async {
                    self.hangouts = fetchedHangouts
                    self.personaDetails = personaMap
                    self.isLoading = false
                    print("🔄 HangoutsViewModel - UI updated with \(self.hangouts.count) hangouts")
                    print("📊 Pending: \(self.pendingHangouts.count), Upcoming: \(self.upcomingHangouts.count), Declined: \(self.declinedHangouts.count), Past: \(self.pastHangouts.count)")
                    
                    // Update app badge count with number of pending requests
                    self.updateAppBadgeCount()
                }
            } catch {
                print("❌ HangoutsViewModel - Error loading hangouts: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    func updateAppBadgeCount() {
        // Count pending hangouts where current user is the invitee (requests to respond to)
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let pendingForUser = hangouts.filter { 
            $0.status == .pending && $0.inviteeID == currentUserId
        }
        
        // Set the app badge to the number of pending requests
        UNUserNotificationCenter.current().setBadgeCount(pendingForUser.count) { error in
            if let error = error {
                print("❌ Error setting badge count: \(error.localizedDescription)")
            } else {
                print("✅ App badge count updated to \(pendingForUser.count)")
            }
        }
    }
    
    // MARK: - Error Handling
    
    /// Handle errors using the centralized error handling system
    func handleErrorWithCentralizedSystem(_ error: Error) {
        // First check if it's already a HangoutError
        if let hangoutError = error as? HangoutError {
            ErrorHandler.shared.handle(hangoutError)
            return
        }
        
        // Convert NSError to HangoutError
        if let nsError = error as? NSError {
            let hangoutError = HangoutError(from: nsError)
            ErrorHandler.shared.handle(hangoutError)
            return
        }
        
        // For other error types, create a generic HangoutError
        let hangoutError = HangoutError(
            errorType: .internalError(error.localizedDescription),
            underlyingError: error
        )
        ErrorHandler.shared.handle(hangoutError)
    }
    
    // MARK: - Hangout Creation
    
    func createHangout(title: String, description: String, startDate: Date, endDate: Date, location: String?, inviteeID: String, creatorPersonaID: String, inviteePersonaID: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw HangoutError(errorType: .authenticationRequired)
        }
        
        let newHangout = Hangout(
            title: title,
            description: description,
            startDate: startDate,
            endDate: endDate,
            location: location,
            creatorID: userId,
            creatorPersonaID: creatorPersonaID,
            inviteeID: inviteeID,
            inviteePersonaID: inviteePersonaID
        )
        
        // Use the calendar service to check availability
        let isAvailable = await calendarService.checkAvailability(
            userId: userId, 
            startDate: startDate, 
            endDate: endDate
        )
        
        if !isAvailable {
            throw HangoutError(errorType: .calendarConflict)
        }
        
        // Create hangout in Firestore
        let hangoutId = try await firestoreService.createHangout(newHangout)
        print("Created hangout with ID: \(hangoutId)")
        
        // Add to calendar using the calendar service
        if let user = try? await firestoreService.getUser(id: userId) {
            // Create calendar event
            let calendarEvent = CalendarEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                attendees: [userId, inviteeID],
                associatedHangout: newHangout
            )
            
            do {
                // Use the calendar service to create the event
                let createdEvent = try await calendarService.create(calendarEvent)
                
                // Update hangout with calendar event ID
                if let _ = newHangout.id {
                    var updatedHangout = newHangout
                    updatedHangout.calendarEventID = createdEvent.id
                    try? await firestoreService.updateHangout(updatedHangout)
                }
            } catch {
                print("Error creating calendar event: \(error.localizedDescription)")
                // Continue without calendar event
            }
        }
    }
    
    func updateHangoutStatus(hangout: Hangout, newStatus: HangoutStatus) async {
        guard let hangoutId = hangout.id else { return }
        
        do {
            var updatedHangout = hangout
            updatedHangout.status = newStatus
            updatedHangout.updatedAt = Date()
            
            try await firestoreService.updateHangout(updatedHangout)
            
            // If the status changed to accepted or declined, send notification to creator
            if (newStatus == .accepted || newStatus == .declined) {
                // Get the responder's persona name
                let responderPersonaId = hangout.inviteePersonaID
                if let responderPersona = personaDetails[responderPersonaId] {
                    // Send notification to the creator
                    NotificationService.shared.sendHangoutResponseNotification(
                        to: hangout.creatorID,
                        accepted: newStatus == .accepted,
                        responderName: responderPersona.name,
                        hangoutTitle: hangout.title,
                        hangoutId: hangoutId
                    )
                }
            }
            
            // If the hangout was accepted, add to calendar
            if newStatus == .accepted && hangout.calendarEventID == nil {
                // Create calendar event using the calendar service
                do {
                    let eventId = try await calendarService.createCalendarEvent(
                        for: updatedHangout, 
                        userIDs: [hangout.creatorID, hangout.inviteeID]
                    )
                    
                    // Update hangout with calendar event ID
                    var calendarUpdatedHangout = updatedHangout
                    calendarUpdatedHangout.calendarEventID = eventId
                    try? await firestoreService.updateHangout(calendarUpdatedHangout)
                } catch {
                    print("Error creating calendar event: \(error.localizedDescription)")
                }
            }
            
            // If the hangout was declined or cancelled, remove from calendar
            if (newStatus == .declined || newStatus == .cancelled),
               let calendarEventID = hangout.calendarEventID {
                
                // Delete the event using the calendar service
                do {
                    try await calendarService.delete(calendarEventID)
                } catch {
                    print("Error deleting calendar event: \(error.localizedDescription)")
                }
            }
            
            DispatchQueue.main.async {
                self.loadHangouts()
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
        }
    }
    
    func deleteHangout(hangout: Hangout) async {
        guard let hangoutId = hangout.id else { return }
        
        do {
            // If there's a calendar event, delete it first using the calendar service
            if let calendarEventID = hangout.calendarEventID {
                do {
                    try await calendarService.delete(calendarEventID)
                } catch {
                    print("Error deleting calendar event: \(error.localizedDescription)")
                }
            }
            
            try await firestoreService.deleteHangout(hangoutId)
            
            DispatchQueue.main.async {
                self.loadHangouts()
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
        }
    }
    
    func cancelHangout(_ hangout: Hangout) async {
        guard let _ = hangout.id else { return }
        
        do {
            // Update hangout status
            var updatedHangout = hangout
            updatedHangout.status = .cancelled
            updatedHangout.updatedAt = Date()
            
            try await firestoreService.updateHangout(updatedHangout)
            
            // Remove from calendar if there's a calendar event using the calendar service
            if let calendarEventID = hangout.calendarEventID {
                do {
                    try await calendarService.delete(calendarEventID)
                } catch {
                    print("Error deleting calendar event: \(error.localizedDescription)")
                }
            }
            
            DispatchQueue.main.async {
                self.loadHangouts()
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
        }
    }
} 