import Foundation

/// Model representing an application user
public struct AppUser: Identifiable, Codable {
    /// Unique identifier for the user
    public var id: String
    
    /// User's email address
    public var email: String
    
    /// User's display name
    public var displayName: String
    
    /// User's profile photo URL
    public var photoURL: String?
    
    /// Whether the user has completed onboarding
    public var hasCompletedOnboarding: Bool
    
    /// User's preferences
    public var preferences: UserPreferences
    
    /// User's device token for push notifications
    public var fcmToken: String?
    
    /// Date the user was created
    public var createdAt: Date
    
    /// Date the user was last updated
    public var updatedAt: Date
    
    /// Initialize a new user
    /// - Parameters:
    ///   - id: User ID (optional, defaults to UUID)
    ///   - email: User's email
    ///   - displayName: User's display name
    ///   - photoURL: User's profile photo URL (optional)
    ///   - hasCompletedOnboarding: Whether onboarding is complete (defaults to false)
    ///   - preferences: User preferences (defaults to empty preferences)
    ///   - fcmToken: Device token for push notifications (optional)
    ///   - createdAt: Creation date (defaults to now)
    ///   - updatedAt: Last update date (defaults to now)
    public init(
        id: String = UUID().uuidString,
        email: String,
        displayName: String,
        photoURL: String? = nil,
        hasCompletedOnboarding: Bool = false,
        preferences: UserPreferences = UserPreferences(),
        fcmToken: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.preferences = preferences
        self.fcmToken = fcmToken
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Convert from Firebase Auth User
    /// - Parameter firebaseUser: Firebase Auth User
    /// - Returns: AppUser instance
    public static func fromFirebaseUser(_ firebaseUser: FirebaseAuthUser) -> AppUser {
        return AppUser(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            displayName: firebaseUser.displayName ?? "",
            photoURL: firebaseUser.photoURL?.absoluteString
        )
    }
}

/// Model representing Firebase Auth user properties needed for conversion
public struct FirebaseAuthUser {
    public let uid: String
    public let email: String?
    public let displayName: String?
    public let photoURL: URL?
    
    public init(uid: String, email: String?, displayName: String?, photoURL: URL?) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
    }
}

/// Model for user preferences
public struct UserPreferences: Codable {
    /// Notification preferences
    public var notifications: NotificationPreferences
    
    /// Theme preferences
    public var theme: ThemePreferences
    
    /// Privacy preferences
    public var privacy: PrivacyPreferences
    
    /// Initialize with default values
    public init(
        notifications: NotificationPreferences = NotificationPreferences(),
        theme: ThemePreferences = ThemePreferences(),
        privacy: PrivacyPreferences = PrivacyPreferences()
    ) {
        self.notifications = notifications
        self.theme = theme
        self.privacy = privacy
    }
}

/// Model for notification preferences
public struct NotificationPreferences: Codable {
    /// Push notifications enabled
    public var pushEnabled: Bool
    
    /// Email notifications enabled
    public var emailEnabled: Bool
    
    /// Types of notifications enabled
    public var enabledTypes: [NotificationType]
    
    /// Initialize with default values
    public init(
        pushEnabled: Bool = true,
        emailEnabled: Bool = true,
        enabledTypes: [NotificationType] = NotificationType.allCases
    ) {
        self.pushEnabled = pushEnabled
        self.emailEnabled = emailEnabled
        self.enabledTypes = enabledTypes
    }
    
    /// Notification types
    public enum NotificationType: String, Codable, CaseIterable {
        case hangouts
        case messages
        case reminders
        case partnerActivity
        case system
    }
}

/// Model for theme preferences
public struct ThemePreferences: Codable {
    /// Whether dark mode is enabled
    public var darkModeEnabled: Bool
    
    /// Primary color for the user's UI
    public var primaryColor: String
    
    /// Initialize with default values
    public init(
        darkModeEnabled: Bool = false,
        primaryColor: String = "#0066CC" // Default blue
    ) {
        self.darkModeEnabled = darkModeEnabled
        self.primaryColor = primaryColor
    }
}

/// Model for privacy preferences
public struct PrivacyPreferences: Codable {
    /// Whether location sharing is enabled
    public var locationSharingEnabled: Bool
    
    /// Whether calendar sharing is enabled
    public var calendarSharingEnabled: Bool
    
    /// Whether profile is visible to other users
    public var profileVisibleToOthers: Bool
    
    /// Initialize with default values
    public init(
        locationSharingEnabled: Bool = false,
        calendarSharingEnabled: Bool = true,
        profileVisibleToOthers: Bool = true
    ) {
        self.locationSharingEnabled = locationSharingEnabled
        self.calendarSharingEnabled = calendarSharingEnabled
        self.profileVisibleToOthers = profileVisibleToOthers
    }
} 