import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

/// Firebase implementation of the MessagingService protocol
public class FirebaseMessagingService: MessagingService {
    /// Firestore database reference
    private let db = Firestore.firestore()
    
    /// Reference to the messages collection
    private var messagesCollection: CollectionReference {
        return db.collection("messages")
    }
    
    /// Reference to the conversations collection
    private var conversationsCollection: CollectionReference {
        return db.collection("conversations")
    }
    
    /// Reference to the typing status collection
    private var typingStatusCollection: CollectionReference {
        return db.collection("typingStatus")
    }
    
    /// Initializes a new Firebase messaging service
    public init() {}
    
    /// Sends a direct message to another user
    /// - Parameters:
    ///   - content: Content of the message
    ///   - senderId: ID of the sender
    ///   - receiverId: ID of the receiver
    ///   - metadata: Optional metadata for the message
    /// - Returns: ID of the newly created message
    public func sendMessage(_ content: MessageContent, from senderId: String, to receiverId: String, metadata: [String: Any]?) async throws -> String {
        do {
            // First, ensure a conversation exists between these users
            let conversationId = try await getOrCreateDirectConversation(between: senderId, and: receiverId)
            
            // Create the message
            let message = Message(
                content: content,
                senderId: senderId,
                receiverId: receiverId,
                sentAt: Date(),
                readBy: [senderId: Date()], // Sender has read it
                metadata: metadata,
                messageType: .direct
            )
            
            // Save the message
            let messageRef = messagesCollection.document()
            try messageRef.setData(from: message)
            
            // Update the conversation with the latest message info
            let lastMessagePreview = generateMessagePreview(content)
            try await updateConversationWithLastMessage(
                conversationId: conversationId,
                messageId: messageRef.documentID,
                messagePreview: lastMessagePreview,
                senderId: senderId
            )
            
            return messageRef.documentID
        } catch {
            throw MessagingError.messageSendFailed(error.localizedDescription)
        }
    }
    
    /// Retrieves messages between two users
    /// - Parameters:
    ///   - userId1: First user ID
    ///   - userId2: Second user ID
    ///   - limit: Maximum number of messages to retrieve
    ///   - before: Optional timestamp to retrieve messages before
    /// - Returns: Array of messages between the users
    public func getMessages(between userId1: String, and userId2: String, limit: Int, before: Date?) async throws -> [Message] {
        do {
            var query = messagesCollection
                .whereField("messageType", isEqualTo: MessageType.direct.rawValue)
                .whereFilter(Filter.orFilter([
                    Filter.andFilter([
                        Filter.whereField("senderId", isEqualTo: userId1),
                        Filter.whereField("receiverId", isEqualTo: userId2)
                    ]),
                    Filter.andFilter([
                        Filter.whereField("senderId", isEqualTo: userId2),
                        Filter.whereField("receiverId", isEqualTo: userId1)
                    ])
                ]))
                .order(by: "sentAt", descending: true)
                .limit(to: limit)
            
            if let beforeDate = before {
                query = query.whereField("sentAt", isLessThan: beforeDate)
            }
            
            let snapshot = try await query.getDocuments()
            
            return try snapshot.documents.compactMap { document in
                var message = try document.data(as: Message.self)
                message.id = document.documentID
                return message
            }
        } catch {
            throw MessagingError.retrievalFailed(error.localizedDescription)
        }
    }
    
    /// Retrieves all conversations for a user
    /// - Parameters:
    ///   - userId: The user ID to get conversations for
    ///   - limit: Maximum number of conversations to retrieve
    /// - Returns: Array of conversations the user is part of
    public func getConversations(for userId: String, limit: Int) async throws -> [Conversation] {
        do {
            let snapshot = try await conversationsCollection
                .whereField("participantIds", arrayContains: userId)
                .order(by: "lastMessageAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                var conversation = try document.data(as: Conversation.self)
                conversation.id = document.documentID
                return conversation
            }
        } catch {
            throw MessagingError.retrievalFailed(error.localizedDescription)
        }
    }
    
