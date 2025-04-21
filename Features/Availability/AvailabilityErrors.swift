import Foundation
import SwiftUI
// Removed // Removed: import Unhinged.Utilities

/// Errors related to availability functionality
public enum AvailabilityErrorType {
    case noFriendCoupleSelected
    case noMutualAvailabilityFound
    case calendarPermissionRequired
    case searchRangeTooNarrow
    case internalError(String)
    case networkError
}

/// Error type for availability features that integrates with the central error handling system
public struct AvailabilityError: AppError {
    private let errorType: AvailabilityErrorType
    private let underlyingError: Error?
    
    public init(errorType: AvailabilityErrorType, underlyingError: Error? = nil) {
        self.errorType = errorType
        self.underlyingError = underlyingError
    }
    
    /// Create from a MutualAvailabilityViewModel.MutualAvailabilityError
    public init(legacyError: MutualAvailabilityViewModel.MutualAvailabilityError) {
        switch legacyError {
        case .noFriendCoupleSelected:
            self.errorType = .noFriendCoupleSelected
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
    
    public var domain: String {
        return "Availability"
    }
    
    public var errorTitle: String {
        switch errorType {
        case .noFriendCoupleSelected:
            return "Select a Friend"
        case .noMutualAvailabilityFound:
            return "No Available Times"
        case .calendarPermissionRequired:
            return "Calendar Access Required"
        case .searchRangeTooNarrow:
            return "Adjust Time Range"
        case .internalError:
            return "Error"
        case .networkError:
            return "Network Error"
        }
    }
    
    public var errorDescription: String? {
        switch errorType {
        case .noFriendCoupleSelected:
            return "Please select a friend couple first"
        case .noMutualAvailabilityFound:
            return "No mutual availability found. Try adjusting your date range or duration."
        case .calendarPermissionRequired:
            return "Calendar access is required to check availability. Please grant permission in Settings."
        case .searchRangeTooNarrow:
            return "Search range is too narrow. Try extending the date range or shortening the duration."
        case .internalError(let message):
            return "Internal error: \(message)"
        case .networkError:
            return "Network error. Please check your connection and try again."
        }
    }
    
    public var recoverySuggestion: String? {
        switch errorType {
        case .noFriendCoupleSelected:
            return "Tap 'Select Friend Couple' to choose a couple to hang out with."
        case .noMutualAvailabilityFound:
            return "Consider different days, times, or shortening the duration."
        case .calendarPermissionRequired:
            return "You can either grant calendar access in Settings or use manual availability."
        case .searchRangeTooNarrow:
            return "Try a wider date range or shorter duration."
        case .internalError:
            return "Try again later or contact support if the issue persists."
        case .networkError:
            return "Check your internet connection and try again."
        }
    }
    
    public var severity: ErrorSeverity {
        switch errorType {
        case .noFriendCoupleSelected:
            return .info
        case .noMutualAvailabilityFound:
            return .info
        case .calendarPermissionRequired:
            return .warning
        case .searchRangeTooNarrow:
            return .info
        case .internalError:
            return .error
        case .networkError:
            return .warning
        }
    }
    
    public var recoveryActions: [ErrorRecoveryAction] {
        var actions: [ErrorRecoveryAction] = []
        
        switch errorType {
        case .noFriendCoupleSelected:
            actions.append(
                ErrorRecoveryAction(
                    title: "Select Friend Couple",
                    icon: "person.2",
                    isPrimary: true,
                    action: {
                        NotificationManager.shared.showFriendPicker()
                    }
                )
            )
            
        case .noMutualAvailabilityFound:
            actions.append(
                ErrorRecoveryAction(
                    title: "Suggest Alternative Times",
                    icon: "calendar.badge.plus",
                    isPrimary: true,
                    action: {}  // To be filled by client
                )
            )
            
            actions.append(
                ErrorRecoveryAction(
                    title: "Adjust Date Range",
                    icon: "calendar",
                    action: {
                        NotificationManager.shared.showDateRangePicker()
                    }
                )
            )
            
            actions.append(
                ErrorRecoveryAction(
                    title: "Adjust Duration",
                    icon: "clock",
                    action: {
                        NotificationManager.shared.showDurationPicker()
                    }
                )
            )
            
        case .calendarPermissionRequired:
            actions.append(
                ErrorRecoveryAction(
                    title: "Open Settings",
                    icon: "gear",
                    isPrimary: true,
                    action: {
                        PlatformUtilities.openSettings()
                    }
                )
            )
            
            actions.append(
                ErrorRecoveryAction(
                    title: "Use Manual Availability",
                    icon: "hand.raised",
                    action: {}  // To be filled by client
                )
            )
            
        case .searchRangeTooNarrow:
            actions.append(
                ErrorRecoveryAction(
                    title: "Adjust Date Range",
                    icon: "calendar",
                    isPrimary: true,
                    action: {
                        NotificationManager.shared.showDateRangePicker()
                    }
                )
            )
            
            actions.append(
                ErrorRecoveryAction(
                    title: "Adjust Duration",
                    icon: "clock",
                    action: {
                        NotificationManager.shared.showDurationPicker()
                    }
                )
            )
            
        case .internalError:
            actions.append(
                ErrorRecoveryAction(
                    title: "Try Again",
                    icon: "arrow.clockwise",
                    isPrimary: true,
                    action: {}  // To be filled by client
                )
            )
            
        case .networkError:
            actions.append(
                ErrorRecoveryAction(
                    title: "Retry Connection",
                    icon: "network",
                    isPrimary: true,
                    action: {}  // To be filled by client
                )
            )
        }
        
        return actions
    }
}

/// Extension to integrate with legacy MutualAvailabilityViewModel
extension MutualAvailabilityViewModel {
    /// Handle errors using the new centralized error handling system
    func handleErrorWithCentralizedSystem(_ error: Error) {
        // Map service errors to our domain-specific error type
        if let availabilityError = error as? AvailabilityServiceError {
            switch availabilityError {
            case .invalidTimeRange, .invalidDuration:
                let appError = AvailabilityError(errorType: .searchRangeTooNarrow, underlyingError: error)
                ErrorHandler.shared.showError(appError)
                
            case .calendarSyncFailed:
                let appError = AvailabilityError(errorType: .calendarPermissionRequired, underlyingError: error)
                ErrorHandler.shared.showError(appError)
                
            case .relationshipNotFound:
                let appError = AvailabilityError(errorType: .internalError("Relationship not found"), underlyingError: error)
                ErrorHandler.shared.showError(appError)
                
            case .preferenceConflict, .unavailableTimePeriod:
                let appError = AvailabilityError(errorType: .noMutualAvailabilityFound, underlyingError: error)
                ErrorHandler.shared.showError(appError)
                
            case .networkTimeout:
                let appError = AvailabilityError(errorType: .networkError, underlyingError: error)
                ErrorHandler.shared.showError(appError)
                
            default:
                let appError = AvailabilityError(errorType: .internalError(availabilityError.localizedDescription), underlyingError: error)
                ErrorHandler.shared.showError(appError)
            }
        } 
        // Handle existing MutualAvailabilityError
        else if let mutualError = error as? MutualAvailabilityError {
            let appError = AvailabilityError(legacyError: mutualError)
            ErrorHandler.shared.showError(appError)
        }
        // Handle unrecognized errors
        else {
            ErrorHandler.shared.handle(error)
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