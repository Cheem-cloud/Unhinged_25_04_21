import Foundation
import FirebaseFirestore

/// Status of a couple referral
enum CoupleReferralStatus: String, Codable {
    /// The referral was sent but not yet accepted
    case pending
    
    /// The referral was accepted and the new couple joined
    case accepted
    
    /// The referral expired without being used
    case expired
    
    /// The referral was revoked by the referring couple
    case revoked
}

/// Model representing a referral from one couple to another
struct CoupleReferral: Identifiable, Codable {
    /// The unique identifier for the referral
    @DocumentID var id: String?
    
    /// The relationship ID of the referring couple
    var referringRelationshipID: String
    
    /// Email of the person who was invited
    var inviteeEmail: String
    
    /// Optional - name of the person who was invited (if provided during invitation)
    var inviteeName: String?
    
    /// Optional - email of the partner being invited (if provided during invitation)
    var inviteePartnerEmail: String?
    
    /// Optional - name of the partner being invited (if provided during invitation)
    var inviteePartnerName: String?
    
    /// The relationship ID of the new couple (set when they join)
    var referredRelationshipID: String?
    
    /// Status of the referral
    var status: CoupleReferralStatus = .pending
    
    /// When the referral was created
    var createdAt: Date = Date()
    
    /// When the referral was last updated
    var updatedAt: Date = Date()
    
    /// When the referral expires
    var expiresAt: Date?
    
    /// Custom message from the referring couple
    var message: String?
    
    /// Unique code for this referral (used in the invite URL)
    var referralCode: String
    
    /// Whether this referral includes special perks
    var includesPerks: Bool = false
    
    /// Used to track which perks are included with this referral
    var perkIDs: [String]?
    
    /// Initialize with required fields
    init(referringRelationshipID: String, inviteeEmail: String) {
        self.referringRelationshipID = referringRelationshipID
        self.inviteeEmail = inviteeEmail
        
        // Generate a random referral code
        self.referralCode = Self.generateReferralCode()
        
        // Set expiration 30 days from now
        self.expiresAt = Calendar.current.date(byAdding: .day, value: 30, to: Date())
    }
    
    /// Generate a unique random referral code
    static func generateReferralCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"  // Removed I and O which can look like 1 and 0
        let numbers = "23456789"  // Removed 0 and 1 which can look like O and I
        
        var code = ""
        
        // Add 3 letters
        for _ in 0..<3 {
            if let letter = letters.randomElement() {
                code.append(letter)
            }
        }
        
        // Add 3 numbers
        for _ in 0..<3 {
            if let number = numbers.randomElement() {
                code.append(number)
            }
        }
        
        return code
    }
    
    /// Get the invite URL for this referral
    func getInviteURL() -> URL? {
        // Universal link format - would need to be configured in the app and on the server
        let urlString = "https://cheemhang.app/invite/\(referralCode)"
        return URL(string: urlString)
    }
    
    /// Codable keys for Firestore
    enum CodingKeys: String, CodingKey {
        case id
        case referringRelationshipID
        case inviteeEmail
        case inviteeName
        case inviteePartnerEmail
        case inviteePartnerName
        case referredRelationshipID
        case status
        case createdAt
        case updatedAt
        case expiresAt
        case message
        case referralCode
        case includesPerks
        case perkIDs
    }
}

/// Firestore extension for CoupleReferral
extension CoupleReferral {
    /// Convert a Firestore document to a CoupleReferral
    static func fromFirestore(_ document: DocumentSnapshot) -> CoupleReferral? {
        do {
            return try document.data(as: CoupleReferral.self)
        } catch {
            print("Error decoding couple referral: \(error)")
            return nil
        }
    }
} 