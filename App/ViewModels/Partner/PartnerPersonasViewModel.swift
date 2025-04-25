import Foundation
import SwiftUI
import Combine

/// View model for managing partner personas
public class PartnerPersonasViewModel: ObservableObject {
    /// Published personas list
    @Published public var personas: [PartnerPersona] = []
    
    /// Published loading state
    @Published public var isLoading: Bool = false
    
    /// Published error state
    @Published public var error: Error?
    
    /// The relationship ID
    private let relationshipID: String
    
    /// The relationship service
    private let relationshipService: RelationshipService
    
    /// Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Initialize with relationship ID
    /// - Parameter relationshipID: The relationship ID to load personas for
    public init(relationshipID: String) {
        self.relationshipID = relationshipID
        
        // Use the service manager to get the relationship service
        self.relationshipService = ServiceManager.shared.getService(RelationshipService.self)
        
        // Load personas when initialized
        loadPersonas()
    }
    
    /// Load personas for the relationship
    public func loadPersonas() {
        isLoading = true
        
        Task {
            do {
                let loadedPersonas = try await relationshipService.getPartnerPersonas(for: relationshipID)
                
                await MainActor.run {
                    self.personas = loadedPersonas
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
    
    /// Add a new persona
    /// - Parameter persona: The persona to add
    public func addPersona(_ persona: PartnerPersona) {
        Task {
            do {
                var updatedPersona = persona
                updatedPersona.id = UUID().uuidString
                
                try await relationshipService.addPartnerPersona(updatedPersona, for: relationshipID)
                
                await MainActor.run {
                    self.personas.append(updatedPersona)
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
    
    /// Update an existing persona
    /// - Parameter persona: The persona to update
    public func updatePersona(_ persona: PartnerPersona) {
        Task {
            do {
                try await relationshipService.updatePartnerPersona(persona, for: relationshipID)
                
                await MainActor.run {
                    if let index = self.personas.firstIndex(where: { $0.id == persona.id }) {
                        self.personas[index] = persona
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
    
    /// Delete a persona
    /// - Parameter personaID: The ID of the persona to delete
    public func deletePersona(withID personaID: String) {
        Task {
            do {
                try await relationshipService.deletePartnerPersona(withID: personaID, for: relationshipID)
                
                await MainActor.run {
                    self.personas.removeAll { $0.id == personaID }
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
}

/// Model representing a partner persona
public struct PartnerPersona: Identifiable, Codable {
    public var id: String
    public var name: String
    public var description: String
    public var emoji: String
    public var color: String
    public var preferences: [String]
    public var createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        emoji: String,
        color: String,
        preferences: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.emoji = emoji
        self.color = color
        self.preferences = preferences
        self.createdAt = createdAt
    }
} 