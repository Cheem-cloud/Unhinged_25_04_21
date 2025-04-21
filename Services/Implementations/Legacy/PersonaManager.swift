import Foundation
import Firebase
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import UIKit

class PersonaManager: ObservableObject {
    static let shared = PersonaManager()
    
    @Published var userPersonas: [Persona] = []
    @Published var selectedPersona: Persona?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()
    
    init() {
        // Load personas if user is signed in
        if let userId = Auth.auth().currentUser?.uid {
            fetchUserPersonas(userId: userId)
        }
        
        // Set up auth state listener
        Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            guard let self = self else { return }
            if let userId = user?.uid {
                self.fetchUserPersonas(userId: userId)
            } else {
                self.userPersonas = []
                self.selectedPersona = nil
            }
        }
    }
    
    func fetchUserPersonas(userId: String) {
        isLoading = true
        
        db.collection("users").document(userId).collection("personas")
            .getDocuments { [weak self] (snapshot, error) in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Error fetching personas: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.errorMessage = "No personas found"
                        return
                    }
                    
                    self.userPersonas = documents.compactMap { document in
                        do {
                            var persona = try document.data(as: Persona.self)
                            persona.id = document.documentID
                            return persona
                        } catch {
                            self.errorMessage = "Error parsing persona data: \(error.localizedDescription)"
                            return nil
                        }
                    }
                    
                    // Set the first persona as selected if none is selected
                    if self.selectedPersona == nil && !self.userPersonas.isEmpty {
                        self.selectedPersona = self.userPersonas.first
                    }
                }
            }
    }
    
    func createPersona(_ persona: Persona, image: UIImage? = nil) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "PersonaManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        
        var newPersona = persona
        
        // Upload image if provided
        if let image = image {
            let imageURL = try await uploadImage(image, userId: userId)
            newPersona.imageURL = imageURL
        }
        
        // Add new persona to Firestore
        let personaRef = try db.collection("users").document(userId).collection("personas").addDocument(from: newPersona)
        
        DispatchQueue.main.async {
            newPersona.id = personaRef.documentID
            self.userPersonas.append(newPersona)
            
            // Set as selected if first persona
            if self.userPersonas.count == 1 {
                self.selectedPersona = newPersona
            }
        }
        
        return personaRef.documentID
    }
    
    func updatePersona(_ persona: Persona, image: UIImage? = nil) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "PersonaManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        
        guard let personaId = persona.id else {
            throw NSError(domain: "PersonaManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid persona ID"])
        }
        
        var updatedPersona = persona
        
        // Upload new image if provided
        if let image = image {
            let imageURL = try await uploadImage(image, userId: userId)
            updatedPersona.imageURL = imageURL
        }
        
        // Update persona in Firestore
        try db.collection("users").document(userId).collection("personas").document(personaId).setData(from: updatedPersona)
        
        DispatchQueue.main.async {
            // Update local array
            if let index = self.userPersonas.firstIndex(where: { $0.id == personaId }) {
                self.userPersonas[index] = updatedPersona
            }
            
            // Update selected persona if needed
            if self.selectedPersona?.id == personaId {
                self.selectedPersona = updatedPersona
            }
        }
    }
    
    func deletePersona(personaId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "PersonaManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        
        // Delete persona from Firestore
        try await db.collection("users").document(userId).collection("personas").document(personaId).delete()
        
        DispatchQueue.main.async {
            // Update local array
            self.userPersonas.removeAll(where: { $0.id == personaId })
            
            // Update selected persona if needed
            if self.selectedPersona?.id == personaId {
                self.selectedPersona = self.userPersonas.first
            }
        }
    }
    
    func selectPersona(_ persona: Persona) {
        selectedPersona = persona
    }
    
    private func uploadImage(_ image: UIImage, userId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.75) else {
            throw NSError(domain: "PersonaManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let fileName = "\(UUID().uuidString).jpg"
        let fileRef = storage.child("users/\(userId)/personas/\(fileName)")
        
        _ = try await fileRef.putDataAsync(imageData)
        let downloadURL = try await fileRef.downloadURL()
        
        return downloadURL.absoluteString
    }
} 