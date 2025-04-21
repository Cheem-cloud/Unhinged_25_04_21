import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Foundation

// Make the class sendable to fix issues with closures
@MainActor
class HangoutCreationViewModel: ObservableObject {
    @Published var personas: [Persona] = []
    @Published var availableTimeSlots: [TimeSlot] = []
    @Published var isLoading = false
    @Published var isLoadingTimes = false
    @Published var error: Error?
    
    private let db = Firestore.firestore()
    private let calendarService: any CRUDService
    private let calendarOpsService: CalendarOperationsService
    
    // Add dependency injection for testability
    init(
        calendarService: (any CRUDService)? = nil,
        calendarOpsService: CalendarOperationsService? = nil
    ) {
        self.calendarService = calendarService ?? ServiceManager.shared.getService(CRUDService.self)
        self.calendarOpsService = calendarOpsService ?? ServiceManager.shared.getService(CalendarOperationsService.self)
    }
    
    func loadPersonas() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        do {
            let snapshot = try await db.collection("users").document(userId).collection("personas").getDocuments()
            
            var loadedPersonas: [Persona] = []
            
            for doc in snapshot.documents {
                let data = doc.data()
                // Extract required fields
                if let name = data["name"] as? String {
                    // Create persona manually with basic fields
                    let persona = Persona(
                        id: doc.documentID,
                        name: name,
                        bio: data["bio"] as? String ?? data["description"] as? String,
                        imageURL: data["imageURL"] as? String ?? data["avatarURL"] as? String,
                        isPremium: data["isPremium"] as? Bool ?? false
                    )
                    loadedPersonas.append(persona)
                    print("DEBUG: Manually created persona: id=\(doc.documentID), name=\(name)")
                } else {
                    print("DEBUG: Document missing required name field: \(doc.documentID)")
                }
            }
            
            personas = loadedPersonas
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    func loadAvailableTimes(date: Date, partnerUserId: String, partnerPersonaId: String, duration: TimeInterval) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            self.error = NSError(domain: "com.cheemhang.calendar", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            return
        }
        
        // No need for DispatchQueue in @MainActor
        self.isLoadingTimes = true
        self.availableTimeSlots = []
        
        do {
            // First check if both users have calendar access
            let userSettings = try await calendarOpsService.getCalendarSettings(for: userId)
            let partnerSettings = try await calendarOpsService.getCalendarSettings(for: partnerUserId)
            
            let userHasAccess = userSettings != nil && (userSettings?.connectedProviders.count ?? 0) > 0
            let partnerHasAccess = partnerSettings != nil && (partnerSettings?.connectedProviders.count ?? 0) > 0
            
            guard userHasAccess && partnerHasAccess else {
                throw NSError(
                    domain: "com.cheemhang.calendar",
                    code: 403,
                    userInfo: [NSLocalizedDescriptionKey: "Both users must connect a calendar provider to schedule hangouts"]
                )
            }
            
            // Calculate date range for fetching busy times
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            // Get busy times for both users using the adapter
            let calendarAdapter = calendarService as? CalendarServiceAdapter
            let userBusyTimes = try await calendarAdapter?.getFreeBusyInfo(
                for: userId,
                startDate: startOfDay,
                endDate: endOfDay
            ) ?? []
            
            let partnerBusyTimes = try await calendarAdapter?.getFreeBusyInfo(
                for: partnerUserId,
                startDate: startOfDay,
                endDate: endOfDay
            ) ?? []
            
            // Convert BusyTimePeriod to the expected format for generateTimeSlots
            let userBusyTimeTuples = userBusyTimes.map { (start: $0.start, end: $0.end) }
            let partnerBusyTimeTuples = partnerBusyTimes.map { (start: $0.start, end: $0.end) }
            
            // Generate available time slots based on busy times
            let slots = generateTimeSlots(
                date: date,
                duration: duration,
                userBusyTimes: userBusyTimeTuples,
                partnerBusyTimes: partnerBusyTimeTuples
            )
            
            // No need for DispatchQueue in @MainActor
            self.availableTimeSlots = slots
            self.isLoadingTimes = false
        } catch {
            // For demo purposes, generate some fake time slots if calendar API fails
            #if DEBUG
            let slots = generateFakeTimeSlots(date: date, duration: duration)
            
            // No need for DispatchQueue in @MainActor
            self.availableTimeSlots = slots
            self.isLoadingTimes = false
            #else
            self.error = error
            self.isLoadingTimes = false
            #endif
        }
    }
    
