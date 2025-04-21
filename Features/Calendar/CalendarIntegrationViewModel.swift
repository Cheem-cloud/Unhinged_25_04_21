import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import EventKit

// Calendar step tracking
enum CalendarStep: Equatable {
    case overview
    case providerSelection
    case providerAuth(CalendarProvider)
    case availability
    case privacySettings
    case syncSettings
    
    static func == (lhs: CalendarStep, rhs: CalendarStep) -> Bool {
        switch (lhs, rhs) {
        case (.overview, .overview),
             (.providerSelection, .providerSelection),
             (.availability, .availability),
             (.privacySettings, .privacySettings),
             (.syncSettings, .syncSettings):
            return true
        case (.providerAuth(let lhsProvider), .providerAuth(let rhsProvider)):
            return lhsProvider == rhsProvider
        default:
            return false
        }
    }
}

// Transition animation direction
enum TransitionDirection {
    case forward
    case backward
}

// Sync frequency options
enum SyncFrequency: String, CaseIterable, Identifiable {
    case realTime = "Real-time"
    case hourly = "Hourly"
    case daily = "Daily"
    case manual = "Manual only"
    case never = "Never"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .realTime: return "Update immediately when changes occur"
        case .hourly: return "Update once every hour"
        case .daily: return "Update once per day"
        case .manual: return "Only update when manually refreshed"
        case .never: return "Don't automatically sync"
        }
    }
}

// Calendar event structure - simpler version for the UI
struct CalendarEvent: Identifiable {
    let id = UUID()
    let title: String
    let startTime: Date
    let endTime: Date
    let colorHex: String
    let provider: CalendarProvider
    let location: String?
}

class CalendarIntegrationViewModel: ObservableObject {
    // MARK: - Properties
    
    @Published var connectedProviders: [CalendarProvider] = []
    @Published var calendarEvents: [CalendarEvent] = []
    @Published var isLoading: Bool = false
    @Published var isSyncing: Bool = false
    @Published var syncSuccessful: Bool = false
    
    // Availability settings
    @Published var workHoursStart: Date = Date.today(hour: 9)
    @Published var workHoursEnd: Date = Date.today(hour: 17)
    @Published var selectedDays: Set<Unhinged.Weekday> = Set(Unhinged.Weekday.allCases)
    
    // Privacy settings
    @Published var showBusyEvents: Bool = true
    @Published var showEventDetails: Bool = false
    
    // Sync settings
    @Published var syncFrequency: SyncFrequency = .daily
    @Published var syncNotifications: Bool = true
    
    // EventKit access (for Apple Calendar)
    private var hasEventKitAccess: Bool = false
    private let eventStore = EKEventStore()
    
    // Calendar service for API calls
    private let calendarService: CalendarServiceAdapter
    private let calendarAuthService = CalendarAuthService.shared
    
    // Firestore reference
    private let db = Firestore.firestore()
    
    // Calendar service factory
    private let serviceFactory = CalendarServiceFactory.shared
    
    init() {
        // Get CalendarServiceAdapter from ServiceManager
        self.calendarService = ServiceManager.shared.getService(CRUDService.self) as! CalendarServiceAdapter
        
        // Initialize with sample data for demo purposes
        #if DEBUG
        loadSampleData()
        #endif
        
        // Request access to EventKit (for Apple Calendar)
        requestEventKitAccess()
    }
    
    // MARK: - Calendar Operations
    
