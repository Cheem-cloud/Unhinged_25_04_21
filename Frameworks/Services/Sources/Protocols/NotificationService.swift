import Foundation
import UserNotifications

/// Protocol defining notification service operations
public protocol NotificationService {
    /// Setup notification permissions and handlers
    func setupNotifications()
    
    /// Save device token for push notifications
    /// - Parameter token: FCM token to save
    func saveDeviceToken(_ token: String) async throws
    
    /// Clear FCM token for a user
    /// - Parameter userId: User ID to clear token for
    func clearFCMToken(for userId: String) async throws
    
    /// Send notification for a new hangout request
    /// - Parameters:
    ///   - userId: User ID to send notification to
    ///   - creatorName: Name of the user who created the request
    ///   - hangoutTitle: Title of the hangout
    ///   - hangoutId: ID of the hangout
    func sendNewHangoutRequestNotification(to userId: String, from creatorName: String, hangoutTitle: String, hangoutId: String) async throws
    
    /// Send notification for a hangout response (accepted/declined)
    /// - Parameters:
    ///   - userId: User ID to send notification to
    ///   - accepted: Whether the hangout was accepted or declined
    ///   - responderName: Name of the user who responded
    ///   - hangoutTitle: Title of the hangout
    ///   - hangoutId: ID of the hangout
    func sendHangoutResponseNotification(to userId: String, accepted: Bool, responderName: String, hangoutTitle: String, hangoutId: String) async throws
    
    /// Send a poke notification
    /// - Parameters:
    ///   - userId: User ID to send notification to
    ///   - pokerName: Name of the user sending the poke
    func sendPokeNotification(to userId: String, from pokerName: String) async throws
    
    /// Send notification for partner invitation
    /// - Parameters:
    ///   - userId: User ID to send notification to
    ///   - senderName: Name of the user sending the invitation
    ///   - invitationID: ID of the invitation
    func sendPartnerInvitationNotification(to userId: String, from senderName: String, invitationID: String) async throws
    
    /// Send notification when a partner invitation is accepted
    /// - Parameters:
    ///   - userId: User ID to send notification to
    ///   - accepterName: Name of the user who accepted
    ///   - relationshipID: ID of the newly created relationship
    func sendPartnerInvitationAcceptedNotification(to userId: String, from accepterName: String, relationshipID: String) async throws
    
    /// Send notification when a hangout has a calendar conflict
    /// - Parameters:
    ///   - userId: User ID to send notification to
    ///   - userName: Name of the user who has the conflict
    ///   - hangoutTitle: Title of the hangout
    ///   - hangoutId: ID of the hangout
    func sendHangoutConflictNotification(to userId: String, userName: String, hangoutTitle: String, hangoutId: String) async throws
    
    /// Schedule a local notification
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - userInfo: Additional data to include
    ///   - delay: Time to wait before showing the notification
    func scheduleLocalNotification(title: String, body: String, userInfo: [String: Any], delay: TimeInterval) 
    
    /// Schedule a notification for an upcoming hangout
    /// - Parameters:
    ///   - hangoutTitle: Title of the hangout
    ///   - partnerName: Name of the partner
    ///   - date: Date of the hangout
    ///   - hangoutId: ID of the hangout
    func scheduleHangoutNotification(hangoutTitle: String, partnerName: String, date: Date, hangoutId: String)
    
    /// Cancel a specific notification
    /// - Parameter identifier: Identifier of the notification to cancel
    func cancelNotification(withIdentifier identifier: String)
    
    /// Cancel all pending notifications
    func cancelAllNotifications()
} 