    /// Marks messages as read
    /// - Parameters:
    ///   - messageIds: Array of message IDs to mark as read
    ///   - userId: ID of the user marking the messages as read
    public func markMessagesAsRead(_ messageIds: [String], by userId: String) async throws {
        do {
            // Get current timestamp
            let readAt = Date()
            
            // Batch update to mark all messages at once
            let batch = db.batch()
            
            for messageId in messageIds {
                let messageRef = messagesCollection.document(messageId)
                batch.updateData([
                    "readBy.\(userId)": readAt
                ], forDocument: messageRef)
            }
            
            // Commit the batch update
            try await batch.commit()
            
            // Update unread counts in conversations
            try await updateUnreadCountsForUser(userId)
        } catch {
            throw MessagingError.updateFailed(error.localizedDescription)
        }
    }
    
    /// Gets the unread message count for a user
    /// - Parameter userId: The user ID to check
    /// - Returns: Count of unread messages
    public func getUnreadMessageCount(for userId: String) async throws -> Int {
        do {
            // Get all conversations for the user
            let conversationSnapshot = try await conversationsCollection
                .whereField("participantIds", arrayContains: userId)
                .getDocuments()
            
            var totalUnread = 0
            
            // Sum up the unread counts for this user across all conversations
            for document in conversationSnapshot.documents {
                if let conversation = try? document.data(as: Conversation.self),
                   let unreadCounts = conversation.unreadCounts,
                   let userUnreadCount = unreadCounts[userId] {
                    totalUnread += userUnreadCount
                }
            }
            
            return totalUnread
        } catch {
            throw MessagingError.retrievalFailed(error.localizedDescription)
        }
    }
    
    /// Creates a group conversation
    /// - Parameters:
    ///   - name: Name of the group
    ///   - creatorId: ID of the user creating the group
    ///   - participantIds: IDs of the initial participants
    ///   - metadata: Optional metadata for the group
    /// - Returns: ID of the newly created group
    public func createGroupConversation(name: String, creatorId: String, participantIds: [String], metadata: [String: Any]?) async throws -> String {
        do {
            // Ensure the creator is in the participant list
            var allParticipants = participantIds
            if !allParticipants.contains(creatorId) {
                allParticipants.append(creatorId)
            }
            
            // Initialize unread counts at 0 for all participants
            var unreadCounts: [String: Int] = [:]
            for participantId in allParticipants {
                unreadCounts[participantId] = 0
            }
            
            // Create the conversation
            let conversation = Conversation(
                name: name,
                participantIds: allParticipants,
                creatorId: creatorId,
                isGroup: true,
                unreadCounts: unreadCounts,
                createdAt: Date(),
                metadata: metadata
            )
            
            // Save the conversation
            let conversationRef = conversationsCollection.document()
            try conversationRef.setData(from: conversation)
            
            // Create a system message announcing the group creation
            let systemMessage = Message(
                content: MessageContent(
                    type: .text,
                    text: "\(creatorId) created the group \"\(name)\""
                ),
                senderId: creatorId,
                groupId: conversationRef.documentID,
                sentAt: Date(),
                messageType: .system
            )
            
            // Save the system message
            let messageRef = messagesCollection.document()
            try messageRef.setData(from: systemMessage)
            
            return conversationRef.documentID
        } catch {
            throw MessagingError.groupCreationFailed(error.localizedDescription)
        }
    }
    
    /// Sends a message to a group
    /// - Parameters:
    ///   - content: Content of the message
    ///   - senderId: ID of the sender
    ///   - groupId: ID of the group
    ///   - metadata: Optional metadata for the message
    /// - Returns: ID of the newly created message
    public func sendGroupMessage(_ content: MessageContent, from senderId: String, to groupId: String, metadata: [String: Any]?) async throws -> String {
        do {
            // Verify the group exists and the sender is a participant
            let conversationSnapshot = try await conversationsCollection.document(groupId).getDocument()
            guard 
                let conversation = try? conversationSnapshot.data(as: Conversation.self),
                conversation.isGroup,
                conversation.participantIds.contains(senderId)
            else {
                throw MessagingError.invalidConversation
            }
            
            // Create the message
            let message = Message(
                content: content,
                senderId: senderId,
                groupId: groupId,
                sentAt: Date(),
                readBy: [senderId: Date()], // Sender has read it
                metadata: metadata,
                messageType: .group
            )
            
            // Save the message
            let messageRef = messagesCollection.document()
            try messageRef.setData(from: message)
            
            // Update the conversation with the latest message info
            let lastMessagePreview = generateMessagePreview(content)
            try await updateConversationWithLastMessage(
                conversationId: groupId,
                messageId: messageRef.documentID,
                messagePreview: lastMessagePreview,
                senderId: senderId
            )
            
            return messageRef.documentID
        } catch {
            throw MessagingError.messageSendFailed(error.localizedDescription)
        }
    }
    
