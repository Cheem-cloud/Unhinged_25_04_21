import Foundation
import Firebase
import FirebaseFirestore
import GoogleSignIn
import UIKit

/// Service responsible for handling calendar authentication operations
class CalendarAuthService {
    // MARK: - Properties
    
    /// Shared instance
    static let shared = CalendarAuthService()
    
    /// Firestore database reference
    private let db = Firestore.firestore()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Authenticate a user with Google Calendar and save their access token
    /// - Parameter userId: The user ID to authenticate
    /// - Throws: An error if authentication fails
    public func authenticateAndSaveCalendarAccess(for userId: String) async throws {
        guard userId == Auth.auth().currentUser?.uid else {
            throw CalendarServiceError.apiError("Can only authenticate calendar for the current user")
        }
        
        // Configure Google sign-in
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: FirebaseApp.app()?.options.clientID ?? "",
            serverClientID: nil
        )
        
        // Get the top view controller to present sign-in UI
        guard let topVC = UIApplication.shared.windows.first?.rootViewController else {
            throw CalendarServiceError.apiError("Cannot present sign-in UI")
        }
        
        // Add required scopes for calendar access
        let scopes = [
            "https://www.googleapis.com/auth/calendar",
            "https://www.googleapis.com/auth/calendar.events"
        ]
        
