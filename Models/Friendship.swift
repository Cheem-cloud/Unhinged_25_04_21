import Foundation
import FirebaseFirestore

struct Friendship: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let userId: String
    let friendId: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Friendship, rhs: Friendship) -> Bool {
        lhs.id == rhs.id
    }
} 
