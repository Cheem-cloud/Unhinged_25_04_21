import Foundation
import SwiftUI
import Combine

/// A protocol for defining app-specific errors with consistent presentation
public protocol AppError: LocalizedError {
    /// The error title for display
    var errorTitle: String { get }
    
    /// The error code for tracking and debugging
    var errorCode: String { get }
    
    /// The severity level of the error
    var severity: ErrorSeverity { get }
    
    /// Actions that can help recover from this error
    var recoveryActions: [ErrorRecoveryAction] { get }
    
    /// The domain this error belongs to (e.g., "Network", "Calendar", "Auth")
    var domain: String { get }
    
    /// Whether this error should be logged to analytics
    var shouldLog: Bool { get }
}

/// Default implementations for AppError
public extension AppError {
    /// Default error title derived from localized description
    var errorTitle: String {
        return "Error" // Subclasses should override this
    }
    
    /// Default severity is warning
    var severity: ErrorSeverity {
        return .warning
    }
    
    /// Default is to log all errors
    var shouldLog: Bool {
        return true
    }
    
    /// Default is no recovery actions
    var recoveryActions: [ErrorRecoveryAction] {
        return []
    }
    
    /// Default code format: {domain}-{000}
    var errorCode: String {
        return "\(domain)-\(String(describing: self).hashValue % 1000)"
    }
}

/// The severity level of an error
public enum ErrorSeverity {
    /// Informational - not a true error
    case info
    
    /// Warning - requires attention but not critical
    case warning
    
    /// Error - requires user action
    case error
    
    /// Critical - may prevent app functionality
    case critical
    
    /// Color that represents this severity level
    public var color: Color {
        switch self {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        }
    }
    
    /// Icon that represents this severity level
    public var icon: String {
        switch self {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "exclamationmark.circle"
        case .critical:
            return "xmark.octagon"
        }
    }
}

/// Represents an action that can help recover from an error
public struct ErrorRecoveryAction {
    /// Title of the action
    public let title: String
    
    /// Icon for the action
    public let icon: String
    
    /// Whether this is the primary action
    public let isPrimary: Bool
    
    /// The action to perform
    public let action: () -> Void
    
    /// Creates a new recovery action
    /// - Parameters:
    ///   - title: The title of the action
    ///   - icon: The icon for the action
    ///   - isPrimary: Whether this is the primary action
    ///   - action: The action to perform
    public init(title: String, icon: String, isPrimary: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isPrimary = isPrimary
        self.action = action
    }
}

/// A centralized error handler that manages errors and provides UI representation
public class ErrorHandler: ObservableObject {
    /// Shared instance of the error handler
    public static let shared = ErrorHandler()
    
    /// The current error
    @Published public private(set) var currentError: (any AppError)?
    
    /// Whether an error is currently being presented
    @Published public private(set) var isShowingError = false
    
    /// Error publisher for reactive error handling
    public var errorPublisher: AnyPublisher<(any AppError)?, Never> {
        $currentError.eraseToAnyPublisher()
    }
    
    /// Error display state publisher
    public var isShowingErrorPublisher: AnyPublisher<Bool, Never> {
        $isShowingError.eraseToAnyPublisher()
    }
    
    private init() {}
    
    /// Handle an error by determining its type and appropriate presentation
    /// - Parameter error: The error to handle
    public func handle(_ error: Error) {
        // If already an AppError, use it directly
        if let appError = error as? any AppError {
            self.showError(appError)
            return
        }
        
        // Map known error types to AppError
        // Order matters - check most specific types first
        let mappedError: any AppError
        
        switch error {
        case let urlError as URLError:
            mappedError = NetworkError(urlError: urlError)
        case let decodingError as DecodingError:
            mappedError = DataError(decodingError: decodingError)
        case let firestoreError as FirestoreError:
            mappedError = DatabaseError(firestoreError: firestoreError)
        case let nsError as NSError:
            // Handle NSError with specific domains
            if nsError.domain == NSURLErrorDomain {
                mappedError = NetworkError(nsError: nsError)
            } else if nsError.domain == "EKErrorDomain" {
                mappedError = CalendarError(nsError: nsError)
            } else {
                mappedError = GeneralError(error: error)
            }
        default:
            mappedError = GeneralError(error: error)
        }
        
        showError(mappedError)
    }
    
