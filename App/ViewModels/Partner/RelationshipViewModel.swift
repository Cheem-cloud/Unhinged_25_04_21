import Foundation
import SwiftUI
import Combine

/// View model for managing partner relationships
public class RelationshipViewModel: ObservableObject {
    /// Published relationship data
    @Published public var relationship: Relationship?
    
    /// Published partner data
    @Published public var partner: AppUser?
    
    /// Published loading state
    @Published public var isLoading: Bool = false
    
    /// Published error state
    @Published public var error: Error?
    
    /// Published invitation state
    @Published public var invitationSent: Bool = false
    
    /// The current user ID
    private let currentUserID: String
    
    /// The relationship service
    private let relationshipService: RelationshipService
    
    /// The user service
    private let userService: UserService
    
    /// Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Initialize with user ID
    /// - Parameter userID: The current user ID
    public init(userID: String) {
        self.currentUserID = userID
        
        // Use the service manager to get services
        self.relationshipService = ServiceManager.shared.getService(RelationshipService.self)
        self.userService = ServiceManager.shared.getService(UserService.self)
        
        // Load relationship data when initialized
        loadRelationshipData()
    }
    
    /// Load relationship data for the current user
    public func loadRelationshipData() {
        isLoading = true
        
        Task {
            do {
                // Get the relationship for the current user
                if let relationship = try await relationshipService.getRelationshipForUser(userID: currentUserID) {
                    await MainActor.run {
                        self.relationship = relationship
                        self.isLoading = false
                    }
                    
                    // Get the partner user data
                    let partnerID = relationship.userIDs.first { $0 != currentUserID } ?? ""
                    
                    if !partnerID.isEmpty {
                        if let partner = try await userService.getUser(id: partnerID) {
                            await MainActor.run {
                                self.partner = partner
                            }
                        }
                    }
                } else {
                    await MainActor.run {
                        self.relationship = nil
                        self.partner = nil
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Send a partner invitation
    /// - Parameters:
    ///   - email: The partner's email
    ///   - message: Optional personal message
    public func invitePartner(email: String, message: String = "") {
        isLoading = true
        
        Task {
            do {
                try await relationshipService.invitePartner(partnerEmail: email, message: message)
                
                await MainActor.run {
                    self.invitationSent = true
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Accept a partner invitation
    /// - Parameter invitationID: The invitation ID
    public func acceptInvitation(invitationID: String) {
        isLoading = true
        
        Task {
            do {
                try await relationshipService.acceptPartnerInvitation(invitationID: invitationID)
                
                // Reload relationship data after accepting
                self.loadRelationshipData()
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Decline a partner invitation
    /// - Parameter invitationID: The invitation ID
    public func declineInvitation(invitationID: String) {
        isLoading = true
        
        Task {
            do {
                try await relationshipService.declinePartnerInvitation(invitationID: invitationID)
                
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Remove a partner relationship
    public func removePartner() {
        guard let relationshipID = relationship?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                try await relationshipService.removePartnerRelationship(relationshipID: relationshipID)
                
                await MainActor.run {
                    self.relationship = nil
                    self.partner = nil
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}

/// Model representing a relationship between users
public struct Relationship: Identifiable, Codable {
    public var id: String
    public var userIDs: [String]
    public var status: RelationshipStatus
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        userIDs: [String],
        status: RelationshipStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userIDs = userIDs
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public enum RelationshipStatus: String, Codable {
        case pending
        case active
        case paused
        case ended
    }
} 