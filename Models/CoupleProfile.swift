import Foundation
import FirebaseFirestore

/// Represents a shared profile for a couple (two partners in a relationship)
struct CoupleProfile: Identifiable, Codable {
    /// Firebase document ID
    @DocumentID var id: String?
    
    /// Reference to the relationship ID
    var relationshipID: String
    
    /// Optional display name for the couple (e.g., "Sam & Alex")
    var displayName: String?
    
    /// Anniversary date if set by the couple
    var anniversaryDate: Date?
    
    /// Joint privacy settings
    var privacySettings: CouplePrivacySettings = CouplePrivacySettings()
    
    /// Metrics data about the relationship
    var metrics: CoupleMetrics = CoupleMetrics()
    
    /// Availability preferences for the couple
    var availabilityPreferences: CoupleAvailabilityPreferences = CoupleAvailabilityPreferences()
    
    /// Date when the profile was created
    var createdDate: Date = Date()
    
    /// Date when the profile was last updated
    var updatedDate: Date = Date()
    
    /// CodingKeys for Codable conformance
    enum CodingKeys: String, CodingKey {
        case id
        case relationshipID
        case displayName
        case anniversaryDate
        case privacySettings
        case metrics
        case availabilityPreferences
        case createdDate
        case updatedDate
    }
    
    /// Initialize with required fields
    init(relationshipID: String, displayName: String) {
        self.relationshipID = relationshipID
        self.displayName = displayName
        self.createdDate = Date()
        self.updatedDate = Date()
    }
}

/// Privacy settings for a couple profile
struct CouplePrivacySettings: Codable {
    /// Whether other users can see the couple's anniversary
    var showAnniversary: Bool = true
    
    /// Whether other users can see the couple's hangout history
    var showHangoutHistory: Bool = true
    
    /// Whether other users can see the couple's availability
    var showAvailability: Bool = true
    
    /// Whether to share metrics with partner
    var shareMetricsWithPartner: Bool = true
}

/// Metrics about a couple's relationship
struct CoupleMetrics: Codable {
    /// Total number of hangouts the couple has had
    var totalHangouts: Int = 0
    
    /// Most recent hangout date
    var lastHangoutDate: Date?
    
    /// Total time spent together (in minutes) based on hangout durations
    var totalTimeSpentTogether: Int = 0
    
    /// Most common hangout type
    var favoriteHangoutType: String?
    
    /// Number of friends the couple has hung out with
    var friendsCount: Int = 0
}

/// Availability preferences for a couple
struct CoupleAvailabilityPreferences: Codable {
    /// Preferred days of the week for hangouts (0 = Sunday, 6 = Saturday)
    var preferredDays: [Int] = []
    
    /// Preferred time ranges for hangouts
    var preferredTimeRanges: [PreferredTimeRange] = []
    
    /// Whether to automatically suggest hangouts based on availability
    var autoSuggestHangouts: Bool = false
}

/// A time range preference for scheduling
struct PreferredTimeRange: Codable {
    /// Day of week (0 = Sunday, 6 = Saturday)
    var dayOfWeek: Int
    
    /// Start time in minutes from midnight (e.g., 8am = 480)
    var startMinute: Int
    
    /// End time in minutes from midnight (e.g., 5pm = 1020)
    var endMinute: Int
    
    /// Preference weight (1-10, higher = more preferred)
    var preference: Int = 5
} 