    /// Present an error to the user
    /// - Parameter error: The AppError to show
    public func showError(_ error: any AppError) {
        DispatchQueue.main.async {
            self.currentError = error
            self.isShowingError = true
            
            if error.shouldLog {
                self.logError(error)
            }
        }
    }
    
    /// Dismiss the current error
    public func dismissError() {
        DispatchQueue.main.async {
            self.isShowingError = false
            
            // Wait for animation to complete before clearing the error
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.currentError = nil
            }
        }
    }
    
    /// Log an error to analytics or console
    private func logError(_ error: any AppError) {
        // In a real app, this would log to your analytics service
        print("ERROR [\(error.domain)]: \(error.errorCode) - \(error.localizedDescription)")
    }
}

// MARK: - Domain-Specific Error Types

/// Network related errors
public struct NetworkError: AppError {
    private let underlyingError: Error
    private let statusCode: Int?
    
    public init(urlError: URLError) {
        self.underlyingError = urlError
        self.statusCode = nil
    }
    
    public init(nsError: NSError) {
        self.underlyingError = nsError
        self.statusCode = nil
    }
    
    public init(statusCode: Int, error: Error? = nil) {
        self.statusCode = statusCode
        self.underlyingError = error ?? NSError(domain: "NetworkError", code: statusCode, userInfo: nil)
    }
    
    public var domain: String {
        return "Network"
    }
    
    public var errorDescription: String? {
        if let statusCode = statusCode {
            switch statusCode {
            case 401:
                return "Authentication required. Please log in again."
            case 403:
                return "You don't have permission to access this resource."
            case 404:
                return "The requested resource could not be found."
            case 500..<600:
                return "A server error occurred. Please try again later."
            default:
                return "Network error: \(statusCode)"
            }
        } else if let urlError = underlyingError as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection. Please check your connection and try again."
            case .timedOut:
                return "The network request timed out. Please try again."
            case .cancelled:
                return "The network request was cancelled."
            default:
                return "Network error: \(urlError.localizedDescription)"
            }
        } else {
            return "Network error: \(underlyingError.localizedDescription)"
        }
    }
    
    public var errorTitle: String {
        return "Network Error"
    }
    
    public var recoveryActions: [ErrorRecoveryAction] {
        var actions: [ErrorRecoveryAction] = []
        
        actions.append(
            ErrorRecoveryAction(
                title: "Try Again",
                icon: "arrow.clockwise",
                isPrimary: true,
                action: {}  // This would be filled in by the caller
            )
        )
        
        if let urlError = underlyingError as? URLError, 
           urlError.code == .notConnectedToInternet {
            actions.append(
                ErrorRecoveryAction(
                    title: "Open Settings",
                    icon: "gear",
                    action: {
                        PlatformUtilities.openSettings()
                    }
                )
            )
        }
        
        return actions
    }
    
    public var recoverySuggestion: String? {
        if let statusCode = statusCode, statusCode >= 500 {
            return "The server is experiencing issues. Try again later or contact support if the problem persists."
        } else if let urlError = underlyingError as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "Check your Wi-Fi or cellular connection and try again."
            case .timedOut:
                return "The server took too long to respond. Try again later."
            default:
                return "Check your connection and try again."
            }
        }
        return "Please check your internet connection and try again."
    }
}

/// Data processing and parsing errors
public struct DataError: AppError {
    private let underlyingError: Error
    
    public init(decodingError: DecodingError) {
        self.underlyingError = decodingError
    }
    
    public init(error: Error) {
        self.underlyingError = error
    }
    
    public var domain: String {
        return "Data"
    }
    
