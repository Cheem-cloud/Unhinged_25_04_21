import Foundation
import Firebase
import FirebaseAuth
import GoogleSignIn
import SwiftUI
import FirebaseFirestore
import FirebaseMessaging
import UIKit
import AuthenticationServices
import CryptoKit

public enum AuthState {
    case signedIn
    case signedOut
    case loading
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var authState: AuthState = .loading
    @Published var error: Error?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var isNewUser: Bool = false
    
    // Partner invitation related
    @Published var pendingPartnerInvitation: PartnerInvitation?
    @Published var showPartnerInvitation: Bool = false
    
    // Auth form fields
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    
    // Store auth state listener handle
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    private let db = Firestore.firestore()
    private let firestoreService = FirestoreService()
    let relationshipService = RelationshipService()
    
    // Properties for Apple Sign In
    private var currentNonce: String?
    
    var isSignedIn: Bool {
        return user != nil
    }
    
    init() {
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
    
    func setupAuthStateListener() {
        print("AuthViewModel: Setting up auth state listener")
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user = user
                if let user = user {
                    print("AuthViewModel: Auth state changed to signedIn for user: \(user.uid)")
                    print("AuthViewModel: Email verified: \(user.isEmailVerified), Creation time: \(user.metadata.creationDate?.description ?? "unknown")")
                    
                    self?.authState = .signedIn
                    self?.updateUserFCMToken(userId: user.uid)
                    
                    // Check for pending invitations when signed in
                    Task {
                        await self?.checkForPendingPartnerInvitation()
                    }
                    
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
                    self?.deleteFCMToken()
                }
            }
        }
    }
    
    private func updateUserFCMToken(userId: String) {
        if let token = Messaging.messaging().fcmToken {
            print("AuthViewModel: Updating FCM token for user \(userId)")
            Task {
                try? await firestoreService.saveFCMToken(token, for: userId)
            }
        }
    }
    
    private func deleteFCMToken() {
        // Remove the FCM token on sign out
        Messaging.messaging().deleteToken { error in
            if let error = error {
                print("AuthViewModel: Error deleting FCM token: \(error)")
            } else {
                print("AuthViewModel: Successfully deleted FCM token")
            }
        }
    }
    
    func signInWithGoogle() async {
        print("AuthViewModel: Starting Google sign-in flow")
        isLoading = true
        
        // Set error message for user feedback
        errorMessage = ""
        
        // Use defer to ensure isLoading is set to false when the function exits
        defer {
            isLoading = false
        }
        
        // Get the client ID from GoogleService-Info.plist
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("AuthViewModel: Firebase client ID not found")
            self.error = NSError(domain: "com.cheemhang.auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase configuration error"])
            self.errorMessage = "Firebase configuration error"
            return
        }
        
        print("AuthViewModel: Firebase client ID found: \(clientID)")
        
        // Create Google Sign In configuration object
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        do {
            // Get the key window from the active scene - this is guaranteed to be on the main thread with @MainActor
            print("AuthViewModel: Looking for window scene and root view controller")
            let windowScene = UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .first as? UIWindowScene
            
            print("AuthViewModel: Found window scene: \(windowScene != nil)")
            
            guard let rootViewController = windowScene?.windows.first?.rootViewController else {
                print("AuthViewModel: No root view controller found")
                self.errorMessage = "Unable to present sign-in screen"
                throw NSError(domain: "com.cheemhang.auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller found"])
            }
            
            print("AuthViewModel: Found root view controller, presenting Google sign-in view")
            
            // Start the sign-in flow
            print("AuthViewModel: Calling GIDSignIn.sharedInstance.signIn")
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            print("AuthViewModel: Received sign-in result")
            let user = result.user
            guard let idToken = user.idToken?.tokenString else {
                print("AuthViewModel: ID token missing from Google sign-in result")
                self.errorMessage = "ID token missing from Google Sign-In result"
                throw NSError(domain: "com.cheemhang.auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "ID token missing"])
            }
            
            print("AuthViewModel: Got Google credentials, authenticating with Firebase")
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            
            try await Auth.auth().signIn(with: credential)
            print("AuthViewModel: Successfully signed in with Firebase")
            
            // Get user's calendar access token
            // This is where we would set up Google Calendar API if needed
            let scopes = ["https://www.googleapis.com/auth/calendar"]
            try await user.addScopes(scopes, presenting: rootViewController)
            
            // Now we should have calendar access
            // Store token in UserDefaults or another persistent storage
            UserDefaults.standard.set(user.accessToken.tokenString, forKey: "calendarAccessToken")
            print("AuthViewModel: Calendar access token stored")
            
        } catch {
            print("AuthViewModel: Error signing in with Google: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    func signOut() {
        print("AuthViewModel: Signing out")
        
        // Clear FCM token from Firestore before signing out
        if let currentUser = Auth.auth().currentUser {
            Task {
                do {
                    try await NotificationService.shared.clearFCMToken(for: currentUser.uid)
                    print("AuthViewModel: Successfully deleted FCM token")
                } catch {
                    print("AuthViewModel: Error clearing FCM token - \(error.localizedDescription)")
                }
            }
        }
        
        do {
            try Auth.auth().signOut()
            
            // Ensure Google Sign-In state is completely disconnected
            GIDSignIn.sharedInstance.signOut()
            GIDSignIn.sharedInstance.disconnect { error in
                if let error = error {
                    print("AuthViewModel: Error disconnecting Google Sign-In - \(error.localizedDescription)")
                } else {
                    print("AuthViewModel: Successfully disconnected Google Sign-In")
                }
            }
            
            // Clear any cached data
            URLCache.shared.removeAllCachedResponses()
            print("AuthViewModel: Cleared URL cache")
            
            print("AuthViewModel: Successfully signed out")
        } catch {
            print("AuthViewModel: Error signing out: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    func signIn() {
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
                try await Auth.auth().signIn(withEmail: email, password: password)
                isLoading = false
                resetFields()
            } catch {
                handleAuthError(error)
            }
        }
    }
    
    /// Sign in with email and password parameters (for use from other views)
    func signIn(email: String, password: String) async {
        print("AuthViewModel: Starting email sign-in flow with parameters")
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        guard !email.isEmpty, !password.isEmpty else {
            await MainActor.run {
                errorMessage = "Please enter both email and password"
                isLoading = false
            }
            return
        }
        
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                handleAuthError(error)
            }
        }
    }
    
    func signUp() {
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
                let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
                print("AuthViewModel: User created successfully with ID: \(authResult.user.uid)")
                
                // Set the display name
                let changeRequest = authResult.user.createProfileChangeRequest()
                changeRequest.displayName = name
                try await changeRequest.commitChanges()
                print("AuthViewModel: Display name set to: \(name)")
                
                // Create user in Firestore
                let newUser = AppUser(
                    id: authResult.user.uid,
                    email: email,
                    displayName: name,
                    photoURL: nil,
                    createdAt: Timestamp().dateValue(),
                    updatedAt: Timestamp().dateValue()
                )
                
                try await firestoreService.createUser(newUser)
                print("AuthViewModel: User document created in Firestore")
                
                // Set the user property and mark as signed in
                await MainActor.run {
                    self.user = authResult.user
                    self.authState = .signedIn
                    self.isNewUser = true
                    print("AuthViewModel: isNewUser flag set to true")
                    
                    // Persist to UserDefaults
                    UserDefaults.standard.set(true, forKey: "isNewUser")
                    print("AuthViewModel: isNewUser saved to UserDefaults")
                    
                    self.isLoading = false
                    self.resetFields()
                }
            } catch {
                await MainActor.run {
                    self.handleAuthError(error)
                }
            }
        }
    }
    
    /// Sign up with email, password, name, and partner email (required)
    func signUpWithPartner(email: String, password: String, name: String, partnerEmail: String) async {
        print("AuthViewModel: Starting email sign-up flow with partner email")
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        // Validate inputs
        guard !name.isEmpty else {
            await MainActor.run {
                errorMessage = "Please enter your name"
                isLoading = false
            }
            return
        }
        
        guard !email.isEmpty else {
            await MainActor.run {
                errorMessage = "Please enter your email"
                isLoading = false
            }
            return
        }
        
        guard !partnerEmail.isEmpty else {
            await MainActor.run {
                errorMessage = "Please enter your partner's email"
                isLoading = false
            }
            return
        }
        
        guard email.lowercased() != partnerEmail.lowercased() else {
            await MainActor.run {
                errorMessage = "You cannot enter your own email as your partner's email"
                isLoading = false
            }
            return
        }
        
        guard !password.isEmpty else {
            await MainActor.run {
                errorMessage = "Please enter a password"
                isLoading = false
            }
            return
        }
        
        guard password.count >= 6 else {
            await MainActor.run {
                errorMessage = "Password must be at least 6 characters"
                isLoading = false
            }
            return
        }
        
        do {
            // Step 1: Create the user
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            print("AuthViewModel: User created successfully with ID: \(authResult.user.uid)")
            
            // Step 2: Set the display name
            let changeRequest = authResult.user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
            print("AuthViewModel: Display name set to: \(name)")
            
            // Step 3: Create user in Firestore
            let newUser = AppUser(
                id: authResult.user.uid,
                email: email,
                displayName: name,
                photoURL: nil,
                createdAt: Timestamp().dateValue(),
                updatedAt: Timestamp().dateValue()
            )
            
            try await firestoreService.createUser(newUser)
            print("AuthViewModel: User document created in Firestore")
            
            // Step 4: Check if partner already exists
            let partnerUsers = try await relationshipService.getUsersByEmail(email: partnerEmail)
            
            if let partnerUser = partnerUsers.first {
                print("AuthViewModel: Partner found with ID: \(partnerUser.id ?? "unknown")")
                
                // Check if partner already has a relationship
                let partnerRelationship = try? await relationshipService.getUserRelationship(userID: partnerUser.id ?? "")
                
                if partnerRelationship != nil {
                    print("AuthViewModel: Partner already has a relationship, sending invitation")
                    // Partner already has a relationship, just send an invitation
                    _ = try await relationshipService.invitePartner(partnerEmail: partnerEmail, message: "I've just joined Unhinged!")
                } else {
                    print("AuthViewModel: Creating relationship with partner")
                    // Create direct relationship since partner exists but has no relationship
                    let relationship = Relationship(initiatorID: authResult.user.uid, partnerID: partnerUser.id ?? "")
                    let createdRelationship = try await relationshipService.createRelationship(relationship)
                    print("AuthViewModel: Relationship created with ID: \(createdRelationship.id ?? "unknown")")
                }
            } else {
                print("AuthViewModel: Partner not found, sending invitation")
                // Partner doesn't exist yet, send invitation
                _ = try await relationshipService.invitePartner(partnerEmail: partnerEmail, message: "I've just joined Unhinged!")
            }
            
            // Set the user property
            await MainActor.run {
                self.user = authResult.user
                self.authState = .signedIn
                self.isNewUser = true
                print("AuthViewModel: isNewUser flag set to true")
                
                // Persist to UserDefaults
                UserDefaults.standard.set(true, forKey: "isNewUser")
                print("AuthViewModel: isNewUser saved to UserDefaults")
                
                // Also save that partner invitation was already sent during signup
                UserDefaults.standard.set(true, forKey: "partnerInvitationSent")
                print("AuthViewModel: partnerInvitationSent flag saved to UserDefaults")
                
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.handleAuthError(error)
            }
        }
    }
    
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
    
    private func resetFields() {
        name = ""
        email = ""
        password = ""
        confirmPassword = ""
        errorMessage = ""
    }
    
    deinit {
        if let handle = authStateListener {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Partner Invitation Methods
    
    /// Check if the current user has any pending partner invitations
    func checkForPendingPartnerInvitation() async {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        do {
            // Check if user has a relationship
            if let relationship = try await self.relationshipService.getCurrentUserRelationship(),
                relationship.status == .active {
                // User already has an active relationship, no need to check for invitations
                return
            }
            
            // If no relationship but pending invitation, show it
            if let invitation = try await relationshipService.getPendingPartnerInvitation() {
                print("AuthViewModel: Found pending invitation from \(invitation.senderID ?? "unknown")")
                
                await MainActor.run {
                    self.pendingPartnerInvitation = invitation
                    self.showPartnerInvitation = true
                }
            }
        } catch {
            print("AuthViewModel: Error checking for partner invitation: \(error.localizedDescription)")
        }
    }
    
    /// Send an invitation to become partners
    func invitePartner(email: String, message: String? = nil) async -> Bool {
        isLoading = true
        errorMessage = ""
        
        do {
            let _ = try await relationshipService.invitePartner(partnerEmail: email, message: message)
            isLoading = false
            return true
        } catch {
            print("AuthViewModel: Error inviting partner: \(error.localizedDescription)")
            
            if let relationshipError = error as? RelationshipError {
                switch relationshipError {
                case .userAlreadyInRelationship:
                    errorMessage = "You are already in a relationship."
                case .cannotInviteSelf:
                    errorMessage = "You cannot invite yourself."
                default:
                    errorMessage = "Error inviting partner: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "Error inviting partner: \(error.localizedDescription)"
            }
            
            isLoading = false
            return false
        }
    }
    
    /// Accept a partner invitation
    func acceptPartnerInvitation(invitationID: String) async -> Bool {
        isLoading = true
        errorMessage = ""
        
        do {
            let relationship = try await relationshipService.acceptPartnerInvitation(invitationID: invitationID)
            await MainActor.run {
                self.pendingPartnerInvitation = nil
                self.showPartnerInvitation = false
                self.isLoading = false
            }
            return true
        } catch {
            print("AuthViewModel: Error accepting partnership: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Error accepting partnership: \(error.localizedDescription)"
                self.isLoading = false
            }
            return false
        }
    }
    
    /// Decline a partner invitation
    func declinePartnerInvitation(invitationID: String) async {
        isLoading = true
        errorMessage = ""
        
        do {
            try await relationshipService.declinePartnerInvitation(invitationID: invitationID)
            await MainActor.run {
                self.pendingPartnerInvitation = nil
                self.showPartnerInvitation = false
                self.isLoading = false
            }
        } catch {
            print("AuthViewModel: Error declining partnership: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Error declining partnership: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        print("AuthViewModel: Starting Apple sign-in flow")
        isLoading = true
        errorMessage = ""
        
        // Verify that we have a valid nonce and credential
        guard let nonce = currentNonce,
              let appleIDToken = credential.identityToken,
              let tokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("AuthViewModel: Invalid Apple Sign In state")
            errorMessage = "Invalid Apple Sign In state"
            isLoading = false
            return
        }

        print("AuthViewModel: Apple ID token obtained")
        
        // Create Firebase credential
        let firebaseCredential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: tokenString,
            rawNonce: nonce
        )
        
        do {
            // Sign in with Firebase
            let authResult = try await Auth.auth().signIn(with: firebaseCredential)
            print("AuthViewModel: Successfully signed in with Apple")
            
            // If this is a new user, update display name from Apple credential
            if let displayName = credential.fullName?.formatted(),
               displayName.count > 0,
               let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest() {
                    
                try await changeRequest.commitChanges()
                
                // Create user document in Firestore if it doesn't exist
                let newUser = AppUser(
                    id: authResult.user.uid,
                    email: credential.email ?? authResult.user.email ?? "",
                    displayName: displayName,
                    photoURL: nil,
                    createdAt: Timestamp().dateValue(),
                    updatedAt: Timestamp().dateValue()
                )
                
                do {
                    try await firestoreService.createUser(newUser)
                } catch {
                    // User might already exist, which is fine
                    print("AuthViewModel: Error creating user document: \(error)")
                }
            }
            
            isLoading = false
        } catch {
            print("AuthViewModel: Error signing in with Apple: \(error.localizedDescription)")
            errorMessage = "Error signing in with Apple: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Apple Sign In Helper Methods
    
    /// Starts an Apple sign-in flow with a secure nonce
    func startSignInWithAppleFlow() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        return request
    }
    
    /// Generates a random string for secure authentication
    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            for random in randoms {
                if remainingLength == 0 {
                    break
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    /// Hashes a string with SHA256
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        
        return hashString
    }
    
    // Reset isNewUser flag when onboarding is complete
    func completeOnboarding() {
        self.isNewUser = false
        UserDefaults.standard.set(false, forKey: "isNewUser")
        print("AuthViewModel: Onboarding completed, isNewUser flag reset")
    }
} 
