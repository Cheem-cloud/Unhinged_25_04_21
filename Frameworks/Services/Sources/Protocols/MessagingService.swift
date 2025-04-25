import Foundation

/// Protocol defining operations for in-app messaging functionality
public protocol MessagingService {
    /// Sends a direct message to another user
    /// - Parameters:
    ///   - content: Content of the message
    ///   - senderId: ID of the sender
    ///   - receiverId: ID of the receiver
    ///   - metadata: Optional metadata for the message
    /// - Returns: ID of the newly created message
    func sendMessage(_ content: MessageContent, from senderId: String, to receiverId: String, metadata: [String: Any]?) async throws -> String
    
    /// Retrieves messages between two users
    /// - Parameters:
    ///   - userId1: First user ID
    ///   - userId2: Second user ID
    ///   - limit: Maximum number of messages to retrieve
    ///   - before: Optional timestamp to retrieve messages before
    /// - Returns: Array of messages between the users
    func getMessages(between userId1: String, and userId2: String, limit: Int, before: Date?) async throws -> [Message]
    
    /// Retrieves all conversations for a user
    /// - Parameters:
    ///   - userId: The user ID to get conversations for
    ///   - limit: Maximum number of conversations to retrieve
    /// - Returns: Array of conversations the user is part of
    func getConversations(for userId: String, limit: Int) async throws -> [Conversation]
    
    /// Marks messages as read
    /// - Parameters:
    ///   - messageIds: Array of message IDs to mark as read
    ///   - userId: ID of the user marking the messages as read
    func markMessagesAsRead(_ messageIds: [String], by userId: String) async throws
    
    /// Gets the unread message count for a user
    /// - Parameter userId: The user ID to check
    /// - Returns: Count of unread messages
    func getUnreadMessageCount(for userId: String) async throws -> Int
    
    /// Creates a group conversation
    /// - Parameters:
    ///   - name: Name of the group
    ///   - creatorId: ID of the user creating the group
    ///   - participantIds: IDs of the initial participants
    ///   - metadata: Optional metadata for the group
    /// - Returns: ID of the newly created group
    func createGroupConversation(name: String, creatorId: String, participantIds: [String], metadata: [String: Any]?) async throws -> String
    
    /// Sends a message to a group
    /// - Parameters:
    ///   - content: Content of the message
    ///   - senderId: ID of the sender
    ///   - groupId: ID of the group
    ///   - metadata: Optional metadata for the message
    /// - Returns: ID of the newly created message
    func sendGroupMessage(_ content: MessageContent, from senderId: String, to groupId: String, metadata: [String: Any]?) async throws -> String
    
    /// Gets messages from a group conversation
    /// - Parameters:
    ///   - groupId: ID of the group
    ///   - limit: Maximum number of messages to retrieve
    ///   - before: Optional timestamp to retrieve messages before
    /// - Returns: Array of messages in the group
    func getGroupMessages(groupId: String, limit: Int, before: Date?) async throws -> [Message]
    
    /// Adds users to a group conversation
    /// - Parameters:
    ///   - userIds: IDs of users to add
    ///   - groupId: ID of the group to add to
    ///   - addedBy: ID of the user adding the new members
    func addUsersToGroup(_ userIds: [String], groupId: String, addedBy: String) async throws
    
    /// Removes users from a group conversation
    /// - Parameters:
    ///   - userIds: IDs of users to remove
    ///   - groupId: ID of the group to remove from
    ///   - removedBy: ID of the user removing the members
    func removeUsersFromGroup(_ userIds: [String], groupId: String, removedBy: String) async throws
    
    /// Updates group conversation details
    /// - Parameters:
    ///   - groupId: ID of the group to update
    ///   - name: Optional new name for the group
    ///   - metadata: Optional new metadata for the group
    ///   - updatedBy: ID of the user making the update
    func updateGroupConversation(groupId: String, name: String?, metadata: [String: Any]?, updatedBy: String) async throws
    
    /// Deletes a message
    /// - Parameters:
    ///   - messageId: ID of the message to delete
    ///   - deletedBy: ID of the user deleting the message
    func deleteMessage(_ messageId: String, deletedBy: String) async throws
    
    /// Checks if a user is typing in a conversation
    /// - Parameters:
    ///   - userId: ID of the user who is typing
    ///   - conversationId: ID of the conversation
    ///   - isTyping: Whether the user is typing or stopped typing
    func setTypingStatus(userId: String, in conversationId: String, isTyping: Bool) async throws
    
    /// Gets users who are currently typing in a conversation
    /// - Parameter conversationId: ID of the conversation
    /// - Returns: Array of user IDs who are typing
    func getTypingUsers(in conversationId: String) async throws -> [String]
}