    public var errorDescription: String? {
        if let decodingError = underlyingError as? DecodingError {
            switch decodingError {
            case .typeMismatch:
                return "Data received from the server was in an unexpected format."
            case .valueNotFound:
                return "Required data was missing from the server response."
            case .keyNotFound:
                return "Required field was missing from the server response."
            case .dataCorrupted:
                return "The data received from the server was corrupted."
            @unknown default:
                return "Error processing data: \(decodingError.localizedDescription)"
            }
        }
        return "Error processing data: \(underlyingError.localizedDescription)"
    }
    
    public var errorTitle: String {
        return "Data Processing Error"
    }
    
    public var recoveryActions: [ErrorRecoveryAction] {
        let actions: [ErrorRecoveryAction] = [
            ErrorRecoveryAction(
                title: "Try Again",
                icon: "arrow.clockwise",
                isPrimary: true,
                action: {}  // This would be filled in by the caller
            ),
            ErrorRecoveryAction(
                title: "Contact Support",
                icon: "envelope",
                action: {}  // This would be filled in by the caller
            )
        ]
        return actions
    }
    
    public var recoverySuggestion: String? {
        return "Try again or update the app to the latest version. If the problem persists, please contact support."
    }
}

/// Database-related errors
public struct DatabaseError: AppError {
    private let underlyingError: Error
    
    public init(firestoreError: FirestoreError) {
        self.underlyingError = firestoreError
    }
    
    public init(error: Error) {
        self.underlyingError = error
    }
    
    public var domain: String {
        return "Database"
    }
    
    public var errorDescription: String? {
        if let firestoreError = underlyingError as? FirestoreError {
            switch firestoreError {
            case .documentNotFound:
                return "The requested data could not be found."
            case .permissionDenied:
                return "You don't have permission to access this data."
            case .unavailable:
                return "The database is currently unavailable."
            case .dataLost:
                return "Some data was lost or corrupted."
            default:
                return "Database error: \(firestoreError.localizedDescription)"
            }
        }
        return "Database error: \(underlyingError.localizedDescription)"
    }
    
    public var errorTitle: String {
        return "Database Error"
    }
    
    public var recoveryActions: [ErrorRecoveryAction] {
        let actions: [ErrorRecoveryAction] = [
            ErrorRecoveryAction(
                title: "Try Again",
                icon: "arrow.clockwise",
                isPrimary: true,
                action: {}  // This would be filled in by the caller
            )
        ]
        return actions
    }
    
    public var recoverySuggestion: String? {
        return "Try again later. If the problem persists, please contact support."
    }
}

/// Calendar-related errors
public struct CalendarError: AppError {
    private let underlyingError: Error
    private let errorType: CalendarErrorType
    
    public enum CalendarErrorType {
        case permissionDenied
        case eventNotFound
        case eventCreationFailed
        case eventUpdateFailed
        case eventDeletionFailed
        case syncFailed
        case other
    }
    
