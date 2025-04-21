import Foundation
import FirebaseFirestore

/// Types of notifications that can be sent in the app
enum NotificationType: String, Codable {
    case newMessage = "newMessage"
    case hangoutInvite = "hangoutInvite"
    case hangoutReminder = "hangoutReminder"
    case friendRequest = "friendRequest"
    case friendAccept = "friendAccept"
    case systemNotice = "systemNotice"
}

/// Model representing a notification in the system
struct Notification: Identifiable, Codable {
    /// Unique identifier for the notification
    var id: String = UUID().uuidString
    
    /// ID of the user receiving the notification
    var recipientID: String
    
    /// ID of the user who initiated the action causing the notification
    var senderID: String
    
    /// Type of notification
    var type: NotificationType
    
    /// Text content of the notification
    var content: String
    
    /// ID of related content (optional, e.g., hangout ID for a hangout invitation)
    var relatedID: String?
    
    /// Date when the notification was created
    var createdDate: Date
    
    /// Date when the notification was read by the user (nil if unread)
    var readDate: Date?
    
    /// Flag indicating if the notification has been deleted
    var isDeleted: Bool = false
    
    /// Computed property to check if the notification has been read
    var isRead: Bool {
        return readDate != nil
    }
}

// MARK: - Firestore Serialization
extension Notification: FirestoreSerializable {
    init?(documentID: String, data: [String: Any]) {
        self.id = documentID
        
        guard let recipientID = data["recipientID"] as? String,
              let senderID = data["senderID"] as? String,
              let typeString = data["type"] as? String,
              let type = NotificationType(rawValue: typeString),
              let content = data["content"] as? String,
              let createdTimestamp = data["createdDate"] as? Timestamp else {
            return nil
        }
        
        self.recipientID = recipientID
        self.senderID = senderID
        self.type = type
        self.content = content
        self.relatedID = data["relatedID"] as? String
        self.createdDate = createdTimestamp.dateValue()
        
        if let readTimestamp = data["readDate"] as? Timestamp {
            self.readDate = readTimestamp.dateValue()
        } else {
            self.readDate = nil
        }
        
        self.isDeleted = data["isDeleted"] as? Bool ?? false
    }
    
    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "recipientID": recipientID,
            "senderID": senderID,
            "type": type.rawValue,
            "content": content,
            "createdDate": Timestamp(date: createdDate),
            "isDeleted": isDeleted
        ]
        
        if let relatedID = relatedID {
            data["relatedID"] = relatedID
        }
        
        if let readDate = readDate {
            data["readDate"] = Timestamp(date: readDate)
        }
        
        return data
    }
}

// MARK: - FirestoreConvertible

extension Notification: FirestoreConvertible {
    enum CodingKeys: String, CodingKey {
        case id
        case recipientID
        case senderID
        case type
        case content
        case relatedID
        case createdDate
        case readDate
        case isDeleted
    }
} 