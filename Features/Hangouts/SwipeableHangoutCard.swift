import SwiftUI
import FirebaseAuth

extension NotificationService {
    // Handle notification actions to accept or decline hangouts directly
    func handleNotificationAction(actionIdentifier: String, hangoutId: String) {
        print("🔔 Handling notification action: \(actionIdentifier) for hangout: \(hangoutId)")
        
        // Find the hangout and handle the action
        Task {
            do {
                // Get the current user ID
                guard let currentUserId = Auth.auth().currentUser?.uid else {
                    print("❌ Cannot handle notification action: No user logged in")
                    return
                }
                
                let firestoreService = FirestoreService()
                if let hangout = try await firestoreService.getHangout(hangoutId) {
                    // Verify that the current user is the invitee of this hangout
                    guard hangout.inviteeID == currentUserId else {
                        print("⚠️ Not processing notification action: Current user (\(currentUserId)) is not the invitee (\(hangout.inviteeID)) of this hangout")
                        return
                    }
                    
                    // Create the view model on the main actor
                    let hangoutsViewModel = await MainActor.run { HangoutsViewModel() }
                    
                    if actionIdentifier == "ACCEPT_ACTION" {
                        await hangoutsViewModel.updateHangoutStatus(hangout: hangout, newStatus: .accepted)
                        print("✅ Hangout accepted via notification: \(hangoutId)")
                        self.postLocalNotification(title: "Hangout Accepted", body: "You accepted the hangout request.")
                    } else if actionIdentifier == "DECLINE_ACTION" {
                        await hangoutsViewModel.updateHangoutStatus(hangout: hangout, newStatus: .declined)
                        print("❌ Hangout declined via notification: \(hangoutId)")
                        self.postLocalNotification(title: "Hangout Declined", body: "You declined the hangout request.")
                    }
                } else {
                    print("❌ Could not find hangout with ID: \(hangoutId)")
                }
            } catch {
                print("❌ Error handling notification action: \(error.localizedDescription)")
            }
        }
    }
} 