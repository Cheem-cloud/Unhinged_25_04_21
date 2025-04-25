import SwiftUI
import Combine

/// Central manager for app notifications and UI interactions
public class NotificationManager: ObservableObject {
    /// Shared instance for global access
    public static let shared = NotificationManager()
    
    /// Published notifications for UI
    @Published public var notifications: [AppNotification] = []
    
    /// Published actions for UI presenters
    @Published public var actionRequests: [ActionRequest] = []
    
    /// Published error state
    @Published public var currentError: Error?
    
    /// Private publisher for UI presentation requests
    private let presentationRequestSubject = PassthroughSubject<PresentationType, Never>()
    
    /// Public publisher for UI presentation requests
    public var presentationRequests: AnyPublisher<PresentationType, Never> {
        presentationRequestSubject.eraseToAnyPublisher()
    }
    
    /// Private initializer to enforce singleton
    private init() {}
    
    // MARK: - Notification Management
    
    /// Show a notification to the user
    /// - Parameter notification: The notification to show
    public func showNotification(_ notification: AppNotification) {
        withAnimation {
            notifications.append(notification)
        }
        
        // Auto-dismiss after delay
        if notification.autoDismiss {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.dismissNotification(notification)
            }
        }
    }
    
    /// Dismiss a notification
    /// - Parameter notification: The notification to dismiss
    public func dismissNotification(_ notification: AppNotification) {
        withAnimation {
            notifications.removeAll { $0.id == notification.id }
        }
    }
    
    /// Dismiss all notifications
    public func dismissAllNotifications() {
        withAnimation {
            notifications.removeAll()
        }
    }
    
    // MARK: - Error Handling
    
    /// Show an error to the user
    /// - Parameter error: The error to show
    public func showError(_ error: Error) {
        currentError = error
    }
    
    /// Reset error state
    public func resetError() {
        currentError = nil
    }
    
    // MARK: - UI Presentation
    
    /// Request friend picker presentation
    public func showFriendPicker() {
        presentationRequestSubject.send(.friendPicker)
    }
    
    /// Request date range picker presentation
    public func showDateRangePicker() {
        presentationRequestSubject.send(.dateRangePicker)
    }
    
    /// Request duration picker presentation
    public func showDurationPicker() {
        presentationRequestSubject.send(.durationPicker)
    }
    
    /// Request create hangout form presentation
    public func showCreateHangout() {
        presentationRequestSubject.send(.createHangout)
    }
    
    /// Request a specific presentation type
    /// - Parameter type: The type of presentation to request
    public func requestPresentation(_ type: PresentationType) {
        presentationRequestSubject.send(type)
    }
    
    /// Request an action from the user
    /// - Parameter request: The action request
    public func requestAction(_ request: ActionRequest) {
        actionRequests.append(request)
    }
    
    /// Complete an action request
    /// - Parameters:
    ///   - requestId: The ID of the request to complete
    ///   - result: The result of the action
    public func completeActionRequest(id requestId: String, result: Any? = nil) {
        if let index = actionRequests.firstIndex(where: { $0.id == requestId }) {
            let request = actionRequests[index]
            request.completion(result)
            actionRequests.remove(at: index)
        }
    }
}

// MARK: - Supporting Types

/// Types of presentations that can be requested
public enum PresentationType {
    case friendPicker
    case dateRangePicker
    case durationPicker
    case createHangout
    case editHangout(String)
    case calendarSettings
    case personaCreation
    case relationshipSettings
}

/// Model for an app notification
public struct AppNotification: Identifiable {
    /// Unique identifier
    public let id: String
    
    /// Title of the notification
    public let title: String
    
    /// Message body
    public let message: String
    
    /// Type of notification
    public let type: NotificationType
    
    /// Whether to auto-dismiss
    public let autoDismiss: Bool
    
    /// Action when tapped
    public let action: (() -> Void)?
    
    /// Initialize a new notification
    /// - Parameters:
    ///   - id: Unique ID (defaults to UUID)
    ///   - title: Title text
    ///   - message: Message body
    ///   - type: Type of notification
    ///   - autoDismiss: Whether to auto-dismiss
    ///   - action: Optional action on tap
    public init(
        id: String = UUID().uuidString,
        title: String,
        message: String,
        type: NotificationType = .info,
        autoDismiss: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.type = type
        self.autoDismiss = autoDismiss
        self.action = action
    }
    
    /// Type of notification
    public enum NotificationType {
        case info
        case success
        case warning
        case error
    }
}

/// Model for an action request
public class ActionRequest: Identifiable {
    /// Unique identifier
    public let id: String
    
    /// Title of the request
    public let title: String
    
    /// Description of the request
    public let description: String
    
    /// Type of action
    public let type: ActionType
    
    /// Completion handler
    public let completion: (Any?) -> Void
    
    /// Initialize a new action request
    /// - Parameters:
    ///   - id: Unique ID (defaults to UUID)
    ///   - title: Title text
    ///   - description: Description text
    ///   - type: Type of action
    ///   - completion: Completion handler
    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        type: ActionType,
        completion: @escaping (Any?) -> Void
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.completion = completion
    }
    
    /// Type of action request
    public enum ActionType {
        case confirmation
        case selection(options: [String])
        case input(placeholder: String, initialValue: String?)
        case dateSelection(range: ClosedRange<Date>?)
    }
} 