    /// Gets messages from a group conversation
    /// - Parameters:
    ///   - groupId: ID of the group
    ///   - limit: Maximum number of messages to retrieve
    ///   - before: Optional timestamp to retrieve messages before
    /// - Returns: Array of messages in the group
    public func getGroupMessages(groupId: String, limit: Int, before: Date?) async throws -> [Message] {
        do {
            var query = messagesCollection
                .whereField("groupId", isEqualTo: groupId)
                .order(by: "sentAt", descending: true)
                .limit(to: limit)
            
            if let beforeDate = before {
                query = query.whereField("sentAt", isLessThan: beforeDate)
            }
            
            let snapshot = try await query.getDocuments()
            
            return try snapshot.documents.compactMap { document in
                var message = try document.data(as: Message.self)
                message.id = document.documentID
                return message
            }
        } catch {
            throw MessagingError.retrievalFailed(error.localizedDescription)
        }
    }
    
    /// Adds users to a group conversation
    /// - Parameters:
    ///   - userIds: IDs of users to add
    ///   - groupId: ID of the group to add to
    ///   - addedBy: ID of the user adding the new members
    public func addUsersToGroup(_ userIds: [String], groupId: String, addedBy: String) async throws {
        do {
            // Get the current conversation
            let conversationRef = conversationsCollection.document(groupId)
            let snapshot = try await conversationRef.getDocument()
            
            guard 
                var conversation = try? snapshot.data(as: Conversation.self),
                conversation.isGroup,
                conversation.participantIds.contains(addedBy) // Only participants can add others
            else {
                throw MessagingError.invalidConversation
            }
            
            // Filter out any users who are already in the group
            let newUsers = userIds.filter { !conversation.participantIds.contains($0) }
            if newUsers.isEmpty {
                return // No new users to add
            }
            
            // Update the participant list
            conversation.participantIds.append(contentsOf: newUsers)
            
            // Initialize unread counts for new participants
            if conversation.unreadCounts == nil {
                conversation.unreadCounts = [:]
            }
            
            for userId in newUsers {
                conversation.unreadCounts?[userId] = 0
            }
            
            // Update the conversation
            try conversationRef.setData(from: conversation)
            
            // Create a system message
            let userNames = newUsers.joined(separator: ", ")
            let systemMessage = Message(
                content: MessageContent(
                    type: .text,
                    text: "\(addedBy) added \(userNames) to the group"
                ),
                senderId: addedBy,
                groupId: groupId,
                sentAt: Date(),
                messageType: .system
            )
            
            // Save the system message
            let messageRef = messagesCollection.document()
            try messageRef.setData(from: systemMessage)
            
            // Update the conversation with the system message
            try await updateConversationWithLastMessage(
                conversationId: groupId,
                messageId: messageRef.documentID,
                messagePreview: "Added \(userNames) to the group",
                senderId: addedBy
            )
        } catch {
            throw MessagingError.groupUpdateFailed(error.localizedDescription)
        }
    }
    