        // Perform sign-in
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: topVC,
            hint: nil,
            additionalScopes: scopes
        )
        
        // Get the user
        let user = result.user
        
        // Save the token to Firestore
        try await saveToken(from: user, for: userId)
        
        // Create default settings if none exist
        let hasSettings = try await hasCalendarSettings(for: userId)
        if !hasSettings {
            try await createDefaultCalendarSettings(for: userId, provider: .google)
        }
        
        print("Authenticated and saved calendar access for user \(userId)")
    }
    
    /// Get a calendar token for a user
    /// - Parameter userId: The user ID to get a token for
    /// - Returns: The access token
    /// - Throws: An error if the token cannot be retrieved
    public func getCalendarToken(for userId: String) async throws -> String {
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
                                
                                // Get fresh token
                                let accessToken = user.accessToken.tokenString
                                
                                // Save the updated token
                                try await saveToken(from: user, for: userId)
                                
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
    
    /// Check if a user has calendar settings
    /// - Parameter userId: The user ID to check
    /// - Returns: Whether the user has calendar settings
    /// - Throws: An error if the check fails
    public func hasCalendarSettings(for userId: String) async throws -> Bool {
        let docRef = db.collection("users").document(userId).collection("calendarSettings").document("providers")
        let document = try await docRef.getDocument()
        return document.exists && document.data() != nil
    }
    
    /// Check if a user has calendar access for a specific provider
    /// - Parameters:
    ///   - userId: The user ID to check
    ///   - providerType: The calendar provider type
    /// - Returns: Whether the user has access to the specified calendar provider
    public func hasCalendarAccess(for userId: String, providerType: CalendarProviderType) async -> Bool {
        do {
            // Get all calendar settings
            let docRef = db.collection("users").document(userId).collection("calendarSettings").document("providers")
            let document = try await docRef.getDocument()
            
            if !document.exists {
                return false
            }
            
            guard let data = document.data() else {
                return false
            }
            
            // Look for the specific provider
            // Handle different data structures - some might be in "providers" array, some directly as fields
            if let providers = data["providers"] as? [[String: Any]] {
                // Array format
                for providerData in providers {
                    if let typeString = providerData["providerType"] as? String,
                       CalendarProviderType(rawValue: typeString) == providerType {
                        return true
                    }
                }
            } else {
                // Direct fields format
                for (key, value) in data {
                    if key != "lastUpdated", 
                       let providerData = value as? [String: Any],
                       let typeString = providerData["providerType"] as? String,
                       CalendarProviderType(rawValue: typeString) == providerType {
                        return true
                    }
                }
            }
            
            return false
        } catch {
            print("Error checking calendar access for provider \(providerType): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Authenticate and save calendar access for a user with a specific provider
    /// - Parameters:
    ///   - userId: The user ID to authenticate
    ///   - providerType: The calendar provider type
    /// - Throws: An error if authentication fails
    public func authenticateAndSaveCalendarAccess(for userId: String, providerType: CalendarProviderType) async throws {
        guard userId == Auth.auth().currentUser?.uid else {
            throw CalendarServiceError.apiError("Can only authenticate calendar for the current user")
        }
        
        // Handle different provider types
        switch providerType {
        case .google:
            // Configure Google sign-in
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(
                clientID: FirebaseApp.app()?.options.clientID ?? "",
                serverClientID: nil
            )
            
            // Get the top view controller to present sign-in UI
            guard let topVC = UIApplication.shared.windows.first?.rootViewController else {
                throw CalendarServiceError.apiError("Cannot present sign-in UI")
            }
            
            // Add required scopes for calendar access
            let scopes = [
                "https://www.googleapis.com/auth/calendar",
                "https://www.googleapis.com/auth/calendar.events"
            ]
            
            // Perform sign-in
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: topVC,
                hint: nil,
                additionalScopes: scopes
            )
            
            // Get the user
            let user = result.user
            
            // Save the token to Firestore
            try await saveToken(from: user, for: userId)
            
            // Create default settings if none exist
            let hasSettings = try await hasCalendarSettings(for: userId)
            if !hasSettings {
                try await createDefaultCalendarSettings(for: userId, provider: .google)
            }
            
        case .outlook:
            // Microsoft Graph authentication would be implemented here
            throw CalendarServiceError.apiError("Microsoft Outlook integration not implemented yet")
            
        case .apple:
            throw CalendarServiceError.apiError("Apple Calendar authentication should be handled through EventKit directly")
            
        default:
            throw CalendarServiceError.apiError("Unsupported calendar provider type")
        }
        
        print("Authenticated and saved calendar access for user \(userId) with provider \(providerType)")
    }
    
    /// Disconnect a calendar provider for a user
    /// - Parameters:
    ///   - userId: The user ID
    ///   - providerType: The calendar provider to disconnect
    /// - Throws: An error if disconnect fails
    public func disconnectCalendar(for userId: String, providerType: CalendarProviderType) async throws {
        // Get settings document
        let docRef = db.collection("users").document(userId).collection("calendarSettings").document("providers")
        
        // Get current settings
        let document = try await docRef.getDocument()
        guard document.exists, var data = document.data() else {
            throw CalendarServiceError.apiError("Calendar settings not found")
        }
        
        // Remove token for this provider
        if providerType != .apple {
            // For providers that use tokens, delete the token document
            let tokenRef = db.collection("users").document(userId).collection("tokens").document(providerType.rawValue.lowercased())
            try await tokenRef.delete()
        }
        
        // Update settings - using transaction to prevent race conditions
        try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let docSnapshot = try transaction.getDocument(docRef)
            guard var docData = docSnapshot.data() else {
                errorPointer?.pointee = NSError(domain: "CalendarAuthService", code: 404, userInfo: nil)
                return nil
            }
            
            // Handle different data structures
            if var providers = docData["providers"] as? [[String: Any]] {
                // Array format
                providers.removeAll { provider in
                    if let typeString = provider["providerType"] as? String {
                        return CalendarProviderType(rawValue: typeString) == providerType
                    }
                    return false
                }
                docData["providers"] = providers
            } else {
                // Direct fields format - remove by provider key if found
                for (key, value) in docData {
                    if let providerData = value as? [String: Any],
                       let typeString = providerData["providerType"] as? String,
                       CalendarProviderType(rawValue: typeString) == providerType {
                        docData.removeValue(forKey: key)
                        break
                    }
                }
            }
            
            // Update lastUpdated timestamp
            docData["lastUpdated"] = Timestamp(date: Date())
            
            transaction.updateData(docData, forDocument: docRef)
            return nil
        }
        
        print("Successfully disconnected \(providerType) calendar for user \(userId)")
    }
    
    /// Save calendar settings for a provider
    /// - Parameter settings: The calendar provider settings to save
    /// - Throws: An error if save fails
    public func saveCalendarSettings(_ settings: CalendarProviderSettings) async throws {
        let userId = settings.userID
        let docRef = db.collection("users").document(userId).collection("calendarSettings").document("providers")
        
        // Try to get existing document
        let document = try await docRef.getDocument()
        
        // Convert settings to dictionary
        var providerData: [String: Any] = [
            "providerType": settings.providerType.rawValue,
            "name": settings.name,
            "useForEvents": settings.useForEvents,
            "useForAvailability": settings.useForAvailability,
            "isDefault": settings.isDefault
        ]
        
        if document.exists {
            // Update existing document
            try await db.runTransaction { (transaction, errorPointer) -> Any? in
                let docSnapshot = try transaction.getDocument(docRef)
                var docData = docSnapshot.data() ?? [:]
                
                // Handle different data structures
                if var providers = docData["providers"] as? [[String: Any]] {
                    // Array format - replace or add provider
                    var found = false
                    for i in 0..<providers.count {
                        if let typeString = providers[i]["providerType"] as? String,
                           CalendarProviderType(rawValue: typeString) == settings.providerType {
                            providers[i] = providerData
                            found = true
                            break
                        }
                    }
                    
                    if !found {
                        providers.append(providerData)
                    }
                    
                    docData["providers"] = providers
                    
                } else {
                    // Direct fields format - use provider type as key
                    docData[settings.providerType.rawValue] = providerData
                }
                
                // Update lastUpdated timestamp
                docData["lastUpdated"] = Timestamp(date: Date())
                
                if docSnapshot.exists {
                    transaction.updateData(docData, forDocument: docRef)
                } else {
                    transaction.setData(docData, forDocument: docRef)
                }
                
                return nil
            }
        } else {
            // Create new document with providers array
            var docData: [String: Any] = [
                "providers": [providerData],
                "lastUpdated": Timestamp(date: Date())
            ]
            
            try await docRef.setData(docData)
        }
        
        print("Saved calendar settings for \(settings.name) (\(settings.providerType)) for user \(userId)")
    }
    
    /// Save a Google Sign-In token to Firestore
    /// - Parameters:
    ///   - user: The GIDGoogleUser with token information
    ///   - userId: The user ID to save the token for
    /// - Throws: An error if the save fails
    private func saveToken(from user: GIDGoogleUser, for userId: String) async throws {
        let accessToken = user.accessToken.tokenString
        let tokenExpirationDate = user.accessToken.expirationDate
        
        let docRef = db.collection("users").document(userId).collection("tokens").document("calendar")
        
        let data: [String: Any] = [
            "accessToken": accessToken,
            "refreshToken": user.refreshToken?.tokenString ?? "",
            "expirationDate": Timestamp(date: tokenExpirationDate),
            "providerType": "google",
            "lastUpdated": Timestamp(date: Date())
        ]
        
        try await docRef.setData(data, merge: true)
        print("Saved Google calendar token for user \(userId)")
    }
    
    /// Create default calendar settings for a user
    /// - Parameters:
    ///   - userId: The user ID to create settings for
    ///   - provider: The calendar provider type
    /// - Throws: An error if the creation fails
    private func createDefaultCalendarSettings(for userId: String, provider: CalendarProviderType) async throws {
        let docRef = db.collection("users").document(userId).collection("calendarSettings").document("providers")
        
        let providerData: [String: Any] = [
            "providerType": provider.rawValue,
            "name": provider == .google ? "Google Calendar" : provider.rawValue,
            "useForEvents": true,
            "useForAvailability": true,
            "isDefault": true
        ]
        
        let data: [String: Any] = [
            "providers": [providerData],
            "lastUpdated": Timestamp(date: Date())
        ]
        
        try await docRef.setData(data, merge: true)
        print("Created default calendar settings for user \(userId)")
    }
} 