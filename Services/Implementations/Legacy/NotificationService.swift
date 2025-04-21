import Foundation
import Firebase
import FirebaseMessaging
import FirebaseAuth
import FirebaseFunctions
import UIKit
import UserNotifications
import SwiftUI

class NotificationService: NSObject {
    static let shared = NotificationService()
    
    // Firestore database reference is still needed for some operations
    private let db = Firestore.firestore()
    
    // CRUD service for data operations replaces firestoreService
    private let crudService = ServiceManager.shared.getService(CRUDService.self)
    
    // Delegate used to handle foreground notifications
    weak var notificationDelegate: NotificationDelegate?
    
    enum NotificationType: String {
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
    
    private override init() {
        super.init()
        print("📱 NotificationService initialized with CRUDService")
    }
    
    func setupNotifications() {
        // This is now handled by the AppDelegate
        // Do not request permissions directly here to avoid duplication
        
        // Get current notification settings without using trailing closure
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Notification settings: \(settings)")
        }
    }
    
    func saveDeviceToken(_ token: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Cannot save device token: User not logged in")
            return
        }
        
        Task {
            do {
                // Create token data for update
                let tokenData: [String: Any] = [
                    "fcmToken": token,
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                
                // Use CRUD service to update user
                try await crudService.update("users/\(userId)", with: tokenData)
                print("✅ FCM token saved successfully via CRUDService")
            } catch {
                print("❌ Error saving FCM token: \(error.localizedDescription)")
            }
        }
    }
    
