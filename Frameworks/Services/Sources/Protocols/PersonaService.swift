import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Protocol for managing user personas
public protocol PersonaService {
    /// Get all personas for a user
    /// - Parameter userID: ID of the user
    /// - Returns: Array of personas
    func getPersonas(for userID: String) async throws -> [Persona]
    
    /// Get a specific persona by ID
    /// - Parameters:
    ///   - id: ID of the persona
    ///   - userID: ID of the user
    /// - Returns: The persona if found, nil otherwise
    func getPersona(_ id: String, for userID: String) async throws -> Persona?
    
    /// Get the default persona for a user
    /// - Parameter userID: ID of the user
    /// - Returns: The default persona if found, nil otherwise
    func getDefaultPersona(for userID: String) async throws -> Persona?
    
    #if canImport(UIKit)
    /// Create a new persona
    /// - Parameters:
    ///   - persona: The persona to create
    ///   - userID: ID of the user
    ///   - image: Optional image for the persona
    /// - Returns: ID of the created persona
    func createPersona(_ persona: Persona, for userID: String, image: UIImage?) async throws -> String
    
    /// Update an existing persona
    /// - Parameters:
    ///   - persona: The updated persona
    ///   - userID: ID of the user
    ///   - image: Optional image to update
    func updatePersona(_ persona: Persona, for userID: String, image: UIImage?) async throws
    #endif
    
    /// Create a new persona with imageData
    /// - Parameters:
    ///   - persona: The persona to create
    ///   - userID: ID of the user
    ///   - imageData: Optional image data for the persona
    /// - Returns: ID of the created persona
    func createPersona(_ persona: Persona, for userID: String, imageData: Data?) async throws -> String
    
    /// Update an existing persona with imageData
    /// - Parameters:
    ///   - persona: The updated persona
    ///   - userID: ID of the user
    ///   - imageData: Optional image data to update
    func updatePersona(_ persona: Persona, for userID: String, imageData: Data?) async throws
    
    /// Delete a persona
    /// - Parameters:
    ///   - personaID: ID of the persona to delete
    ///   - userID: ID of the user
    func deletePersona(_ personaID: String, for userID: String) async throws
    
    /// Set a persona as the default for a user
    /// - Parameters:
    ///   - personaID: ID of the persona to set as default
    ///   - userID: ID of the user
    func setAsDefault(_ personaID: String, for userID: String) async throws
    
    /// Update activity preferences for a persona
    /// - Parameters:
    ///   - personaID: ID of the persona
    ///   - preferences: Array of activity preferences
    ///   - userID: ID of the user
    func updateActivityPreferences(_ personaID: String, preferences: [ActivityPreference], for userID: String) async throws
    
    /// Update visibility settings for a persona
    /// - Parameters:
    ///   - personaID: ID of the persona
    ///   - settings: The visibility settings
    ///   - userID: ID of the user
    func updateVisibilitySettings(_ personaID: String, settings: VisibilitySettings, for userID: String) async throws
    
    /// Update tags for a persona
    /// - Parameters:
    ///   - personaID: ID of the persona
    ///   - tags: Array of tags
    ///   - userID: ID of the user
    func updateTags(_ personaID: String, tags: [String], for userID: String) async throws
    
    /// Get personas for a partner user (based on visibility settings)
    /// - Parameters:
    ///   - partnerID: ID of the partner user
    ///   - relationshipID: ID of the relationship
    /// - Returns: Array of visible personas
    func getPartnerPersonas(partnerID: String, relationshipID: String) async throws -> [Persona]
} 