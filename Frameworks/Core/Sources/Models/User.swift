import Foundation

/// User model representing a user in the system
public struct User: Identifiable, Codable {
    /// Unique identifier (typically Firebase user ID)
    public var id: String?
    
    /// User's email address
    public var email: String
    
    /// User's display name
    public var displayName: String?
    
    /// User's profile image URL
    public var photoURL: String?
    
    /// Flag indicating if email is verified
    public var isEmailVerified: Bool = false
    
    /// Date when the user was created
    public var createdAt: Date
    
    /// Date when the user last logged in
    public var lastLoginAt: Date?
    
    /// List of persona IDs associated with this user
    public var personaIDs: [String] = []
    
    /// Additional user settings
    public var settings: UserSettings = UserSettings()
    
    /// Active relationship ID, if any
    public var activeRelationshipID: String?
    
    /// Status for feature flags and special user types
    public var status: UserStatus = UserStatus()
    
    /// User's stats
    public var stats: UserStats = UserStats()
    
    public init(
        id: String? = nil,
        email: String,
        displayName: String? = nil,
        photoURL: String? = nil,
        isEmailVerified: Bool = false,
        createdAt: Date = Date(),
        lastLoginAt: Date? = nil,
        personaIDs: [String] = [],
        settings: UserSettings = UserSettings(),
        activeRelationshipID: String? = nil,
        status: UserStatus = UserStatus(),
        stats: UserStats = UserStats()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.isEmailVerified = isEmailVerified
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
        self.personaIDs = personaIDs
        self.settings = settings
        self.activeRelationshipID = activeRelationshipID
        self.status = status
        self.stats = stats
    }
}

/// User settings for preferences and configurations
public struct UserSettings: Codable, Equatable {
    /// Whether to use dark mode
    public var darkMode: Bool = false
    
    /// Notification preferences
    public var notifications: NotificationSettings = NotificationSettings()
    
    /// Privacy settings
    public var privacy: PrivacySettings = PrivacySettings()
    
    /// Preferred language code (ISO 639-1)
    public var language: String = "en"
    
    public init(
        darkMode: Bool = false,
        notifications: NotificationSettings = NotificationSettings(),
        privacy: PrivacySettings = PrivacySettings(),
        language: String = "en"
    ) {
        self.darkMode = darkMode
        self.notifications = notifications
        self.privacy = privacy
        self.language = language
    }
    
    /// Notification preferences
    public struct NotificationSettings: Codable, Equatable {
        /// Push notifications enabled
        public var pushEnabled: Bool = true
        
        /// Email notifications enabled
        public var emailEnabled: Bool = true
        
        /// Do not disturb mode enabled
        public var dndEnabled: Bool = false
        
        /// Start time for DND period (if enabled)
        public var dndStartTime: String = "22:00"
        
        /// End time for DND period (if enabled)
        public var dndEndTime: String = "07:00"
        
        public init(
            pushEnabled: Bool = true,
            emailEnabled: Bool = true,
            dndEnabled: Bool = false,
            dndStartTime: String = "22:00",
            dndEndTime: String = "07:00"
        ) {
            self.pushEnabled = pushEnabled
            self.emailEnabled = emailEnabled
            self.dndEnabled = dndEnabled
            self.dndStartTime = dndStartTime
            self.dndEndTime = dndEndTime
        }
    }
    
    /// Privacy settings
    public struct PrivacySettings: Codable, Equatable {
        /// Show online status
        public var showOnlineStatus: Bool = true
        
        /// Show profile to public
        public var publicProfile: Bool = false
        
        /// Show relationship status
        public var showRelationshipStatus: Bool = true
        
        /// Share calendar data with partner
        public var shareCalendarWithPartner: Bool = true
        
        public init(
            showOnlineStatus: Bool = true,
            publicProfile: Bool = false,
            showRelationshipStatus: Bool = true,
            shareCalendarWithPartner: Bool = true
        ) {
            self.showOnlineStatus = showOnlineStatus
            self.publicProfile = publicProfile
            self.showRelationshipStatus = showRelationshipStatus
            self.shareCalendarWithPartner = shareCalendarWithPartner
        }
    }
}

/// User status tracking feature access and special statuses
public struct UserStatus: Codable, Equatable {
    /// Whether the user is an admin
    public var isAdmin: Bool = false
    
    /// Whether the user has beta access
    public var hasBetaAccess: Bool = false
    
    /// Account status (active, suspended, etc.)
    public var accountStatus: AccountStatus = .active
    
    /// Account type (free, premium, etc.)
    public var accountType: AccountType = .free
    
    /// App version last used by this user
    public var lastAppVersion: String?
    
    /// Account status enum
    public enum AccountStatus: String, Codable {
        case active
        case pendingVerification
        case suspended
        case deactivated
        case deleted
    }
    
    /// Account type enum
    public enum AccountType: String, Codable {
        case free
        case premium
        case lifetimePremium
    }
    
    public init(
        isAdmin: Bool = false,
        hasBetaAccess: Bool = false,
        accountStatus: AccountStatus = .active,
        accountType: AccountType = .free,
        lastAppVersion: String? = nil
    ) {
        self.isAdmin = isAdmin
        self.hasBetaAccess = hasBetaAccess
        self.accountStatus = accountStatus
        self.accountType = accountType
        self.lastAppVersion = lastAppVersion
    }
}

/// User statistics for analytics and insights
public struct UserStats: Codable, Equatable {
    /// Number of hangouts completed
    public var hangoutsCompleted: Int = 0
    
    /// Number of hangouts cancelled
    public var hangoutsCancelled: Int = 0
    
    /// Number of personas created
    public var personasCreated: Int = 0
    
    /// Account creation date
    public var memberSinceDate: Date = Date()
    
    /// Average hangout duration in minutes
    public var averageHangoutDurationMinutes: Int = 0
    
    /// Most used persona ID
    public var mostUsedPersonaID: String?
    
    /// Last active date
    public var lastActiveDate: Date?
    
    public init(
        hangoutsCompleted: Int = 0,
        hangoutsCancelled: Int = 0,
        personasCreated: Int = 0,
        memberSinceDate: Date = Date(),
        averageHangoutDurationMinutes: Int = 0,
        mostUsedPersonaID: String? = nil,
        lastActiveDate: Date? = nil
    ) {
        self.hangoutsCompleted = hangoutsCompleted
        self.hangoutsCancelled = hangoutsCancelled
        self.personasCreated = personasCreated
        self.memberSinceDate = memberSinceDate
        self.averageHangoutDurationMinutes = averageHangoutDurationMinutes
        self.mostUsedPersonaID = mostUsedPersonaID
        self.lastActiveDate = lastActiveDate
    }
} 