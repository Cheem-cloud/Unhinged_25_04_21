import SwiftUI

/// A common structure for handling alert presentation across the app
struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let dismissButton: Alert.Button
    
    // Convenience initializer with default OK button
    init(title: String, message: String, dismissButton: Alert.Button = .default(Text("OK"))) {
        self.title = title
        self.message = message
        self.dismissButton = dismissButton
    }
}

// Common alert creation extensions
extension AlertItem {
    // Create error alert
    static func error(title: String = "Error", message: String) -> AlertItem {
        AlertItem(
            title: title,
            message: message,
            dismissButton: .default(Text("OK"))
        )
    }
    
    // Create success alert
    static func success(title: String = "Success", message: String) -> AlertItem {
        AlertItem(
            title: title,
            message: message,
            dismissButton: .default(Text("OK"))
        )
    }
    
    // Create confirmation alert with custom action
    static func confirmation(
        title: String,
        message: String,
        confirmText: String = "Confirm",
        cancelText: String = "Cancel",
        action: @escaping () -> Void
    ) -> AlertItem {
        AlertItem(
            title: title,
            message: message,
            dismissButton: .default(Text(confirmText), action: action)
        )
    }
} 