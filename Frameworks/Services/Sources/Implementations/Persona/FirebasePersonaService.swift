import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
#if canImport(UIKit)
import UIKit
#endif


/// Firebase implementation of the PersonaService protocol
public class FirebasePersonaService: PersonaService {
    /// Firebase Firestore database
    private let db = Firestore.firestore()
    
    /// Storage service for handling images
    private let storageService: StorageService?
    
    /// Relationship service for checking partner visibility
    private let relationshipService: RelationshipService?
    
    public init(storageService: StorageService? = nil, relationshipService: RelationshipService? = nil) {
        self.storageService = storageService
        self.relationshipService = relationshipService
        print("📱 FirebasePersonaService initialized")
    }
    
    public func getPersonas(for userID: String) async throws -> [Persona] {
        let personasSnapshot = try await db.collection("users").document(userID).collection("personas").getDocuments()
        
        return personasSnapshot.documents.compactMap { document -> Persona? in
            do {
                var persona = try FirestoreDecoder().decode(Persona.self, from: document.data())
                if persona.id == nil {
                    persona.id = document.documentID
                }
                return persona
            } catch {
                print("Error decoding persona: \(error.localizedDescription)")
                return nil
            }
        }
    }
    
    public func getPersona(_ id: String, for userID: String) async throws -> Persona? {
        let document = try await db.collection("users").document(userID).collection("personas").document(id).getDocument()
        
        guard document.exists else {
            return nil
        }
        
        var persona = try FirestoreDecoder().decode(Persona.self, from: document.data() ?? [:])
        if persona.id == nil {
            persona.id = document.documentID
        }
        
        return persona
    }
    
    public func getDefaultPersona(for userID: String) async throws -> Persona? {
        let personas = try await getPersonas(for: userID)
        return personas.first { $0.isDefault }
    }
    
    public func createPersona(_ persona: Persona, for userID: String, image: UIImage? = nil) async throws -> String {
        var newPersona = persona
        
        // Upload image if provided
        if let image = image, let storageService = storageService {
            let imagePath = "users/\(userID)/personas/\(storageService.generateUniqueFilename(with: "jpg"))"
            let imageURL = try await storageService.uploadImage(image, to: imagePath, compressionQuality: 0.75, metadata: nil)
            newPersona.imageURL = imageURL.absoluteString
        }
        
        // If this is the first persona or marked as default, mark it as default
        if newPersona.isDefault || (try await getPersonas(for: userID)).isEmpty {
            newPersona.isDefault = true
        }
        
        // Ensure userID is set
        newPersona.userID = userID
        
        // Save to Firestore
        let personaData = try FirestoreEncoder().encode(newPersona) as? [String: Any] ?? [:]
        let personaRef = try await db.collection("users").document(userID).collection("personas").addDocument(data: personaData)
        
        // If this is default, ensure other personas are not default
        if newPersona.isDefault {
            try await clearOtherDefaultPersonas(except: personaRef.documentID, for: userID)
        }
        
        return personaRef.documentID
    }
    
    public func updatePersona(_ persona: Persona, for userID: String, image: UIImage? = nil) async throws {
        guard let personaID = persona.id else {
            throw NSError(domain: "FirebasePersonaService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Persona ID is required for update"])
        }
        
        var updatedPersona = persona
        
        // Upload image if provided
        if let image = image, let storageService = storageService {
            let imagePath = "users/\(userID)/personas/\(storageService.generateUniqueFilename(with: "jpg"))"
            let imageURL = try await storageService.uploadImage(image, to: imagePath, compressionQuality: 0.75, metadata: nil)
            updatedPersona.imageURL = imageURL.absoluteString
        }
        
        // Ensure userID is set
        updatedPersona.userID = userID
        
        // Save to Firestore
        let personaData = try FirestoreEncoder().encode(updatedPersona) as? [String: Any] ?? [:]
        try await db.collection("users").document(userID).collection("personas").document(personaID).setData(personaData, merge: true)
        
