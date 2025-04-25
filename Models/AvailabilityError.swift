import Foundation
import SwiftUI

/// Errors related to availability functionality
public enum AvailabilityErrorType {
    case noFriendCoupleSelected
    case noMutualAvailabilityFound
    case calendarPermissionRequired
    case searchRangeTooNarrow
    case invalidTimeRange
    case invalidDuration
    case calendarSyncFailed(String)
    case relationshipNotFound
    case preferenceConflict
    case unavailableTimePeriod
    case concurrentUpdateConflict
    case excessiveRecurringCommitments
    case incompatibleCalendarSettings
    case networkTimeout
    case permissionDenied
    case internalError(String)
    case networkError
}

/// Error type for availability features that integrates with the central error handling system
public struct AvailabilityError: Error, LocalizedError, AppError {
    public let errorType: AvailabilityErrorType
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
        case .searchRangeTooNarrow, .invalidTimeRange, .invalidDuration:
            return "Invalid Time Selection"
        case .calendarSyncFailed:
            return "Calendar Sync Failed"
        case .relationshipNotFound:
            return "Relationship Not Found"
        case .preferenceConflict:
            return "Preference Conflict"
        case .unavailableTimePeriod:
            return "No Available Time"
        case .concurrentUpdateConflict:
            return "Update Conflict"
        case .excessiveRecurringCommitments:
            return "Too Many Commitments"
        case .incompatibleCalendarSettings:
            return "Calendar Settings Incompatible"
        case .networkTimeout, .networkError:
            return "Network Error"
        case .permissionDenied:
            return "Permission Denied"
        case .internalError:
            return "Error"
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
        case .invalidTimeRange:
            return "The specified time range is invalid. End time must be after start time."
        case .invalidDuration:
            return "Invalid duration specified. Duration must be between 15 minutes and 12 hours."
        case .calendarSyncFailed(let details):
            return "Failed to sync with calendar: \(details)"
        case .relationshipNotFound:
            return "The specified relationship could not be found."
        case .preferenceConflict:
            return "Conflict detected between partner preferences. Please coordinate settings with your partner."
        case .unavailableTimePeriod:
            return "The requested time period has no available slots based on your preferences."
        case .concurrentUpdateConflict:
            return "Another user updated these preferences. Please refresh and try again."
        case .excessiveRecurringCommitments:
            return "Too many recurring commitments may be limiting available time slots."
        case .incompatibleCalendarSettings:
            return "Calendar integration settings are incompatible between partners."
        case .networkTimeout:
            return "Request timed out. Please check your network connection and try again."
        case .permissionDenied:
            return "You don't have permission to modify these availability settings."
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
        case .invalidTimeRange:
            return "Please ensure the end time is after the start time."
        case .invalidDuration:
            return "Choose a duration between 15 minutes and 12 hours."
        case .calendarSyncFailed:
            return "Check your calendar permissions or try manually setting availability."
        case .relationshipNotFound:
            return "Return to the relationships screen and try again."
        case .preferenceConflict:
            return "Discuss and align on availability preferences with your partner."
        case .unavailableTimePeriod:
            return "Try extending the date range or adjusting your weekly availability settings."
        case .concurrentUpdateConflict:
            return "Refresh the page to see the latest changes, then try again."
        case .excessiveRecurringCommitments:
            return "Consider reviewing and removing some recurring commitments to open more time slots."
        case .incompatibleCalendarSettings:
            return "Both partners should check calendar integration settings and ensure they're properly configured."
        case .networkTimeout, .networkError:
            return "Check your internet connection and try again. If the problem persists, try again later."
        case .permissionDenied:
            return "This action requires both partners to agree on changes to settings."
        case .internalError:
            return "Try again later or contact support if the issue persists."
        }
    }
    
    public var severity: ErrorSeverity {
        switch errorType {
        case .noFriendCoupleSelected, .noMutualAvailabilityFound, .searchRangeTooNarrow, 
             .invalidTimeRange, .invalidDuration, .unavailableTimePeriod, .excessiveRecurringCommitments:
            return .info
        case .calendarPermissionRequired, .calendarSyncFailed, .preferenceConflict, 
             .concurrentUpdateConflict, .incompatibleCalendarSettings, .networkTimeout, 
             .networkError, .permissionDenied:
            return .warning
        case .relationshipNotFound, .internalError:
            return .error
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
            
        case .noMutualAvailabilityFound, .unavailableTimePeriod:
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
            
        case .calendarPermissionRequired, .calendarSyncFailed:
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
            
        case .searchRangeTooNarrow, .invalidTimeRange, .invalidDuration:
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
            
        case .preferenceConflict, .incompatibleCalendarSettings:
            actions.append(
                ErrorRecoveryAction(
                    title: "View Availability Settings",
                    icon: "gear",
                    isPrimary: true,
                    action: {}  // To be filled by client
                )
            )
            
        case .concurrentUpdateConflict:
            actions.append(
                ErrorRecoveryAction(
                    title: "Refresh",
                    icon: "arrow.clockwise",
                    isPrimary: true,
                    action: {}  // To be filled by client
                )
            )
            
        case .excessiveRecurringCommitments:
            actions.append(
                ErrorRecoveryAction(
                    title: "View Commitments",
                    icon: "list.bullet",
                    isPrimary: true,
                    action: {}  // To be filled by client
                )
            )
            
        case .networkTimeout, .networkError:
            actions.append(
                ErrorRecoveryAction(
                    title: "Retry Connection",
                    icon: "network",
                    isPrimary: true,
                    action: {}  // To be filled by client
                )
            )
            
        default:
            actions.append(
                ErrorRecoveryAction(
                    title: "Try Again",
                    icon: "arrow.clockwise",
                    isPrimary: true,
                    action: {}  // To be filled by client
                )
            )
        }
        
        return actions
    }
}

/// Service-layer error types for availability functionality
public enum AvailabilityServiceError: Error {
    case invalidTimeRange
    case invalidDuration
    case calendarSyncFailed(String)
    case relationshipNotFound
    case preferenceConflict
    case unavailableTimePeriod
    case concurrentUpdateConflict
    case networkTimeout
    case permissionDenied
    case unknown(Error)
    
    public init(from error: Error) {
        if let serviceError = error as? AvailabilityServiceError {
            self = serviceError
        } else {
            self = .unknown(error)
        }
    }
} 