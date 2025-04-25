import Foundation

/// Service for tracking analytics events and user behavior
public protocol AnalyticsService {
    /// Track a simple event
    /// - Parameters:
    ///   - eventName: Name of the event to track
    ///   - parameters: Optional parameters describing the event
    func trackEvent(name eventName: String, parameters: [String: Any]?) async
    
    /// Track a screen view
    /// - Parameters:
    ///   - screenName: Name of the screen viewed
    ///   - screenClass: Optional class name of the screen
    func trackScreenView(screenName: String, screenClass: String?) async
    
    /// Track user engagement time
    /// - Parameters:
    ///   - screenName: Name of the screen
    ///   - timeInSeconds: Time spent on the screen in seconds
    func trackEngagementTime(screenName: String, timeInSeconds: TimeInterval) async
    
    /// Set user properties for segmentation
    /// - Parameter properties: Dictionary of user properties to set
    func setUserProperties(_ properties: [String: Any]) async
    
    /// Track application open
    /// - Parameter source: Optional source that opened the app (e.g., notification, deeplink)
    func trackAppOpen(source: String?) async
    
    /// Track application background
    func trackAppBackground() async
    
    /// Track user action in a feature
    /// - Parameters:
    ///   - action: The action performed
    ///   - feature: The feature where the action was performed
    ///   - parameters: Optional additional parameters
    func trackUserAction(action: String, feature: String, parameters: [String: Any]?) async
    
    /// Track error event
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - context: Context where the error occurred
    ///   - fatal: Whether the error was fatal
    func trackError(error: Error, context: String, fatal: Bool) async
    
    /// Track feature usage
    /// - Parameters:
    ///   - featureName: Name of the feature used
    ///   - parameters: Optional parameters about feature usage
    func trackFeatureUsage(featureName: String, parameters: [String: Any]?) async
    
    /// Track hangout related events
    /// - Parameters:
    ///   - eventType: Type of hangout event (create, accept, cancel, etc.)
    ///   - hangoutId: ID of the hangout
    ///   - parameters: Optional additional parameters
    func trackHangoutEvent(eventType: String, hangoutId: String, parameters: [String: Any]?) async
    
    /// Track relationship events
    /// - Parameters:
    ///   - eventType: Type of relationship event
    ///   - relationshipId: ID of the relationship
    ///   - parameters: Optional additional parameters
    func trackRelationshipEvent(eventType: String, relationshipId: String, parameters: [String: Any]?) async
    
    /// Track calendar integration events
    /// - Parameters:
    ///   - eventType: Type of calendar event
    ///   - calendarProvider: The calendar provider (Google, Apple, etc.)
    ///   - parameters: Optional additional parameters
    func trackCalendarEvent(eventType: String, calendarProvider: String, parameters: [String: Any]?) async
    
    /// Reset user analytics data (e.g., on logout)
    func resetUserData() async
    
    /// Enable or disable analytics collection
    /// - Parameter enabled: Whether analytics collection should be enabled
    func setAnalyticsCollectionEnabled(_ enabled: Bool) async
}

/// Standard analytics event types for consistent tracking
public enum AnalyticsEventType {
    // App lifecycle events
    case appOpen
    case appBackground
    case appForeground
    case appCrash
    
    // Session events
    case sessionStart
    case sessionEnd
    
    // User account events
    case signUp
    case login
    case logout
    case profileUpdate
    case accountDeletion
    
    // Feature usage events
    case featureView
    case featureEngagement
    
    // Social events
    case hangoutCreated
    case hangoutAccepted
    case hangoutDeclined
    case hangoutCancelled
    case hangoutCompleted
    case relationshipCreated
    case relationshipAccepted
    case relationshipEnded
    
    // Calendar events
    case calendarConnected
    case calendarDisconnected
    case availabilityUpdated
    
    // Custom event (with string value)
    case custom(String)
    
    public var name: String {
        switch self {
        case .appOpen: return "app_open"
        case .appBackground: return "app_background"
        case .appForeground: return "app_foreground"
        case .appCrash: return "app_crash"
        case .sessionStart: return "session_start"
        case .sessionEnd: return "session_end"
        case .signUp: return "sign_up"
        case .login: return "login"
        case .logout: return "logout"
        case .profileUpdate: return "profile_update"
        case .accountDeletion: return "account_deletion"
        case .featureView: return "feature_view"
        case .featureEngagement: return "feature_engagement"
        case .hangoutCreated: return "hangout_created"
        case .hangoutAccepted: return "hangout_accepted"
        case .hangoutDeclined: return "hangout_declined"
        case .hangoutCancelled: return "hangout_cancelled"
        case .hangoutCompleted: return "hangout_completed"
        case .relationshipCreated: return "relationship_created"
        case .relationshipAccepted: return "relationship_accepted"
        case .relationshipEnded: return "relationship_ended"
        case .calendarConnected: return "calendar_connected"
        case .calendarDisconnected: return "calendar_disconnected"
        case .availabilityUpdated: return "availability_updated"
        case .custom(let name): return name
        }
    }
} 