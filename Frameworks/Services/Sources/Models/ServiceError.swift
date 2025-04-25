import Foundation

public enum ServiceError: Error, Equatable {
    case invalidData
    case documentNotFound
    case networkError(String)
    case permissionDenied
    case serverError(String)
    case unknownError(String)
    
    public var localizedDescription: String {
        switch self {
        case .invalidData:
            return "The data received was invalid or could not be processed."
        case .documentNotFound:
            return "The requested document could not be found."
        case .networkError(let message):
            return "Network error: \(message)"
        case .permissionDenied:
            return "You don't have permission to perform this action."
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknownError(let message):
            return "An unknown error occurred: \(message)"
        }
    }
} 