/// Represents a message in the system
public struct Message: Codable, Identifiable {
    /// Unique identifier for the message
    public var id: String?
    
    /// Content of the message
    public var content: MessageContent
    
    /// ID of the sender
    public var senderId: String
    
    /// ID of the receiver (for direct messages) or group
    public var receiverId: String?
    
    /// ID of the group (for group messages)
    public var groupId: String?
    
    /// When the message was sent
    public var sentAt: Date
    
    /// When the message was delivered to the recipient
    public var deliveredAt: Date?
    
    /// Map of user IDs to when they read the message
    public var readBy: [String: Date]?
    
    /// Whether the message has been deleted
    public var isDeleted: Bool
    
    /// Additional metadata for the message
    public var metadata: [String: Any]?
    
    /// Type of message (direct, group, system)
    public var messageType: MessageType
    
    public init(
        id: String? = nil,
        content: MessageContent,
        senderId: String,
        receiverId: String? = nil,
        groupId: String? = nil,
        sentAt: Date = Date(),
        deliveredAt: Date? = nil,
        readBy: [String: Date]? = nil,
        isDeleted: Bool = false,
        metadata: [String: Any]? = nil,
        messageType: MessageType = .direct
    ) {
        self.id = id
        self.content = content
        self.senderId = senderId
        self.receiverId = receiverId
        self.groupId = groupId
        self.sentAt = sentAt
        self.deliveredAt = deliveredAt
        self.readBy = readBy
        self.isDeleted = isDeleted
        self.metadata = metadata
        self.messageType = messageType
    }
}

/// Content of a message with various types
public struct MessageContent: Codable {
    /// Type of content
    public var type: MessageContentType
    
    /// Text content of the message (if applicable)
    public var text: String?
    
    /// URL of media content (if applicable)
    public var mediaUrl: String?
    
    /// Type of media (if applicable)
    public var mediaType: MediaType?
    
    /// URL of a thumbnail for media (if applicable)
    public var thumbnailUrl: String?
    
    /// Additional data specific to the content type
    public var data: [String: String]?
    
    public init(
        type: MessageContentType,
        text: String? = nil,
        mediaUrl: String? = nil,
        mediaType: MediaType? = nil,
        thumbnailUrl: String? = nil,
        data: [String: String]? = nil
    ) {
        self.type = type
        self.text = text
        self.mediaUrl = mediaUrl
        self.mediaType = mediaType
        self.thumbnailUrl = thumbnailUrl
        self.data = data
    }
}

/// Types of message content
public enum MessageContentType: String, Codable {
    case text = "text"
    case image = "image"
    case video = "video"
    case audio = "audio"
    case file = "file"
    case location = "location"
    case contact = "contact"
    case custom = "custom"
}

/// Types of media
public enum MediaType: String, Codable {
    case image = "image"
    case video = "video"
    case audio = "audio"
    case document = "document"
    case other = "other"
}

/// Types of messages
public enum MessageType: String, Codable {
    case direct = "direct"
    case group = "group"
    case system = "system"
}

/// Represents a conversation between users
public struct Conversation: Codable, Identifiable {
    /// Unique identifier for the conversation
    public var id: String?
    
    /// For group conversations, the name of the group
    public var name: String?
    
    /// IDs of the participants in the conversation
    public var participantIds: [String]
    
    /// ID of the user who created the group (for group conversations)
    public var creatorId: String?
    
    /// Whether this is a group conversation
    public var isGroup: Bool
    
    /// ID of the most recent message in the conversation
    public var lastMessageId: String?
    
    /// Content of the last message for preview
    public var lastMessagePreview: String?
    
    /// When the last message was sent
    public var lastMessageAt: Date?
    
    /// Map of user IDs to counts of unread messages
    public var unreadCounts: [String: Int]?
    
    /// When the conversation was created
    public var createdAt: Date
    
    /// Additional metadata for the conversation
    public var metadata: [String: Any]?
    
    public init(
        id: String? = nil,
        name: String? = nil,
        participantIds: [String],
        creatorId: String? = nil,
        isGroup: Bool = false,
        lastMessageId: String? = nil,
        lastMessagePreview: String? = nil,
        lastMessageAt: Date? = nil,
        unreadCounts: [String: Int]? = nil,
        createdAt: Date = Date(),
        metadata: [String: Any]? = nil
    ) {
        self.id = id
        self.name = name
        self.participantIds = participantIds
        self.creatorId = creatorId
        self.isGroup = isGroup
        self.lastMessageId = lastMessageId
        self.lastMessagePreview = lastMessagePreview
        self.lastMessageAt = lastMessageAt
        self.unreadCounts = unreadCounts
        self.createdAt = createdAt
        self.metadata = metadata
    }
} 