import Foundation
import Firebase
import FirebaseMessaging
import FirebaseAuth
import FirebaseFunctions
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif


/// Firebase implementation of the NotificationService protocol
public class FirebaseNotificationService: NSObject, NotificationService {
    // Firestore database reference
    private let db = Firestore.firestore()
    
    // Delegate used to handle foreground notifications
    weak var notificationDelegate: UNUserNotificationCenterDelegate?
    
    // Notification type enum
    public enum NotificationType: String, Codable {
        case newHangoutRequest = "new_hangout_request"
        case hangoutAccepted = "hangout_accepted"
        case hangoutDeclined = "hangout_declined"
        case poke = "poke_notification"
        case partnerInvitation = "partner_invitation"
        case partnerInvitationAccepted = "partner_invitation_accepted"
        case partnerInvitationDeclined = "partner_invitation_declined"
        case relationshipTerminated = "relationship_terminated"
        case hangoutConflict = "hangout_conflict"
    }
    
    public override init() {
        super.init()
        print("📱 FirebaseNotificationService initialized")
    }
    
    public func setupNotifications() {
        // Get current notification settings
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Notification settings: \(settings)")
        }
    }
    
    public func saveDeviceToken(_ token: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseNotificationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        // Create token data for update
        let tokenData: [String: Any] = [
            "fcmToken": token,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        // Update user document with token
        try await db.collection("users").document(userId).updateData(tokenData)
        print("✅ FCM token saved successfully for user: \(userId)")
    }
    
    public func clearFCMToken(for userId: String) async throws {
        print("🧹 Clearing FCM token for user: \(userId)")
        
        // Delete the token from Firestore
        try await db.collection("users").document(userId).updateData([
            "fcmToken": FieldValue.delete()
        ])
        
        // Also request local FCM token deletion
        return try await withCheckedThrowingContinuation { continuation in
            Messaging.messaging().deleteToken { error in
                if let error = error {
                    print("❌ Error deleting local FCM token: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ Successfully deleted local FCM token")
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Notification Sending Methods
    
    public func sendNewHangoutRequestNotification(to userId: String, from creatorName: String, hangoutTitle: String, hangoutId: String) async throws {
        print("📲 NOTIFY: Sending hangout request notification from \(creatorName) to \(userId)")
        
        // Add a unique notification ID to prevent duplicates
        let notificationId = "hangout_request_\(hangoutId)"
        
        let payload = createNotificationPayload(
            type: .newHangoutRequest,
            title: "New Hangout Request",
            body: "\(creatorName) wants to hangout with you!",
            data: [
                "hangoutId": hangoutId, 
                "title": hangoutTitle,
                "notificationId": notificationId
            ]
        )
        
        try await sendNotification(to: userId, payload: payload)
    }
    
    public func sendHangoutResponseNotification(to userId: String, accepted: Bool, responderName: String, hangoutTitle: String, hangoutId: String) async throws {
        let type: NotificationType = accepted ? .hangoutAccepted : .hangoutDeclined
        let title = accepted ? "Hangout Accepted" : "Hangout Declined"
        let body = accepted 
            ? "\(responderName) accepted your hangout request!"
            : "\(responderName) declined your hangout request."
        
        // Add a unique notification ID to prevent duplicates
        let notificationId = accepted ? "hangout_accepted_\(hangoutId)" : "hangout_declined_\(hangoutId)"
        
        let payload = createNotificationPayload(
            type: type,
            title: title,
            body: body,
            data: [
                "hangoutId": hangoutId, 
                "title": hangoutTitle,
                "notificationId": notificationId
            ]
        )
        
        try await sendNotification(to: userId, payload: payload)
    }
    
    public func sendPokeNotification(to userId: String, from pokerName: String) async throws {
        print("📲 POKE: Sending poke notification to \(userId) from \(pokerName)")
        
        // Generate a unique ID for the poke
        let notificationId = "poke_\(pokerName)_\(Date().timeIntervalSince1970)"
        
        let payload = createNotificationPayload(
            type: .poke,
            title: "❤️ You've Been Poked!",
            body: "\(pokerName) is thinking about you!",
            data: [
                "pokerName": pokerName,
                "notificationId": notificationId
            ]
        )
        
        try await sendNotification(to: userId, payload: payload)
    }
    
    public func sendPartnerInvitationNotification(to userId: String, from senderName: String, invitationID: String) async throws {
        let notificationId = "partner_invitation_\(invitationID)"
        
        let payload = createNotificationPayload(
            type: .partnerInvitation,
            title: "Partner Invitation",
            body: "\(senderName) has invited you to become partners!",
            data: [
                "invitationID": invitationID,
                "senderName": senderName,
                "notificationId": notificationId
            ]
        )
        
        try await sendNotification(to: userId, payload: payload)
    }
    
    public func sendPartnerInvitationAcceptedNotification(to userId: String, from accepterName: String, relationshipID: String) async throws {
        let notificationId = "partner_invitation_accepted_\(relationshipID)"
        
        let payload = createNotificationPayload(
            type: .partnerInvitationAccepted,
            title: "Partner Invitation Accepted",
            body: "\(accepterName) has accepted your partner invitation!",
            data: [
                "relationshipID": relationshipID,
                "accepterName": accepterName,
                "notificationId": notificationId
            ]
        )
        
        try await sendNotification(to: userId, payload: payload)
    }
    
    public func sendHangoutConflictNotification(to userId: String, userName: String, hangoutTitle: String, hangoutId: String) async throws {
        let notificationId = "hangout_conflict_\(hangoutId)_\(Date().timeIntervalSince1970)"
        
        let payload = createNotificationPayload(
            type: .hangoutConflict,
            title: "Schedule Conflict",
            body: "\(userName) now has a calendar conflict with the hangout: \(hangoutTitle)",
            data: [
                "hangoutId": hangoutId,
                "title": hangoutTitle,
                "notificationId": notificationId
            ]
        )
        
        try await sendNotification(to: userId, payload: payload)
    }
    
    // MARK: - Helper Methods
    
    private func createNotificationPayload(type: NotificationType, title: String, body: String, data: [String: String]) -> [String: Any] {
        var payload: [String: Any] = [
            "notification": [
                "title": title,
                "body": body,
                "sound": "default"
            ],
            "data": [
                "type": type.rawValue
            ] as [String: Any]
        ]
        
        // Add any additional data
        var dataDict = payload["data"] as? [String: Any] ?? [:]
        for (key, value) in data {
            dataDict[key] = value
        }
        payload["data"] = dataDict
        
        return payload
    }
    
    private func sendNotification(to userId: String, payload: [String: Any]) async throws {
        // Get the user's FCM token
        print("🔎 NOTIFY: Retrieving FCM token for user: \(userId)")
        
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let userData = userDoc.data() else {
            throw NSError(domain: "FirebaseNotificationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"])
        }
        
        guard let fcmToken = userData["fcmToken"] as? String else {
            throw NSError(domain: "FirebaseNotificationService", code: 400, userInfo: [NSLocalizedDescriptionKey: "FCM token not found for user"])
        }
        
        // Send notification via Firebase Cloud Functions
        print("📲 NOTIFY: Sending notification to token: \(String(fcmToken.prefix(10)))...")
        
        return try await withCheckedThrowingContinuation { continuation in
            let functions = Functions.functions()
            functions.httpsCallable("sendPushNotification").call(["token": fcmToken, "payload": payload]) { result, error in
                if let error = error {
                    print("❌ NOTIFY: Error sending notification: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ NOTIFY: Push notification sent successfully via Firebase")
                    if let resultData = result?.data as? [String: Any] {
                        print("✅ NOTIFY: Result data: \(resultData)")
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Local Notifications
    
    public func scheduleLocalNotification(title: String, body: String, userInfo: [String: Any] = [:], delay: TimeInterval = 0) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Add any custom data
        content.userInfo = userInfo
        
        // Create trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        
        // Create request
        let identifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling local notification: \(error.localizedDescription)")
            } else {
                print("Local notification scheduled with ID: \(identifier)")
            }
        }
    }
    
    public func scheduleHangoutNotification(hangoutTitle: String, partnerName: String, date: Date, hangoutId: String) {
        // Create notification content
        let title = "Upcoming Hangout"
        let body = "Your hangout '\(hangoutTitle)' with \(partnerName) is coming up!"
        let userInfo = ["hangoutID": hangoutId]
        
        // Calculate delay (5 minutes before the hangout)
        let delay = max(0, date.timeIntervalSinceNow - 5 * 60)
        
        // Schedule notification
        scheduleLocalNotification(title: title, body: body, userInfo: userInfo, delay: delay)
    }
    
    public func cancelNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    public func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
} 