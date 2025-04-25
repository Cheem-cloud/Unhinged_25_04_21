import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit
import Firebase

class CalendarOperationsServiceImpl: CalendarOperationsService {
    typealias EntityType = CalendarEvent
    
    private let db = Firestore.firestore()
    private let googleBaseURL = "https://www.googleapis.com/calendar/v3"
    
    init() {
        print("📅 Initialized CalendarOperationsServiceImpl")
    }
    
    // MARK: - CRUDService Methods
    
    func create(_ entity: CalendarEvent) async throws -> CalendarEvent {
        print("Creating calendar event: \(entity.title)")
        
        // Get the current user ID
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ServiceError.notAuthenticated
        }
        
        // Create event across connected calendar providers
        let eventId = try await createEventAcrossCalendars(entity: entity, userId: userId)
        
        // Return updated entity with ID
        var updatedEntity = entity
        updatedEntity.id = eventId
        return updatedEntity
    }
    
    func read(_ id: String) async throws -> CalendarEvent {
        // Implementation of calendar event retrieval
        throw ServiceError.notImplemented("Reading individual calendar events is not implemented yet")
    }
    
    func update(_ entity: CalendarEvent) async throws -> CalendarEvent {
        // Implementation using deletion and recreation
        try await delete(entity.id)
        return try await create(entity)
    }
    
    func delete(_ id: String) async throws {
        print("Deleting calendar event: \(id)")
        
        // Get the current user ID
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ServiceError.notAuthenticated
        }
        
        // Get all connected providers
        let settings = try await getCalendarSettings(for: userId)
        
        // Flag to track if deletion succeeded on at least one provider
        var deletionSuccess = false
        
        // Delete from all connected providers
        for providerSettings in settings.connectedProviders {
            do {
                // Make API call to delete event based on provider type
                if providerSettings.providerType == "google" {
                    try await deleteGoogleCalendarEvent(eventId: id, accessToken: providerSettings.accessToken)
                    deletionSuccess = true
                }
                // Add more providers as needed
            } catch {
                print("Failed to delete event from \(providerSettings.providerType): \(error.localizedDescription)")
                // Continue trying other providers
            }
        }
        
        if !deletionSuccess {
            throw ServiceError.operationFailed("Failed to delete event from all providers")
        }
    }
    
    func list() async throws -> [CalendarEvent] {
        // Implementation of event listing
        throw ServiceError.notImplemented("Listing calendar events is not implemented yet")
    }
    
    // MARK: - CalendarOperationsService Methods
    
    func getCalendarSettings(for userID: String) async throws -> CalendarSettings {
        print("Getting calendar settings for user: \(userID)")
        
        let docRef = db.collection("users").document(userID)
            .collection("settings").document("calendar")
        
        let doc = try await docRef.getDocument()
        
        // Default settings if none exist
        if !doc.exists {
            return CalendarSettings(isCalendarConnected: false, connectedProviders: [])
        }
        
        guard let data = doc.data() else {
            return CalendarSettings(isCalendarConnected: false, connectedProviders: [])
        }
        
        // Parse provider data
        var connectedProviders: [ProviderSettings] = []
        
        if let providers = data["providers"] as? [String] {
            for providerName in providers {
                // Get provider-specific settings
                let providerDoc = try await db.collection("users").document(userID)
                    .collection("tokens").document(providerName.lowercased()).getDocument()
                
                if providerDoc.exists, let providerData = providerDoc.data() {
                    let settings = ProviderSettings(
                        providerType: providerName,
                        accessToken: providerData["accessToken"] as? String ?? "",
                        refreshToken: providerData["refreshToken"] as? String ?? "",
                        useForEvents: true,
                        useForAvailability: true
                    )
                    connectedProviders.append(settings)
                }
            }
        }
        
        return CalendarSettings(
            isCalendarConnected: !connectedProviders.isEmpty,
            connectedProviders: connectedProviders
        )
    }
    
    func hasCalendarAccess(for userID: String) async throws -> Bool {
        print("Checking calendar access for user: \(userID)")
        let settings = try await getCalendarSettings(for: userID)
        return settings.isCalendarConnected
    }
    
    func checkAvailability(userId: String, startDate: Date, endDate: Date) async -> Bool {
        print("Checking availability for user \(userId) from \(startDate) to \(endDate)")
        
        do {
            // Get all busy times for the user
            let busyTimes = try await getBusyTimes(for: userId, startDate: startDate, endDate: endDate)
            
            // Check if the proposed time overlaps with any busy time
            for busyTime in busyTimes {
                // If there's overlap, user is not available
                if startDate < busyTime.end && endDate > busyTime.start {
                    return false
                }
            }
            
            // No conflicts found
            return true
        } catch {
            print("Error checking availability: \(error.localizedDescription)")
            return true // Default to available if we can't check
        }
    }
    
    func findMutualAvailability(userIDs: [String], startRange: Date, endRange: Date, duration: TimeInterval) async -> [DateInterval] {
        print("Finding mutual availability for \(userIDs.count) users")
        
        var allBusyTimes: [(start: Date, end: Date)] = []
        
        // Get busy times for all users
        for userId in userIDs {
            do {
                let userBusyTimes = try await getBusyTimes(for: userId, startDate: startRange, endDate: endRange)
                allBusyTimes.append(contentsOf: userBusyTimes)
            } catch {
                print("Error getting busy times for user \(userId): \(error.localizedDescription)")
            }
        }
        
        // Generate and filter time slots
        let slots = generateTimeSlots(startDate: startRange, endDate: endRange, duration: duration)
        let availableSlots = slots.filter { slot in
            // A slot is available if it doesn't overlap with any busy time
            !allBusyTimes.contains { busy in
                max(slot.start, busy.start) < min(slot.end, busy.end)
            }
        }
        
        // Convert to DateIntervals
        return availableSlots.map { DateInterval(start: $0.start, end: $0.end) }
    }
    
    func createCalendarEvent(for hangout: Hangout, userIDs: [String]) async throws -> String {
        print("Creating calendar event for hangout: \(hangout.title)")
        
        // Create CalendarEvent from Hangout
        let event = CalendarEvent(
            title: hangout.title,
            startDate: hangout.startDate,
            endDate: hangout.endDate,
            attendees: userIDs,
            associatedHangout: hangout
        )
        
        // Create event and return ID
        let createdEvent = try await create(event)
        return createdEvent.id
    }
    
    func authenticateCalendarAccess(for userID: String) async throws {
        print("Authenticating calendar access for user: \(userID)")
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw ServiceError.configurationError("Could not get Firebase client ID")
        }
        
        // Get the top view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw ServiceError.configurationError("Could not get root view controller")
        }
        
        // Configure GIDSignIn
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Sign in with Google and request calendar scope
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController,
            hint: nil, 
            additionalScopes: ["https://www.googleapis.com/auth/calendar", 
                              "https://www.googleapis.com/auth/calendar.events"]
        )
        
        // Save the token to Firestore
        var data: [String: Any] = [
            "accessToken": result.user.accessToken.tokenString,
            "updatedAt": Timestamp(date: Date())
        ]
        
        // Add expiration date if available
        if let expirationDate = result.user.accessToken.expirationDate {
            data["expirationDate"] = Timestamp(date: expirationDate)
        }
        
        // Add refresh token
        if result.user.refreshToken != nil {
            data["refreshToken"] = result.user.refreshToken.tokenString
        }
        
        // Add email if available
        if let email = result.user.profile?.email {
            data["email"] = email
        }
        
        // Save to Firestore
        try await db.collection("users").document(userID)
            .collection("tokens").document("google").setData(data)
        
        // Update provider list
        try await updateProviderList(for: userID, provider: "google")
    }
    
    // MARK: - Private helper methods
    
    private func updateProviderList(for userID: String, provider: String) async throws {
        let docRef = db.collection("users").document(userID)
            .collection("settings").document("calendar")
        
        // Get existing providers
        let doc = try await docRef.getDocument()
        var providers: [String] = []
        
        if doc.exists, let data = doc.data(), let existingProviders = data["providers"] as? [String] {
            providers = existingProviders
        }
        
        // Add provider if not already in list
        if !providers.contains(provider) {
            providers.append(provider)
        }
        
        // Update settings
        try await docRef.setData(["providers": providers], merge: true)
    }
    
    private func createEventAcrossCalendars(entity: CalendarEvent, userId: String) async throws -> String {
        // Get settings for all providers
        let settings = try await getCalendarSettings(for: userId)
        
        if settings.connectedProviders.isEmpty {
            throw ServiceError.configurationError("No calendar providers connected")
        }
        
        // Try to create on all connected providers
        var eventIds: [String: String] = [:]
        
        for provider in settings.connectedProviders where provider.useForEvents {
            do {
                let eventId = try await createEventOnProvider(
                    provider: provider,
                    event: entity,
                    userId: userId
                )
                eventIds[provider.providerType] = eventId
            } catch {
                print("Failed to create event on \(provider.providerType): \(error)")
            }
        }
        
        // Return any successful ID
        if let firstId = eventIds.values.first {
            return firstId
        }
        
        throw ServiceError.operationFailed("Failed to create event on any provider")
    }
    
    private func createEventOnProvider(provider: ProviderSettings, event: CalendarEvent, userId: String) async throws -> String {
        switch provider.providerType.lowercased() {
        case "google":
            return try await createGoogleCalendarEvent(
                event: event,
                accessToken: provider.accessToken,
                userId: userId
            )
        default:
            throw ServiceError.notSupported("Provider \(provider.providerType) not supported")
        }
    }
    
    private func createGoogleCalendarEvent(event: CalendarEvent, accessToken: String, userId: String) async throws -> String {
        // Google Calendar API event creation
        let url = URL(string: "\(googleBaseURL)/calendars/primary/events")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Format dates
        let dateFormatter = ISO8601DateFormatter()
        let startTimeString = dateFormatter.string(from: event.startDate)
        let endTimeString = dateFormatter.string(from: event.endDate)
        
        // Prepare attendees
        var attendees: [[String: String]] = []
        for attendeeId in event.attendees {
            // In a real implementation, you'd fetch the email for this userId
            if let email = try? await getUserEmail(userId: attendeeId) {
                attendees.append(["email": email])
            }
        }
        
        // Create request body
        let requestBody: [String: Any] = [
            "summary": event.title,
            "start": ["dateTime": startTimeString],
            "end": ["dateTime": endTimeString],
            "attendees": attendees
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            throw ServiceError.networkError("Status code: \(httpResponse.statusCode), Response: \(responseString)")
        }
        
        // Parse response to get event ID
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventId = json["id"] as? String else {
            throw ServiceError.dataError("Could not parse event ID from response")
        }
        
        return eventId
    }
    
    private func deleteGoogleCalendarEvent(eventId: String, accessToken: String) async throws {
        let url = URL(string: "\(googleBaseURL)/calendars/primary/events/\(eventId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw ServiceError.networkError("Status code: \(httpResponse.statusCode)")
        }
    }
    
    private func getBusyTimes(for userId: String, startDate: Date, endDate: Date) async throws -> [(start: Date, end: Date)] {
        // Get calendar settings
        let settings = try await getCalendarSettings(for: userId)
        
        if settings.connectedProviders.isEmpty {
            return [] // No calendars connected
        }
        
        var allBusyTimes: [(start: Date, end: Date)] = []
        
        // For each provider, get busy times
        for provider in settings.connectedProviders where provider.useForAvailability {
            do {
                let busyTimes = try await getBusyTimesFromProvider(
                    provider: provider,
                    userId: userId,
                    startDate: startDate,
                    endDate: endDate
                )
                allBusyTimes.append(contentsOf: busyTimes)
            } catch {
                print("Error getting busy times from \(provider.providerType): \(error)")
            }
        }
        
        return allBusyTimes
    }
    
    private func getBusyTimesFromProvider(provider: ProviderSettings, userId: String, startDate: Date, endDate: Date) async throws -> [(start: Date, end: Date)] {
        switch provider.providerType.lowercased() {
        case "google":
            return try await getGoogleCalendarBusyTimes(
                accessToken: provider.accessToken,
                startDate: startDate,
                endDate: endDate
            )
        default:
            return []
        }
    }
    
    private func getGoogleCalendarBusyTimes(accessToken: String, startDate: Date, endDate: Date) async throws -> [(start: Date, end: Date)] {
        let url = URL(string: "\(googleBaseURL)/freeBusy")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dateFormatter = ISO8601DateFormatter()
        let startTimeString = dateFormatter.string(from: startDate)
        let endTimeString = dateFormatter.string(from: endDate)
        
        let requestBody: [String: Any] = [
            "timeMin": startTimeString,
            "timeMax": endTimeString,
            "items": [["id": "primary"]]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ServiceError.networkError("Status code: \(httpResponse.statusCode)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let calendars = json["calendars"] as? [String: Any],
              let primary = calendars["primary"] as? [String: Any],
              let busyArray = primary["busy"] as? [[String: String]] else {
            throw ServiceError.dataError("Could not parse response")
        }
        
        return busyArray.compactMap { busy -> (start: Date, end: Date)? in
            guard let startString = busy["start"],
                  let endString = busy["end"],
                  let startDate = dateFormatter.date(from: startString),
                  let endDate = dateFormatter.date(from: endString) else {
                return nil
            }
            return (start: startDate, end: endDate)
        }
    }
    
    private func getUserEmail(userId: String) async throws -> String {
        // In a real implementation, you'd fetch the user's email from your user database
        // For now, we'll simulate this
        let userDoc = try await db.collection("users").document(userId).getDocument()
        
        if let data = userDoc.data(), let email = data["email"] as? String {
            return email
        }
        
        // Fallback to a placeholder
        return "\(userId)@example.com"
    }
    
    private func generateTimeSlots(startDate: Date, endDate: Date, duration: TimeInterval) -> [(start: Date, end: Date)] {
        var slots: [(start: Date, end: Date)] = []
        let calendar = Calendar.current
        
        // Business hours: 9am to 6pm
        let startHour = 9
        let endHour = 18
        
        // Current date to iterate
        var currentDate = calendar.startOfDay(for: startDate)
        
        // Generate slots until we reach end date
        while currentDate < endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            
            // Skip weekends (1 = Sunday, 7 = Saturday)
            if weekday != 1 && weekday != 7 {
                // For each day, generate slots during business hours
                for hour in startHour..<endHour {
                    for minute in stride(from: 0, to: 60, by: 30) {
                        if let slotStart = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: currentDate) {
                            let slotEnd = slotStart.addingTimeInterval(duration)
                            
                            // Only include if end time is before business hours end
                            if calendar.component(.hour, from: slotEnd) <= endHour && slotEnd <= endDate {
                                slots.append((start: slotStart, end: slotEnd))
                            }
                        }
                    }
                }
            }
            
            // Move to next day
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                currentDate = nextDay
            } else {
                break
            }
        }
        
        return slots
    }
}

// Supporting type definitions
struct CalendarSettings {
    let isCalendarConnected: Bool
    let connectedProviders: [ProviderSettings]
}

struct ProviderSettings {
    let providerType: String
    let accessToken: String
    let refreshToken: String
    let useForEvents: Bool
    let useForAvailability: Bool
} 