        // If this persona is now default, clear other defaults
        if updatedPersona.isDefault {
            try await clearOtherDefaultPersonas(except: personaID, for: userID)
        }
    }
    
    public func deletePersona(_ personaID: String, for userID: String) async throws {
        // Get the persona to check if it's default
        let persona = try await getPersona(personaID, for: userID)
        
        // Delete the persona
        try await db.collection("users").document(userID).collection("personas").document(personaID).delete()
        
        // If this was the default persona, set another as default if any exist
        if persona?.isDefault == true {
            let remainingPersonas = try await getPersonas(for: userID)
            if let firstPersona = remainingPersonas.first, let firstPersonaID = firstPersona.id {
                try await setAsDefault(firstPersonaID, for: userID)
            }
        }
        
        // Delete the image if storageService is available
        if let imageURL = persona?.imageURL, let storageService = storageService, 
           let url = URL(string: imageURL), url.pathComponents.count >= 2 {
            // Extract path from URL - this assumes the URL is from Firebase Storage
            let path = url.pathComponents.dropFirst().joined(separator: "/")
            try? await storageService.deleteFile(at: path)
        }
    }
    
    public func setAsDefault(_ personaID: String, for userID: String) async throws {
        // Get the persona
        guard let persona = try await getPersona(personaID, for: userID) else {
            throw NSError(domain: "FirebasePersonaService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Persona not found"])
        }
        
        // Update this persona to be default
        var updatedPersona = persona
        updatedPersona.isDefault = true
        try await updatePersona(updatedPersona, for: userID, image: nil)
        
        // Clear other defaults
        try await clearOtherDefaultPersonas(except: personaID, for: userID)
    }
    
    public func updateActivityPreferences(_ personaID: String, preferences: [ActivityPreference], for userID: String) async throws {
        try await db.collection("users").document(userID).collection("personas").document(personaID).updateData([
            "activityPreferences": try FirestoreEncoder().encode(preferences)
        ])
    }
    
    public func updateVisibilitySettings(_ personaID: String, settings: VisibilitySettings, for userID: String) async throws {
        try await db.collection("users").document(userID).collection("personas").document(personaID).updateData([
            "visibilitySettings": try FirestoreEncoder().encode(settings)
        ])
    }
    
    public func updateTags(_ personaID: String, tags: [String], for userID: String) async throws {
        try await db.collection("users").document(userID).collection("personas").document(personaID).updateData([
            "tags": tags
        ])
    }
    
    public func getPartnerPersonas(partnerID: String, relationshipID: String) async throws -> [Persona] {
        // Verify that there is a relationship between the current user and the partner
        if let relationshipService = relationshipService, let currentUserID = Auth.auth().currentUser?.uid {
            guard let relationship = try await relationshipService.getRelationship(id: relationshipID),
                  relationship.includesUser(userID: currentUserID),
                  relationship.includesUser(userID: partnerID),
                  relationship.status == .active else {
                throw NSError(domain: "FirebasePersonaService", code: 403, userInfo: [NSLocalizedDescriptionKey: "No active relationship with this partner"])
            }
        }
        
        // Get all personas for the partner
        let allPersonas = try await getPersonas(for: partnerID)
        
        // Filter to only include personas visible to partners
        return allPersonas.filter { persona in
            persona.visibilitySettings.visibleToPartner
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Clear default status on all personas except the one with the specified ID
    /// - Parameters:
    ///   - exceptID: ID of the persona to exclude
    ///   - userID: ID of the user
    private func clearOtherDefaultPersonas(except exceptID: String, for userID: String) async throws {
        let batch = db.batch()
        
        // Get all personas
        let personas = try await getPersonas(for: userID)
        
        // Update each default persona that isn't the excepted one
        for persona in personas {
            if persona.isDefault, let personaID = persona.id, personaID != exceptID {
                let personaRef = db.collection("users").document(userID).collection("personas").document(personaID)
                batch.updateData(["isDefault": false], forDocument: personaRef)
            }
        }
        
        // Commit the batch
        try await batch.commit()
    }
} 