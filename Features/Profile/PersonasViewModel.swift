import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
class PersonasViewModel: ObservableObject {
    @Published var personas: [Persona] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedPersona: Persona?
    @Published var activityTypes = ["Dining", "Movies", "Hiking", "Shopping", "Coffee", "Games", "Sports", "Travel", "Arts", "Music"]
    
    private let firestoreService = FirestoreService()
    
    func loadPersonas() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        Task {
            do {
                let fetchedPersonas = try await firestoreService.getPersonas(for: userId)
                
                DispatchQueue.main.async {
                    self.personas = fetchedPersonas
                    
                    // Set selected persona to default if available
                    if self.selectedPersona == nil {
                        self.selectedPersona = fetchedPersonas.first(where: { $0.isDefault }) ?? fetchedPersonas.first
                    }
                    
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    func createPersona(
        name: String, 
        description: String, 
        avatarURL: String?, 
        makeDefault: Bool,
        activityPreferences: [ActivityPreference] = [],
        visibilitySettings: VisibilitySettings = VisibilitySettings(),
        tags: [String] = []
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "com.cheemhang.personaviewmodel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Create persona with enhanced fields
        let newPersona = Persona(
            name: name,
            bio: description,
            imageURL: avatarURL,
            isDefault: makeDefault,
            userID: userId,
            activityPreferences: activityPreferences,
            visibilitySettings: visibilitySettings,
            tags: tags
        )
        
        // Create the persona
        let personaId = try await firestoreService.createPersona(newPersona, for: userId)
        
        // If this is set as default, unset other defaults
        if makeDefault {
            // Unset current defaults
            for persona in personas where persona.isDefault {
                var updatedPersona = persona
                updatedPersona.isDefault = false
                try await firestoreService.updatePersona(updatedPersona, for: userId)
            }
        }
        
        // Reload personas after creation
        await loadPersonas()
        
        // Select the newly created persona
        if let newPersona = personas.first(where: { $0.id == personaId }) {
            selectedPersona = newPersona
        }
    }
    
    func updatePersona(
        _ persona: Persona,
        name: String,
        description: String,
        avatarURL: String?,
        makeDefault: Bool,
        activityPreferences: [ActivityPreference],
        visibilitySettings: VisibilitySettings,
        tags: [String]
    ) async throws {
        guard let personaId = persona.id,
              let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "com.cheemhang.personaviewmodel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing persona ID or user ID"])
        }
        
        // Create updated persona
        var updatedPersona = persona
        updatedPersona.name = name
        updatedPersona.bio = description
        updatedPersona.imageURL = avatarURL
        updatedPersona.activityPreferences = activityPreferences
        updatedPersona.visibilitySettings = visibilitySettings
        updatedPersona.tags = tags
        
        // Handle default status
        if makeDefault && !persona.isDefault {
            // Unset current defaults
            for p in personas where p.isDefault && p.id != personaId {
                var defaultPersona = p
                defaultPersona.isDefault = false
                try await firestoreService.updatePersona(defaultPersona, for: userId)
            }
            updatedPersona.isDefault = true
        }
        
        // Update the persona
        try await firestoreService.updatePersona(updatedPersona, for: userId)
        
        // Reload personas
        await loadPersonas()
        
        // Select the updated persona
        selectedPersona = personas.first(where: { $0.id == personaId })
    }
    
    func deletePersona(at offsets: IndexSet) {
        for index in offsets {
            guard let personaId = personas[index].id,
                  let userId = Auth.auth().currentUser?.uid else { continue }
            
            Task {
                do {
                    // If deleting the default persona and there are others, make another one default
                    if personas[index].isDefault && personas.count > 1 {
                        // Find a different persona to make default
                        if let newDefault = personas.first(where: { $0.id != personaId }) {
                            var updatedDefault = newDefault
                            updatedDefault.isDefault = true
                            try await firestoreService.updatePersona(updatedDefault, for: userId)
                        }
                    }
                    
                    try await firestoreService.deletePersona(personaId)
                    
                    // Reload personas after deletion
                    await loadPersonas()
                } catch {
                    DispatchQueue.main.async {
                        self.error = error
                    }
                }
            }
        }
    }
    
    func setAsDefault(persona: Persona) async throws {
        guard let personaId = persona.id,
              let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "com.cheemhang.personaviewmodel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing persona ID or user ID"])
        }
        
        // Unset current defaults
        for p in personas where p.isDefault && p.id != personaId {
            var defaultPersona = p
            defaultPersona.isDefault = false
            try await firestoreService.updatePersona(defaultPersona, for: userId)
        }
        
        // Set the new default
        var updatedPersona = persona
        updatedPersona.isDefault = true
        try await firestoreService.updatePersona(updatedPersona, for: userId)
        
        // Reload personas
        await loadPersonas()
        
        // Select the default persona
        selectedPersona = personas.first(where: { $0.id == personaId })
    }
    
    // MARK: - Enhanced Persona Methods
    
    func updateActivityPreferences(for personaId: String, preferences: [ActivityPreference]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "com.cheemhang.personaviewmodel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        try await firestoreService.updatePersonaActivityPreferences(personaId, preferences: preferences, for: userId)
        
        // Update local persona model
        if let index = personas.firstIndex(where: { $0.id == personaId }) {
            personas[index].activityPreferences = preferences
        }
        
        // Update selected persona if needed
        if selectedPersona?.id == personaId {
            selectedPersona?.activityPreferences = preferences
        }
    }
    
    func updateVisibilitySettings(for personaId: String, visibilitySettings: VisibilitySettings) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "com.cheemhang.personaviewmodel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        try await firestoreService.updatePersonaVisibility(personaId, visibilitySettings: visibilitySettings, for: userId)
        
        // Update local persona model
        if let index = personas.firstIndex(where: { $0.id == personaId }) {
            personas[index].visibilitySettings = visibilitySettings
        }
        
        // Update selected persona if needed
        if selectedPersona?.id == personaId {
            selectedPersona?.visibilitySettings = visibilitySettings
        }
    }
    
    func updateTags(for personaId: String, tags: [String]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "com.cheemhang.personaviewmodel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        try await firestoreService.updatePersonaTags(personaId, tags: tags, for: userId)
        
        // Update local persona model
        if let index = personas.firstIndex(where: { $0.id == personaId }) {
            personas[index].tags = tags
        }
        
        // Update selected persona if needed
        if selectedPersona?.id == personaId {
            selectedPersona?.tags = tags
        }
    }
    
    func updateFriendGroups(for personaId: String, friendGroupIds: [String]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "com.cheemhang.personaviewmodel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        try await firestoreService.updatePersonaFriendGroups(personaId, friendGroupIds: friendGroupIds, for: userId)
        
        // Update local persona model
        if let index = personas.firstIndex(where: { $0.id == personaId }) {
            personas[index].friendGroupIDs = friendGroupIds
        }
        
        // Update selected persona if needed
        if selectedPersona?.id == personaId {
            selectedPersona?.friendGroupIDs = friendGroupIds
        }
    }
    
    // Helper function to get recommended activity types based on past preferences
    func getRecommendedActivityTypes() -> [String] {
        // In a more sophisticated version, this would analyze user history
        // For now, just return commonly used ones
        return ["Dining", "Movies", "Coffee", "Hiking"]
    }
} 