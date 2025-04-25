import Foundation

/// Service for managing app configuration and remote configuration settings
public protocol ConfigurationService {
    /// Get a boolean configuration value
    /// - Parameters:
    ///   - key: Configuration key
    ///   - defaultValue: Default value if key is not found
    /// - Returns: The boolean value for the key or the default value
    func getBoolValue(for key: String, defaultValue: Bool) async -> Bool
    
    /// Get a string configuration value
    /// - Parameters:
    ///   - key: Configuration key
    ///   - defaultValue: Default value if key is not found
    /// - Returns: The string value for the key or the default value
    func getStringValue(for key: String, defaultValue: String) async -> String
    
    /// Get a numeric configuration value
    /// - Parameters:
    ///   - key: Configuration key
    ///   - defaultValue: Default value if key is not found
    /// - Returns: The number value for the key or the default value
    func getNumberValue(for key: String, defaultValue: Double) async -> Double
    
    /// Get a dictionary configuration value
    /// - Parameters:
    ///   - key: Configuration key
    ///   - defaultValue: Default value if key is not found
    /// - Returns: The dictionary value for the key or the default value
    func getDictionaryValue(for key: String, defaultValue: [String: Any]) async -> [String: Any]
    
    /// Get a data configuration value
    /// - Parameters:
    ///   - key: Configuration key
    ///   - defaultValue: Default value if key is not found
    /// - Returns: The data value for the key or the default value
    func getDataValue(for key: String, defaultValue: Data) async -> Data
    
    /// Get a configuration value as a decodable object
    /// - Parameters:
    ///   - key: Configuration key
    ///   - type: The type to decode into
    ///   - defaultValue: Default value if key is not found or decoding fails
    /// - Returns: The decoded object for the key or the default value
    func getObjectValue<T: Decodable>(for key: String, as type: T.Type, defaultValue: T) async -> T
    
    /// Set a configuration value locally
    /// - Parameters:
    ///   - value: The value to set
    ///   - key: Configuration key
    func setLocalValue(_ value: Any, for key: String) async
    
    /// Fetch remote configurations
    /// - Parameter expirationDuration: Time before cached config expires
    /// - Returns: Whether fetch was successful
    func fetchRemoteConfig(expirationDuration: TimeInterval) async -> Bool
    
    /// Activate the fetched remote config
    /// - Returns: Whether activation was successful
    func activateRemoteConfig() async -> Bool
    
    /// Get all available configuration keys
    /// - Returns: Array of all configuration keys
    func getAllConfigurationKeys() async -> [String]
    
    /// Reset all local configurations to defaults
    func resetLocalConfigurations() async
    
    /// Add a configuration observer for a specific key
    /// - Parameters:
    ///   - key: Configuration key to observe
    ///   - observer: The observer to notify
    func addObserver(for key: String, observer: AnyObject, handler: @escaping (Any?) -> Void)
    
    /// Remove a configuration observer
    /// - Parameter observer: The observer to remove
    func removeObserver(_ observer: AnyObject)
}

/// Standard configuration keys
public enum ConfigKey: String, CaseIterable {
    // App behavior configs
    case appEnvironment = "app_environment"
    case debugModeEnabled = "debug_mode_enabled"
    case apiBaseURL = "api_base_url"
    case minimumSupportedVersion = "minimum_supported_version"
    
    // Feature toggles
    case enableNewUserOnboarding = "enable_new_user_onboarding"
    case enablePushNotifications = "enable_push_notifications"
    case enableAnalytics = "enable_analytics"
    case enableCrashReporting = "enable_crash_reporting"
    
    // UI customization
    case primaryColor = "primary_color"
    case secondaryColor = "secondary_color"
    case maxHangoutSuggestionsCount = "max_hangout_suggestions_count"
    case refreshIntervalSeconds = "refresh_interval_seconds"
    
    // Calendar settings
    case defaultCalendarProvider = "default_calendar_provider"
    case calendarSyncIntervalMinutes = "calendar_sync_interval_minutes"
    case maxCalendarEventFetchDays = "max_calendar_event_fetch_days"
    
    // Hangout settings
    case hangoutDefaultDurationMinutes = "hangout_default_duration_minutes"
    case maxActiveHangoutsPerUser = "max_active_hangouts_per_user"
    case defaultHangoutFetchLimit = "default_hangout_fetch_limit"
    
    // Availability settings
    case availabilitySlotIntervalMinutes = "availability_slot_interval_minutes"
    case availabilityMaxLookAheadDays = "availability_max_lookahead_days"
    case availabilityDefaultStartHour = "availability_default_start_hour"
    case availabilityDefaultEndHour = "availability_default_end_hour"
    
    // Custom config
    case custom(String)
    
    public var key: String {
        switch self {
        case .custom(let customKey):
            return customKey
        default:
            return self.rawValue
        }
    }
} 