import Foundation
import SwiftUI
import FirebaseAuth
import Core
import Services

/// Authentication states
public enum AuthState {
    case signedIn
    case signedOut
    case loading
}

/// ViewModel for handling authentication
@MainActor
public class AuthViewModel: ObservableObject {
    // Published properties for UI
    @Published public var authState: AuthState = .loading
    @Published public var error: Error?
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String = ""
    @Published public var isNewUser: Bool = false
    
    // Auth form fields
    @Published public var name: String = ""
    @Published public var email: String = ""
    @Published public var password: String = ""
    @Published public var confirmPassword: String = ""
    
    // Services
    private let authService: AuthService
    private let userService: UserService
    
    // Store auth state listener handle
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    /// Convenience property to check if user is signed in
    public var isSignedIn: Bool {
        return authService.currentUser != nil
    }
    
    /// Get the current Firebase user
    public var currentUser: FirebaseAuthUser? {
        return authService.getCurrentFirebaseUser()
    }
    
    /// Initialize with services
    public init(authService: AuthService, userService: UserService) {
        self.authService = authService
        self.userService = userService
        
        print("AuthViewModel: Initializing")
        
        // Initialize with signed out state to see auth flow
        self.authState = .signedOut
        
        // Check if we have a persisted new user flag
        if let isNewUser = UserDefaults.standard.object(forKey: "isNewUser") as? Bool {
            self.isNewUser = isNewUser
            print("AuthViewModel: Loaded isNewUser flag from UserDefaults: \(isNewUser)")
        }
        
        // Setup auth state listener to detect user sign-in state
        setupAuthStateListener()
    }
    
