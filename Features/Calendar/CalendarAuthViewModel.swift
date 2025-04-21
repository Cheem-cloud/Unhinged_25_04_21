import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices

/// ViewModel for handling calendar authentication
class CalendarAuthViewModel: ObservableObject {
    @Published var isConnecting = false
    @Published var error: Error?
    @Published var authURL: URL?
    
    // Service for calendar operations
    private let calendarService: CalendarOperationsService
    private let calendarAuth: CalendarAuthService
    private let db = Firestore.firestore()
    
    // Add dependency injection for testability
    init(calendarService: CalendarOperationsService? = nil, calendarAuth: CalendarAuthService? = nil) {
        // Use injected service or get from ServiceManager
        self.calendarService = calendarService ?? ServiceManager.shared.getService(CalendarOperationsService.self)
        self.calendarAuth = calendarAuth ?? CalendarAuthService.shared
    }
    
    // MARK: - Calendar Authentication Methods
    
    /// Connect to Google Calendar
    func connectGoogleCalendar() async {
        await MainActor.run {
            isConnecting = true
            error = nil
        }
        
        do {
            // Use the calendar service to authenticate with Google
            guard let userId = Auth.auth().currentUser?.uid else {
                throw NSError(domain: "com.cheemhang.auth", code: 401, userInfo: [
                    NSLocalizedDescriptionKey: "Not logged in"
                ])
            }
            
            try await calendarService.authenticateAndSaveCalendarAccess(for: userId)
            
            await MainActor.run {
                isConnecting = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isConnecting = false
            }
        }
    }
    
    /// Connect to Apple Calendar (through EventKit)
    func connectAppleCalendar() async {
        await MainActor.run {
            isConnecting = true
            error = nil
        }
        
        // Apple Calendar uses local permissions via EventKit
        // This will be handled separately
        
        // Simulate a delay for UI feedback
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            isConnecting = false
        }
    }
    
    /// Connect to Microsoft Outlook Calendar
    func connectOutlookCalendar() async {
        await MainActor.run {
            isConnecting = true
            error = nil
        }
        
        do {
            // Use the calendar auth service to authenticate with Microsoft
            guard let userId = Auth.auth().currentUser?.uid else {
                throw NSError(domain: "com.cheemhang.auth", code: 401, userInfo: [
                    NSLocalizedDescriptionKey: "Not logged in"
                ])
            }
            
            // Use the CalendarAuthService instead of legacy service
            try await calendarAuth.authenticateAndSaveOutlookAccess(for: userId)
            
            await MainActor.run {
                isConnecting = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isConnecting = false
            }
        }
    }
    
    /// Create test calendar event to verify connection
    func createTestEvent() async {
        await MainActor.run {
            isConnecting = true
            error = nil
        }
        
        do {
            // Create a test event tomorrow using the CalendarOperationsService
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let startTime = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: tomorrow) ?? tomorrow
            let endTime = Calendar.current.date(byAdding: .hour, value: 1, to: startTime) ?? startTime
            
            let testEvent = CalendarEventModel(
                title: "Test Event from Unhinged",
                description: "This is a test event created via CalendarOperationsService",
                startDate: startTime,
                endDate: endTime,
                isAllDay: false,
                location: "Test Location",
                provider: .google
            )
            
            // Use CalendarOperationsService to create the event
            let eventId = try await calendarService.create(testEvent)
            print("Test event created with ID: \(eventId)")
            
            await MainActor.run {
                isConnecting = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isConnecting = false
            }
        }
    }
} 