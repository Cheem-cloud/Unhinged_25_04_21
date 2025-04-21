import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Central service for managing calendar integrations
class CalendarIntegrationService {
    /// Shared singleton instance
    static let shared = CalendarIntegrationService()
    
    /// Factory for creating calendar providers
    private let providerFactory = CalendarServiceFactory.shared
    
    /// Firestore reference
    private let db = Firestore.firestore()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// Get the list of connected calendar providers for a user
    /// - Parameter userID: The user ID
    /// - Returns: Array of connected calendar providers
    func getConnectedCalendarProviders(for userID: String) async throws -> [CalendarProvider] {
        let snapshot = try await db.collection("users")
            .document(userID)
            .collection("calendarProviders")
            .getDocuments()
        
        var providers: [CalendarProvider] = []
        
        for document in snapshot.documents {
            if let providerTypeString = document.data()["providerType"] as? String,
               let providerType = CalendarProviderType(rawValue: providerTypeString) {
                
                switch providerType {
                case .google:
                    providers.append(.google)
                case .outlook:
                    providers.append(.outlook)
                case .apple:
                    providers.append(.apple)
                }
            }
        }
        
        return providers
    }
    
    /// Connect a Google Calendar for a user
    /// - Parameter userID: The user ID
    func connectGoogleCalendar(for userID: String) async throws {
        // In real implementation, this would handle the OAuth flow
        // and save tokens to Firestore
        
        // For now, we'll just save a record that the provider is connected
        let data: [String: Any] = [
            "providerType": CalendarProviderType.google.rawValue,
            "userID": userID,
            "useForAvailability": true,
            "useForEvents": true,
            "connectedAt": Date()
        ]
        
        try await db.collection("users")
            .document(userID)
            .collection("calendarProviders")
            .document("google")
            .setData(data)
    }
    
    /// Connect an Outlook Calendar for a user
    /// - Parameter userID: The user ID
    func connectOutlookCalendar(for userID: String) async throws {
        // In real implementation, this would handle the OAuth flow
        // and save tokens to Firestore
        
        // For now, we'll just save a record that the provider is connected
        let data: [String: Any] = [
            "providerType": CalendarProviderType.outlook.rawValue,
            "userID": userID,
            "useForAvailability": true,
            "useForEvents": true,
            "connectedAt": Date()
        ]
        
        try await db.collection("users")
            .document(userID)
            .collection("calendarProviders")
            .document("outlook")
            .setData(data)
    }
    
    /// Disconnect a calendar provider for a user
    /// - Parameters:
    ///   - userID: The user ID
    ///   - providerType: The provider type to disconnect
    func disconnectCalendar(for userID: String, providerType: CalendarProviderType) async throws {
        // Remove the provider from Firestore
        try await db.collection("users")
            .document(userID)
            .collection("calendarProviders")
            .document(providerType.rawValue)
            .delete()
    }
    
    /// Save availability settings for a user
    /// - Parameters:
    ///   - userID: The user ID
    ///   - workHoursStart: Start of work hours
    ///   - workHoursEnd: End of work hours
    ///   - selectedDays: Selected days of the week
    func saveAvailabilitySettings(
        userId: String,
        workHoursStart: Date,
        workHoursEnd: Date,
        selectedDays: [Unhinged.Weekday]
    ) async throws {
        // Convert dates to hour/minute integers for storage
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: workHoursStart)
        let startMinute = calendar.component(.minute, from: workHoursStart)
        let endHour = calendar.component(.hour, from: workHoursEnd)
        let endMinute = calendar.component(.minute, from: workHoursEnd)
        
        // Convert weekdays to strings for storage
        let weekdayStrings = selectedDays.map { $0.rawValue }
        
        let data: [String: Any] = [
            "workHoursStartHour": startHour,
            "workHoursStartMinute": startMinute,
            "workHoursEndHour": endHour,
            "workHoursEndMinute": endMinute,
            "selectedDays": weekdayStrings,
            "updatedAt": Date()
        ]
        
        try await db.collection("users")
            .document(userId)
            .collection("settings")
            .document("availability")
            .setData(data)
    }
    
    /// Save privacy settings for a user
    /// - Parameters:
    ///   - userId: The user ID
    ///   - showBusyEvents: Whether to show busy/free status
    ///   - showEventDetails: Whether to show event details
    func savePrivacySettings(
        userId: String,
        showBusyEvents: Bool,
        showEventDetails: Bool
    ) async throws {
        let data: [String: Any] = [
            "showBusyEvents": showBusyEvents,
            "showEventDetails": showEventDetails,
            "updatedAt": Date()
        ]
        
        try await db.collection("users")
            .document(userId)
            .collection("settings")
            .document("privacy")
            .setData(data)
    }
    
    /// Save sync settings for a user
    /// - Parameters:
    ///   - userId: The user ID
    ///   - frequency: The sync frequency
    func saveSyncSettings(
        userId: String,
        frequency: String
    ) async throws {
        let data: [String: Any] = [
            "syncFrequency": frequency,
            "updatedAt": Date()
        ]
        
        try await db.collection("users")
            .document(userId)
            .collection("settings")
            .document("sync")
            .setData(data)
    }
} 