    public init(nsError: NSError) {
        self.underlyingError = nsError
        
        // Map EventKit error codes to our types
        switch nsError.code {
        case 1:  // EKErrorEventNotMutable
            self.errorType = .eventUpdateFailed
        case 2:  // EKErrorNoCalendar
            self.errorType = .permissionDenied
        case 3:  // EKErrorNoStartDate
            self.errorType = .eventCreationFailed
        case 4:  // EKErrorNoEndDate
            self.errorType = .eventCreationFailed
        case 5:  // EKErrorDatesTooFar
            self.errorType = .eventCreationFailed
        case 6:  // EKErrorInternalFailure
            self.errorType = .other
        case 7:  // EKErrorCalendarReadOnly
            self.errorType = .permissionDenied
        case 8:  // EKErrorDurationGreaterThanRecurrence
            self.errorType = .eventCreationFailed
        case 9:  // EKErrorAlarmGreaterThanRecurrence
            self.errorType = .eventCreationFailed
        case 10: // EKErrorStartDateTooFarInFuture
            self.errorType = .eventCreationFailed
        case 11: // EKErrorStartDateCollidesWithOtherOccurrence
            self.errorType = .eventCreationFailed
        case 12: // EKErrorObjectBelongsToDifferentStore
            self.errorType = .other
        case 13: // EKErrorInvitesCannotBeMoved
            self.errorType = .eventUpdateFailed
        case 14: // EKErrorInvalidSpan
            self.errorType = .eventCreationFailed
        case 15: // EKErrorCalendarHasNoSource
            self.errorType = .other
        case 16: // EKErrorCalendarSourceCannotBeModified
            self.errorType = .permissionDenied
        case 17: // EKErrorCalendarIsImmutable
            self.errorType = .permissionDenied
        case 18: // EKErrorSourceDoesNotAllowCalendarAddDelete
            self.errorType = .permissionDenied
        case 19: // EKErrorRecurringReminderRequiresDueDate
            self.errorType = .eventCreationFailed
        case 20: // EKErrorStructuredLocationsNotSupported
            self.errorType = .eventCreationFailed
        case 21: // EKErrorReminderLocationsNotSupported
            self.errorType = .eventCreationFailed
        case 22: // EKErrorAlarmProximityNotSupported
            self.errorType = .eventCreationFailed
        case 23: // EKErrorCalendarDoesNotAllowEvents
            self.errorType = .eventCreationFailed
        case 24: // EKErrorCalendarDoesNotAllowReminders
            self.errorType = .eventCreationFailed
        case 25: // EKErrorSourceDoesNotAllowReminders
            self.errorType = .eventCreationFailed
        case 26: // EKErrorSourceDoesNotAllowEvents
            self.errorType = .eventCreationFailed
        case 27: // EKErrorPriorityIsInvalid
            self.errorType = .eventCreationFailed
        case 28: // EKErrorInvalidEntityType
            self.errorType = .other
        case 29: // EKErrorProcedureAlarmsNotMutable
            self.errorType = .eventUpdateFailed
        case 30: // EKErrorEventStoreNotAuthorized
            self.errorType = .permissionDenied
        case 31: // EKErrorNoEndDate
            self.errorType = .eventCreationFailed
        case 32: // EKErrorRecurringOccurrenceCannotBeJoinedWithOtherOccurrences
            self.errorType = .eventUpdateFailed
        case 33: // EKErrorOccurrencesCannotBeJoinedWithOtherOccurrences
            self.errorType = .eventUpdateFailed
        case 34: // EKErrorInviteeInOtherMode
            self.errorType = .eventCreationFailed
        case 35: // EKErrorUnsupportedMethod
            self.errorType = .other
        case 36: // EKErrorObjectPathDoesNotExist
            self.errorType = .eventNotFound
        case 37: // EKErrorLastModifierIsNotActionableInActionEngine
            self.errorType = .other
        case 38: // EKErrorGrantedAuthorizedWriteAccess
            self.errorType = .permissionDenied
        case 39: // EKErrorAccountNotConsideredForSharedCalendars
            self.errorType = .permissionDenied
        case 100...199:
            self.errorType = .syncFailed
        default:
            self.errorType = .other
        }
    }
    
    public init(errorType: CalendarErrorType, error: Error? = nil) {
        self.errorType = errorType
        self.underlyingError = error ?? NSError(domain: "CalendarError", code: 0, userInfo: nil)
    }
    
    public var domain: String {
        return "Calendar"
    }
    
    public var errorDescription: String? {
        switch errorType {
        case .permissionDenied:
            return "Calendar access is required. Please grant permission in Settings."
        case .eventNotFound:
            return "The calendar event could not be found."
        case .eventCreationFailed:
            return "Failed to create the calendar event."
        case .eventUpdateFailed:
            return "Failed to update the calendar event."
        case .eventDeletionFailed:
            return "Failed to delete the calendar event."
        case .syncFailed:
            return "Failed to sync with your calendar."
        case .other:
            return "Calendar error: \(underlyingError.localizedDescription)"
        }
    }
    
    public var errorTitle: String {
        return "Calendar Error"
    }
    
    public var severity: ErrorSeverity {
        switch errorType {
        case .permissionDenied:
            return .warning
        case .syncFailed:
            return .warning
        default:
            return .error
        }
    }
    
