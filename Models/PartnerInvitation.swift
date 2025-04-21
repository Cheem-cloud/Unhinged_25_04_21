import Foundation
import FirebaseFirestore

/// Status of a partner invitation
enum PartnerInvitationStatus: String, Codable {
    /// Invitation has been sent but not yet responded to
    case pending
    /// Invitation has been accepted
    case accepted
    /// Invitation has been declined
    case declined
    /// Invitation has been canceled
    case canceled
}

/// Represents an invitation from one user to another to become partners
struct PartnerInvitation: Identifiable, Codable {
    /// Firebase document ID
    @DocumentID var id: String?
    
    /// ID of the user who sent the invitation
    var senderID: String
    
    /// Email of the user being invited
    var recipientEmail: String
    
    /// Optional ID of the recipient (may be null if they haven't registered yet)
    var recipientID: String?
    
    /// Custom message from the sender
    var message: String?
    
    /// Status of the invitation
    var status: PartnerInvitationStatus = .pending
    
    /// Date when the invitation was sent
    var createdDate: Date = Date()
    
    /// Date when the invitation status was last updated
    var updatedDate: Date = Date()
    
    /// Date when the invitation was responded to
    var responseDate: Date?
    
    /// Unique invitation code for QR code sharing
    var invitationCode: String
    
    /// CodingKeys for Codable conformance
    enum CodingKeys: String, CodingKey {
        case id
        case senderID
        case recipientEmail
        case recipientID
        case message
        case status
        case createdDate
        case updatedDate
        case responseDate
        case invitationCode
    }
    
    /// Initialize a partner invitation with required fields
    init(senderID: String, recipientEmail: String, message: String? = nil) {
        self.senderID = senderID
        self.recipientEmail = recipientEmail
        self.message = message
        self.createdDate = Date()
        self.updatedDate = Date()
        self.invitationCode = Self.generateInvitationCode()
    }
    
    /// Mark this invitation as accepted
    /// - Parameter recipientID: The ID of the user accepting the invitation
    mutating func accept(recipientID: String) {
        self.status = .accepted
        self.recipientID = recipientID
        self.responseDate = Date()
        self.updatedDate = Date()
    }
    
    /// Mark this invitation as declined
    mutating func decline() {
        self.status = .declined
        self.responseDate = Date()
        self.updatedDate = Date()
    }
    
    /// Mark this invitation as canceled
    mutating func cancel() {
        self.status = .canceled
        self.updatedDate = Date()
    }
    
    /// Generate a URL for sharing this invitation
    /// - Returns: A URL string for the invitation
    func generateShareURL() -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "cheemhang.app"
        components.path = "/invite"
        
        // Add invitation code to query parameters
        components.queryItems = [
            URLQueryItem(name: "code", value: invitationCode)
        ]
        
        return components.url
    }
    
    /// Generate a unique invitation code
    /// - Returns: A unique alphanumeric code
    private static func generateInvitationCode() -> String {
        // Characters to use in the code (omitting easily confused characters)
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        
        // Generate a random string of 8 characters
        let randomString = String((0..<8).map { _ in
            characters.randomElement()!
        })
        
        // Format as XXXX-XXXX for easier reading
        let index = randomString.index(randomString.startIndex, offsetBy: 4)
        let formatted = randomString[..<index] + "-" + randomString[index...]
        
        return String(formatted)
    }
} 