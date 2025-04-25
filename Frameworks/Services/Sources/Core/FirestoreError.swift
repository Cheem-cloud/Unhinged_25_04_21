import Foundation

/// Firestore error types
public enum FirestoreError: Error, LocalizedError {
    case documentNotFound
    case permissionDenied
    case unavailable
    case dataLost
    case unknownError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "The requested document was not found."
        case .permissionDenied:
            return "Permission denied. You don't have access to this resource."
        case .unavailable:
            return "The service is currently unavailable."
        case .dataLost:
            return "Some data was lost or corrupted."
        case .unknownError(let error):
            return "Firestore error: \(error.localizedDescription)"
        }
    }
    
    /// Creates a FirestoreError from a general Error
    /// - Parameter error: The source error
    /// - Returns: A categorized FirestoreError
    public static func from(_ error: Error) -> FirestoreError {
        // If it's already a FirestoreError, return it
        if let firestoreError = error as? FirestoreError {
            return firestoreError
        }
        
        // Map Firebase error codes to our custom error types
        let nsError = error as NSError
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 5:  // NOT_FOUND
                return .documentNotFound
            case 7:  // PERMISSION_DENIED
                return .permissionDenied
            case 14: // UNAVAILABLE
                return .unavailable
            case 16: // DATA_LOSS 
                return .dataLost
            default:
                return .unknownError(error)
            }
        }
        
        return .unknownError(error)
    }
} 