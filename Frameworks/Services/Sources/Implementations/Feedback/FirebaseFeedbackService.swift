import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

/// Firebase implementation of the FeedbackService protocol
public class FirebaseFeedbackService: FeedbackService {
    /// Firestore database reference
    private let db = Firestore.firestore()
    
    /// Reference to the feedback collection
    private var feedbackCollection: CollectionReference {
        return db.collection("feedback")
    }
    
    /// Initializes a new Firebase feedback service
    public init() {}
    
    /// Submits new feedback from a user
    /// - Parameters:
    ///   - feedback: The feedback content to submit
    ///   - userID: The ID of the user submitting the feedback
    /// - Returns: The ID of the newly created feedback entry
    public func submitFeedback(_ feedback: FeedbackItem, from userID: String) async throws -> String {
        var updatedFeedback = feedback
        updatedFeedback.userID = userID
        updatedFeedback.status = .submitted
        updatedFeedback.createdAt = Date()
        updatedFeedback.updatedAt = Date()
        
        do {
            let docRef = feedbackCollection.document()
            try docRef.setData(from: updatedFeedback)
            return docRef.documentID
        } catch {
            throw FeedbackError.submissionFailed(error.localizedDescription)
        }
    }
    
    /// Retrieves all feedback submitted by a specific user
    /// - Parameter userID: The ID of the user whose feedback to retrieve
    /// - Returns: Array of feedback items submitted by the user
    public func getUserFeedback(for userID: String) async throws -> [FeedbackItem] {
        do {
            let snapshot = try await feedbackCollection
                .whereField("userID", isEqualTo: userID)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                var feedback = try document.data(as: FeedbackItem.self)
                feedback.id = document.documentID
                return feedback
            }
        } catch {
            throw FeedbackError.retrievalFailed(error.localizedDescription)
        }
    }
    
    /// Retrieves all feedback with a specific status
    /// - Parameter status: The status of feedback to retrieve
    /// - Returns: Array of feedback items with the specified status
    public func getFeedbackByStatus(_ status: FeedbackStatus) async throws -> [FeedbackItem] {
        do {
            let snapshot = try await feedbackCollection
                .whereField("status", isEqualTo: status.rawValue)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                var feedback = try document.data(as: FeedbackItem.self)
                feedback.id = document.documentID
                return feedback
            }
        } catch {
            throw FeedbackError.retrievalFailed(error.localizedDescription)
        }
    }
    
    /// Updates the status of a feedback item
    /// - Parameters:
    ///   - feedbackID: The ID of the feedback to update
    ///   - status: The new status for the feedback
    public func updateFeedbackStatus(feedbackID: String, status: FeedbackStatus) async throws {
        do {
            try await feedbackCollection.document(feedbackID).updateData([
                "status": status.rawValue,
                "updatedAt": Date()
            ])
        } catch {
            throw FeedbackError.updateFailed(error.localizedDescription)
        }
    }
    
    /// Adds an admin response to a feedback item
    /// - Parameters:
    ///   - feedbackID: The ID of the feedback to respond to
    ///   - response: The admin response text
    ///   - adminID: The ID of the admin user providing the response
    public func addResponseToFeedback(feedbackID: String, response: String, adminID: String) async throws {
        let adminResponse = AdminResponse(adminID: adminID, content: response)
        
        do {
            // Convert to dictionary representation
            let encoder = Firestore.Encoder()
            let responseData = try encoder.encode(adminResponse)
            
            try await feedbackCollection.document(feedbackID).updateData([
                "adminResponse": responseData,
                "updatedAt": Date(),
                "status": FeedbackStatus.inReview.rawValue
            ])
        } catch {
            throw FeedbackError.responseFailed(error.localizedDescription)
        }
    }
    
    /// Deletes a feedback item
    /// - Parameter feedbackID: The ID of the feedback to delete
    public func deleteFeedback(feedbackID: String) async throws {
        do {
            try await feedbackCollection.document(feedbackID).delete()
        } catch {
            throw FeedbackError.deletionFailed(error.localizedDescription)
        }
    }
    
    /// Retrieves analytics data about feedback
    /// - Returns: Summary statistics about feedback
    public func getFeedbackAnalytics() async throws -> FeedbackAnalytics {
        do {
            let snapshot = try await feedbackCollection.getDocuments()
            let feedbackItems = try snapshot.documents.compactMap { document -> FeedbackItem? in
                var feedback = try document.data(as: FeedbackItem.self)
                feedback.id = document.documentID
                return feedback
            }
            
            // Calculate counts by type
            var countsByType: [FeedbackType: Int] = [:]
            for type in FeedbackType.allCases {
                countsByType[type] = feedbackItems.filter { $0.type == type }.count
            }
            
            // Calculate counts by status
            var countsByStatus: [FeedbackStatus: Int] = [:]
            for status in FeedbackStatus.allCases {
                countsByStatus[status] = feedbackItems.filter { $0.status == status }.count
            }
            
            // Calculate average response time
            var totalResponseTime: TimeInterval = 0
            var responseCount = 0
            
            for item in feedbackItems where item.adminResponse != nil {
                let responseTime = item.adminResponse!.createdAt.timeIntervalSince(item.createdAt)
                totalResponseTime += responseTime
                responseCount += 1
            }
            
            let averageResponseTime = responseCount > 0 ? (totalResponseTime / Double(responseCount)) / 86400 : nil // Convert to days
            
            // Extract top categories (from appScreen field)
            var categories: [String: Int] = [:]
            for item in feedbackItems {
                if let screen = item.appScreen {
                    categories[screen, default: 0] += 1
                }
            }
            
            // Sort and limit to top 5
            let topCategories = Dictionary(categories.sorted { $0.value > $1.value }.prefix(5)) { $0 }
            
            return FeedbackAnalytics(
                totalCount: feedbackItems.count,
                countsByType: countsByType,
                countsByStatus: countsByStatus,
                averageResponseTime: averageResponseTime,
                topCategories: topCategories
            )
        } catch {
            throw FeedbackError.analyticsFailure(error.localizedDescription)
        }
    }
}

/// Error types specific to feedback operations
public enum FeedbackError: Error {
    case submissionFailed(String)
    case retrievalFailed(String)
    case updateFailed(String)
    case responseFailed(String)
    case deletionFailed(String)
    case analyticsFailure(String)
    case invalidFeedback
}

extension FeedbackError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .submissionFailed(let message):
            return "Failed to submit feedback: \(message)"
        case .retrievalFailed(let message):
            return "Failed to retrieve feedback: \(message)"
        case .updateFailed(let message):
            return "Failed to update feedback status: \(message)"
        case .responseFailed(let message):
            return "Failed to add response to feedback: \(message)"
        case .deletionFailed(let message):
            return "Failed to delete feedback: \(message)"
        case .analyticsFailure(let message):
            return "Failed to generate feedback analytics: \(message)"
        case .invalidFeedback:
            return "The feedback item is invalid or malformed"
        }
    }
} 