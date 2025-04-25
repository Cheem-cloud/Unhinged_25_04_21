import Foundation
import SwiftUI
import Utilities

/// Error cases for availability functionality
public struct AvailabilityError: Error, LocalizedError, Identifiable {
    public var id = UUID()
    
    /// The specific error type
    public var errorType: ErrorType
    
    /// Underlying error, if any
    public var underlyingError: Error?
    
    /// Initialize with an error type
    /// - Parameter errorType: The type of error
    public init(errorType: ErrorType, underlyingError: Error? = nil) {
        self.errorType = errorType
        self.underlyingError = underlyingError
    }
    
    /// Initialize from a legacy error type
    /// - Parameter legacyError: The legacy error type to convert
    public init(legacyError: MutualAvailabilityViewModel.MutualAvailabilityError) {
        switch legacyError {
        case .noFriendCoupleSelected:
            self.errorType = .relationshipNotFound
        case .noMutualAvailabilityFound:
            self.errorType = .noMutualAvailabilityFound
        case .calendarPermissionRequired:
            self.errorType = .calendarPermissionRequired
        case .searchRangeTooNarrow:
            self.errorType = .searchRangeTooNarrow
        case .internalError(let message):
            self.errorType = .internalError(message)
        case .networkError:
            self.errorType = .networkError
        }
        self.underlyingError = legacyError
    }
    
    /// Error description
    public var errorDescription: String? {
        return errorType.localizedDescription
    }
    
    /// Recovery suggestion
    public var recoverySuggestion: String? {
        return errorType.recoverySuggestion
    }
    
    /// Error title
    public var errorTitle: String {
        return errorType.title
    }
    
    /// Error severity
    public var severity: ErrorSeverity {
        switch errorType {
        case .calendarPermissionRequired, .calendarSyncFailed:
            return .warning
        case .invalidTimeRange, .invalidDuration, .searchRangeTooNarrow, .relationshipNotFound, .noMutualAvailabilityFound, .preferenceConflict, .unavailableTimePeriod:
            return .info
        case .networkTimeout, .networkError:
            return .warning
        case .internalError:
            return .error
        }
    }
    
    /// Recovery actions
    public var recoveryActions: [ErrorRecoveryAction] {
        var actions: [ErrorRecoveryAction] = []
        
        switch errorType {
        case .noMutualAvailabilityFound:
            actions.append(ErrorRecoveryAction(
                title: "Try Different Times",
                icon: "arrow.clockwise",
                isPrimary: true,
                action: {
                    // Handled in view code
                }
            ))
        case .calendarPermissionRequired, .calendarSyncFailed:
            actions.append(ErrorRecoveryAction(
                title: "Open Settings",
                icon: "gear",
                isPrimary: true,
                action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            ))
            actions.append(ErrorRecoveryAction(
                title: "Continue Without Calendar",
                icon: "calendar.badge.minus",
                isPrimary: false,
                action: {
                    // Handled in view code
                }
            ))
        case .networkTimeout, .networkError:
            actions.append(ErrorRecoveryAction(
                title: "Try Again",
                icon: "arrow.clockwise",
                isPrimary: true,
                action: {
                    // Handled in view code
                }
            ))
        default:
            // No recovery actions for other error types
            break
        }
        
        return actions
    }
    
    /// Specific error types for availability
    public enum ErrorType: Equatable {
        /// Invalid time range (start after end, etc.)
        case invalidTimeRange
        
        /// Invalid duration
        case invalidDuration
        
        /// Search range too narrow for finding mutual availability
        case searchRangeTooNarrow
        
        /// Calendar permission required
        case calendarPermissionRequired
        
        /// Calendar sync failed
        case calendarSyncFailed
        
        /// No mutual availability found in the given time range
        case noMutualAvailabilityFound
        
        /// Relationship not found
        case relationshipNotFound
        
        /// Conflicting preferences between users
        case preferenceConflict
        
        /// Unavailable time period
        case unavailableTimePeriod
        
        /// Network timeout
        case networkTimeout
        
        /// Network error
        case networkError
        
        /// Internal error with message
        case internalError(String)
        
