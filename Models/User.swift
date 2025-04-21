import Foundation
import FirebaseFirestore
import FirebaseAuth

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