    public var recoveryActions: [ErrorRecoveryAction] {
        var actions: [ErrorRecoveryAction] = []
        
        switch errorType {
        case .permissionDenied:
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
                    action: {}  // This would be filled in by the caller
                )
            )
            
        case .syncFailed:
            actions.append(
                ErrorRecoveryAction(
                    title: "Try Again",
                    icon: "arrow.clockwise",
                    isPrimary: true,
                    action: {}  // This would be filled in by the caller
                )
            )
            
            actions.append(
                ErrorRecoveryAction(
                    title: "Use Manual Availability",
                    icon: "hand.raised",
                    action: {}  // This would be filled in by the caller
                )
            )
            
        default:
            actions.append(
                ErrorRecoveryAction(
                    title: "Try Again",
                    icon: "arrow.clockwise",
                    isPrimary: true,
                    action: {}  // This would be filled in by the caller
                )
            )
        }
        
        return actions
    }
    
    public var recoverySuggestion: String? {
        switch errorType {
        case .permissionDenied:
            return "You can grant calendar access in Settings or use manual availability instead."
        case .syncFailed:
            return "Please check your internet connection and try again."
        case .eventCreationFailed, .eventUpdateFailed, .eventDeletionFailed:
            return "Check that your calendar is accessible and try again."
        default:
            return "Try again or use manual availability."
        }
    }
}

/// General error for cases not covered by specific domains
public struct GeneralError: AppError {
    private let underlyingError: Error
    
    public init(error: Error) {
        self.underlyingError = error
    }
    
    public var domain: String {
        return "General"
    }
    
    public var errorDescription: String? {
        return underlyingError.localizedDescription
    }
    
    public var errorTitle: String {
        return "Error"
    }
    
    public var recoveryActions: [ErrorRecoveryAction] {
        let actions: [ErrorRecoveryAction] = [
            ErrorRecoveryAction(
                title: "OK",
                icon: "checkmark",
                isPrimary: true,
                action: {}  // This would be filled in by the caller
            )
        ]
        return actions
    }
    
    public var recoverySuggestion: String? {
        return "Please try again. If the problem persists, contact support."
    }
}

// MARK: - Firebase-specific Error Types

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
}

// MARK: - Error View Modifiers

/// A view modifier that displays an error alert
public struct ErrorAlertModifier: ViewModifier {
    @StateObject private var errorHandler = ErrorHandler.shared
    @Binding var isPresented: Bool
    private let action: ((any AppError) -> Void)?
    
    public init(isPresented: Binding<Bool>, action: ((any AppError) -> Void)? = nil) {
        self._isPresented = isPresented
        self.action = action
    }
    
    public func body(content: Content) -> some View {
        content
            .alert(
                errorHandler.currentError?.errorTitle ?? "Error",
                isPresented: $isPresented,
                presenting: errorHandler.currentError
            ) { error in
                if let recoveryActions = error.recoveryActions, !recoveryActions.isEmpty {
                    ForEach(0..<recoveryActions.count, id: \.self) { index in
                        let recoveryAction = recoveryActions[index]
                        Button(recoveryAction.title) {
                            recoveryAction.action()
                            if let action = action {
                                action(error)
                            }
                        }
                        .bold(recoveryAction.isPrimary)
                    }
                } else {
                    Button("OK") {
                        if let action = action {
                            action(error)
                        }
                    }
                }
            } message: { error in
                Text(error.localizedDescription)
                if let recoverySuggestion = error.recoverySuggestion {
                    Text("\n\n\(recoverySuggestion)")
                }
            }
            .onReceive(errorHandler.isShowingErrorPublisher) { isShowingError in
                isPresented = isShowingError
            }
    }
}

extension View {
    /// Adds an error alert to a view
    /// - Parameters:
    ///   - isPresented: Binding to whether the alert is presented
    ///   - action: Optional action to perform when an error is presented
    /// - Returns: A view with an error alert
    public func errorAlert(isPresented: Binding<Bool>, action: ((any AppError) -> Void)? = nil) -> some View {
        self.modifier(ErrorAlertModifier(isPresented: isPresented, action: action))
    }
} 