    /// Set up Firebase auth state listener
    private func setupAuthStateListener() {
        print("AuthViewModel: Setting up auth state listener")
        authStateListener = authService.addAuthStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    print("AuthViewModel: Auth state changed to signedIn for user: \(user.uid)")
                    print("AuthViewModel: Email verified: \(user.isEmailVerified), Creation time: \(user.metadata.creationDate?.description ?? "unknown")")
                    
                    self?.authState = .signedIn
                    
                    // Check if this is a newly created user by comparing timestamps
                    if let creationDate = user.metadata.creationDate,
                       let lastSignInDate = user.metadata.lastSignInDate,
                       // User is considered new if account was created less than 10 minutes ago
                       creationDate.timeIntervalSince1970 > Date().timeIntervalSince1970 - 600,
                       // And this is their first sign-in (creation time equals last sign-in time)
                       abs(creationDate.timeIntervalSince1970 - lastSignInDate.timeIntervalSince1970) < 60 {
                        
                        print("AuthViewModel: Detected a newly created user")
                        self?.isNewUser = true
                        // Persist to UserDefaults
                        UserDefaults.standard.set(true, forKey: "isNewUser")
                    }
                } else {
                    print("AuthViewModel: Auth state changed to signedOut")
                    self?.authState = .signedOut
                }
            }
        }
    }
    
    /// Sign in with Google
    public func signInWithGoogle() async {
        print("AuthViewModel: Starting Google sign-in flow")
        isLoading = true
        errorMessage = ""
        
        do {
            let authResult = try await authService.signInWithGoogle()
            print("AuthViewModel: Successfully signed in with Google")
            
            // Create or update user in database if needed
            await createOrUpdateUser(from: authResult.user)
            
            isLoading = false
        } catch {
            print("AuthViewModel: Error signing in with Google: \(error.localizedDescription)")
            handleAuthError(error)
        }
    }
    
    /// Sign out the current user
    public func signOut() {
        print("AuthViewModel: Signing out")
        
        do {
            try authService.signOut()
            print("AuthViewModel: Successfully signed out")
        } catch {
            print("AuthViewModel: Error signing out: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    /// Sign in with email and password
    public func signIn() {
        print("AuthViewModel: Starting email sign-in flow")
        isLoading = true
        errorMessage = ""
        
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password"
            isLoading = false
            return
        }
        
        Task {
            do {
                try await authService.signIn(email: email, password: password)
                isLoading = false
                resetFields()
            } catch {
                handleAuthError(error)
            }
        }
    }
    
    /// Sign in with email and password parameters (for use from other views)
    public func signIn(email: String, password: String) async {
        print("AuthViewModel: Starting email sign-in flow with parameters")
        isLoading = true
        errorMessage = ""
        
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password"
            isLoading = false
            return
        }
        
        do {
            try await authService.signIn(email: email, password: password)
            isLoading = false
        } catch {
            handleAuthError(error)
        }
    }
    
    /// Sign up with email and password
    public func signUp() {
        print("AuthViewModel: Starting email sign-up flow")
        isLoading = true
        errorMessage = ""
        
        // Validate inputs
        guard !name.isEmpty else {
            errorMessage = "Please enter your name"
            isLoading = false
            return
        }
        
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            isLoading = false
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "Please enter a password"
            isLoading = false
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            isLoading = false
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            isLoading = false
            return
        }
        
        Task {
            do {
                // Create the user
                let authResult = try await authService.signUp(email: email, password: password)
                print("AuthViewModel: User created successfully with ID: \(authResult.user.uid)")
                
                // Set the display name
                try await authService.updateUserProfile(displayName: name, photoURL: nil)
                print("AuthViewModel: Display name set to: \(name)")
                
                // Create user in database
                await createOrUpdateUser(from: authResult.user)
                
                // Set as signed in and new user
                self.authState = .signedIn
                self.isNewUser = true
                print("AuthViewModel: isNewUser flag set to true")
                
                // Persist to UserDefaults
                UserDefaults.standard.set(true, forKey: "isNewUser")
                print("AuthViewModel: isNewUser saved to UserDefaults")
                
                self.isLoading = false
                self.resetFields()
            } catch {
                handleAuthError(error)
            }
        }
    }
    
    /// Send password reset email
    public func sendPasswordReset(to email: String) async {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        
        isLoading = true
        
        do {
            try await authService.sendPasswordResetEmail(to: email)
            errorMessage = "Password reset email sent"
            isLoading = false
        } catch {
            handleAuthError(error)
        }
    }
    
    /// Create or update a user in the database based on Firebase auth user
    private func createOrUpdateUser(from firebaseUser: User) async {
        do {
            // Convert to our FirebaseAuthUser model
            let authUser = FirebaseAuthUser(
                uid: firebaseUser.uid,
                email: firebaseUser.email,
                displayName: firebaseUser.displayName,
                photoURL: firebaseUser.photoURL
            )
            
            // Create AppUser from FirebaseAuthUser
            let appUser = AppUser.fromFirebaseUser(authUser)
            
            // Check if user exists in database
            if let _ = try await userService.getUser(id: firebaseUser.uid) {
                // User exists, update
                try await userService.updateUser(appUser)
                print("AuthViewModel: User updated in database")
            } else {
                // User doesn't exist, create
                let userId = try await userService.createUser(appUser)
                print("AuthViewModel: User created in database with ID: \(userId)")
            }
        } catch {
            print("AuthViewModel: Error creating/updating user in database: \(error.localizedDescription)")
            // We don't fail the sign-in if this fails, just log the error
        }
    }
    
    /// Handle authentication errors
    private func handleAuthError(_ error: Error) {
        isLoading = false
        print("AuthViewModel: Authentication error: \(error.localizedDescription)")
        
        let nsError = error as NSError
        if let errorCode = AuthErrorCode(rawValue: nsError.code) {
            switch errorCode {
            case .invalidEmail:
                errorMessage = "The email address is invalid"
            case .wrongPassword:
                errorMessage = "Incorrect password"
            case .userNotFound:
                errorMessage = "No account found with this email"
            case .emailAlreadyInUse:
                errorMessage = "This email is already in use"
            case .weakPassword:
                errorMessage = "Password is too weak"
            case .networkError:
                errorMessage = "Network error. Please try again"
            default:
                errorMessage = "Authentication failed: \(error.localizedDescription)"
            }
        } else {
            errorMessage = "Authentication failed: \(error.localizedDescription)"
        }
    }
    
    /// Reset input fields
    private func resetFields() {
        name = ""
        email = ""
        password = ""
        confirmPassword = ""
        errorMessage = ""
    }
    
    /// Clean up when view model is deallocated
    deinit {
        if let handle = authStateListener {
            authService.removeAuthStateDidChangeListener(handle)
        }
    }
} 