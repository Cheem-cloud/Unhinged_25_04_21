import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Service for user-related operations
class UserService {
    /// Shared instance (singleton)
    static let shared = UserService()
    
    /// CRUD service for data operations
    private let crudService: CRUDService
    
    /// Private initializer to enforce singleton pattern
    private init(crudService: CRUDService = ServiceManager.shared.getService(CRUDService.self)) {
        self.crudService = crudService
        print("📱 UserService initialized with CRUDService")
    }
    
    /// Get a user by ID
    /// - Parameter id: User ID
    /// - Returns: User if found, nil otherwise
    func getUser(id: String) async throws -> AppUser? {
        do {
            // Use the CRUDService to read user data
            let userData = try await crudService.read("users/\(id)")
            
            guard let userData = userData else {
                return nil
            }
            
            // Convert to AppUser
            var user = try FirestoreDecoder().decode(AppUser.self, from: userData)
            if user.id == nil {
                user.id = id
            }
            
            return user
        } catch {
            print("❌ Error getting user: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Create a new user
    /// - Parameter user: User to create
    /// - Returns: User ID
    func createUser(_ user: AppUser) async throws -> String {
        do {
            // Convert AppUser to dictionary
            var userData = try FirestoreEncoder().encode(user) as? [String: Any] ?? [:]
            userData["collection"] = "users"
            
            // Use the CRUDService to create user
            let path = try await crudService.create(userData)
            
            // Extract user ID from path
            let components = path.components(separatedBy: "/")
            guard components.count >= 2 else {
                throw ServiceError.operationFailed("Invalid path returned from create operation")
            }
            
            return components[1]
        } catch {
            print("❌ Error creating user: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Update a user
    /// - Parameter user: User to update
    func updateUser(_ user: AppUser) async throws {
        guard let id = user.id else {
            throw ServiceError.invalidOperation("User ID is required for update")
        }
        
        do {
            // Convert AppUser to dictionary
            var userData = try FirestoreEncoder().encode(user) as? [String: Any] ?? [:]
            
            // Use the CRUDService to update user
            try await crudService.update("users/\(id)", with: userData)
        } catch {
            print("❌ Error updating user: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Get current authenticated user
    /// - Returns: Current user if authenticated, nil otherwise
    func getCurrentUser() -> AppUser? {
        guard let currentUser = Auth.auth().currentUser else {
            return nil
        }
        
        return AppUser(
            id: currentUser.uid,
            email: currentUser.email ?? "",
            displayName: currentUser.displayName ?? "",
            photoURL: currentUser.photoURL?.absoluteString ?? ""
        )
    }
    
    /// Get current user ID
    /// - Returns: Current user ID if authenticated, nil otherwise
    func getCurrentUserId() -> String? {
        return Auth.auth().currentUser?.uid
    }
    
    /// Save FCM token for a user
    /// - Parameters:
    ///   - token: FCM token
    ///   - userId: User ID
    func saveFCMToken(_ token: String, for userId: String) async throws {
        // Create update dictionary
        let tokenData: [String: Any] = [
            "fcmToken": token,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        // Use the CRUDService to update user
        try await crudService.update("users/\(userId)", with: tokenData)
    }
    
    /// Save user data
    /// - Parameters:
    ///   - userData: User data
    ///   - userId: User ID
    func saveUserData(_ userData: [String: Any], for userId: String) async throws {
        // Use the CRUDService to update user
        try await crudService.update("users/\(userId)", with: userData)
    }
    
    /// Get user data
    /// - Parameter userId: User ID
    /// - Returns: User data if found, nil otherwise
    func getUserData(for userId: String) async throws -> [String: Any]? {
        // Use the CRUDService to read user data
        return try await crudService.read("users/\(userId)")
    }
} 