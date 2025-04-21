import Foundation
import SwiftUI
// Removed // Removed: import Unhinged.Utilities

/// Error types specific to the Hangouts feature
public enum HangoutErrorType {
    case authenticationRequired
    case hangoutNotFound
    case invalidTimeSlot
    case calendarConflict
    case participantUnavailable
    case permissionDenied
    case networkError
    case internalError(String)
}

/// Error type for Hangouts feature that integrates with the central error handling system
public struct HangoutError: AppError {
    private let errorType: HangoutErrorType
    private let underlyingError: Error?
    
    public init(errorType: HangoutErrorType, underlyingError: Error? = nil) {
        self.errorType = errorType
        self.underlyingError = underlyingError
    }
    
    /// Convert NSError to domain-specific HangoutError
    public init(from error: NSError) {
        if error.domain == "com.cheemhang.hangoutsviewmodel" {
            switch error.code {
            case -1:
                self.errorType = .authenticationRequired
            case -2:
                self.errorType = .calendarConflict
            default:
                self.errorType = .internalError(error.localizedDescription)
            }
        } else if error.domain == FirestoreErrorDomain {
            switch error.code {
            case 7: // Not found
                self.errorType = .hangoutNotFound
            case 13: // Permission denied
                self.errorType = .permissionDenied
            case 14: // Network error
                self.errorType = .networkError
            default:
                self.errorType = .internalError("Firebase error: \(error.localizedDescription)")
            }
        } else {
            self.errorType = .internalError(error.localizedDescription)
        }
        self.underlyingError = error
    }
    
    public var domain: String {
        return "Hangouts"
    }
    
    public var errorTitle: String {
        switch errorType {
        case .authenticationRequired:
            return "Sign In Required"
        case .hangoutNotFound:
            return "Hangout Not Found"
        case .invalidTimeSlot:
            return "Invalid Time"
        case .calendarConflict:
            return "Calendar Conflict"
        case .participantUnavailable:
            return "Participant Unavailable"
        case .permissionDenied:
            return "Permission Denied"
        case .networkError:
            return "Network Error"
        case .internalError:
            return "Error"
        }
    }
    
    public var errorDescription: String? {
        switch errorType {
        case .authenticationRequired:
            return "You need to be signed in to manage hangouts."
        case .hangoutNotFound:
            return "The requested hangout could not be found."
        case .invalidTimeSlot:
            return "The selected time is invalid. Please choose another time."
        case .calendarConflict:
            return "There's a calendar conflict during the selected time."
        case .participantUnavailable:
            return "One or more participants are not available during this time."
        case .permissionDenied:
            return "You don't have permission to perform this action."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .internalError(let message):
            return "An error occurred: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch errorType {
        case .authenticationRequired:
            return "Please sign in to continue."
        case .hangoutNotFound:
            return "The hangout may have been deleted or you don't have access to it."
        case .invalidTimeSlot:
            return "Choose a different date or time for your hangout."
        case .calendarConflict:
            return "Check your calendar and select a time when you're available."
        case .participantUnavailable:
            return "Try scheduling for a different time or check with the participants."
        case .permissionDenied:
            return "You can only modify hangouts you've created or been invited to."
        case .networkError:
            return "Check your internet connection and try again."
        case .internalError:
            return "Try again later or contact support if the issue persists."
        }
    }
    
    public var severity: ErrorSeverity {
        switch errorType {
        case .authenticationRequired, .permissionDenied:
            return .error
        case .hangoutNotFound, .invalidTimeSlot:
            return .warning
        case .calendarConflict, .participantUnavailable:
            return .info
        case .networkError:
            return .warning
        case .internalError:
            return .error
        }
    }
    
    public var recoveryActions: [ErrorRecoveryAction] {
        var actions: [ErrorRecoveryAction] = []
        
        switch errorType {
        case .authenticationRequired:
            actions.append(
                ErrorRecoveryAction(
                    title: "Sign In",
                    icon: "person.crop.circle.fill",
                    isPrimary: true,
                    action: {
                        NotificationManager.shared.navigateToSignIn()
                    }
                )
            )
            
        case .hangoutNotFound:
            actions.append(
                ErrorRecoveryAction(
                    title: "Back to Hangouts",
                    icon: "calendar",
                    isPrimary: true,
                    action: {
                        NotificationManager.shared.navigateToHangoutsList()
                    }
                )
            )
            
        case .invalidTimeSlot, .calendarConflict, .participantUnavailable:
            actions.append(
                ErrorRecoveryAction(
                    title: "Choose Different Time",
                    icon: "clock",
                    isPrimary: true,
                    action: {
                        NotificationManager.shared.navigateToFindTime()
                    }
                )
            )
            
            actions.append(
                ErrorRecoveryAction(
                    title: "View Calendar",
                    icon: "calendar",
                    action: {
                        NotificationManager.shared.navigateToCalendar()
                    }
                )
            )
            
        case .permissionDenied:
            actions.append(
                ErrorRecoveryAction(
                    title: "Back to Hangouts",
                    icon: "calendar",
                    isPrimary: true,
                    action: {
                        NotificationManager.shared.navigateToHangoutsList()
                    }
                )
            )
            
        case .networkError:
            actions.append(
                ErrorRecoveryAction(
                    title: "Retry",
                    icon: "arrow.clockwise",
                    isPrimary: true,
                    action: {}  // Placeholder to be filled by client
                )
            )
            
        case .internalError:
            actions.append(
                ErrorRecoveryAction(
                    title: "Try Again",
                    icon: "arrow.clockwise",
                    isPrimary: true,
                    action: {}  // Placeholder to be filled by client
                )
            )
            
            actions.append(
                ErrorRecoveryAction(
                    title: "Contact Support",
                    icon: "questionmark.circle",
                    action: {
                        NotificationManager.shared.navigateToSupport()
                    }
                )
            )
        }
        
        return actions
    }
} 