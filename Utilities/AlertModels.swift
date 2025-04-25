import SwiftUI

/// The canonical AlertItem struct used throughout the app
public struct AlertItem: Identifiable {
    public var id = UUID()
    public var title: String
    public var message: String
    public var dismissButton: String
    public var action: (() -> Void)?
    
    public init(title: String, message: String, dismissButton: String = "OK", action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.dismissButton = dismissButton
        self.action = action
    }
}

// MARK: - Helper Extensions

/// Extension for SwiftUI Alert compatibility
public extension AlertItem {
    // Create Alert from AlertItem
    func asAlert() -> Alert {
        if let action = self.action {
            return Alert(
                title: Text(title),
                message: Text(message),
                dismissButton: .default(Text(dismissButton), action: action)
            )
        } else {
            return Alert(
                title: Text(title),
                message: Text(message),
                dismissButton: .default(Text(dismissButton))
            )
        }
    }
}

// MARK: - Common Alerts

/// Common alerts used throughout the app
public enum CommonAlerts {
    // Network error alert
    public static func networkError() -> AlertItem {
        return AlertItem(
            title: "Network Error",
            message: "There was a problem connecting to the server. Please check your internet connection and try again."
        )
    }
    
    // Permission error alert
    public static func permissionError() -> AlertItem {
        return AlertItem(
            title: "Permission Denied",
            message: "You don't have permission to perform this action."
        )
    }
    
    // Unknown error alert
    public static func unknownError() -> AlertItem {
        return AlertItem(
            title: "Something Went Wrong",
            message: "An unexpected error occurred. Please try again later."
        )
    }
    
    // Custom error alert
    public static func customError(title: String, message: String, action: (() -> Void)? = nil) -> AlertItem {
        return AlertItem(
            title: title,
            message: message,
            dismissButton: "OK",
            action: action
        )
    }
    
    // Confirmation alert
    public static func confirmation(title: String, message: String, confirmText: String = "Confirm", action: @escaping () -> Void) -> AlertItem {
        return AlertItem(
            title: title,
            message: message,
            dismissButton: confirmText,
            action: action
        )
    }
} 