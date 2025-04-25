import Foundation

/// Standard service errors
public enum ServiceError: Error, LocalizedError {
    case notInitialized
    case notAvailable
    case notConfigured
    case alreadyInitialized
    case configurationFailed(String)
    case notAuthenticated
    case invalidOperation(String)
    case operationFailed(String)
    case notImplemented
    case serviceTimeout
    case unknown(String)
    case invalidModelType
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Service has not been initialized"
        case .notAvailable:
            return "Service is not available"
        case .notConfigured:
            return "Service has not been configured"
        case .alreadyInitialized:
            return "Service has already been initialized"
        case .configurationFailed(let message):
            return "Service configuration failed: \(message)"
        case .notAuthenticated:
            return "Service requires authentication"
        case .invalidOperation(let message):
            return "Invalid operation for this service: \(message)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .notImplemented:
            return "This operation is not implemented"
        case .serviceTimeout:
            return "Service operation timed out"
        case .unknown(let message):
            return "Unknown error: \(message)"
        case .invalidModelType:
            return "Invalid model type provided"
        }
    }
} 