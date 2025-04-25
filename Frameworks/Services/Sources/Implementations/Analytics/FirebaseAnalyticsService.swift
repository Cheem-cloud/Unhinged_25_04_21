import Foundation
import Firebase
import FirebaseAnalytics


/// Firebase implementation of the AnalyticsService protocol
public class FirebaseAnalyticsService: AnalyticsService {
    
    public init() {
        print("📊 FirebaseAnalyticsService initialized")
    }
    
    public func trackEvent(name eventName: String, parameters: [String: Any]?) async {
        Analytics.logEvent(eventName, parameters: parameters)
    }
    
    public func trackScreenView(screenName: String, screenClass: String?) async {
        var params: [String: Any] = ["screen_name": screenName]
        if let screenClass = screenClass {
            params["screen_class"] = screenClass
        }
        Analytics.logEvent(AnalyticsEventScreenView, parameters: params)
    }
    
    public func trackEngagementTime(screenName: String, timeInSeconds: TimeInterval) async {
        let params: [String: Any] = [
            "screen_name": screenName,
            "engagement_time_sec": timeInSeconds
        ]
        Analytics.logEvent("screen_engagement", parameters: params)
    }
    
    public func setUserProperties(_ properties: [String: Any]) async {
        for (key, value) in properties {
            if let stringValue = value as? String {
                Analytics.setUserProperty(stringValue, forName: key)
            } else {
                Analytics.setUserProperty(String(describing: value), forName: key)
            }
        }
    }
    
    public func trackAppOpen(source: String?) async {
        var params: [String: Any] = [:]
        if let source = source {
            params["source"] = source
        }
        Analytics.logEvent(AnalyticsEventAppOpen, parameters: params)
    }
    
    public func trackAppBackground() async {
        Analytics.logEvent("app_background", parameters: nil)
    }
    
    public func trackUserAction(action: String, feature: String, parameters: [String: Any]?) async {
        var params: [String: Any] = [
            "action": action,
            "feature": feature
        ]
        
        if let additionalParams = parameters {
            params.merge(additionalParams) { (_, new) in new }
        }
        
        Analytics.logEvent("user_action", parameters: params)
    }
    
    public func trackError(error: Error, context: String, fatal: Bool) async {
        let params: [String: Any] = [
            "error_code": (error as NSError).code,
            "error_domain": (error as NSError).domain,
            "error_description": error.localizedDescription,
            "error_context": context,
            "is_fatal": fatal
        ]
        
        Analytics.logEvent("app_error", parameters: params)
    }
    
    public func trackFeatureUsage(featureName: String, parameters: [String: Any]?) async {
        var params: [String: Any] = ["feature_name": featureName]
        
        if let additionalParams = parameters {
            params.merge(additionalParams) { (_, new) in new }
        }
        
        Analytics.logEvent("feature_usage", parameters: params)
    }
    
    public func trackHangoutEvent(eventType: String, hangoutId: String, parameters: [String: Any]?) async {
        var params: [String: Any] = [
            "event_type": eventType,
            "hangout_id": hangoutId
        ]
        
        if let additionalParams = parameters {
            params.merge(additionalParams) { (_, new) in new }
        }
        
        Analytics.logEvent("hangout_event", parameters: params)
    }
    
    public func trackRelationshipEvent(eventType: String, relationshipId: String, parameters: [String: Any]?) async {
        var params: [String: Any] = [
            "event_type": eventType,
            "relationship_id": relationshipId
        ]
        
        if let additionalParams = parameters {
            params.merge(additionalParams) { (_, new) in new }
        }
        
        Analytics.logEvent("relationship_event", parameters: params)
    }
    
    public func trackCalendarEvent(eventType: String, calendarProvider: String, parameters: [String: Any]?) async {
        var params: [String: Any] = [
            "event_type": eventType,
            "calendar_provider": calendarProvider
        ]
        
        if let additionalParams = parameters {
            params.merge(additionalParams) { (_, new) in new }
        }
        
        Analytics.logEvent("calendar_event", parameters: params)
    }
    
    public func resetUserData() async {
        Analytics.resetAnalyticsData()
    }
    
    public func setAnalyticsCollectionEnabled(_ enabled: Bool) async {
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }
} 