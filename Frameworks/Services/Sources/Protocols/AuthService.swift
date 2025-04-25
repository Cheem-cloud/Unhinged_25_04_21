import Foundation
import FirebaseAuth

/// Service responsible for handling authentication operations
public protocol AuthService {
    /// The current authenticated user
    var currentUser: User? { get }
    
    /// Get the current user as a FirebaseAuthUser model
    /// - Returns: FirebaseAuthUser if authenticated, nil otherwise
    func getCurrentFirebaseUser() -> FirebaseAuthUser?
    
    /// Sign in with email and password
    /// - Parameters:
    ///   - email: User's email
    ///   - password: User's password
    /// - Returns: Authentication result
    func signIn(email: String, password: String) async throws -> AuthDataResult
    
    /// Sign up with email and password
    /// - Parameters:
    ///   - email: User's email
    ///   - password: User's password
    /// - Returns: Authentication result
    func signUp(email: String, password: String) async throws -> AuthDataResult
    
    /// Sign in with Google
    /// - Returns: Authentication result
    func signInWithGoogle() async throws -> AuthDataResult
    
    /// Sign out the current user
    /// - Throws: Error if sign out fails
    func signOut() throws
    
    /// Send password reset email
    /// - Parameter email: User's email
    func sendPasswordResetEmail(to email: String) async throws
    
    /// Update user profile
    /// - Parameters:
    ///   - displayName: New display name (optional)
    ///   - photoURL: New photo URL (optional)
    func updateUserProfile(displayName: String?, photoURL: URL?) async throws
    
    /// Get authentication state changes 
    /// - Parameter handler: Callback that will be invoked when auth state changes
    /// - Returns: Listener handle that can be used to remove the listener
    func addAuthStateDidChangeListener(_ handler: @escaping (Auth, User?) -> Void) -> AuthStateDidChangeListenerHandle
    
    /// Remove auth state listener
    /// - Parameter handle: Listener handle to remove
    func removeAuthStateDidChangeListener(_ handle: AuthStateDidChangeListenerHandle)
} 