    private func generateTimeSlots(
        date: Date,
        duration: TimeInterval,
        userBusyTimes: [(start: Date, end: Date)],
        partnerBusyTimes: [(start: Date, end: Date)]
    ) -> [TimeSlot] {
        // Combine all busy times
        let allBusyTimes = userBusyTimes + partnerBusyTimes
        
        // Start with standard time slots (9am to 9pm)
        let calendar = Calendar.current
        var timeSlots: [TimeSlot] = []
        
        // Create date components from the selected date
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        
        // Create potential start times at 30-minute intervals
        for hour in 9..<21 {
            for minute in stride(from: 0, to: 60, by: 30) {
                var startComponents = dateComponents
                startComponents.hour = hour
                startComponents.minute = minute
                
                if let startTime = calendar.date(from: startComponents) {
                    let endTime = startTime.addingTimeInterval(duration)
                    
                    // Check if this time slot conflicts with any busy time
                    let hasConflict = allBusyTimes.contains { busyTime in
                        // Check for overlap
                        (startTime < busyTime.end && endTime > busyTime.start)
                    }
                    
                    if !hasConflict {
                        timeSlots.append(TimeSlot(start: startTime, end: endTime))
                    }
                }
            }
        }
        
        return timeSlots
    }
    
    private func generateFakeTimeSlots(date: Date, duration: TimeInterval) -> [TimeSlot] {
        // For development/demo purposes only
        let calendar = Calendar.current
        var slots: [TimeSlot] = []
        
        // Create date components from the selected date
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        
        // Generate some time slots at different hours
        for hour in [9, 11, 13, 15, 17, 19] {
            var startComponents = dateComponents
            startComponents.hour = hour
            startComponents.minute = 0
            
            if let startTime = calendar.date(from: startComponents) {
                let endTime = startTime.addingTimeInterval(duration)
                slots.append(TimeSlot(start: startTime, end: endTime))
            }
        }
        
        return slots
    }
    