    /// Removes users from a group conversation
    /// - Parameters:
    ///   - userIds: IDs of users to remove
    ///   - groupId: ID of the group to remove from
    ///   - removedBy: ID of the user removing the members
    public func removeUsersFromGroup(_ userIds: [String], groupId: String, removedBy: String) async throws {
        do {
            // Get the current conversation
            let conversationRef = conversationsCollection.document(groupId)
            let snapshot = try await conversationRef.getDocument()
            
            guard 
                var conversation = try? snapshot.data(as: Conversation.self),
                conversation.isGroup,
                conversation.participantIds.contains(removedBy) // Only participants can remove others
            else {
                throw MessagingError.invalidConversation
            }
            
            // Make sure we're not removing the creator
            if userIds.contains(conversation.creatorId ?? "") {
                throw MessagingError.cannotRemoveCreator
            }
            
            // Update the participant list
            conversation.participantIds.removeAll { userIds.contains($0) }
            
            // Remove unread counts for removed participants
            if conversation.unreadCounts != nil {
                for userId in userIds {
                    conversation.unreadCounts?.removeValue(forKey: userId)
                }
            }
            
            // Update the conversation
            try conversationRef.setData(from: conversation)
            
            // Create a system message
            let userNames = userIds.joined(separator: ", ")
            let systemMessage = Message(
                content: MessageContent(
                    type: .text,
                    text: "\(removedBy) removed \(userNames) from the group"
                ),
                senderId: removedBy,
                groupId: groupId,
                sentAt: Date(),
                messageType: .system
            )
            
            // Save the system message
            let messageRef = messagesCollection.document()
            try messageRef.setData(from: systemMessage)
            
            // Update the conversation with the system message
            try await updateConversationWithLastMessage(
                conversationId: groupId,
                messageId: messageRef.documentID,
                messagePreview: "Removed \(userNames) from the group",
                senderId: removedBy
            )
        } catch {
            throw MessagingError.groupUpdateFailed(error.localizedDescription)
        }
    }
    
    /// Updates group conversation details
    /// - Parameters:
    ///   - groupId: ID of the group to update
    ///   - name: Optional new name for the group
    ///   - metadata: Optional new metadata for the group
    ///   - updatedBy: ID of the user making the update
    public func updateGroupConversation(groupId: String, name: String?, metadata: [String: Any]?, updatedBy: String) async throws {
        do {
            // Get the current conversation
            let conversationRef = conversationsCollection.document(groupId)
            let snapshot = try await conversationRef.getDocument()
            
            guard 
                var conversation = try? snapshot.data(as: Conversation.self),
                conversation.isGroup,
                conversation.participantIds.contains(updatedBy) // Only participants can update
            else {
                throw MessagingError.invalidConversation
            }
            
            var updateData: [String: Any] = [:]
            var systemMessageText: String? = nil
            
            // Update name if provided
            if let newName = name, newName != conversation.name {
                updateData["name"] = newName
                conversation.name = newName
                systemMessageText = "\(updatedBy) renamed the group to \"\(newName)\""
            }
            
            // Update metadata if provided
            if let newMetadata = metadata {
                updateData["metadata"] = newMetadata
                conversation.metadata = newMetadata
                if systemMessageText == nil {
                    systemMessageText = "\(updatedBy) updated the group information"
                }
            }
            
            if !updateData.isEmpty {
                // Update the conversation
                try await conversationRef.updateData(updateData)
                
                // If there are changes, create a system message
                if let messageText = systemMessageText {
                    let systemMessage = Message(
                        content: MessageContent(
                            type: .text,
                            text: messageText
                        ),
                        senderId: updatedBy,
                        groupId: groupId,
                        sentAt: Date(),
                        messageType: .system
                    )
                    
                    // Save the system message
                    let messageRef = messagesCollection.document()
                    try messageRef.setData(from: systemMessage)
                    
                    // Update the conversation with the system message
                    try await updateConversationWithLastMessage(
                        conversationId: groupId,
                        messageId: messageRef.documentID,
                        messagePreview: messageText,
                        senderId: updatedBy
                    )
                }
            }
        } catch {
            throw MessagingError.groupUpdateFailed(error.localizedDescription)
        }
    }
    
