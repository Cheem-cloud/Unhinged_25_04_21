import Foundation
import Firebase
import FirebaseAuth
import GoogleSignIn
#if canImport(UIKit)
#if canImport(UIKit)
import UIKit
#endif
#endif

import Core

/// Firebase implementation of the AuthService protocol
public class FirebaseAuthService: AuthService {
    private var authStateListeners: [AuthStateDidChangeListenerHandle] = []
    
    public init() {
        print("📱 FirebaseAuthService initialized")
    }
    
    public var currentUser: User? {
        Auth.auth().currentUser
    }
    
    public func getCurrentFirebaseUser() -> FirebaseAuthUser? {
        guard let user = Auth.auth().currentUser else {
            return nil
        }
        
        return FirebaseAuthUser(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            photoURL: user.photoURL
        )
    }
    
    public func signIn(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let authResult = authResult {
                    continuation.resume(returning: authResult)
                } else {
                    continuation.resume(throwing: NSError(domain: "FirebaseAuthService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to sign in"]))
                }
            }
        }
    }
    
    public func signUp(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let authResult = authResult {
                    continuation.resume(returning: authResult)
                } else {
                    continuation.resume(throwing: NSError(domain: "FirebaseAuthService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to sign up"]))
                }
            }
        }
    }
    
    public func signInWithGoogle() async throws -> AuthDataResult {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "FirebaseAuthService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Firebase clientID not available"])
        }
        
        #if canImport(UIKit) && !os(macOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "FirebaseAuthService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No root view controller available"])
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        guard let user = result.user,
              let idToken = user.idToken?.tokenString else {
            throw NSError(domain: "FirebaseAuthService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to get Google user or token"])
        }
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
        
        return try await Auth.auth().signIn(with: credential)
        #else
        // Mock implementation for non-UIKit platforms (e.g., macOS)
        throw NSError(domain: "FirebaseAuthService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Google Sign-In is not supported on this platform"])
        #endif
    }
    
    public func signOut() throws {
        try Auth.auth().signOut()
    }
    
    public func sendPasswordResetEmail(to email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
    
    public func updateUserProfile(displayName: String?, photoURL: URL?) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseAuthService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        let changeRequest = user.createProfileChangeRequest()
        
        if let displayName = displayName {
            changeRequest.displayName = displayName
        }
        
        if let photoURL = photoURL {
            changeRequest.photoURL = photoURL
        }
        
        try await changeRequest.commitChanges()
    }
    
    public func addAuthStateDidChangeListener(_ handler: @escaping (Auth, User?) -> Void) -> AuthStateDidChangeListenerHandle {
        let handle = Auth.auth().addStateDidChangeListener(handler)
        authStateListeners.append(handle)
        return handle
    }
    
    public func removeAuthStateDidChangeListener(_ handle: AuthStateDidChangeListenerHandle) {
        Auth.auth().removeStateDidChangeListener(handle)
        authStateListeners.removeAll { $0 === handle }
    }
} 