    func createHangout(with partnerPersona: Persona, type: HangoutType, customTypeDescription: String? = nil, timeSlot: TimeSlot) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        do {
            // Get the current user's default persona
            print("🔍 DEBUG: Fetching personas for user: \(userId)")
            let userPersonas = try await db.collection("users").document(userId).collection("personas").getDocuments()
            print("🔍 DEBUG: Found \(userPersonas.documents.count) personas")
            
            // Manually create personas from document data to avoid decoding issues
            var loadedPersonas: [Persona] = []
            
            for doc in userPersonas.documents {
                let data = doc.data()
                // Extract required fields
                if let name = data["name"] as? String {
                    // Create persona manually with basic fields
                    let persona = Persona(
                        id: doc.documentID,
                        name: name,
                        bio: data["bio"] as? String ?? data["description"] as? String,
                        imageURL: data["imageURL"] as? String ?? data["avatarURL"] as? String,
                        isPremium: data["isPremium"] as? Bool ?? false
                    )
                    loadedPersonas.append(persona)
                    print("🔍 DEBUG: Manually created persona: id=\(doc.documentID), name=\(name)")
                } else {
                    print("🔍 DEBUG: Document missing required name field: \(doc.documentID)")
                }
            }
            
            // Since isDefault doesn't exist in Persona, use the first persona as default
            let defaultPersona = loadedPersonas.first
            
            if let defaultPersona = defaultPersona {
                print("✅ DEBUG: Found persona to use: \(defaultPersona.name) with ID: \(defaultPersona.id ?? "unknown")")
            } else {
                print("❌ DEBUG: No personas found")
                throw NSError(domain: "com.cheemhang.hangout", code: 1, userInfo: [NSLocalizedDescriptionKey: "No personas found for user"])
            }
            
            guard let userPersona = defaultPersona, let userPersonaId = userPersona.id else {
                throw NSError(domain: "com.cheemhang.hangout", code: 1, userInfo: [NSLocalizedDescriptionKey: "No persona found or persona has no ID"])
            }
            
            // Get invitee ID from Auth.auth().currentUser?.uid since partnerPersona doesn't have userID
            // For the invitee ID, we need to fetch it from Firestore
            
            // Fetch the owner of the partner persona
            print("🔍 DEBUG: Fetching owner for partner persona: \(partnerPersona.name) with ID: \(partnerPersona.id ?? "unknown")")
            
            // Initialize with a fallback value
            var inviteeUserId = "unknown_user"
            
            // Try to find the invitee ID by querying Firestore for personas with matching ID
            do {
                // Query all users' persona collections
                let usersRef = db.collection("users")
                let usersSnapshot = try await usersRef.getDocuments()
                
                for userDoc in usersSnapshot.documents {
                    let potentialInviteeId = userDoc.documentID
                    // Skip checking our own user doc
                    if potentialInviteeId == userId { continue }
                    
                    // Check this user's personas for a match
                    if let partnerPersonaId = partnerPersona.id {
                        let personaRef = userDoc.reference.collection("personas").document(partnerPersonaId)
                        let personaDoc = try await personaRef.getDocument()
                        
                        if personaDoc.exists {
                            // We found the owner of this persona
                            inviteeUserId = potentialInviteeId
                            print("✅ DEBUG: Found invitee user ID: \(inviteeUserId) for persona: \(partnerPersona.name)")
                            break
                        }
                    }
                }
            } catch {
                print("⚠️ DEBUG: Error finding invitee user ID: \(error.localizedDescription)")
                // Continue with the unknown user ID as fallback
            }
            
            // Determine the hangout title and description
            let hangoutTypeLabel = type == .other && customTypeDescription != nil ? 
                               customTypeDescription! : 
                               type.rawValue
            
            // Create the hangout data
            let hangout = Hangout(
                title: "\(hangoutTypeLabel) with \(partnerPersona.name)",
                description: type == .other && customTypeDescription != nil ?
                    "A custom \(customTypeDescription!.lowercased()) hangout between \(userPersona.name) and \(partnerPersona.name)." :
                    "A \(type.rawValue.lowercased()) hangout between \(userPersona.name) and \(partnerPersona.name).",
                startDate: timeSlot.start,
                endDate: timeSlot.end,
                location: nil,
                creatorID: userId,
                creatorPersonaID: userPersonaId,
                inviteeID: inviteeUserId,
                inviteePersonaID: partnerPersona.id ?? "",
                status: .pending
            )
            
            print("🔶 CREATING HANGOUT - Creator: \(userId), Invitee: \(inviteeUserId)")
            print("🔶 Hangout details - Type: \(hangoutTypeLabel), Start: \(timeSlot.start)")
            print("🔶 STATUS SET TO: \(hangout.status.rawValue)")
            
            // Save to Firestore
            let firestoreService = FirestoreService()
            let hangoutId = try await firestoreService.createHangout(hangout)
            
            print("✅ HANGOUT CREATED SUCCESSFULLY with ID: \(hangoutId)")
            print("📩 The invitee (\(inviteeUserId)) should now see this request")
            
            // Verify hangout creation
            if let createdHangout = try? await firestoreService.getHangout(hangoutId) {
                print("✅ VERIFIED HANGOUT - ID: \(hangoutId), Status: \(createdHangout.status.rawValue)")
            } else {
                print("❌ FAILED TO VERIFY HANGOUT - ID: \(hangoutId)")
            }
            
            // Send notification to invitee - using only the persona name
            NotificationService.shared.sendNewHangoutRequestNotification(
                to: inviteeUserId,
                from: userPersona.name,  // Using only the persona name, not the real user name
                hangoutTitle: hangout.title,
                hangoutId: hangoutId
            )
            
            // Add to both users' calendars if they have calendar access
            do {
                let hangoutEvent = CalendarEventModel(
                    title: hangout.title,
                    description: hangout.description,
                    startDate: hangout.startDate,
                    endDate: hangout.endDate,
                    location: hangout.location,
                    provider: .google
                )
                
                // Use our CRUDService interface to create the event
                let _ = try await calendarService.create(hangoutEvent)
            } catch {
                // Just log the error but don't fail the hangout creation
                print("Error creating calendar event: \(error.localizedDescription)")
            }
            
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
            print("Error creating hangout: \(error.localizedDescription)")
        }
    }
} 