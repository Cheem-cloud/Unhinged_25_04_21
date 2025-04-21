import Foundation
import GoogleSignIn
import FirebaseFirestore
import FirebaseAuth
import UIKit
import Firebase

/// Calendar invite response options
enum InviteResponse {
    case accept
    case decline
    case tentative
}

enum CalendarServiceError: Error {
    case invalidToken
    case requestFailed
    case invalidResponse
    case parseError
    case apiError(String)
    case noCalendarConfigured
}

/// Legacy calendar service - use CalendarServiceAdapter instead
@available(*, deprecated, message: "Use CalendarServiceAdapter through ServiceManager.shared.getService(CRUDService.self) instead")
class CalendarService {
    @available(*, deprecated, message: "Use ServiceManager.shared.getService(CRUDService.self) instead")
    static let shared = CalendarService()
    
    private let baseURL = "https://www.googleapis.com/calendar/v3"
    private let db = Firestore.firestore()
    private let firestoreService = FirestoreService.shared
    
    public init() {}
    
    @available(*, deprecated, message: "Use calendarService.checkAvailability(userId:startDate:endDate:) instead")
    func checkAvailability(userId: String, startDate: Date, endDate: Date) async -> Bool {
        do {
            // Get busy times for this time range
            let userToken = try await getCalendarToken(for: userId)
            let busyTimes = try await getBusyTimes(accessToken: userToken, startDate: startDate, endDate: endDate)
            
            // Check if our proposed time overlaps with any busy time
            let hasConflict = busyTimes.contains { busyTime in
                // Check for overlap
                (startDate < busyTime.end && endDate > busyTime.start)
            }
            
            return !hasConflict
        } catch {
            print("Error checking calendar availability: \(error.localizedDescription)")
            // If we can't check availability, we'll assume available
            return true
        }
    }
    