    func clearFCMToken(for userId: String) async throws {
        print("🧹 Clearing FCM token for user: \(userId)")
        
        // Delete the token using CRUDService instead of direct Firestore access
        do {
            // Create update data with FieldValue.delete()
            let updateData = ["fcmToken": FieldValue.delete()]
            
            // Use CRUD service to update user document
            try await crudService.update("users/\(userId)", with: updateData)
            print("✅ FCM token successfully deleted from Firestore for user: \(userId)")
            
            // Also request local FCM token deletion
            Messaging.messaging().deleteToken { error in
                if let error = error {
                    print("❌ Error deleting local FCM token: \(error.localizedDescription)")
                } else {
                    print("✅ Successfully deleted local FCM token")
                }
            }
        } catch {
            print("❌ Error clearing FCM token in Firestore: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Notification Sending
    
    func sendNewHangoutRequestNotification(to userId: String, from creatorName: String, hangoutTitle: String, hangoutId: String) {
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
        
        // Make sure we're only using the persona name, not the actual user name
        print("📲 NOTIFY: Notification content: \(creatorName) wants to hangout with you!")
        print("📲 NOTIFY: Using unique notification ID: \(notificationId)")
        
        sendNotification(to: userId, payload: payload)
    }
    
    func sendHangoutResponseNotification(to userId: String, accepted: Bool, responderName: String, hangoutTitle: String, hangoutId: String) {
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
        
        print("📲 NOTIFY: Sending response notification with ID: \(notificationId)")
        
        sendNotification(to: userId, payload: payload)
    }
    
    func sendPokeNotification(to userId: String, from pokerName: String) {
        print("📲 POKE: Starting sendPokeNotification process")
        print("📲 POKE: To userId: \(userId)")
        print("📲 POKE: From name: \(pokerName)")
        
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
        
        print("📲 POKE: Created payload: \(payload)")
        print("📲 POKE: Using notification ID: \(notificationId)")
        
        // Check if we're sending to self (for testing)
        if userId == Auth.auth().currentUser?.uid {
            print("⚠️ POKE: Warning - Sending poke notification to self (testing)")
        }
        
        sendNotification(to: userId, payload: payload)
    }
    
    // MARK: - Partner Notifications
    
    /// Send a notification when a user is invited to become a partner
    /// - Parameters:
    ///   - userId: ID of the user to send the notification to
    ///   - senderName: Name of the user who sent the invitation
    ///   - invitationID: ID of the partner invitation
    func sendPartnerInvitationNotification(to userId: String, from senderName: String, invitationID: String) async throws {
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
        
        print("📲 NOTIFY: Sending partner invitation notification with ID: \(notificationId)")
        
        sendNotification(to: userId, payload: payload)
    }
    
    /// Send a notification when a user accepts a partner invitation
    /// - Parameters:
    ///   - userId: ID of the user to send the notification to
    ///   - accepterName: Name of the user who accepted the invitation
    ///   - relationshipID: ID of the newly created relationship
    func sendPartnerInvitationAcceptedNotification(to userId: String, from accepterName: String, relationshipID: String) async throws {
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
        
        print("📲 NOTIFY: Sending partner invitation accepted notification with ID: \(notificationId)")
        
        sendNotification(to: userId, payload: payload)
    }
    
    /// Send a notification when a user declines a partner invitation
    /// - Parameters:
    ///   - userId: ID of the user to send the notification to
    ///   - declinerName: Name of the user who declined the invitation
    func sendPartnerInvitationDeclinedNotification(to userId: String, from declinerName: String) async throws {
        let notificationId = "partner_invitation_declined_\(userId)_\(Date().timeIntervalSince1970)"
        
        let payload = createNotificationPayload(
            type: .partnerInvitationDeclined,
            title: "Partner Invitation Declined",
            body: "\(declinerName) has declined your partner invitation.",
            data: [
                "declinerName": declinerName,
                "notificationId": notificationId
            ]
        )
        
        print("📲 NOTIFY: Sending partner invitation declined notification with ID: \(notificationId)")
        
        sendNotification(to: userId, payload: payload)
    }
    
    /// Send a notification when a relationship is terminated
    /// - Parameters:
    ///   - userId: ID of the user to send the notification to
    ///   - terminatorName: Name of the user who terminated the relationship
    func sendRelationshipTerminatedNotification(to userId: String, from terminatorName: String) async throws {
        let notificationId = "relationship_terminated_\(userId)_\(Date().timeIntervalSince1970)"
        
        let payload = createNotificationPayload(
            type: .relationshipTerminated,
            title: "Relationship Ended",
            body: "\(terminatorName) has ended your partnership.",
            data: [
                "terminatorName": terminatorName,
                "notificationId": notificationId
            ]
        )
        
        print("📲 NOTIFY: Sending relationship terminated notification with ID: \(notificationId)")
        
        sendNotification(to: userId, payload: payload)
    }
    
    /// Send notification when a hangout has a calendar conflict
    /// - Parameters:
    ///   - userId: ID of the user to send the notification to
    ///   - userName: Name of the user who has the conflict
    ///   - hangoutTitle: Title of the hangout
    ///   - hangoutId: ID of the hangout
    func sendHangoutConflictNotification(to userId: String, userName: String, hangoutTitle: String, hangoutId: String) async throws {
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
        
        print("📲 NOTIFY: Sending hangout conflict notification with ID: \(notificationId)")
        
        sendNotification(to: userId, payload: payload)
    }
    
    /// Send a notification when a relationship is created
    /// - Parameters:
    ///   - userId: ID of the user to send the notification to
    ///   - partnerName: Name of the partner
    func sendRelationshipCreatedNotification(to userId: String, partnerName: String) async throws {
        let notificationId = "relationship_created_\(userId)_\(Date().timeIntervalSince1970)"
        
        let payload = createNotificationPayload(
            type: .partnerInvitationAccepted, // Reusing this type since it's closest
            title: "Relationship Created",
            body: "You are now in a relationship with \(partnerName)!",
            data: [
                "partnerName": partnerName,
                "notificationId": notificationId
            ]
        )
        
        print("📲 NOTIFY: Sending relationship created notification with ID: \(notificationId)")
        
        sendNotification(to: userId, payload: payload)
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
    
    private func sendNotification(to userId: String, payload: [String: Any]) {
        // Get the user's FCM token
        print("🔎 NOTIFY: Retrieving FCM token for user: \(userId)")
        print("🔎 NOTIFY: Current auth user: \(Auth.auth().currentUser?.uid ?? "none")")
        
        Task {
            do {
                // Get user document using CRUDService instead of direct Firestore access
                guard let userData = try await crudService.fetchData("users/\(userId)") as? [String: Any] else {
                    print("❌ NOTIFY: User document not found or has no data for ID: \(userId)")
                    return
                }
                
                guard let fcmToken = userData["fcmToken"] as? String else {
                    print("❌ NOTIFY: Cannot send notification: FCM token not found for user \(userId)")
                    print("📋 NOTIFY: Available user data fields: \(userData.keys.joined(separator: ", "))")
                    if let email = userData["email"] as? String {
                        print("📧 NOTIFY: User email: \(email)")
                    }
                    return
                }
                
                // Send notification via Firebase Cloud Functions
                print("📲 NOTIFY: Sending notification to token: \(String(fcmToken.prefix(10)))...")
                print("📲 NOTIFY: Notification type: \((payload["data"] as? [String: Any])?["type"] as? String ?? "unknown")")
                
                let functions = Functions.functions()
                functions.httpsCallable("sendPushNotification").call(["token": fcmToken, "payload": payload]) { result, error in
                    if let error = error {
                        print("❌ NOTIFY: Error sending notification: \(error.localizedDescription)")
                        if let nsError = error as NSError? {
                            print("❌ NOTIFY: Error details - Code: \(nsError.code), Domain: \(nsError.domain)")
                            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                                print("❌ NOTIFY: Underlying error - \(underlyingError)")
                            }
                        }
                    } else {
                        print("✅ NOTIFY: Push notification sent successfully via Firebase")
                        if let resultData = result?.data as? [String: Any] {
                            print("✅ NOTIFY: Result data: \(resultData)")
                        }
                    }
                }
            } catch {
                print("❌ NOTIFY: Error fetching user document: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Local Notifications (for testing)
    
    func postLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        //content.sound = .default
        
        // Add a category identifier for notification actions
        content.categoryIdentifier = "HANGOUT_INVITATION"
        
        // Create a unique identifier for this notification
        let identifier = UUID().uuidString
        
        // Create a trigger - 1 second delay for testing
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create a request with the content and trigger
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        // Add notification actions if appropriate
        addNotificationActions()
        
        // Add the request to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error posting local notification: \(error.localizedDescription)")
            } else {
                print("✅ Local notification scheduled successfully with ID: \(identifier)")
            }
        }
        
        // For testing/demo purposes, if app is in foreground, also show an alert
        // In a real app, the UNUserNotificationCenterDelegate handles this
        if UIApplication.shared.applicationState == .active {
            print("📱 App is active - notification would appear as banner")
        }
    }
    
    // Add notification action buttons
    private func addNotificationActions() {
        // Accept action
        let acceptAction = UNNotificationAction(
            identifier: "ACCEPT_ACTION",
            title: "Accept",
            options: [.foreground]
        )
        
        // Decline action
        let declineAction = UNNotificationAction(
            identifier: "DECLINE_ACTION",
            title: "Decline",
            options: [.destructive, .foreground]
        )
        
        // Create category with actions
        let hangoutCategory = UNNotificationCategory(
            identifier: "HANGOUT_INVITATION",
            actions: [acceptAction, declineAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register the category
        UNUserNotificationCenter.current().setNotificationCategories([hangoutCategory])
    }
    
    // Function to display a test notification immediately
    func sendTestNotification() {
        // First check notification authorization status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:
                    print("✅ Notifications are authorized")
                    self.proceedWithTestNotification()
                case .denied:
                    print("❌ Notifications are denied by user")
                    // Show an alert to the user
                    self.showPermissionAlert(message: "Notifications are disabled. Please enable them in Settings to receive push notifications.")
                case .notDetermined:
                    print("⚠️ Notification permission not determined")
                    // Request permission
                    self.requestNotificationPermission()
                case .provisional, .ephemeral:
                    print("ℹ️ Notifications have provisional/ephemeral permission")
                    self.proceedWithTestNotification()
                @unknown default:
                    print("❓ Unknown notification authorization status")
                    self.proceedWithTestNotification()
                }
            }
        }
    }
    
    private func proceedWithTestNotification() {
        // No longer sending local notification for immediate feedback
        print("🧪 Testing Firebase Cloud Messaging...")
        
        // Verify FCM token exists
        if let userId = Auth.auth().currentUser?.uid {
            // Check if token is saved in Firestore using CRUDService
            Task {
                do {
                    guard let userData = try await crudService.fetchData("users/\(userId)") as? [String: Any],
                          let fcmToken = userData["fcmToken"] as? String else {
                        print("⚠️ No FCM token found in Firestore. Attempting to save current token...")
                        
                        // Try to get and save the current token
                        if let token = Messaging.messaging().fcmToken {
                            print("ℹ️ Current FCM token: \(token)")
                            self.saveDeviceToken(token)
                        } else {
                            print("❌ No FCM token available from Messaging.messaging().fcmToken")
                        }
                        return
                    }
                    
                    print("✅ FCM token found in Firestore: \(fcmToken)")
                    
                    // Test Firebase Cloud Function connectivity
                    self.testCloudFunction(fcmToken: fcmToken)
                } catch {
                    print("❌ Error checking FCM token in Firestore: \(error.localizedDescription)")
                }
            }
        } else {
            print("❌ User not logged in, cannot test cloud function")
        }
    }
    
    private func testCloudFunction(fcmToken: String) {
        // Prepare a test payload
        let payload: [String: Any] = [
            "notification": [
                "title": "Firebase Cloud Function Test",
                "body": "This notification was sent via Firebase Cloud Functions!"
            ],
            "data": [
                "type": "test_notification",
                "timestamp": "\(Date().timeIntervalSince1970)"
            ]
        ]
        
        // Call the cloud function
        let functions = Functions.functions()
        functions.httpsCallable("sendPushNotification").call([
            "token": fcmToken,
            "payload": payload
        ]) { result, error in
            if let error = error {
                print("❌ Cloud function error: \(error.localizedDescription)")
                
                // Try to ping function to check if it's deployed
                self.pingFunction()
            } else {
                print("✅ Cloud function successfully called!")
                print("✅ Result: \(String(describing: result?.data))")
                print("✅ A push notification should arrive shortly...")
            }
        }
    }
    
    private func pingFunction() {
        let functions = Functions.functions()
        functions.httpsCallable("ping").call() { result, error in
            if let error = error {
                print("❌ Ping failed: \(error.localizedDescription)")
                print("❌ Make sure you have deployed the Firebase Cloud Functions")
                print("❌ Run 'firebase deploy --only functions' in your functions directory")
            } else {
                print("✅ Ping succeeded! Functions are deployed correctly.")
                print("✅ Result: \(String(describing: result?.data))")
                print("❌ There may be an issue with the sendPushNotification function specifically.")
            }
        }
    }
    
    private func requestNotificationPermission() {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error requesting notification permissions: \(error.localizedDescription)")
                }
                
                if granted {
                    print("✅ Notification permission granted")
                    UIApplication.shared.registerForRemoteNotifications()
                    self.proceedWithTestNotification()
                } else {
                    print("❌ Notification permission denied")
                    self.showPermissionAlert(message: "Push notifications were not enabled. You won't receive notifications about new hangout requests.")
                }
            }
        }
    }
    
