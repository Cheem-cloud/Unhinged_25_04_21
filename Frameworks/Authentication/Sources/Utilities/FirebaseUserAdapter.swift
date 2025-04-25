import Foundation
import FirebaseAuth
import Core

/// Utility for converting between Firebase Auth user objects and app user models
public struct FirebaseUserAdapter {
    /// Convert a Firebase Auth user to an AppUser
    /// - Parameter firebaseUser: The Firebase Auth user
    /// - Returns: An AppUser model
    public static func toAppUser(_ firebaseUser: User) -> AppUser {
        return AppUser(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            displayName: firebaseUser.displayName ?? "",
            photoURL: firebaseUser.photoURL?.absoluteString
        )
    }
    
    /// Convert a Firebase Auth user to a FirebaseAuthUser struct
    /// - Parameter firebaseUser: The Firebase Auth user
    /// - Returns: A FirebaseAuthUser struct
    public static func toFirebaseAuthUser(_ firebaseUser: User) -> FirebaseAuthUser {
        return FirebaseAuthUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email,
            displayName: firebaseUser.displayName,
            photoURL: firebaseUser.photoURL
        )
    }
} 