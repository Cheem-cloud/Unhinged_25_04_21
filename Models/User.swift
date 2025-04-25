import Foundation
import FirebaseFirestore
import FirebaseAuth

/// User model for the application
public struct User: Identifiable, Codable {
    /// Unique identifier for the user
    public var id: String
    
    /// User's email address
    public var email: String?
    
    /// User's display name
    public var displayName: String?
    
    /// URL to the user's profile photo
    public var photoURL: URL?
    
    /// Whether the user's email has been verified
    public var isEmailVerified: Bool
    
    /// When the user was created
    public var createdAt: Date
    
    /// When the user was last active
    public var lastActive: Date?
    
    /// User's settings and preferences
    public var settings: UserSettings?
    
    /// User's FCM token for notifications
    public var fcmToken: String?
    
    /// Initializes a new User
    public init(
        id: String,
        email: String? = nil,
        displayName: String? = nil,
        photoURL: URL? = nil,
        isEmailVerified: Bool = false,
        createdAt: Date = Date(),
        lastActive: Date? = nil,
        settings: UserSettings? = nil,
        fcmToken: String? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.isEmailVerified = isEmailVerified
        self.createdAt = createdAt
        self.lastActive = lastActive
        self.settings = settings
        self.fcmToken = fcmToken
    }
    
    /// Initialize from a Firebase User
    public init(from firebaseUser: FirebaseAuth.User) {
        self.id = firebaseUser.uid
        self.email = firebaseUser.email
        self.displayName = firebaseUser.displayName
        self.photoURL = firebaseUser.photoURL
        self.isEmailVerified = firebaseUser.isEmailVerified
        self.createdAt = firebaseUser.metadata.creationDate ?? Date()
        self.lastActive = firebaseUser.metadata.lastSignInDate
    }
}

/// User settings and preferences
public struct UserSettings: Codable {
    /// Whether to receive push notifications
    public var pushNotificationsEnabled: Bool
    
    /// Whether to receive email notifications
    public var emailNotificationsEnabled: Bool
    
    /// User's preferred theme
    public var theme: String
    
    /// User's preferred locale
    public var locale: String
    
    /// User's time zone
    public var timeZone: String
    
    /// Whether to show the user's calendar availability
    public var showAvailability: Bool
    
    /// Other user preferences as key-value pairs
    public var preferences: [String: String]?
    
    /// Initializes new UserSettings
    public init(
        pushNotificationsEnabled: Bool = true,
        emailNotificationsEnabled: Bool = true,
        theme: String = "system",
        locale: String = "en_US",
        timeZone: String = TimeZone.current.identifier,
        showAvailability: Bool = true,
        preferences: [String: String]? = nil
    ) {
        self.pushNotificationsEnabled = pushNotificationsEnabled
        self.emailNotificationsEnabled = emailNotificationsEnabled
        self.theme = theme
        self.locale = locale
        self.timeZone = timeZone
        self.showAvailability = showAvailability
        self.preferences = preferences
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

struct AppUser: Identifiable, Codable, Hashable, Equatable {
    @DocumentID var id: String?
    var email: String
    var displayName: String
    var photoURL: String?
    var relationshipID: String?
    var calendarID: String?
    var calendarAccessToken: String?
    var calendarRefreshToken: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Add hash and equality methods
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AppUser, rhs: AppUser) -> Bool {
        lhs.id == rhs.id
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName
        case photoURL
        case relationshipID
        case calendarID
        case calendarAccessToken
        case calendarRefreshToken
        case createdAt
        case updatedAt
    }
    
    static func create(from authUser: FirebaseAuth.User) -> AppUser {
        return AppUser(
            id: authUser.uid,
            email: authUser.email ?? "",
            displayName: authUser.displayName ?? "",
            photoURL: authUser.photoURL?.absoluteString
        )
    }
}

// For compatibility with existing code
public extension User {
    /// Whether the user has set up a profile
    var hasCompletedProfile: Bool {
        return displayName != nil && !displayName!.isEmpty
    }
    
    /// User's first name (derived from display name)
    var firstName: String {
        return displayName?.components(separatedBy: " ").first ?? ""
    }
} 
