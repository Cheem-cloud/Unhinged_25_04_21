import Foundation

/// Service for managing feature flags and toggles
public protocol FeatureFlagService {
    /// Get all available feature flags
    /// - Returns: Dictionary of feature flags and their values
    func getAllFeatureFlags() async throws -> [String: FeatureFlag]
    
    /// Get a specific feature flag by its key
    /// - Parameter key: Key of the feature flag
    /// - Returns: The feature flag if found, nil otherwise
    func getFeatureFlag(key: String) async throws -> FeatureFlag?
    
    /// Check if a feature is enabled
    /// - Parameters:
    ///   - key: Key of the feature flag
    ///   - defaultValue: Default value if flag is not found
    /// - Returns: Whether the feature is enabled
    func isFeatureEnabled(key: String, defaultValue: Bool) async -> Bool
    
    /// Get feature flag value for a specific user
    /// - Parameters:
    ///   - key: Key of the feature flag
    ///   - userID: ID of the user
    ///   - defaultValue: Default value if flag is not found
    /// - Returns: Whether the feature is enabled for the user
    func isFeatureEnabledForUser(key: String, userID: String, defaultValue: Bool) async -> Bool
    
    /// Update a feature flag
    /// - Parameters:
    ///   - key: Key of the feature flag
    ///   - isEnabled: Whether the feature should be enabled
    ///   - description: Optional description of the feature
    ///   - rolloutPercentage: Optional rollout percentage (0-100)
    ///   - enabledUserIDs: Optional list of specific users for whom the feature is enabled
    ///   - disabledUserIDs: Optional list of specific users for whom the feature is disabled
    func updateFeatureFlag(
        key: String,
        isEnabled: Bool,
        description: String?,
        rolloutPercentage: Int?,
        enabledUserIDs: [String]?,
        disabledUserIDs: [String]?
    ) async throws
    
    /// Delete a feature flag
    /// - Parameter key: Key of the feature flag to delete
    func deleteFeatureFlag(key: String) async throws
    
    /// Sync remote feature flags with local cache
    /// - Parameter completion: Optional callback when sync completes
    func syncFeatureFlags(completion: ((Error?) -> Void)?) async
}

/// Feature flag model
public struct FeatureFlag: Codable, Identifiable {
    /// Unique identifier for the feature flag
    public var id: String?
    
    /// Key of the feature flag (e.g., "new_profile_ui")
    public var key: String
    
    /// Whether the feature is enabled by default
    public var isEnabled: Bool
    
    /// Description of the feature
    public var description: String?
    
    /// Optional rollout percentage (0-100)
    public var rolloutPercentage: Int?
    
    /// Optional list of user IDs for whom the feature is explicitly enabled
    public var enabledUserIDs: [String]?
    
    /// Optional list of user IDs for whom the feature is explicitly disabled
    public var disabledUserIDs: [String]?
    
    /// Creation date of the feature flag
    public var createdAt: Date
    
    /// Last update date of the feature flag
    public var updatedAt: Date
    
    /// Whether the feature is under test
    public var isTesting: Bool
    
    /// Version of the app this feature was introduced in
    public var introductionVersion: String?
    
    /// Environment where the feature is available
    public var environment: Environment
    
    /// Environment enum
    public enum Environment: String, Codable {
        case development
        case staging
        case production
        case all
    }
    
    public init(
        id: String? = nil,
        key: String,
        isEnabled: Bool = false,
        description: String? = nil,
        rolloutPercentage: Int? = nil,
        enabledUserIDs: [String]? = nil,
        disabledUserIDs: [String]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isTesting: Bool = false,
        introductionVersion: String? = nil,
        environment: Environment = .all
    ) {
        self.id = id
        self.key = key
        self.isEnabled = isEnabled
        self.description = description
        self.rolloutPercentage = rolloutPercentage
        self.enabledUserIDs = enabledUserIDs
        self.disabledUserIDs = disabledUserIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isTesting = isTesting
        self.introductionVersion = introductionVersion
        self.environment = environment
    }
} 