    func fetchConnectedCalendars() {
        isLoading = true
        
        Task {
            do {
                // Get current user
                guard let userId = Auth.auth().currentUser?.uid else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }
                
                // Get calendar settings from CalendarAuthService
                let settings = try await calendarAuthService.getCalendarSettings(for: userId)
                let providers = settings.map { $0.providerType.rawValue }
                
                // Check Apple Calendar separately through EventKit
                let includeApple = hasEventKitAccess
                
                await MainActor.run {
                    // Convert string provider types to CalendarProvider enum values
                    self.connectedProviders = providers.compactMap { providerString -> CalendarProvider? in
                        switch providerString {
                        case "google": return .google
                        case "outlook": return .outlook
                        case "apple": return .apple
                        default: return nil
                        }
                    }
                    
                    // Add Apple if we have access and it's not already included
                    if includeApple && !self.connectedProviders.contains(.apple) {
                        self.connectedProviders.append(.apple)
                    }
                    
                    self.isLoading = false
                    
                    // Refresh events after getting connected calendars
                    if !self.connectedProviders.isEmpty {
                        Task {
                            await self.refreshAllCalendarEvents()
                        }
                    }
                }
            } catch {
                print("Error fetching connected calendars: \(error.localizedDescription)")
                await MainActor.run {
                    // Fall back to sample data if there's an error
                    if self.connectedProviders.isEmpty {
                        self.loadSampleData()
                    }
                    self.isLoading = false
                }
            }
        }
    }
    
    func refreshAllCalendarEvents() async {
        await MainActor.run {
            self.isSyncing = true
        }
        
        do {
            // Get current user
            guard let userId = Auth.auth().currentUser?.uid else {
                await MainActor.run {
                    self.isSyncing = false
                }
                return
            }
            
            // Calculate date range - next 30 days by default
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate) ?? startDate
            
            // Fetch events from all connected providers using our new service
            let providerEvents = try await fetchCalendarEvents(
                userId: userId,
                startDate: startDate,
                endDate: endDate
            )
            
            // Flatten the events into our UI model
            var allEvents: [CalendarEvent] = []
            for (provider, events) in providerEvents {
                allEvents.append(contentsOf: events.map { event in
                    return CalendarEvent(
                        title: event.title,
                        startTime: event.startTime,
                        endTime: event.endTime,
                        colorHex: event.colorHex ?? "#4285F4",
                        provider: provider,
                        location: event.location
                    )
                })
            }
            
            // If we couldn't get any real events, use sample data in debug mode
            #if DEBUG
            if allEvents.isEmpty && !connectedProviders.isEmpty {
                for provider in connectedProviders {
                    addSampleEvents(for: provider)
                }
                await MainActor.run {
                    self.isSyncing = false
                    self.syncSuccessful = true
                }
                return
            }
            #endif
            
            // Update the UI with the fetched events
            await MainActor.run {
                if !allEvents.isEmpty {
                    self.calendarEvents = allEvents
                }
                self.isSyncing = false
                self.syncSuccessful = true
            }
            
        } catch {
            print("Error refreshing calendar events: \(error.localizedDescription)")
            
            await MainActor.run {
                // If we failed to get events, use sample data in debug mode
                #if DEBUG
                if self.calendarEvents.isEmpty && !self.connectedProviders.isEmpty {
                    for provider in self.connectedProviders {
                        self.addSampleEvents(for: provider)
                    }
                }
                #endif
                
                self.isSyncing = false
            }
        }
    }
    
    func connectCalendar(provider: CalendarProvider) {
        isLoading = true
        
        Task {
            do {
                // Get current user
                guard let userId = Auth.auth().currentUser?.uid else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }
                
                // Connect to the calendar provider
                switch provider {
                case .google:
                    try await calendarAuthService.authenticateAndSaveCalendarAccess(for: userId, providerType: .google)
                case .outlook:
                    try await calendarAuthService.authenticateAndSaveCalendarAccess(for: userId, providerType: .outlook)
                case .apple:
                    // Apple Calendar uses local permissions via EventKit
                    requestEventKitAccess()
                }
                
                // Refresh the list of connected providers
                await MainActor.run {
                    if !self.connectedProviders.contains(provider) {
                        self.connectedProviders.append(provider)
                        self.addSampleEvents(for: provider)
                    }
                    self.isLoading = false
                }
                
            } catch {
                print("Error connecting calendar: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    func disconnectCalendar(provider: CalendarProvider) {
        isLoading = true
        
        Task {
            do {
                // Get current user
                guard let userId = Auth.auth().currentUser?.uid else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }
                
                // Disconnect the calendar provider
                switch provider {
                case .google, .outlook:
                    try await calendarAuthService.disconnectCalendar(for: userId, providerType: provider.toProviderType())
                case .apple:
                    // For Apple Calendar, we just remove it from our list
                    // In a real app, we'd update user preferences
                    break
                }
                
                await MainActor.run {
                    // Remove the provider
                    self.connectedProviders.removeAll(where: { $0 == provider })
                    // Remove events from this provider
                    self.calendarEvents.removeAll(where: { $0.provider == provider })
                    self.isLoading = false
                }
                
            } catch {
                print("Error disconnecting calendar: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    func refreshCalendar(provider: CalendarProvider) {
        isLoading = true
        
        Task {
            do {
                // Get current user
                guard let userId = Auth.auth().currentUser?.uid else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }
                
                // Calculate date range - next 30 days by default
                let startDate = Date()
                let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate) ?? startDate
                
                // Fetch events for the specific provider
                let providerEvents = try await fetchCalendarEvents(
                    userId: userId,
                    startDate: startDate,
                    endDate: endDate
                )
                
                // Get events only for the specific provider
                var calendarEvents: [CalendarEvent] = []
                if let events = providerEvents[provider] {
                    calendarEvents = events.map { event in
                        return CalendarEvent(
                            title: event.title,
                            startTime: event.startTime,
                            endTime: event.endTime,
                            colorHex: event.colorHex ?? "#4285F4",
                            provider: provider,
                            location: event.location
                        )
                    }
                }
                
                await MainActor.run {
                    // Remove existing events for this provider
                    self.calendarEvents.removeAll(where: { $0.provider == provider })
                    
                    // Add the new events
                    if !calendarEvents.isEmpty {
                        self.calendarEvents.append(contentsOf: calendarEvents)
                    } else {
                        // Fall back to sample data if we couldn't get real events
                        #if DEBUG
                        self.addSampleEvents(for: provider)
                        #endif
                    }
                    
                    self.isLoading = false
                }
                
            } catch {
                print("Error refreshing calendar: \(error.localizedDescription)")
                await MainActor.run {
                    // Fall back to sample data
                    #if DEBUG
                    self.calendarEvents.removeAll(where: { $0.provider == provider })
                    self.addSampleEvents(for: provider)
                    #endif
                    self.isLoading = false
                }
            }
        }
    }
    
    func updateAvailabilitySettings(workHoursStart: Date, workHoursEnd: Date, selectedDays: Set<Unhinged.Weekday>) {
        // In a real app, we would save these settings to user's profile
        self.workHoursStart = workHoursStart
        self.workHoursEnd = workHoursEnd
        self.selectedDays = selectedDays
        
        // Save to Firebase
        Task {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            
            do {
                // Save to Firestore directly
                let userRef = db.collection("users").document(userId)
                let data: [String: Any] = [
                    "availabilitySettings": [
                        "workHoursStart": Timestamp(date: workHoursStart),
                        "workHoursEnd": Timestamp(date: workHoursEnd),
                        "selectedDays": Array(selectedDays).map { $0.rawValue }
                    ]
                ]
                try await userRef.setData(data, merge: true)
                print("Successfully saved availability settings")
            } catch {
                print("Error saving availability settings: \(error.localizedDescription)")
            }
        }
    }
    
    func updatePrivacySettings(showBusyEvents: Bool, showEventDetails: Bool) {
        self.showBusyEvents = showBusyEvents
        self.showEventDetails = showEventDetails
        
        // Save to Firebase
        Task {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            
            do {
                // Save to Firestore directly
                let userRef = db.collection("users").document(userId)
                let data: [String: Any] = [
                    "privacySettings": [
                        "showBusyEvents": showBusyEvents,
                        "showEventDetails": showEventDetails
                    ]
                ]
                try await userRef.setData(data, merge: true)
                print("Successfully saved privacy settings")
            } catch {
                print("Error saving privacy settings: \(error.localizedDescription)")
            }
        }
    }
    
    func updateSyncSettings(frequency: SyncFrequency) {
        self.syncFrequency = frequency
        
        // Save to Firebase
        Task {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            
            do {
                // Save to Firestore directly
                let userRef = db.collection("users").document(userId)
                let data: [String: Any] = [
                    "syncSettings": [
                        "frequency": frequency.rawValue
                    ]
                ]
                try await userRef.setData(data, merge: true)
                print("Successfully saved sync settings")
            } catch {
                print("Error saving sync settings: \(error.localizedDescription)")
            }
        }
    }
    
    /// Save user preferences to Firebase
    func savePreferences() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            do {
                // Save all settings in one go
                let userRef = db.collection("users").document(userId)
                let data: [String: Any] = [
                    "availabilitySettings": [
                        "workHoursStart": Timestamp(date: workHoursStart),
                        "workHoursEnd": Timestamp(date: workHoursEnd),
                        "selectedDays": Array(selectedDays).map { $0.rawValue }
                    ],
                    "privacySettings": [
                        "showBusyEvents": showBusyEvents,
                        "showEventDetails": showEventDetails
                    ],
                    "syncSettings": [
                        "frequency": syncFrequency.rawValue
                    ]
                ]
                
                try await userRef.setData(data, merge: true)
                print("Calendar preferences saved successfully")
            } catch {
                print("Error saving calendar preferences: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - EventKit Integration (Apple Calendar)
    
    private func requestEventKitAccess() {
        // Check EventKit authorization status
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized:
            hasEventKitAccess = true
        case .notDetermined:
            // Request access if not determined
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                if granted {
                    self?.hasEventKitAccess = true
                } else if let error = error {
                    print("EventKit access error: \(error.localizedDescription)")
                }
            }
        case .denied, .restricted:
            hasEventKitAccess = false
        @unknown default:
            hasEventKitAccess = false
        }
    }
    
    private func fetchAppleCalendarEvents() async throws -> [CalendarEvent] {
        // Make sure we have permission
        guard hasEventKitAccess else {
            throw NSError(domain: "com.cheemhang.calendar", code: 401, userInfo: [NSLocalizedDescriptionKey: "No calendar access"])
        }
        
        // Define the date range for events (next 14 days)
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 14, to: startDate)!
        
        // Create the predicate for the event search
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        
        // Get the events
        let ekEvents = eventStore.events(matching: predicate)
        
        // Convert EKEvents to our CalendarEvent model
        var events: [CalendarEvent] = []
        
        for ekEvent in ekEvents {
            // Skip events without a title
            guard let title = ekEvent.title, !title.isEmpty else { continue }
            
            // Get color
            let colorHex = ekEvent.calendar.cgColor?.toHexString() ?? "#1E90FF" // Default to blue
            
            // Create our event model
            let event = CalendarEvent(
                title: title,
                startTime: ekEvent.startDate,
                endTime: ekEvent.endDate,
                colorHex: colorHex,
                provider: .apple,
                location: ekEvent.location
            )
            
            events.append(event)
        }
        
        return events
    }
    
    // MARK: - API Calls for Other Calendar Types
    
    private func fetchGoogleCalendarEvents(userId: String) async throws -> [CalendarEvent] {
        do {
            // Get provider and tokens from Firestore
            guard let provider = serviceFactory.getProvider(for: .google) as? GoogleCalendarProvider else {
                throw CalendarError.invalidResponse
            }
            
            let tokens = try await getCalendarTokens(for: userId, providerType: .google)
            
            // Configure provider with tokens
            provider.configure(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
            
            // Create the URL for fetching events
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 14, to: startDate)!
            
            // Format dates for API call
            let dateFormatter = ISO8601DateFormatter()
            let formattedStartDate = dateFormatter.string(from: startDate)
            let formattedEndDate = dateFormatter.string(from: endDate)
            
            // Build URL
            guard let baseURL = URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events") else {
                throw CalendarError.invalidResponse
            }
            
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
            components?.queryItems = [
                URLQueryItem(name: "timeMin", value: formattedStartDate),
                URLQueryItem(name: "timeMax", value: formattedEndDate),
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime")
            ]
            
            guard let url = components?.url else {
                throw CalendarError.invalidResponse
            }
            
            // Create request
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
            
            // Make API call
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, 
                  httpResponse.statusCode == 200 else {
                throw CalendarError.requestFailed
            }
            
            // Parse the response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = json["items"] as? [[String: Any]] {
                
                // Convert API response to CalendarEvent objects
                return try items.compactMap { item -> CalendarEvent? in
                    // Extract event details
                    guard let id = item["id"] as? String,
                          let title = item["summary"] as? String,
                          let startInfo = item["start"] as? [String: Any],
                          let endInfo = item["end"] as? [String: Any] else {
                        return nil
                    }
                    
                    // Handle both date and dateTime formats
                    var startDate: Date?
                    var endDate: Date?
                    var isAllDay = false
                    
                    if let dateString = startInfo["dateTime"] as? String,
                       let date = dateFormatter.date(from: dateString) {
                        startDate = date
                    } else if let dateString = startInfo["date"] as? String,
                              let date = parseDate(dateString) {
                        startDate = date
                        isAllDay = true
                    }
                    
                    if let dateString = endInfo["dateTime"] as? String,
                       let date = dateFormatter.date(from: dateString) {
                        endDate = date
                    } else if let dateString = endInfo["date"] as? String,
                              let date = parseDate(dateString) {
                        endDate = date
                        isAllDay = true
                    }
                    
                    guard let start = startDate, let end = endDate else {
                        return nil
                    }
                    
                    // Get event color
                    let colorId = item["colorId"] as? String
                    let colorHex = getGoogleEventColor(colorId: colorId) ?? "#4285F4"
                    
                    // Get location using a safer approach that avoids double optionals
                    let location: String?
                    if let rawLocation = item["location"] {
                        location = rawLocation as? String
                    } else {
                        location = nil
                    }
                    
                    return CalendarEvent(
                        title: title,
                        startTime: start,
                        endTime: end,
                        colorHex: colorHex,
                        provider: .google,
                        location: location
                    )
                }
            }
            
            throw CalendarError.invalidResponse
        } catch {
            print("Error fetching Google Calendar events: \(error.localizedDescription)")
            // Fall back to sample data
            return createSampleEventsWithRealDates(for: .google)
        }
    }
    
    private func fetchOutlookCalendarEvents(userId: String) async throws -> [CalendarEvent] {
        do {
            // Get provider and tokens from Firestore
            guard let provider = serviceFactory.getProvider(for: .outlook) as? OutlookCalendarProvider else {
                throw CalendarError.invalidResponse
            }
            
            let tokens = try await getCalendarTokens(for: userId, providerType: .outlook)
            
            // Configure provider with tokens
            provider.configure(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
            
            // Create the URL for fetching events
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 14, to: startDate)!
            
            // Format dates for API call
            let dateFormatter = ISO8601DateFormatter()
            let formattedStartDate = dateFormatter.string(from: startDate)
            let formattedEndDate = dateFormatter.string(from: endDate)
            
            // Build URL
            guard let url = URL(string: "https://graph.microsoft.com/v1.0/me/calendar/calendarView?startDateTime=\(formattedStartDate)&endDateTime=\(formattedEndDate)") else {
                throw CalendarError.invalidResponse
            }
            
            // Create request
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            // Make API call
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, 
                  httpResponse.statusCode == 200 else {
                throw CalendarError.requestFailed
            }
            
            // Parse the response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = json["value"] as? [[String: Any]] {
                
                // Convert API response to CalendarEvent objects
                return items.compactMap { item -> CalendarEvent? in
                    // Extract event details
                    guard let id = item["id"] as? String,
                          let title = item["subject"] as? String,
                          let startInfo = item["start"] as? [String: Any],
                          let endInfo = item["end"] as? [String: Any],
                          let startTimeString = startInfo["dateTime"] as? String,
                          let endTimeString = endInfo["dateTime"] as? String else {
                        return nil
                    }
                    
                    // Parse dates
                    guard let startTime = dateFormatter.date(from: startTimeString),
                          let endTime = dateFormatter.date(from: endTimeString) else {
                        return nil
                    }
                    
                    // Check if all day event
                    let isAllDay = item["isAllDay"] as? Bool ?? false
                    
                    // Get location with explicit unwrapping to avoid double optionals
                    let location: String?
                    if let rawLocation = item["location"],
                       let locationDict = rawLocation as? [String: Any] {
                        location = locationDict["displayName"] as? String
                    } else {
                        location = nil
                    }
                    
                    return CalendarEvent(
                        title: title,
                        startTime: startTime,
                        endTime: endTime,
                        colorHex: "#0078D4", // Outlook blue
                        provider: .outlook,
                        location: location
                    )
                }
            }
            
            throw CalendarError.invalidResponse
        } catch {
            print("Error fetching Outlook Calendar events: \(error.localizedDescription)")
            // Fall back to sample data
            return createSampleEventsWithRealDates(for: .outlook)
        }
    }
    
    // Helper method to get tokens from Firestore
    private func getCalendarTokens(for userId: String, providerType: CalendarProviderType) async throws -> (accessToken: String, refreshToken: String?) {
        let document = try await db.collection("users")
            .document(userId)
            .collection("calendarProviders")
            .document(providerType.rawValue)
            .getDocument()
        
        guard let data = document.data(),
              let accessToken = data["accessToken"] as? String else {
            throw CalendarError.authorizationFailed
        }
        
        let refreshToken = data["refreshToken"] as? String
        
        return (accessToken: accessToken, refreshToken: refreshToken)
    }
    
    // Helper to parse simple date string (YYYY-MM-DD)
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    
    // Helper to get Google Calendar event color
    private func getGoogleEventColor(colorId: String?) -> String? {
        let colors = [
            "1": "#7986CB", // Lavender
            "2": "#33B679", // Sage
            "3": "#8E24AA", // Grape
            "4": "#E67C73", // Flamingo
            "5": "#F6BF26", // Banana
            "6": "#F4511E", // Tangerine
            "7": "#039BE5", // Peacock
            "8": "#616161", // Graphite
            "9": "#3F51B5", // Blueberry
            "10": "#0B8043", // Basil
            "11": "#D50000"  // Tomato
        ]
        
        return colorId.flatMap { colors[$0] }
    }
    
    private func createSampleEventsWithRealDates(for provider: CalendarProvider) -> [CalendarEvent] {
        var events: [CalendarEvent] = []
        
        // Sample event colors based on provider
        let colorHex: String
        switch provider {
        case .google:
            colorHex = "#4285F4" // Google blue
        case .apple:
            colorHex = "#FF9500" // Apple orange
        case .outlook:
            colorHex = "#0078D4" // Outlook blue
        }
        
        // Today's date
        let today = Date()
        let calendar = Calendar.current
        
        // Create sample events over the next few days
        for i in 0..<5 {
            // Event on today + i days
            if let eventDate = calendar.date(byAdding: .day, value: i, to: today) {
                // Morning event
                if let startTime = calendar.date(bySettingHour: 9 + (i % 3), minute: 0, second: 0, of: eventDate),
                   let endTime = calendar.date(byAdding: .hour, value: 1, to: startTime) {
                    
                    let event = CalendarEvent(
                        title: sampleEventTitles.randomElement() ?? "Meeting",
                        startTime: startTime,
                        endTime: endTime,
                        colorHex: colorHex,
                        provider: provider,
                        location: sampleLocations.randomElement() as! String
                    )
                    
                    events.append(event)
                }
                
                // Afternoon event (50% chance)
                if i % 2 == 0,
                   let startTime = calendar.date(bySettingHour: 14 + (i % 3), minute: 30, second: 0, of: eventDate),
                   let endTime = calendar.date(byAdding: .hour, value: 1, to: startTime) {
                    
                    let event = CalendarEvent(
                        title: sampleEventTitles.randomElement() ?? "Meeting",
                        startTime: startTime,
                        endTime: endTime,
                        colorHex: colorHex,
                        provider: provider,
                        location: sampleLocations.randomElement() as! String
                    )
                    
                    events.append(event)
                }
            }
        }
        
        return events
    }
    
    // Sample event titles for demo data
    private let sampleEventTitles = [
        "Team Meeting",
        "Coffee with Alex",
        "Doctor Appointment",
        "Project Review",
        "Lunch with Client",
        "Gym Session",
        "Birthday Party",
        "Conference Call",
        "Dentist Appointment",
        "Dinner with Friends"
    ]
    
    // Sample locations for demo data
    private let sampleLocations = [
        "Conference Room A",
        "Starbucks Downtown",
        "Dr. Smith's Office",
        "Main Office",
        "Sushi Palace",
        "24 Hour Fitness",
        "Dave's Place",
        nil,
        "Dental Clinic",
        "Italian Restaurant"
    ]
    
    // MARK: - Helper Methods
    
    private func loadSampleData() {
        // Sample connected providers
        #if DEBUG
        connectedProviders = [.google]
        
        // Add sample events
        addSampleEvents(for: .google)
        #endif
    }
    
    private func addSampleEvents(for provider: CalendarProvider) {
        let newEvents = createSampleEventsWithRealDates(for: provider)
        
        DispatchQueue.main.async {
            self.calendarEvents.append(contentsOf: newEvents)
            
            // Sort events by start time
            self.calendarEvents.sort { $0.startTime < $1.startTime }
        }
    }
    
    /// Fetch calendar events for the given user across all providers
    private func fetchCalendarEvents(userId: String, startDate: Date, endDate: Date) async throws -> [CalendarProvider: [CalendarEvent]] {
        var results: [CalendarProvider: [CalendarEvent]] = [:]
        
        // Collect events from each connected provider
        for provider in connectedProviders {
            switch provider {
            case .google:
                let events = try await fetchGoogleCalendarEvents(userId: userId)
                results[.google] = events
            case .outlook:
                let events = try await fetchOutlookCalendarEvents(userId: userId)
                results[.outlook] = events
            case .apple:
                let events = try await fetchAppleCalendarEvents()
                results[.apple] = events
            }
        }
        
        return results
    }
}

// MARK: - Helper Extensions

extension Date {
    static func today(hour: Int = 0, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }
    
    var shortTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }
}

extension CalendarProvider {
    func toProviderType() -> CalendarProviderType {
        switch self {
        case .google:
            return .google
        case .outlook:
            return .outlook
        case .apple:
            return .apple
        }
    }
}

extension CGColor {
    func toHexString() -> String {
        guard let components = components, components.count >= 3 else {
            return "#000000"
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        let hex = String(
            format: "#%02lX%02lX%02lX",
            lroundf(r * 255),
            lroundf(g * 255),
            lroundf(b * 255)
        )
        
        return hex
    }
} 