    /// Deletes a message
    /// - Parameters:
    ///   - messageId: ID of the message to delete
    ///   - deletedBy: ID of the user deleting the message
    public func deleteMessage(_ messageId: String, deletedBy: String) async throws {
        do {
            // Get the message
            let messageRef = messagesCollection.document(messageId)
            let snapshot = try await messageRef.getDocument()
            
            guard let message = try? snapshot.data(as: Message.self) else {
                throw MessagingError.messageNotFound
            }
            
            // Only the sender or a group admin can delete a message
            if message.senderId != deletedBy {
                // For group messages, check if the user is the creator
                if message.messageType == .group, let groupId = message.groupId {
                    let conversationSnapshot = try await conversationsCollection.document(groupId).getDocument()
                    guard 
                        let conversation = try? conversationSnapshot.data(as: Conversation.self),
                        conversation.creatorId == deletedBy
                    else {
                        throw MessagingError.notAuthorized
                    }
                } else {
                    // For direct messages, only the sender can delete
                    throw MessagingError.notAuthorized
                }
            }
            
            // Mark as deleted rather than actually deleting
            try await messageRef.updateData([
                "isDeleted": true,
                "content.text": "This message was deleted"
            ])
            
            // If this was the last message in the conversation, update the preview
            let conversationId = message.groupId ?? try await getConversationId(between: message.senderId, and: message.receiverId ?? "")
            if conversationId.isEmpty {
                return // No conversation to update
            }
            
            let conversationSnapshot = try await conversationsCollection.document(conversationId).getDocument()
            if let conversation = try? conversationSnapshot.data(as: Conversation.self),
               conversation.lastMessageId == messageId {
                try await conversationsCollection.document(conversationId).updateData([
                    "lastMessagePreview": "This message was deleted"
                ])
            }
        } catch {
            throw MessagingError.deletionFailed(error.localizedDescription)
        }
    }
    
    /// Checks if a user is typing in a conversation
    /// - Parameters:
    ///   - userId: ID of the user who is typing
    ///   - conversationId: ID of the conversation
    ///   - isTyping: Whether the user is typing or stopped typing
    public func setTypingStatus(userId: String, in conversationId: String, isTyping: Bool) async throws {
        do {
            let typingStatusId = "\(conversationId)_\(userId)"
            let typingStatusRef = typingStatusCollection.document(typingStatusId)
            
            if isTyping {
                // User started typing - set status with current timestamp
                try await typingStatusRef.setData([
                    "userId": userId,
                    "conversationId": conversationId,
                    "timestamp": FieldValue.serverTimestamp(),
                    "isTyping": true
                ])
            } else {
                // User stopped typing - remove status
                try await typingStatusRef.delete()
            }
        } catch {
            throw MessagingError.typingStatusUpdateFailed(error.localizedDescription)
        }
    }
    
