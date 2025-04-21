import Foundation
import Firebase
import FirebaseFirestore

struct Persona: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var bio: String?
    var imageURL: String?
    var age: Int?
    var breed: String?
    var interests: [String]?
    var isPremium: Bool = false
    var createdAt: Timestamp = Timestamp()
    
    // Added for backward compatibility
    var isDefault: Bool = false
    var userID: String?
    
    // New fields for enhanced functionality
    var friendGroupIDs: [String] = []
    var activityPreferences: [ActivityPreference] = []
    var visibilitySettings: VisibilitySettings = VisibilitySettings()
    var tags: [String] = []
    
    // Computed property for backward compatibility
    var description: String? {
        return bio
    }
    
    // Computed property for backward compatibility
    var avatarURL: String? {
        return imageURL
    }
    
    init(id: String? = nil, name: String, bio: String? = nil, imageURL: String? = nil, 
         age: Int? = nil, breed: String? = nil, interests: [String]? = nil, 
         isPremium: Bool = false, createdAt: Timestamp = Timestamp(),
         isDefault: Bool = false, userID: String? = nil,
         friendGroupIDs: [String] = [], activityPreferences: [ActivityPreference] = [],
         visibilitySettings: VisibilitySettings = VisibilitySettings(),
         tags: [String] = []) {
        self.id = id
        self.name = name
        self.bio = bio
        self.imageURL = imageURL
        self.age = age
        self.breed = breed
        self.interests = interests
        self.isPremium = isPremium
        self.createdAt = createdAt
        self.isDefault = isDefault
        self.userID = userID
        self.friendGroupIDs = friendGroupIDs
        self.activityPreferences = activityPreferences
        self.visibilitySettings = visibilitySettings
        self.tags = tags
    }
}

// Activity preference model to describe activities this persona enjoys
struct ActivityPreference: Codable, Hashable {
    var activityType: String
    var preferenceLevel: Int // 1-5 scale, 5 being most preferred
    var notes: String?
    
    init(activityType: String, preferenceLevel: Int = 3, notes: String? = nil) {
        self.activityType = activityType
        self.preferenceLevel = max(1, min(5, preferenceLevel)) // Ensure valid range
        self.notes = notes
    }
}

// Visibility settings to control who can see this persona
struct VisibilitySettings: Codable, Hashable {
    var visibleToPartner: Bool = true
    var visibleToFriends: Bool = true
    var visibleInPublicProfile: Bool = false
    
    init(visibleToPartner: Bool = true, visibleToFriends: Bool = true, visibleInPublicProfile: Bool = false) {
        self.visibleToPartner = visibleToPartner
        self.visibleToFriends = visibleToFriends
        self.visibleInPublicProfile = visibleInPublicProfile
    }
} 
