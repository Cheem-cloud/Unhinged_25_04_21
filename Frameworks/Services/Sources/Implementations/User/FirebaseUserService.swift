import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth

import Core

/// Firebase implementation of the UserService protocol
public class FirebaseUserService: UserService {
    private let db = Firestore.firestore()
    private let authService: AuthService
    
    public init(authService: AuthService) {
        self.authService = authService
    }
    
    /// Get a user by ID
    /// - Parameter id: User ID
    /// - Returns: User if found, nil otherwise
    public func getUser(id: String) async throws -> AppUser? {
        do {
            let document = try await db.collection("users").document(id).getDocument()
            
            if document.exists {
                return try document.data(as: AppUser.self)
            } else {
                return nil
            }
        } catch {
            throw error
        }
    }
    
    /// Create a new user
    /// - Parameter user: User to create
    /// - Returns: User ID
    public func createUser(_ user: AppUser) async throws -> String {
        do {
            let docRef = db.collection("users").document(user.id)
            
            try await docRef.setData([
                "id": user.id,
                "email": user.email,
                "displayName": user.displayName,
                "photoURL": user.photoURL as Any,
                "hasCompletedOnboarding": user.hasCompletedOnboarding,
                "preferences": [
                    "notifications": [
                        "pushEnabled": user.preferences.notifications.pushEnabled,
                        "emailEnabled": user.preferences.notifications.emailEnabled,
                        "enabledTypes": user.preferences.notifications.enabledTypes.map { $0.rawValue }
                    ],
                    "theme": [
                        "darkModeEnabled": user.preferences.theme.darkModeEnabled,
                        "primaryColor": user.preferences.theme.primaryColor
                    ],
                    "privacy": [
                        "locationSharingEnabled": user.preferences.privacy.locationSharingEnabled,
                        "calendarSharingEnabled": user.preferences.privacy.calendarSharingEnabled,
                        "profileVisibleToOthers": user.preferences.privacy.profileVisibleToOthers
                    ]
                ],
                "fcmToken": user.fcmToken as Any,
                "createdAt": user.createdAt,
                "updatedAt": user.updatedAt
            ])
            
            return user.id
        } catch {
            throw error
        }
    }
    
    /// Update a user
    /// - Parameter user: User to update
    public func updateUser(_ user: AppUser) async throws {
        guard !user.id.isEmpty else {
            throw NSError(domain: "FirebaseUserService", code: 400, userInfo: [NSLocalizedDescriptionKey: "User ID is missing"])
        }
        
        do {
            let userData: [String: Any] = [
                "email": user.email,
                "displayName": user.displayName,
                "photoURL": user.photoURL as Any,
                "hasCompletedOnboarding": user.hasCompletedOnboarding,
                "preferences": [
                    "notifications": [
                        "pushEnabled": user.preferences.notifications.pushEnabled,
                        "emailEnabled": user.preferences.notifications.emailEnabled,
                        "enabledTypes": user.preferences.notifications.enabledTypes.map { $0.rawValue }
                    ],
                    "theme": [
                        "darkModeEnabled": user.preferences.theme.darkModeEnabled,
                        "primaryColor": user.preferences.theme.primaryColor
                    ],
                    "privacy": [
                        "locationSharingEnabled": user.preferences.privacy.locationSharingEnabled,
                        "calendarSharingEnabled": user.preferences.privacy.calendarSharingEnabled,
                        "profileVisibleToOthers": user.preferences.privacy.profileVisibleToOthers
                    ]
                ],
                "fcmToken": user.fcmToken as Any,
                "updatedAt": Date()
            ]
            
            try await db.collection("users").document(user.id).updateData(userData)
        } catch {
            throw error
        }
    }
    
    /// Get current authenticated user
    /// - Returns: Current user if authenticated, nil otherwise
    public func getCurrentUser() -> AppUser? {
        guard let firebaseUser = authService.getCurrentFirebaseUser() else {
            return nil
        }
        
        return AppUser.fromFirebaseUser(firebaseUser)
    }
    
    /// Get current user ID
    /// - Returns: Current user ID if authenticated, nil otherwise
    public func getCurrentUserId() -> String? {
        return authService.getCurrentFirebaseUser()?.uid
    }
    
    /// Save FCM token for a user
    /// - Parameters:
    ///   - token: FCM token
    ///   - userId: User ID
    public func saveFCMToken(_ token: String, for userId: String) async throws {
        do {
            try await db.collection("users").document(userId).updateData([
                "fcmToken": token
            ])
        } catch {
            throw error
        }
    }
    
    /// Save user data
    /// - Parameters:
    ///   - userData: User data
    ///   - userId: User ID
    public func saveUserData(_ userData: [String: Any], for userId: String) async throws {
        do {
            try await db.collection("users").document(userId).setData(userData, merge: true)
        } catch {
            throw error
        }
    }
    
    /// Get user data
    /// - Parameter userId: User ID
    /// - Returns: User data if found, nil otherwise
    public func getUserData(for userId: String) async throws -> [String: Any]? {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            if document.exists {
                return document.data()
            } else {
                return nil
            }
        } catch {
            throw error
        }
    }
} 