    /// Gets users who are currently typing in a conversation
    /// - Parameter conversationId: ID of the conversation
    /// - Returns: Array of user IDs who are typing
    public func getTypingUsers(in conversationId: String) async throws -> [String] {
        do {
            // Get typing statuses that are not older than 10 seconds
            let timestamp = Date(timeIntervalSinceNow: -10) // 10 seconds ago
            
            let snapshot = try await typingStatusCollection
                .whereField("conversationId", isEqualTo: conversationId)
                .whereField("isTyping", isEqualTo: true)
                .whereField("timestamp", isGreaterThan: timestamp)
                .getDocuments()
            
            // Extract user IDs
            return snapshot.documents.compactMap { document in
                document.data()["userId"] as? String
            }
        } catch {
            throw MessagingError.retrievalFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Gets or creates a direct conversation between two users
    /// - Parameters:
    ///   - userId1: First user ID
    ///   - userId2: Second user ID
    /// - Returns: The conversation ID
    private func getOrCreateDirectConversation(between userId1: String, and userId2: String) async throws -> String {
        // Try to find existing conversation
        let conversationId = try await getConversationId(between: userId1, and: userId2)
        if !conversationId.isEmpty {
            return conversationId
        }
        
        // No existing conversation, create one
        let participants = [userId1, userId2]
        let unreadCounts: [String: Int] = [
            userId1: 0,
            userId2: 0
        ]
        
        let conversation = Conversation(
            participantIds: participants,
            isGroup: false,
            unreadCounts: unreadCounts,
            createdAt: Date()
        )
        
        let conversationRef = conversationsCollection.document()
        try conversationRef.setData(from: conversation)
        
        return conversationRef.documentID
    }
    
    /// Gets the conversation ID between two users
    /// - Parameters:
    ///   - userId1: First user ID
    ///   - userId2: Second user ID
    /// - Returns: The conversation ID, or empty string if none exists
    private func getConversationId(between userId1: String, and userId2: String) async throws -> String {
        let snapshot = try await conversationsCollection
            .whereField("isGroup", isEqualTo: false)
            .whereField("participantIds", arrayContains: userId1)
            .getDocuments()
        
        for document in snapshot.documents {
            if let conversation = try? document.data(as: Conversation.self),
               conversation.participantIds.contains(userId2) {
                return document.documentID
            }
        }
        
        return ""
    }
    
    /// Updates a conversation with information about the last message
    /// - Parameters:
    ///   - conversationId: ID of the conversation to update
    ///   - messageId: ID of the last message
    ///   - messagePreview: Preview text of the last message
    ///   - senderId: ID of the user who sent the message
    private func updateConversationWithLastMessage(conversationId: String, messageId: String, messagePreview: String, senderId: String) async throws {
        let conversationRef = conversationsCollection.document(conversationId)
        
        // Get current conversation data to update unread counts
        let snapshot = try await conversationRef.getDocument()
        guard var conversation = try? snapshot.data(as: Conversation.self) else {
            throw MessagingError.invalidConversation
        }
        
        // Update unread counts (increment for all participants except sender)
        if conversation.unreadCounts == nil {
            conversation.unreadCounts = [:]
        }
        
        for participantId in conversation.participantIds {
            if participantId != senderId {
                conversation.unreadCounts?[participantId, default: 0] += 1
            }
        }
        
        // Update conversation with new message info
        try await conversationRef.updateData([
            "lastMessageId": messageId,
            "lastMessagePreview": messagePreview,
            "lastMessageAt": Date(),
            "unreadCounts": conversation.unreadCounts ?? [:] 
        ])
    }
    
    /// Updates unread counts for all conversations a user is part of
    /// - Parameter userId: The user ID
    private func updateUnreadCountsForUser(_ userId: String) async throws {
        // Get all conversations for the user
        let snapshot = try await conversationsCollection
            .whereField("participantIds", arrayContains: userId)
            .getDocuments()
        
        // Batch update to update all conversations at once
        let batch = db.batch()
        
        for document in snapshot.documents {
            batch.updateData([
                "unreadCounts.\(userId)": 0
            ], forDocument: document.reference)
        }
        
        // Commit the batch update
        try await batch.commit()
    }
    
    /// Generates a preview text for a message based on its content
    /// - Parameter content: The message content
    /// - Returns: A preview string for the message
    private func generateMessagePreview(_ content: MessageContent) -> String {
        switch content.type {
        case .text:
            return content.text ?? ""
        case .image:
            return "📷 Photo"
        case .video:
            return "🎥 Video"
        case .audio:
            return "🎵 Audio"
        case .file:
            return "📎 File"
        case .location:
            return "📍 Location"
        case .contact:
            return "👤 Contact"
        case .custom:
            return "Custom Message"
        }
    }
}

/// Errors specific to messaging operations
public enum MessagingError: Error {
    case messageSendFailed(String)
    case retrievalFailed(String)
    case updateFailed(String)
    case invalidConversation
    case conversationNotFound
    case messageNotFound
    case groupCreationFailed(String)
    case groupUpdateFailed(String)
    case cannotRemoveCreator
    case notAuthorized
    case deletionFailed(String)
    case typingStatusUpdateFailed(String)
    case invalidParameters(String)
}

extension MessagingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .messageSendFailed(let message):
            return "Failed to send message: \(message)"
        case .retrievalFailed(let message):
            return "Failed to retrieve data: \(message)"
        case .updateFailed(let message):
            return "Failed to update data: \(message)"
        case .invalidConversation:
            return "The conversation is invalid or you don't have access"
        case .conversationNotFound:
            return "Conversation not found"
        case .messageNotFound:
            return "Message not found"
        case .groupCreationFailed(let message):
            return "Failed to create group: \(message)"
        case .groupUpdateFailed(let message):
            return "Failed to update group: \(message)"
        case .cannotRemoveCreator:
            return "Cannot remove the creator from the group"
        case .notAuthorized:
            return "You are not authorized to perform this action"
        case .deletionFailed(let message):
            return "Failed to delete message: \(message)"
        case .typingStatusUpdateFailed(let message):
            return "Failed to update typing status: \(message)"
        case .invalidParameters(let message):
            return "Invalid parameters: \(message)"
        }
    }
} 