    @available(*, deprecated, message: "Use calendarService.getBusyTimes(accessToken:date:) instead")
    func getBusyTimes(accessToken: String, date: Date) async throws -> [(start: Date, end: Date)] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Call the version that accepts a date range
        return try await getBusyTimes(accessToken: accessToken, startDate: startOfDay, endDate: endOfDay)
    }
    
    @available(*, deprecated, message: "Use calendarService.create(CalendarEventModel) instead")
    func createCalendarEvent(
        accessToken: String,
        title: String,
        description: String,
        startDate: Date,
        endDate: Date,
        location: String?,
        attendees: [String]? = nil
    ) async throws -> String {
        guard !accessToken.isEmpty else {
            throw CalendarServiceError.invalidToken
        }
        
        let url = URL(string: "\(baseURL)/calendars/primary/events")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dateFormatter = ISO8601DateFormatter()
        
        var eventBody: [String: Any] = [
            "summary": title,
            "description": description,
            "start": [
                "dateTime": dateFormatter.string(from: startDate),
                "timeZone": TimeZone.current.identifier
            ],
            "end": [
                "dateTime": dateFormatter.string(from: endDate),
                "timeZone": TimeZone.current.identifier
            ],
            "status": "confirmed",
            "guestsCanModify": true
        ]
        
        // Add attendees if provided
        if let attendees = attendees, !attendees.isEmpty {
            let attendeeObjects = attendees.map { email -> [String: Any] in
                return [
                    "email": email,
                    "responseStatus": "needsAction",
                    "optional": false
                ]
            }
            eventBody["attendees"] = attendeeObjects
        }
        
        if let location = location, !location.isEmpty {
            eventBody["location"] = location
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: eventBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CalendarServiceError.invalidResponse
            }
            
            // Accept 200 (OK) or 201 (Created)
            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                print("Calendar API error creating event: \(responseString)")
                throw CalendarServiceError.apiError("Status code: \(httpResponse.statusCode)")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let eventId = json["id"] as? String else {
                throw CalendarServiceError.parseError
            }
            
            print("Successfully created calendar event with ID: \(eventId)")
            return eventId
        } catch {
            print("Error creating calendar event: \(error.localizedDescription)")
            throw error
        }
    }
    
    @available(*, deprecated, message: "Use calendarService.delete(eventId) instead")
    func deleteCalendarEvent(accessToken: String, eventId: String) async throws {
        guard !accessToken.isEmpty else {
            throw CalendarServiceError.invalidToken
        }
        
        let url = URL(string: "\(baseURL)/calendars/primary/events/\(eventId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CalendarServiceError.invalidResponse
            }
            
            // 204 is success for DELETE
            guard httpResponse.statusCode == 204 else {
                throw CalendarServiceError.apiError("Status code: \(httpResponse.statusCode)")
            }
            
            print("Successfully deleted calendar event with ID: \(eventId)")
        } catch {
            print("Error deleting calendar event: \(error.localizedDescription)")
            throw error
        }
    }
    
    @available(*, deprecated, message: "Use calendarService.findMutualAvailability(userIDs:startDate:endDate:duration:) instead")
    func findMutualAvailability(userIDs: [String], startDate: Date, endDate: Date, duration: TimeInterval) async throws -> [DateInterval] {
        guard userIDs.count == 2 else {
            throw CalendarServiceError.invalidResponse
        }

        print("CalendarService: Finding mutual availability for \(userIDs)")
        
        // Get providers for both users
        let user1Providers = await getConnectedCalendarProviders(for: userIDs[0])
        let user2Providers = await getConnectedCalendarProviders(for: userIDs[1])
        
        guard !user1Providers.isEmpty && !user2Providers.isEmpty else {
            throw NSError(
                domain: "com.cheemhang.calendar",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Both users must connect a calendar provider to schedule hangouts"]
            )
        }
        
        var allBusyTimes: [(start: Date, end: Date)] = []
        
        // Get user1's busy times from all their connected calendars
        let user1BusyTimes = await getAllBusyTimes(for: userIDs[0], startDate: startDate, endDate: endDate)
        allBusyTimes.append(contentsOf: user1BusyTimes)
        print("CalendarService: Found \(user1BusyTimes.count) busy times for user1")
        
        // Get user2's busy times from all their connected calendars
        let user2BusyTimes = await getAllBusyTimes(for: userIDs[1], startDate: startDate, endDate: endDate)
        allBusyTimes.append(contentsOf: user2BusyTimes)
        print("CalendarService: Found \(user2BusyTimes.count) busy times for user2")
        
        // Sort busy times chronologically
        allBusyTimes.sort { $0.start < $1.start }
        
        // Merge overlapping busy times
        var mergedBusyTimes: [(start: Date, end: Date)] = []
        for busyTime in allBusyTimes {
            if let lastBusy = mergedBusyTimes.last, lastBusy.end >= busyTime.start {
                // Overlap exists, merge them
                let newEnd = max(lastBusy.end, busyTime.end)
                mergedBusyTimes[mergedBusyTimes.count - 1] = (start: lastBusy.start, end: newEnd)
            } else {
                // No overlap, add as new busy time
                mergedBusyTimes.append(busyTime)
            }
        }
        
        // Generate potential time slots
        let potentialSlots = generateAllPossibleTimeSlots(startDate: startDate, endDate: endDate, duration: duration)
        
        // Filter out busy slots
        let availableSlots = potentialSlots.filter { slot in
            !mergedBusyTimes.contains { busyTime in
                // Check if this slot overlaps with any busy time
                max(slot.start, busyTime.start) < min(slot.end, busyTime.end)
            }
        }
        
        // Convert to DateIntervals
        let dateIntervals = availableSlots.map { DateInterval(start: $0.start, end: $0.end) }
        
        // If no slots are available, fallback to some realistic samples
        if dateIntervals.isEmpty {
            print("CalendarService: No available slots found, providing fallback slots")
            return generateRealisticAvailability(startDate: startDate, endDate: endDate, duration: duration)
        }
        
        return dateIntervals
    }
    
    @available(*, deprecated, message: "Use calendarService.getCalendarToken(for:) instead")
    func getCalendarToken(for userId: String) async throws -> String {
        do {
            // Attempt to get token from Firestore
            let docRef = db.collection("users").document(userId).collection("tokens").document("calendar")
            
            let document = try await docRef.getDocument()
            
            guard let data = document.data(),
                  let accessToken = data["accessToken"] as? String else {
                
                // If no token exists but the user is the current user, try to authenticate
                if userId == Auth.auth().currentUser?.uid {
                    print("No token found for current user, attempting authentication")
                    try await authenticateAndSaveCalendarAccess(for: userId)
                    return try await getCalendarToken(for: userId) // Recursive call after auth
                }
                
                throw CalendarServiceError.invalidToken
            }
            
            // Check if token is expired
            if let expirationTimestamp = data["expirationDate"] as? Timestamp {
                let expirationDate = expirationTimestamp.dateValue()
                
                // If token is expired or will expire in the next 5 minutes
                if expirationDate.timeIntervalSinceNow < 300 {
                    // Only refresh for current user
                    if userId == Auth.auth().currentUser?.uid {
                        print("Token expired, refreshing...")
                        
                        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
                            do {
                                // Restore previous sign-in session
                                let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
                                
                                // Get fresh token - accessToken is non-optional in GoogleSignIn v6+
                                let accessToken = user.accessToken.tokenString
                                
                                // Save the updated token
                                try await saveTokenFromUser(user, userId: userId)
                                
                                print("Token refreshed successfully")
                                return accessToken
                            } catch {
                                print("Failed to refresh token: \(error.localizedDescription)")
                                // Fall back to full re-authentication
                                try await authenticateAndSaveCalendarAccess(for: userId)
                                return try await getCalendarToken(for: userId)
                            }
                        } else {
                            // No previous sign-in, need full re-auth
                            try await authenticateAndSaveCalendarAccess(for: userId) 
                            return try await getCalendarToken(for: userId)
                        }
                    }
                }
            }
            
            print("Retrieved valid calendar token for user \(userId)")
            return accessToken
        } catch {
            print("Error getting calendar token: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Helper function to get busy times for a specific user
    private func getBusyTimesForUser(userID: String, startDate: Date, endDate: Date) async throws -> [(start: Date, end: Date)] {
        do {
            // Get the user's calendar token from Firebase
            let accessToken = try await getCalendarToken(for: userID)
            
            // Use the token to query Google Calendar API
            return try await getBusyTimes(accessToken: accessToken, startDate: startDate, endDate: endDate)
        } catch {
            print("Error getting busy times for user \(userID): \(error.localizedDescription)")
            // Return some simulated busy times for development
            return generateSimulatedBusyTimes(startDate: startDate, endDate: endDate)
        }
    }
    
    @available(*, deprecated, message: "Use calendarService.getBusyTimes(accessToken:startDate:endDate:) instead")
    func getBusyTimes(accessToken: String, startDate: Date, endDate: Date) async throws -> [(start: Date, end: Date)] {
        guard !accessToken.isEmpty else {
            throw CalendarServiceError.invalidToken
        }
        
        let startTimeString = ISO8601DateFormatter().string(from: startDate)
        let endTimeString = ISO8601DateFormatter().string(from: endDate)
        
        let url = URL(string: "\(baseURL)/freeBusy")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "timeMin": startTimeString,
            "timeMax": endTimeString,
            "items": [["id": "primary"]]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CalendarServiceError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                print("Calendar API error: \(responseString)")
                throw CalendarServiceError.apiError("Status code: \(httpResponse.statusCode)")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let calendars = json["calendars"] as? [String: Any],
                  let primary = calendars["primary"] as? [String: Any],
                  let busyArray = primary["busy"] as? [[String: String]] else {
                throw CalendarServiceError.parseError
            }
            
            let dateFormatter = ISO8601DateFormatter()
            let busyTimes = busyArray.compactMap { busy -> (start: Date, end: Date)? in
                guard let startString = busy["start"],
                      let endString = busy["end"],
                      let startDate = dateFormatter.date(from: startString),
                      let endDate = dateFormatter.date(from: endString) else {
                    return nil
                }
                return (start: startDate, end: endDate)
            }
            
            return busyTimes
        } catch {
            print("Error fetching busy times: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Generate some simulated busy times for development
    private func generateSimulatedBusyTimes(startDate: Date, endDate: Date) -> [(start: Date, end: Date)] {
        var busyTimes: [(start: Date, end: Date)] = []
        let calendar = Calendar.current
        
        // Current date to iterate
        var currentDate = calendar.startOfDay(for: startDate)
        
        // Generate busy times until we reach end date
        while currentDate < endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            
            // Work hours (9am-5pm) on weekdays
            if weekday >= 2 && weekday <= 6 {
                // Morning meeting 10-11am
                if let meetingStart = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: currentDate),
                   let meetingEnd = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: currentDate) {
                    busyTimes.append((start: meetingStart, end: meetingEnd))
                }
                
                // Lunch 12-1pm
                if let lunchStart = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: currentDate),
                   let lunchEnd = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: currentDate) {
                    busyTimes.append((start: lunchStart, end: lunchEnd))
                }
                
                // Random afternoon meeting (30% chance)
                if Double.random(in: 0...1) < 0.3, 
                   let meetingStart = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: currentDate),
                   let meetingEnd = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: currentDate) {
                    busyTimes.append((start: meetingStart, end: meetingEnd))
                }
            }
            
            // Random weekend plans (20% chance)
            if (weekday == 1 || weekday == 7) && Double.random(in: 0...1) < 0.2 {
                if let planStart = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: currentDate),
                   let planEnd = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: currentDate) {
                    busyTimes.append((start: planStart, end: planEnd))
                }
            }
            
            // Move to next day
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                currentDate = nextDay
            } else {
                break
            }
        }
        
        return busyTimes
    }
    
    // Generate all possible time slots that could be scheduled
    private func generateAllPossibleTimeSlots(startDate: Date, endDate: Date, duration: TimeInterval) -> [(start: Date, end: Date)] {
        var slots: [(start: Date, end: Date)] = []
        let calendar = Calendar.current
        
        // Business hours: 9am to 9pm
        let startHour = 9
        let endHour = 21
        
        // Current date to iterate
        var currentDate = calendar.startOfDay(for: startDate)
        
        // Generate slots until we reach end date
        while currentDate < endDate {
            // For each day, generate slots during business hours
            for hour in startHour..<endHour {
                for minute in stride(from: 0, to: 60, by: 30) {
                    if let slotStart = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: currentDate) {
                        let slotEnd = slotStart.addingTimeInterval(duration)
                        
                        // Only include if end time is before business hours end and before endDate
                        if calendar.component(.hour, from: slotEnd) < endHour && slotEnd <= endDate {
                            slots.append((start: slotStart, end: slotEnd))
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
    
    // Generate realistic mock availability for debugging/development
    private func generateRealisticAvailability(startDate: Date, endDate: Date, duration: TimeInterval) -> [DateInterval] {
        var availableSlots: [DateInterval] = []
        let calendar = Calendar.current
        
        // Business hours: 9am to 6pm
        let businessHoursStart = 9
        let businessHoursEnd = 18
        
        // Current date to iterate
        var currentDate = calendar.startOfDay(for: startDate)
        
        // Weekdays that should have more availability
        let moreDaysAvailable = [2, 3, 4] // Tuesday, Wednesday, Thursday
        
        // Generate slots until we reach end date
        while currentDate < endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            
            // Skip weekends (1 = Sunday, 7 = Saturday)
            if weekday != 1 && weekday != 7 {
                // How many slots to generate for this day (more on certain days)
                let slotCount = moreDaysAvailable.contains(weekday) ? 5 : 3
                
                // Generate specific slots with more realistic timing
                var hoursToUse: [Int] = []
                
                // Morning slots (9-12)
                if Bool.random() {
                    hoursToUse.append(contentsOf: [9, 10, 11])
                }
                
                // Lunch slot (12-1)
                if Bool.random() && Bool.random() { // Less likely
                    hoursToUse.append(12)
                }
                
                // Afternoon slots (1-6)
                if Bool.random() {
                    hoursToUse.append(contentsOf: [13, 14, 15])
                }
                
                if Bool.random() {
                    hoursToUse.append(contentsOf: [16, 17])
                }
                
                // Shuffle and pick a subset
                hoursToUse.shuffle()
                let selectedHours = Array(hoursToUse.prefix(min(slotCount, hoursToUse.count)))
                
                // Create slots at those hours
                for hour in selectedHours.sorted() {
                    let minutes: [Int] = [0, 30] // Start at either :00 or :30
                    if let slotStart = calendar.date(bySettingHour: hour, minute: minutes.randomElement() ?? 0, second: 0, of: currentDate) {
                        // Check if slot is within range and during business hours
                        if slotStart >= startDate && 
                           calendar.component(.hour, from: slotStart) >= businessHoursStart &&
                           calendar.component(.hour, from: slotStart) < businessHoursEnd {
                            availableSlots.append(DateInterval(start: slotStart, duration: duration))
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
        
        // Sort by start time
        return availableSlots.sorted(by: { $0.start < $1.start })
    }
    
    func createCalendarEvent(for hangout: Hangout, userIDs: [String]) async throws -> String {
        do {
            // Get emails for both users to add as attendees
            var attendeeEmails: [String] = []
            
            // Try to get creator's email
            let creatorUser = try? await firestoreService.getUser(id: hangout.creatorID)
            if let creatorUser = creatorUser, creatorUser.email != nil && !creatorUser.email.isEmpty {
                attendeeEmails.append(creatorUser.email)
            }
            
            // Try to get invitee's email
            let inviteeUser = try? await firestoreService.getUser(id: hangout.inviteeID)
            if let inviteeUser = inviteeUser, inviteeUser.email != nil && !inviteeUser.email.isEmpty {
                attendeeEmails.append(inviteeUser.email)
            }
            
            // Get connected providers for creator
            let creatorProviders = await getConnectedCalendarProviders(for: hangout.creatorID)
            var eventIds: [String] = []
            
            // Check each provider and create event
            if creatorProviders.contains("google") {
                // Create event in Google Calendar
                let creatorToken = try await getCalendarToken(for: hangout.creatorID)
                let googleEventId = try await createCalendarEvent(
                    accessToken: creatorToken,
                    title: hangout.title,
                    description: hangout.description,
                    startDate: hangout.startDate,
                    endDate: hangout.endDate,
                    location: hangout.location,
                    attendees: attendeeEmails
                )
                eventIds.append(googleEventId)
            }
            
            if creatorProviders.contains("outlook") {
                // Create event in Outlook Calendar
                let outlookEventId = try await createOutlookEvent(
                    for: hangout.creatorID,
                    title: hangout.title,
                    description: hangout.description,
                    startDate: hangout.startDate,
                    endDate: hangout.endDate,
                    location: hangout.location,
                    attendees: attendeeEmails
                )
                eventIds.append(outlookEventId)
            }
            
            // Get connected providers for invitee
            let inviteeProviders = await getConnectedCalendarProviders(for: hangout.inviteeID)
            
            // Create events in invitee's calendars
            if inviteeProviders.contains("google") {
                // Create event in Google Calendar
                let inviteeToken = try? await getCalendarToken(for: hangout.inviteeID)
                if let token = inviteeToken {
                    _ = try? await createCalendarEvent(
                        accessToken: token,
                        title: hangout.title,
                        description: hangout.description,
                        startDate: hangout.startDate,
                        endDate: hangout.endDate,
                        location: hangout.location,
                        attendees: attendeeEmails
                    )
                }
            }
            
            if inviteeProviders.contains("outlook") {
                // Create event in Outlook Calendar
                _ = try? await createOutlookEvent(
                    for: hangout.inviteeID,
                    title: hangout.title,
                    description: hangout.description,
                    startDate: hangout.startDate,
                    endDate: hangout.endDate,
                    location: hangout.location,
                    attendees: attendeeEmails
                )
            }
            
            // Return first event ID (from creator's calendar)
            return eventIds.first ?? UUID().uuidString
        } catch {
            print("Error creating calendar events: \(error.localizedDescription)")
            // Return a mock ID for development
            return UUID().uuidString
        }
    }
    
    private func getAuthenticatedURLRequest(for endpoint: String, accessToken: String) -> URLRequest {
        let url = URL(string: baseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    // Method to save calendar token for a user
    func saveCalendarToken(for userId: String, accessToken: String, refreshToken: String? = nil, expirationDate: Date? = nil) async throws {
        let docRef = db.collection("users").document(userId).collection("tokens").document("calendar")
        
        var tokenData: [String: Any] = ["accessToken": accessToken]
        
        if let refreshToken = refreshToken {
            tokenData["refreshToken"] = refreshToken
        }
        
        if let expirationDate = expirationDate {
            tokenData["expirationDate"] = Timestamp(date: expirationDate)
        }
        
        try await docRef.setData(tokenData, merge: true)
        print("Saved calendar token for user \(userId)")
    }
    
    // Method to check if a user has connected their Google Calendar
    func hasCalendarAccess(for userId: String) async -> Bool {
        do {
            let document = try await db.collection("users").document(userId).collection("tokens").document("calendar").getDocument()
            return document.exists
        } catch {
            print("Error checking calendar access: \(error.localizedDescription)")
            return false
        }
    }
    
    // Authenticate and save calendar token
    func authenticateAndSaveCalendarAccess(for userId: String) async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "com.unhinged.calendar", code: 500, 
                  userInfo: [NSLocalizedDescriptionKey: "Could not get Firebase client ID"])
        }
        
        // Get the top view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "com.unhinged.calendar", code: 500, 
                  userInfo: [NSLocalizedDescriptionKey: "Could not get root view controller"])
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
        } else {
            data["refreshToken"] = ""
        }
        
        // Add email if available
        if let email = result.user.profile?.email {
            data["email"] = email
        }
        
        try await db.collection("users").document(userId).collection("tokens").document("calendar").setData(data)
    }
    
    // Helper to save token from GIDGoogleUser
    private func saveTokenFromUser(_ user: GIDGoogleUser, userId: String) async throws {
        // Google Sign-In v6+ has non-optional tokens but different access pattern
        let accessToken = user.accessToken.tokenString
        
        // Handle refresh token - check if we have a non-empty refresh token
        var refreshTokenString: String? = nil
        // Check if user has a refresh token
        if user.refreshToken != nil {
            let refreshToken = user.refreshToken
            if !refreshToken.tokenString.isEmpty {
                refreshTokenString = refreshToken.tokenString
            }
        }
        
        try await saveCalendarToken(
            for: userId,
            accessToken: accessToken,
            refreshToken: refreshTokenString,
            expirationDate: user.accessToken.expirationDate
        )
    }
    
    // Get available time slots based on calendar (stub implementation)
    func getAvailableTimeSlots(for userId: String, duration: Int, startDate: Date, endDate: Date) async -> [TimeSlot] {
        // This would normally query the Google Calendar API for free/busy information
        // For now, we'll return dummy data
        
        var timeSlots: [TimeSlot] = []
        let calendar = Calendar.current
        
        // Generate time slots for the next week
        for day in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: day, to: startDate) else { continue }
            
            // Generate 3 random slots per day
            for _ in 0..<3 {
                // Random hour between 9 AM and 5 PM
                let hour = Int.random(in: 9...17)
                
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = hour
                components.minute = 0
                
                guard let slotStart = calendar.date(from: components),
                      let slotEnd = calendar.date(byAdding: .minute, value: duration, to: slotStart) else {
                    continue
                }
                
                let timeSlot = TimeSlot(startTime: slotStart, endTime: slotEnd)
                timeSlots.append(timeSlot)
            }
        }
        
        return timeSlots
    }
    
    // Method to create a calendar event for the voice assistant
    func createCalendarEvent(
        title: String,
        description: String,
        startDate: Date,
        endDate: Date,
        location: String?,
        attendees: [String]? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        print("DEBUG: CalendarService - Creating calendar event: \(title)")
        
        guard let currentUser = Auth.auth().currentUser else {
            print("DEBUG: CalendarService - No authenticated user")
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "com.cheemhang.calendar", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            }
            return
        }
        
        let userId = currentUser.uid
        print("DEBUG: CalendarService - Creating event for user: \(userId)")
        
        Task {
            do {
                // Get the user's calendar token
                print("DEBUG: CalendarService - Getting calendar token")
                let accessToken = try await getCalendarToken(for: userId)
                
                // Create the event using the token
                print("DEBUG: CalendarService - Creating event with Google Calendar API")
                let eventId = try await createCalendarEvent(
                    accessToken: accessToken,
                    title: title,
                    description: description,
                    startDate: startDate,
                    endDate: endDate,
                    location: location,
                    attendees: attendees
                )
                
                print("DEBUG: CalendarService - Event created successfully: \(eventId)")
                // Return the event ID on success
                DispatchQueue.main.async {
                    completion(.success(eventId))
                }
            } catch {
                print("DEBUG: CalendarService - Failed to create event: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Check if a user has connected a specific calendar provider
    /// - Parameters:
    ///   - userId: The user ID
    ///   - providerType: The calendar provider type
    /// - Returns: Whether the user has connected this calendar provider
    func hasCalendarAccess(for userId: String, providerType: CalendarProviderType) async -> Bool {
        do {
            // Attempt to get token from Firestore for the specific provider
            let docRef = db.collection("users").document(userId)
                .collection("tokens").document(providerType.rawValue.lowercased())
            
            let document = try await docRef.getDocument()
            return document.exists
        } catch {
            print("Error checking calendar access for \(providerType.rawValue): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Authenticate and save calendar access for a specific provider
    /// - Parameters:
    ///   - userId: The user ID
    ///   - providerType: The calendar provider type
    func authenticateAndSaveCalendarAccess(for userId: String, providerType: CalendarProviderType) async throws {
        // Get the appropriate provider from the factory
        let provider = CalendarServiceFactory.shared.getProvider(for: providerType)
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "com.cheemhang.calendar", code: 500, 
                  userInfo: [NSLocalizedDescriptionKey: "Could not get Firebase client ID"])
        }
        
        // Get the top view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "com.cheemhang.calendar", code: 500, 
                  userInfo: [NSLocalizedDescriptionKey: "Could not get root view controller"])
        }
        
        switch providerType {
        case .google:
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
            } else {
                data["refreshToken"] = ""
            }
            
            // Add email if available
            if let email = result.user.profile?.email {
                data["email"] = email
            }
            
            try await db.collection("users").document(userId)
                .collection("tokens").document("google").setData(data)
            
        case .outlook:
            // Get authorization URL from Outlook provider
            guard let authURL = provider.getAuthorizationURL() else {
                throw NSError(domain: "com.cheemhang.calendar", code: 500, 
                      userInfo: [NSLocalizedDescriptionKey: "Could not create authorization URL"])
            }
            
            // Open the URL in a web view
            // This would typically be handled by a web authentication session
            // For now, throw an error indicating this is not fully implemented
            throw NSError(domain: "com.cheemhang.calendar", code: 501, 
                  userInfo: [NSLocalizedDescriptionKey: "Outlook calendar integration requires web authentication, which is not yet implemented"])
            
        case .apple:
            // For Apple Calendar, we just request permission through EventKit
            // The actual connection is handled in the AppleCalendarProvider 
            // and CalendarAuthViewModel
            throw NSError(domain: "com.cheemhang.calendar", code: 501, 
                  userInfo: [NSLocalizedDescriptionKey: "Apple Calendar integration should be handled through the AppleCalendarProvider directly"])
        }
    }
    
    /// Disconnect a calendar provider for a user
    /// - Parameters:
    ///   - userId: The user ID
    ///   - providerType: The calendar provider type to disconnect
    func disconnectCalendar(for userId: String, providerType: CalendarProviderType) async throws {
        // Remove token from Firestore
        try await db.collection("users").document(userId)
            .collection("tokens").document(providerType.rawValue.lowercased()).delete()
        
        // If it's Google, also sign out from Google
        if providerType == .google {
            GIDSignIn.sharedInstance.signOut()
        }
        
        // Remove from calendar settings
        try await db.collection("users").document(userId)
            .collection("settings").document("calendar").updateData([
                "providers": FieldValue.arrayRemove([providerType.rawValue])
            ])
    }
    
    /// Save calendar settings for a user
    /// - Parameter settings: The calendar provider settings
    func saveCalendarSettings(_ settings: CalendarProviderSettings) async throws {
        let userId = settings.userID
        
        // Convert to dictionary
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "com.cheemhang.calendar", code: 500,
                  userInfo: [NSLocalizedDescriptionKey: "Failed to serialize settings"])
        }
        
        // Save to Firestore
        try await db.collection("users").document(userId)
            .collection("settings").document("calendar").setData(dict, merge: true)
        
        // Also add to providers array
        try await db.collection("users").document(userId)
            .collection("settings").document("calendar").updateData([
                "providers": FieldValue.arrayUnion([settings.providerType.rawValue])
            ])
    }
    
    /// Get calendar settings for a user
    /// - Parameter userId: The user ID
    /// - Returns: The calendar settings
    func getCalendarSettings(for userId: String) async throws -> [CalendarProviderSettings] {
        let docRef = db.collection("users").document(userId)
            .collection("settings").document("calendar")
        
        let doc = try await docRef.getDocument()
        
        if !doc.exists {
            return []
        }
        
        guard let data = doc.data(),
              let providersArray = data["providers"] as? [String] else {
            return []
        }
        
        var settings: [CalendarProviderSettings] = []
        
        for providerString in providersArray {
            // Use guard let instead of if let for better clarity
            guard let providerType = CalendarProviderType(rawValue: providerString) else {
                continue
            }
            
            // Fetch specific provider settings
            let providerDoc = try await db.collection("users").document(userId)
                .collection("tokens").document(providerString.lowercased()).getDocument()
            
            if providerDoc.exists, let providerData = providerDoc.data() {
                var providerSettings = CalendarProviderSettings(
                    providerType: providerType,
                    userID: userId,
                    useForAvailability: true,
                    useForEvents: true
                )
                
                // Set tokens if available
                providerSettings.accessToken = providerData["accessToken"] as? String
                providerSettings.refreshToken = providerData["refreshToken"] as? String
                
                // Set expiration date if available
                if let expirationTimestamp = providerData["expirationDate"] as? Timestamp {
                    providerSettings.tokenExpirationDate = expirationTimestamp.dateValue()
                }
                
                settings.append(providerSettings)
            }
        }
        
        return settings
    }
    
    /// Check availability across all connected calendars for a user
    /// - Parameters:
    ///   - userId: The user ID
    ///   - startDate: The start date to check
    ///   - endDate: The end date to check
    /// - Returns: Whether the user is available
    func checkAvailabilityAcrossAllCalendars(userId: String, startDate: Date, endDate: Date) async -> Bool {
        do {
            // Get all connected calendar providers
            let settings = try await getCalendarSettings(for: userId)
            
            // If no calendars are connected, assume available
            if settings.isEmpty {
                return true
            }
            
            // Check each calendar
            for providerSettings in settings {
                // Skip if not used for availability checking
                if !providerSettings.useForAvailability {
                    continue
                }
                
                let provider = CalendarServiceFactory.shared.getProviderFromSettings(providerSettings)
                
                do {
                    // Get busy times from this provider
                    let busyTimes = try await provider.getAvailability(
                        userID: userId,
                        startDate: startDate,
                        endDate: endDate
                    )
                    
                    // Check if our proposed time overlaps with any busy time
                    let hasConflict = busyTimes.contains { busyTime in
                        // Check for overlap
                        (startDate < busyTime.endTime && endDate > busyTime.startTime)
                    }
                    
                    // If there's a conflict in any calendar, the user is not available
                    if hasConflict {
                        return false
                    }
                } catch {
                    // If we can't check one calendar, log the error but continue with others
                    print("Error checking \(providerSettings.providerType.rawValue) calendar: \(error.localizedDescription)")
                }
            }
            
            // If we get here, there were no conflicts in any calendars
            return true
        } catch {
            print("Error checking availability across calendars: \(error.localizedDescription)")
            // If we can't check availability, assume available
            return true
        }
    }
    
    /// Create a calendar event across all connected calendars for a user
    /// - Parameters:
    ///   - userId: The user ID
    ///   - event: The event to create
    /// - Returns: Dictionary mapping provider types to event IDs
    func createEventAcrossAllCalendars(userId: String, event: CalendarEventModel) async throws -> [CalendarProviderType: String] {
        var eventIds: [CalendarProviderType: String] = [:]
        
        // Get all connected calendar providers
        let settings = try await getCalendarSettings(for: userId)
        
        // If no calendars are connected, throw an error
        if settings.isEmpty {
            throw CalendarServiceError.noCalendarConfigured
        }
        
        // For each calendar that's used for events
        for providerSettings in settings {
            // Skip if not used for event creation
            if !providerSettings.useForEvents {
                continue
            }
            
            let provider = CalendarServiceFactory.shared.getProviderFromSettings(providerSettings)
            
            do {
                // Create the event using this provider
                let eventId = try await provider.createEvent(event: event, userID: userId)
                eventIds[providerSettings.providerType] = eventId
            } catch {
                print("Error creating event in \(providerSettings.providerType.rawValue) calendar: \(error.localizedDescription)")
            }
        }
        
        return eventIds
    }
    
    /// Get calendar events for a specific provider and date range
    /// - Parameters:
    ///   - provider: The calendar provider
    ///   - startDate: The start date
    ///   - endDate: The end date
    /// - Returns: List of calendar events
    func getEvents(for provider: CalendarProvider, from startDate: Date, to endDate: Date, completion: @escaping (Result<[CalendarEventModel], Error>) -> Void) {
        // Simulate fetching events from the calendar provider
        let events = simulateEvents(for: provider, from: startDate, to: endDate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(events))
        }
    }
    
    /// Simulate calendar events for testing purposes
    /// - Parameters:
    ///   - provider: The calendar provider
    ///   - startDate: The start date
    ///   - endDate: The end date
    /// - Returns: List of simulated calendar events
    private func simulateEvents(for provider: CalendarProvider, from startDate: Date, to endDate: Date) -> [CalendarEventModel] {
        var events: [CalendarEventModel] = []
        let calendar = Calendar.current
        var currentDate = startDate
        
        // Generate some simulated events for each day
        while currentDate < endDate {
            // Only create events on weekdays
            let weekday = calendar.component(.weekday, from: currentDate)
            if (2...6).contains(weekday) { // Monday through Friday
                let workStartTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: currentDate)!
                let workEndTime = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: currentDate)!
                
                // Morning standup
                let standupStart = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: currentDate)!
                let standupEnd = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: currentDate)!
                
                // Create mock events
                var events = [CalendarEventModel(
                    id: UUID().uuidString,
                    title: "Daily Standup",
                    description: "Team check-in",
                    startDate: standupStart,
                    endDate: standupEnd,
                    isAllDay: false,
                    location: "Conference Room A",
                    provider: provider
                )]
                
                // Lunch break
                let lunchStart = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: currentDate)!
                let lunchEnd = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: currentDate)!
                
                events.append(CalendarEventModel(
                    id: UUID().uuidString,
                    title: "Lunch Break",
                    description: nil,
                    startDate: lunchStart,
                    endDate: lunchEnd,
                    provider: provider
                ))
                
                // Afternoon meeting
                if weekday == 3 || weekday == 5 { // Tuesday or Thursday
                    let meetingStart = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: currentDate)!
                    let meetingEnd = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: currentDate)!
                    
                    events.append(CalendarEventModel(
                        id: UUID().uuidString,
                        title: "Project Review",
                        description: "Weekly project status review",
                        startDate: meetingStart,
                        endDate: meetingEnd,
                        location: "Meeting Room B",
                        provider: provider
                    ))
                }
            }
            
            // Move to next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return events
    }
    
    func createEvent(event: CalendarEventModel, userID: String) async throws -> String {
        do {
            // Get access token for the user
            let accessToken = try await getCalendarToken(for: userID)
            
            return try await createCalendarEvent(
                accessToken: accessToken,
                title: event.title,
                description: event.description ?? "",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                attendees: [] // We don't have attendees in the model anymore
            )
        } catch {
            print("Error creating calendar event: \(error.localizedDescription)")
            throw error
        }
    }
    
    func processCalendarEventInvite(eventID: String, response: InviteResponse) async throws {
        // Check if we have a calendar event with this ID
        if eventID.isEmpty {
            // Exit early if no event ID provided
            return
        }
        
        // Process calendar event invite response
        switch response {
        case .accept:
            // Accept the calendar event
            try await acceptCalendarEventInvite(eventID: eventID)
        case .decline:
            // Decline the calendar event
            try await declineCalendarEventInvite(eventID: eventID)
        case .tentative:
            // Mark as tentative
            try await markCalendarEventTentative(eventID: eventID)
        }
    }
    
    /// Accept a calendar event invite
    /// - Parameter eventID: The ID of the event to accept
    private func acceptCalendarEventInvite(eventID: String) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw CalendarServiceError.invalidToken
        }
        
        // Get user's access token
        let accessToken = try await getCalendarToken(for: currentUserID)
        
        // Set up the request to update the event
        let url = URL(string: "\(baseURL)/calendars/primary/events/\(eventID)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Set the response status to "accepted"
        let body: [String: Any] = [
            "attendees": [
                [
                    "self": true,
                    "responseStatus": "accepted"
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Make the request
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CalendarServiceError.apiError("Failed to accept event invite")
        }
    }
    
    /// Decline a calendar event invite
    /// - Parameter eventID: The ID of the event to decline
    private func declineCalendarEventInvite(eventID: String) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw CalendarServiceError.invalidToken
        }
        
        // Get user's access token
        let accessToken = try await getCalendarToken(for: currentUserID)
        
        // Set up the request to update the event
        let url = URL(string: "\(baseURL)/calendars/primary/events/\(eventID)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Set the response status to "declined"
        let body: [String: Any] = [
            "attendees": [
                [
                    "self": true,
                    "responseStatus": "declined"
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Make the request
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CalendarServiceError.apiError("Failed to decline event invite")
        }
    }
    
    /// Mark a calendar event as tentative
    /// - Parameter eventID: The ID of the event to mark as tentative
    private func markCalendarEventTentative(eventID: String) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw CalendarServiceError.invalidToken
        }
        
        // Get user's access token
        let accessToken = try await getCalendarToken(for: currentUserID)
        
        // Set up the request to update the event
        let url = URL(string: "\(baseURL)/calendars/primary/events/\(eventID)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Set the response status to "tentative"
        let body: [String: Any] = [
            "attendees": [
                [
                    "self": true,
                    "responseStatus": "tentative"
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Make the request
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CalendarServiceError.apiError("Failed to mark event as tentative")
        }
    }

    // MARK: - Microsoft Outlook Integration Methods

    /// Authenticate with Microsoft Outlook and save tokens
    func authenticateAndSaveOutlookAccess(for userId: String) async throws {
        // Get the Microsoft Graph Service
        let msGraphService = MicrosoftGraphService.shared
        
        do {
            // Authenticate with Microsoft
            let (accessToken, refreshToken) = try await msGraphService.authenticate()
            
            // Save tokens to Firestore
            var data: [String: Any] = [
                "accessToken": accessToken,
                "updatedAt": Timestamp(date: Date()),
                "providerType": "outlook" // Add provider type for identification
            ]
            
            // Add refresh token if available
            if let refreshToken = refreshToken {
                data["refreshToken"] = refreshToken
            }
            
            // Calculate expiration (Outlook tokens typically expire in 1 hour)
            let expirationDate = Date().addingTimeInterval(3600)
            data["expirationDate"] = Timestamp(date: expirationDate)
            
            // Save to Firestore
            try await db.collection("users").document(userId).collection("tokens").document("outlook").setData(data)
            print("Saved Outlook calendar token for user \(userId)")
            
            // Also save to calendarProviders for consistency with our UI
            let providerData: [String: Any] = [
                "providerType": "outlook",
                "userID": userId,
                "useForAvailability": true,
                "useForEvents": true,
                "connectedAt": Date()
            ]
            
            try await db.collection("users")
                .document(userId)
                .collection("calendarProviders")
                .document("outlook")
                .setData(providerData)
            
            return
        } catch {
            print("Error authenticating with Outlook: \(error.localizedDescription)")
            throw error
        }
    }

    /// Get Outlook calendar token for a user
    func getOutlookToken(for userId: String) async throws -> String {
        do {
            // Attempt to get token from Firestore
            let docRef = db.collection("users").document(userId).collection("tokens").document("outlook")
            
            let document = try await docRef.getDocument()
            
            guard let data = document.data(),
                  let accessToken = data["accessToken"] as? String else {
                
                // If no token exists but the user is the current user, try to authenticate
                if userId == Auth.auth().currentUser?.uid {
                    print("No Outlook token found for current user, attempting authentication")
                    try await authenticateAndSaveOutlookAccess(for: userId)
                    return try await getOutlookToken(for: userId) // Recursive call after auth
                }
                
                throw CalendarServiceError.invalidToken
            }
            
            // Check if token is expired
            if let expirationTimestamp = data["expirationDate"] as? Timestamp {
                let expirationDate = expirationTimestamp.dateValue()
                
                // If token is expired or will expire in the next 5 minutes
                if expirationDate.timeIntervalSinceNow < 300 {
                    // Only refresh for current user
                    if userId == Auth.auth().currentUser?.uid, let refreshToken = data["refreshToken"] as? String {
                        print("Outlook token expired, refreshing...")
                        
                        do {
                            // Refresh the token
                            let msGraphService = MicrosoftGraphService.shared
                            let (newAccessToken, expirationDate) = try await msGraphService.refreshAccessToken(refreshToken: refreshToken)
                            
                            // Save the updated token
                            try await saveOutlookToken(
                                for: userId,
                                accessToken: newAccessToken,
                                refreshToken: refreshToken,
                                expirationDate: expirationDate
                            )
                            
                            print("Outlook token refreshed successfully")
                            return newAccessToken
                        } catch {
                            print("Failed to refresh Outlook token: \(error.localizedDescription)")
                            // Fall back to full re-authentication
                            try await authenticateAndSaveOutlookAccess(for: userId)
                            return try await getOutlookToken(for: userId)
                        }
                    } else {
                        // Need full re-auth
                        try await authenticateAndSaveOutlookAccess(for: userId)
                        return try await getOutlookToken(for: userId)
                    }
                }
            }
            
            print("Retrieved valid Outlook token for user \(userId)")
            return accessToken
        } catch {
            print("Error getting Outlook token: \(error.localizedDescription)")
            throw error
        }
    }

    /// Save Outlook calendar token for a user
    func saveOutlookToken(for userId: String, accessToken: String, refreshToken: String? = nil, expirationDate: Date? = nil) async throws {
        let docRef = db.collection("users").document(userId).collection("tokens").document("outlook")
        
        var tokenData: [String: Any] = ["accessToken": accessToken]
        
        if let refreshToken = refreshToken {
            tokenData["refreshToken"] = refreshToken
        }
        
        if let expirationDate = expirationDate {
            tokenData["expirationDate"] = Timestamp(date: expirationDate)
        }
        
        try await docRef.setData(tokenData, merge: true)
        print("Saved Outlook token for user \(userId)")
    }

    /// Check if a user has connected their Outlook Calendar
    func hasOutlookAccess(for userId: String) async -> Bool {
        do {
            let document = try await db.collection("users").document(userId).collection("tokens").document("outlook").getDocument()
            return document.exists
        } catch {
            print("Error checking Outlook access: \(error.localizedDescription)")
            return false
        }
    }

    /// Get busy times from Outlook calendar for a user
    func getOutlookBusyTimes(for userId: String, startDate: Date, endDate: Date) async throws -> [(start: Date, end: Date)] {
        do {
            // Get the user's Outlook token
            let accessToken = try await getOutlookToken(for: userId)
            
            // Use Microsoft Graph service to get busy times
            let msGraphService = MicrosoftGraphService.shared
            return try await msGraphService.getBusyTimes(accessToken: accessToken, startDate: startDate, endDate: endDate)
        } catch {
            print("Error getting Outlook busy times: \(error.localizedDescription)")
            throw error
        }
    }

    /// Create event in Outlook calendar
    func createOutlookEvent(
        for userId: String,
        title: String,
        description: String,
        startDate: Date,
        endDate: Date,
        location: String?,
        attendees: [String]? = nil
    ) async throws -> String {
        do {
            // Get the user's Outlook token
            let accessToken = try await getOutlookToken(for: userId)
            
            // Use Microsoft Graph service to create event
            let msGraphService = MicrosoftGraphService.shared
            return try await msGraphService.createCalendarEvent(
                accessToken: accessToken,
                title: title,
                description: description,
                startDate: startDate,
                endDate: endDate,
                location: location,
                attendees: attendees
            )
        } catch {
            print("Error creating Outlook event: \(error.localizedDescription)")
            throw error
        }
    }

    /// Delete event from Outlook calendar
    func deleteOutlookEvent(for userId: String, eventId: String) async throws {
        do {
            // Get the user's Outlook token
            let accessToken = try await getOutlookToken(for: userId)
            
            // Use Microsoft Graph service to delete event
            let msGraphService = MicrosoftGraphService.shared
            try await msGraphService.deleteCalendarEvent(accessToken: accessToken, eventId: eventId)
        } catch {
            print("Error deleting Outlook event: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Provider-Agnostic Methods

    /// Get calendar token for a specific provider
    func getCalendarTokenForProvider(userId: String, providerType: String) async throws -> String {
        switch providerType.lowercased() {
        case "google":
            return try await getCalendarToken(for: userId)
        case "outlook":
            return try await getOutlookToken(for: userId)
        default:
            throw CalendarServiceError.invalidResponse
        }
    }

    /// Check what calendar providers the user has connected
    func getConnectedCalendarProviders(for userId: String) async -> [String] {
        var providers: [String] = []
        
        // Check Google Calendar
        if await hasCalendarAccess(for: userId) {
            providers.append("google")
        }
        
        // Check Outlook Calendar
        if await hasOutlookAccess(for: userId) {
            providers.append("outlook")
        }
        
        return providers
    }

    /// Get busy times from all connected calendars
    func getAllBusyTimes(for userId: String, startDate: Date, endDate: Date) async -> [(start: Date, end: Date)] {
        var allBusyTimes: [(start: Date, end: Date)] = []
        
        // Try to get Google Calendar busy times
        if await hasCalendarAccess(for: userId) {
            do {
                let googleBusyTimes = try await getBusyTimes(accessToken: try await getCalendarToken(for: userId), 
                                                          startDate: startDate, 
                                                          endDate: endDate)
                allBusyTimes.append(contentsOf: googleBusyTimes)
            } catch {
                print("Error getting Google busy times: \(error.localizedDescription)")
            }
        }
        
        // Try to get Outlook busy times
        if await hasOutlookAccess(for: userId) {
            do {
                let outlookBusyTimes = try await getOutlookBusyTimes(for: userId, 
                                                                  startDate: startDate, 
                                                                  endDate: endDate)
                allBusyTimes.append(contentsOf: outlookBusyTimes)
            } catch {
                print("Error getting Outlook busy times: \(error.localizedDescription)")
            }
        }
        
        // If we couldn't get any real events, use simulated data in debug mode
        #if DEBUG
        if allBusyTimes.isEmpty {
            allBusyTimes = generateSimulatedBusyTimes(startDate: startDate, endDate: endDate)
        }
        #endif
        
        return allBusyTimes
    }
} 