    private func showPermissionAlert(message: String) {
        // We can't show an alert directly from this service
        // Post a notification to be handled by the UI
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowNotificationPermissionAlert"),
            object: nil,
            userInfo: ["message": message]
        )
        
        // Also print to console for debugging
        print("⚠️ Notification permission alert: \(message)")
    }
    
    func scheduleLocalNotification(title: String, body: String, userInfo: [String: Any] = [:], delay: TimeInterval = 0) {
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
    
    func scheduleHangoutNotification(hangoutTitle: String, partnerName: String, date: Date, hangoutId: String) {
        // Create notification content
        let title = "Upcoming Hangout"
        let body = "Your hangout '\(hangoutTitle)' with \(partnerName) is coming up!"
        let userInfo = ["hangoutID": hangoutId]
        
        // Calculate delay (5 minutes before the hangout)
        let delay = max(0, date.timeIntervalSinceNow - 5 * 60)
        
        // Schedule notification
        scheduleLocalNotification(title: title, body: body, userInfo: userInfo, delay: delay)
    }
    
    func cancelNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - Test Functions
    
    func testPokeNotification() {
        print("🧪 POKE: Running poke notification test...")
        
        // First check if the user is logged in
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ POKE TEST: Error - User not logged in")
            return
        }
        
        print("✅ POKE TEST: User logged in: \(userId)")
        print("🧪 POKE TEST: Testing Firebase connection...")
        
        // Check if Firebase is configured
        if FirebaseApp.app() != nil {
            print("✅ POKE TEST: Firebase is configured")
        } else {
            print("❌ POKE TEST: Firebase is NOT configured")
            return
        }
        
        // Check if Firebase Cloud Functions are available
        let functions = Functions.functions()
        functions.httpsCallable("ping").call() { result, error in
            if let error = error {
                print("❌ POKE TEST: Firebase Cloud Functions error: \(error.localizedDescription)")
                print("❌ POKE TEST: Make sure you have deployed the 'ping' function")
                
                let nsError = error as NSError
                print("❌ POKE TEST: Error details - Domain: \(nsError.domain), Code: \(nsError.code)")
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    print("❌ POKE TEST: Underlying error - \(underlyingError)")
                }
                
                // Try calling sendPushNotification to see if it exists
                print("🧪 POKE TEST: Trying sendPushNotification function directly...")
                self.testSendPushNotificationFunction()
            } else {
                print("✅ POKE TEST: Firebase Cloud Functions are available!")
                print("✅ POKE TEST: Response: \(String(describing: result?.data))")
                
                // If ping works, test the FCM token
                self.testFCMToken(for: userId)
            }
        }
    }
    
    private func testSendPushNotificationFunction() {
        let functions = Functions.functions()
        functions.httpsCallable("sendPushNotification").call(["test": true]) { result, error in
            if let error = error {
                print("❌ POKE TEST: sendPushNotification function error: \(error.localizedDescription)")
                print("❌ POKE TEST: Make sure you have deployed the sendPushNotification function")
            } else {
                print("✅ POKE TEST: sendPushNotification function exists!")
                print("✅ POKE TEST: Response: \(String(describing: result?.data))")
            }
        }
    }
    
    private func testFCMToken(for userId: String) {
        print("🧪 POKE TEST: Testing FCM token for user \(userId)...")
        
        // Check if current FCM token is available
        if let token = Messaging.messaging().fcmToken {
            print("✅ POKE TEST: Current FCM token is available: \(String(token.prefix(10)))...")
        } else {
            print("❌ POKE TEST: Current FCM token is NOT available")
        }
        
        // Check if token is saved in Firestore using CRUDService
        Task {
            do {
                guard let userData = try await crudService.fetchData("users/\(userId)") as? [String: Any] else {
                    print("❌ POKE TEST: User document not found or has no data for ID: \(userId)")
                    return
                }
                
                if let fcmToken = userData["fcmToken"] as? String {
                    print("✅ POKE TEST: FCM token found in Firestore: \(String(fcmToken.prefix(10)))...")
                    
                    // Test sending a notification to self
                    self.testSendSelfNotification(userId: userId, fcmToken: fcmToken)
                } else {
                    print("❌ POKE TEST: FCM token NOT found in Firestore")
                    print("📋 POKE TEST: Available user data fields: \(userData.keys.joined(separator: ", "))")
                    
                    // Try to save current token
                    if let token = Messaging.messaging().fcmToken {
                        print("🧪 POKE TEST: Attempting to save current token...")
                        self.saveDeviceToken(token)
                    }
                }
            } catch {
                print("❌ POKE TEST: Error fetching user document: \(error.localizedDescription)")
            }
        }
    }
    
    private func testSendSelfNotification(userId: String, fcmToken: String) {
        print("🧪 POKE TEST: Testing sending notification to self...")
        
        // Create test payload
        let payload: [String: Any] = [
            "notification": [
                "title": "Test Poke Notification",
                "body": "This is a test notification to verify the poke feature!",
                "sound": "default"
            ],
            "data": [
                "type": "poke_notification",
                "test": "true"
            ] as [String: Any]
        ]
        
        // Send via Cloud Functions
        let functions = Functions.functions()
        functions.httpsCallable("sendPushNotification").call(["token": fcmToken, "payload": payload]) { result, error in
            if let error = error {
                print("❌ POKE TEST: Error sending test notification: \(error.localizedDescription)")
                print("❌ POKE TEST: Falling back to local notification for testing")
                
                // Send a local notification as fallback
                self.postLocalNotification(title: "Test Poke (Local)", body: "This is a local test notification")
            } else {
                print("✅ POKE TEST: Test notification sent successfully!")
                print("✅ POKE TEST: Result: \(String(describing: result?.data))")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // For foreground notifications - show banner, play sound, and update badge
        // iOS 14 and later supports .banner (iOS 13 used .alert)
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
        print("🔔 Notification will be presented while app is in foreground")
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        print("🔔 Notification response received: \(response.actionIdentifier)")
        print("🔔 Notification userInfo: \(userInfo)")
        
        // Extract hangout ID if available
        let hangoutId = (userInfo["hangoutId"] as? String) ?? 
                        (userInfo["data"] as? [String: Any])?["hangoutId"] as? String
        
        // Handle custom actions
        if response.actionIdentifier == "ACCEPT_ACTION" {
            print("🔔 User tapped Accept button")
            if let hangoutId = hangoutId {
                // Handle the accept action
                handleNotificationAction(actionIdentifier: "ACCEPT_ACTION", hangoutId: hangoutId)
            }
        } else if response.actionIdentifier == "DECLINE_ACTION" {
            print("🔔 User tapped Decline button")
            if let hangoutId = hangoutId {
                // Handle the decline action
                handleNotificationAction(actionIdentifier: "DECLINE_ACTION", hangoutId: hangoutId)
            }
        } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // Standard tap on notification (not on an action button)
            if let notificationType = (userInfo["type"] as? String) ?? (userInfo["data"] as? [String: Any])?["type"] as? String,
               let hangoutId = hangoutId {
                print("🔔 Notification tapped: Type=\(notificationType), HangoutId=\(hangoutId)")
                
                // Here you would navigate to the appropriate screen
                // Since we don't have direct access to the navigation stack, we'll post a notification
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenHangoutFromNotification"),
                    object: nil,
                    userInfo: ["hangoutId": hangoutId]
                )
            }
        }
        
        completionHandler()
    }
}

// MARK: - MessagingDelegate
extension NotificationService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            print("✅ Firebase registration token: \(token)")
            saveDeviceToken(token)
        } else {
            print("❌ FCM token is nil")
        }
    }
} 
