import Foundation

/// Protocol defining operations for managing user feedback within the application
public protocol FeedbackService {
    /// Submits new feedback from a user
    /// - Parameters:
    ///   - feedback: The feedback content to submit
    ///   - userID: The ID of the user submitting the feedback
    /// - Returns: The ID of the newly created feedback entry
    func submitFeedback(_ feedback: FeedbackItem, from userID: String) async throws -> String
    
    /// Retrieves all feedback submitted by a specific user
    /// - Parameter userID: The ID of the user whose feedback to retrieve
    /// - Returns: Array of feedback items submitted by the user
    func getUserFeedback(for userID: String) async throws -> [FeedbackItem]
    
    /// Retrieves all feedback with a specific status
    /// - Parameter status: The status of feedback to retrieve
    /// - Returns: Array of feedback items with the specified status
    func getFeedbackByStatus(_ status: FeedbackStatus) async throws -> [FeedbackItem]
    
    /// Updates the status of a feedback item
    /// - Parameters:
    ///   - feedbackID: The ID of the feedback to update
    ///   - status: The new status for the feedback
    func updateFeedbackStatus(feedbackID: String, status: FeedbackStatus) async throws
    
    /// Adds an admin response to a feedback item
    /// - Parameters:
    ///   - feedbackID: The ID of the feedback to respond to
    ///   - response: The admin response text
    ///   - adminID: The ID of the admin user providing the response
    func addResponseToFeedback(feedbackID: String, response: String, adminID: String) async throws
    
    /// Deletes a feedback item
    /// - Parameter feedbackID: The ID of the feedback to delete
    func deleteFeedback(feedbackID: String) async throws
    
    /// Retrieves analytics data about feedback
    /// - Returns: Summary statistics about feedback
    func getFeedbackAnalytics() async throws -> FeedbackAnalytics
}

/// Represents a user feedback item
public struct FeedbackItem: Codable, Identifiable {
    /// Unique identifier for the feedback
    public var id: String?
    
    /// The user who submitted the feedback
    public var userID: String
    
    /// Type of feedback
    public var type: FeedbackType
    
    /// Content of the feedback
    public var content: String
    
    /// Optional app screen where feedback was submitted
    public var appScreen: String?
    
    /// Optional app version when feedback was submitted
    public var appVersion: String?
    
    /// Current status of the feedback
    public var status: FeedbackStatus
    
    /// When the feedback was submitted
    public var createdAt: Date
    
    /// When the feedback was last updated
    public var updatedAt: Date
    
    /// Optional admin response to the feedback
    public var adminResponse: AdminResponse?
    
    /// Optional attachment URLs (e.g., screenshots)
    public var attachments: [String]?
    
    /// App platform (iOS, iPadOS, etc.)
    public var platform: String?
    
    /// Device model
    public var deviceModel: String?
    
    public init(
        id: String? = nil,
        userID: String,
        type: FeedbackType,
        content: String,
        appScreen: String? = nil,
        appVersion: String? = nil,
        status: FeedbackStatus = .submitted,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        adminResponse: AdminResponse? = nil,
        attachments: [String]? = nil,
        platform: String? = nil,
        deviceModel: String? = nil
    ) {
        self.id = id
        self.userID = userID
        self.type = type
        self.content = content
        self.appScreen = appScreen
        self.appVersion = appVersion
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.adminResponse = adminResponse
        self.attachments = attachments
        self.platform = platform
        self.deviceModel = deviceModel
    }
}

/// Represents an admin response to feedback
public struct AdminResponse: Codable {
    /// Admin user ID who responded
    public var adminID: String
    
    /// Response content
    public var content: String
    
    /// When the response was created
    public var createdAt: Date
    
    public init(adminID: String, content: String, createdAt: Date = Date()) {
        self.adminID = adminID
        self.content = content
        self.createdAt = createdAt
    }
}

/// Types of feedback a user can submit
public enum FeedbackType: String, Codable, CaseIterable {
    case bug = "bug"
    case featureRequest = "feature_request"
    case improvement = "improvement"
    case generalFeedback = "general_feedback"
    case other = "other"
}

/// Status of feedback items
public enum FeedbackStatus: String, Codable, CaseIterable {
    case submitted = "submitted"
    case inReview = "in_review"
    case inProgress = "in_progress"
    case completed = "completed"
    case declined = "declined"
    case closed = "closed"
}

/// Analytics data for feedback reporting
public struct FeedbackAnalytics: Codable {
    /// Total number of feedback items
    public var totalCount: Int
    
    /// Feedback counts by type
    public var countsByType: [FeedbackType: Int]
    
    /// Feedback counts by status
    public var countsByStatus: [FeedbackStatus: Int]
    
    /// Average response time (in days)
    public var averageResponseTime: Double?
    
    /// Most common feedback categories
    public var topCategories: [String: Int]
    
    public init(
        totalCount: Int,
        countsByType: [FeedbackType: Int],
        countsByStatus: [FeedbackStatus: Int],
        averageResponseTime: Double? = nil,
        topCategories: [String: Int] = [:]
    ) {
        self.totalCount = totalCount
        self.countsByType = countsByType
        self.countsByStatus = countsByStatus
        self.averageResponseTime = averageResponseTime
        self.topCategories = topCategories
    }
} 