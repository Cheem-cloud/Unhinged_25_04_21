import Foundation

/// Protocol for user-related service operations
public protocol UserService {
    /// Get a user by ID
    /// - Parameter id: User ID
    /// - Returns: User if found, nil otherwise
    func getUser(id: String) async throws -> AppUser?
    
    /// Create a new user
    /// - Parameter user: User to create
    /// - Returns: User ID
    func createUser(_ user: AppUser) async throws -> String
    
    /// Update a user
    /// - Parameter user: User to update
    func updateUser(_ user: AppUser) async throws
    
    /// Get current authenticated user
    /// - Returns: Current user if authenticated, nil otherwise
    func getCurrentUser() -> AppUser?
    
    /// Get current user ID
    /// - Returns: Current user ID if authenticated, nil otherwise
    func getCurrentUserId() -> String?
    
    /// Save FCM token for a user
    /// - Parameters:
    ///   - token: FCM token
    ///   - userId: User ID
    func saveFCMToken(_ token: String, for userId: String) async throws
    
    /// Save user data
    /// - Parameters:
    ///   - userData: User data
    ///   - userId: User ID
    func saveUserData(_ userData: [String: Any], for userId: String) async throws
    
    /// Get user data
    /// - Parameter userId: User ID
    /// - Returns: User data if found, nil otherwise
    func getUserData(for userId: String) async throws -> [String: Any]?
} 