        /// Localized description of the error
        public var localizedDescription: String {
            switch self {
            case .invalidTimeRange:
                return "Invalid time range. End time must be after start time."
            case .invalidDuration:
                return "Invalid duration. Duration must be between 15 minutes and 12 hours."
            case .searchRangeTooNarrow:
                return "The search range is too narrow. Please select a wider date range or shorter duration."
            case .calendarPermissionRequired:
                return "Calendar access is required to find mutual availability."
            case .calendarSyncFailed:
                return "Could not sync with your calendar. Please check your calendar connection."
            case .noMutualAvailabilityFound:
                return "No mutual availability found in the selected time range."
            case .relationshipNotFound:
                return "Could not find the specified relationship."
            case .preferenceConflict:
                return "There's a conflict between user preferences that prevents finding mutual availability."
            case .unavailableTimePeriod:
                return "The selected time period is unavailable."
            case .networkTimeout:
                return "The request timed out. Please check your connection and try again."
            case .networkError:
                return "A network error occurred. Please check your connection and try again."
            case .internalError(let message):
                return "An internal error occurred: \(message)"
            }
        }
        
        /// Recovery suggestion for the error
        public var recoverySuggestion: String? {
            switch self {
            case .invalidTimeRange:
                return "Please select an end time that is after the start time."
            case .invalidDuration:
                return "Please select a duration between 15 minutes and 12 hours."
            case .searchRangeTooNarrow:
                return "Try selecting a wider date range or reduce the duration of the hangout."
            case .calendarPermissionRequired:
                return "Please grant calendar access in settings or continue without using calendar data."
            case .calendarSyncFailed:
                return "Try reconnecting your calendar in settings or continue without using calendar data."
            case .noMutualAvailabilityFound:
                return "Try a different date range, reduce the duration, or check your availability preferences."
            case .relationshipNotFound:
                return "Please select a valid relationship or refresh your connections."
            case .preferenceConflict:
                return "Try adjusting your availability preferences to find mutual availability."
            case .unavailableTimePeriod:
                return "Please select a different time period."
            case .networkTimeout:
                return "Check your internet connection and try again."
            case .networkError:
                return "Check your internet connection and try again later."
            case .internalError:
                return "Please try again or contact support if the problem persists."
            }
        }
        
        /// Error title for display
        public var title: String {
            switch self {
            case .invalidTimeRange, .invalidDuration, .searchRangeTooNarrow:
                return "Invalid Time Selection"
            case .calendarPermissionRequired, .calendarSyncFailed:
                return "Calendar Access Required"
            case .noMutualAvailabilityFound, .preferenceConflict, .unavailableTimePeriod:
                return "No Mutual Availability"
            case .relationshipNotFound:
                return "Relationship Not Found"
            case .networkTimeout, .networkError:
                return "Connection Issue"
            case .internalError:
                return "Unexpected Error"
            }
        }
        
        /// Equatable implementation
        public static func == (lhs: ErrorType, rhs: ErrorType) -> Bool {
            switch (lhs, rhs) {
            case (.invalidTimeRange, .invalidTimeRange),
                 (.invalidDuration, .invalidDuration),
                 (.searchRangeTooNarrow, .searchRangeTooNarrow),
                 (.calendarPermissionRequired, .calendarPermissionRequired),
                 (.calendarSyncFailed, .calendarSyncFailed),
                 (.noMutualAvailabilityFound, .noMutualAvailabilityFound),
                 (.relationshipNotFound, .relationshipNotFound),
                 (.preferenceConflict, .preferenceConflict),
                 (.unavailableTimePeriod, .unavailableTimePeriod),
                 (.networkTimeout, .networkTimeout),
                 (.networkError, .networkError):
                return true
            case (.internalError(let lhsMsg), .internalError(let rhsMsg)):
                return lhsMsg == rhsMsg
            default:
                return false
            }
        }
    }
}

// MARK: - Error Handling Extension for MutualAvailabilityViewModel

extension MutualAvailabilityViewModel {
    /// Handle errors using the centralized error handling system
    public func handleErrorWithCentralizedSystem(_ error: Error) {
        // Convert error to AppError if not already
        if let availabilityError = error as? AvailabilityError {
            // Availability error is already conforming to AppError, pass directly
            UIErrorHandler.shared.showError(availabilityError)
        } else if let mutualError = error as? MutualAvailabilityError {
            // Convert legacy error
            let availabilityError = AvailabilityError(legacyError: mutualError)
            UIErrorHandler.shared.showError(availabilityError)
        } else {
            // Wrap generic error
            let availabilityError = AvailabilityError(
                errorType: .internalError(error.localizedDescription),
                underlyingError: error
            )
            UIErrorHandler.shared.showError(availabilityError)
        }
    }
}

// Mock service error for demonstration
public enum AvailabilityServiceError: Error {
    case invalidTimeRange
    case invalidDuration
    case calendarSyncFailed
    case relationshipNotFound
    case preferenceConflict
    case unavailableTimePeriod
    case networkTimeout
    case unknown
} 