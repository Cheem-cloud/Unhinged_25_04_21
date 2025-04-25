import Foundation
import SwiftUI
import Combine

/// ViewModel for hangout creation and editing
public class HangoutFormViewModel: ObservableObject {
    // Form data
    @Published public var title: String = ""
    @Published public var description: String = ""
    @Published public var location: String = ""
    @Published public var startDate: Date = Date()
    @Published public var endDate: Date = Date().addingTimeInterval(3600) // 1 hour later
    @Published public var selectedPersonaID: String = ""
    @Published public var selectedPartnerPersonaID: String = ""
    @Published public var hangoutType: HangoutType = .inPerson
    
    // State
    @Published public var isLoading: Bool = false
    @Published public var error: Error?
    @Published public var personas: [PartnerPersona] = []
    @Published public var partnerPersonas: [PartnerPersona] = []
    @Published public var relationshipID: String?
    @Published public var partnerID: String?
    
    // Services
    private let hangoutService: HangoutService
    private let relationshipService: RelationshipService
    
    // Editing state
    private var editingHangoutID: String?
    private var existingHangout: Hangout?
    
    /// Validation state for the form
    public var isValid: Bool {
        return !title.isEmpty &&
               startDate < endDate &&
               !selectedPersonaID.isEmpty &&
               !selectedPartnerPersonaID.isEmpty &&
               relationshipID != nil
    }
    
    /// Computed end date that's at least 15 minutes after start
    public var validEndDate: Date {
        let minEndDate = startDate.addingTimeInterval(15 * 60)
        return endDate < minEndDate ? minEndDate : endDate
    }
    
    /// Initialize for creating a new hangout
    /// - Parameter relationshipID: Optional relationship ID
    public init(relationshipID: String? = nil) {
        self.relationshipID = relationshipID
        
        // Get services from service manager
        self.hangoutService = ServiceManager.shared.getService(HangoutService.self)
        self.relationshipService = ServiceManager.shared.getService(RelationshipService.self)
        
        // Load data
        Task {
            await loadInitialData()
        }
    }
    
    /// Initialize for editing an existing hangout
    /// - Parameter hangoutID: The ID of the hangout to edit
    public init(editingHangoutID: String) {
        self.editingHangoutID = editingHangoutID
        
        // Get services from service manager
        self.hangoutService = ServiceManager.shared.getService(HangoutService.self)
        self.relationshipService = ServiceManager.shared.getService(RelationshipService.self)
        
        // Load hangout data
        Task {
            await loadHangoutForEditing()
        }
    }
    
    /// Load initial data for the form
    @MainActor
    private func loadInitialData() async {
        isLoading = true
        
        do {
            // Load relationship if not provided
            if relationshipID == nil {
                if let relationship = try await relationshipService.getRelationshipForUser(userID: getCurrentUserID()) {
                    relationshipID = relationship.id
                    
                    // Find partner ID
                    partnerID = relationship.userIDs.first { $0 != getCurrentUserID() }
                }
            }
            
            // Load personas
            if let relationshipID = relationshipID {
                personas = try await relationshipService.getPartnerPersonas(for: relationshipID)
                
                // Set default persona if available
                if let firstPersona = personas.first {
                    selectedPersonaID = firstPersona.id
                }
                
                // Load partner personas
                partnerPersonas = try await relationshipService.getPartnerPersonas(for: relationshipID)
                
                // Set default partner persona if available
                if let firstPartnerPersona = partnerPersonas.first {
                    selectedPartnerPersonaID = firstPartnerPersona.id
                }
            }
            
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    /// Load an existing hangout for editing
    @MainActor
    private func loadHangoutForEditing() async {
        guard let hangoutID = editingHangoutID else { return }
        
        isLoading = true
        
        do {
            // Load hangout
            if let hangout = try await hangoutService.getHangout(id: hangoutID) {
                existingHangout = hangout
                
                // Fill form with hangout data
                title = hangout.title ?? ""
                description = hangout.description ?? ""
                location = hangout.location ?? ""
                startDate = hangout.startDate ?? Date()
                endDate = hangout.endDate ?? Date().addingTimeInterval(3600)
                selectedPersonaID = hangout.creatorPersonaID
                selectedPartnerPersonaID = hangout.inviteePersonaID
                
                // Set relationship ID
                relationshipID = try await getRelationshipIDForUsers(userIDs: [hangout.creatorID, hangout.inviteeID])
                
                // Load personas
                if let relationshipID = relationshipID {
                    personas = try await relationshipService.getPartnerPersonas(for: relationshipID)
                    partnerPersonas = try await relationshipService.getPartnerPersonas(for: relationshipID)
                }
            }
            
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    /// Save the hangout (create or update)
    public func saveHangout() async throws -> String {
        guard isValid, let relationshipID = relationshipID else {
            throw NSError(domain: "HangoutForm", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Invalid form data"
            ])
        }
        
        isLoading = true
        
        do {
            let hangoutID: String
            
            if let existingHangout = existingHangout, let id = existingHangout.id {
                // Update existing hangout
                var updatedHangout = existingHangout
                updatedHangout.title = title
                updatedHangout.description = description
                updatedHangout.location = location
                updatedHangout.startDate = startDate
                updatedHangout.endDate = endDate
                updatedHangout.creatorPersonaID = selectedPersonaID
                updatedHangout.inviteePersonaID = selectedPartnerPersonaID
                updatedHangout.updatedAt = Date()
                
                try await hangoutService.updateHangout(updatedHangout)
                hangoutID = id
            } else {
                // Create new hangout
                let currentUserID = getCurrentUserID()
                
                // Get partner ID if not already set
                let partnerUserID: String
                if let partnerID = partnerID {
                    partnerUserID = partnerID
                } else {
                    guard let relationship = try await relationshipService.getRelationshipForUser(userID: currentUserID),
                          let partner = relationship.userIDs.first(where: { $0 != currentUserID }) else {
                        throw NSError(domain: "HangoutForm", code: 404, userInfo: [
                            NSLocalizedDescriptionKey: "Could not find partner for relationship"
                        ])
                    }
                    partnerUserID = partner
                }
                
                // Create new hangout
                let newHangout = Hangout(
                    title: title,
                    description: description,
                    startDate: startDate,
                    endDate: endDate,
                    location: location,
                    creatorID: currentUserID,
                    creatorPersonaID: selectedPersonaID,
                    inviteeID: partnerUserID,
                    inviteePersonaID: selectedPartnerPersonaID
                )
                
                hangoutID = try await hangoutService.createHangout(newHangout)
            }
            
            isLoading = false
            return hangoutID
        } catch {
            isLoading = false
            throw error
        }
    }
    
    /// Get the current user ID
    private func getCurrentUserID() -> String {
        // This would typically come from your auth service
        return "current_user_id"
    }
    
    /// Get relationship ID for a set of users
    private func getRelationshipIDForUsers(userIDs: [String]) async throws -> String? {
        // Find a relationship containing these users
        let relationship = try await relationshipService.getRelationshipForUser(userID: userIDs[0])
        return relationship?.id
    }
}

/// Simple validation error
private struct ValidationError: LocalizedError {
    let errorDescription: String
    
    init(_ description: String) {
        self.errorDescription = description
    }
}

/// Auth service stub for example
private class AuthService {
    static let shared = AuthService()
    var currentUserID: String? = "mock-user-id"
} 