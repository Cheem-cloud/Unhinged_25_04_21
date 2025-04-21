import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth

enum FirestoreError: Error {
    case documentNotFound
    case failedToEncode
    case failedToDecode
    case failedToSave
    case failedToDelete
    case failedToFetch
    case unknown
    case invalidData
    case failedToCreate
    case notAuthenticated
    case failedToUpdate
    case permissionDenied
    
    var localizedDescription: String {
        switch self {
        case .failedToFetch:
            return "Failed to fetch data from Firestore"
        case .failedToCreate:
            return "Failed to create document in Firestore"
        case .failedToUpdate:
            return "Failed to update document in Firestore"
        case .failedToDelete:
            return "Failed to delete document from Firestore"
        case .invalidData:
            return "Invalid data provided"
        case .notAuthenticated:
            return "User is not authenticated"
        case .documentNotFound:
            return "Document not found in Firestore"
        case .permissionDenied:
            return "Permission denied. Check your Firestore rules."
        case .failedToEncode:
            return "Failed to encode data for Firestore"
        case .failedToDecode:
            return "Failed to decode data from Firestore"
        case .failedToSave:
            return "Failed to save data to Firestore"
        case .unknown:
            return "Unknown Firestore error occurred"
        }
    }
}

class FirestoreService {
    static let shared = FirestoreService()
    
    private let db = Firestore.firestore()
    
    // Collections
    private let usersCollection = "users"
    private let personasCollection = "personas"
    private let hangoutsCollection = "hangouts"
    private let friendshipsCollection = "friendships"
    
    // MARK: - Helper methods for async/await
    
    // MARK: - User Operations
    
    func getUser(id: String) async throws -> AppUser? {
        let docRef = db.collection(usersCollection).document(id)
        let document = try await docRef.getDocument()
        
        guard document.exists else {
            return nil
        }
        
        // Explicitly create AppUser to avoid type inference issues
        let data = document.data() ?? [:]
        var user = try Firestore.Decoder().decode(AppUser.self, from: data)
        user.id = document.documentID
        return user
    }
    
    func createUser(_ user: AppUser) async throws -> String {
        do {
            let docRef = db.collection(usersCollection).document()
            var userCopy = user
            userCopy.id = docRef.documentID
            
            try await docRef.setDataAsync(from: userCopy)
            
            // Initialize FCM token field if it doesn't exist
            try await docRef.updateData([
                "fcmToken": FieldValue.delete()
            ])
            
            // Initialize user's settings
            try? await docRef.collection("settings").document("preferences").setData([
                "notificationsEnabled": true,
                "calendarSyncEnabled": true,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            print("DEBUG: Successfully created user document for \(docRef.documentID)")
            return docRef.documentID
        } catch {
            print("DEBUG: Failed to create user document: \(error.localizedDescription)")
            throw FirestoreError.failedToCreate
        }
    }
    
    func updateUser(_ user: AppUser) async throws {
        guard let id = user.id else {
            throw FirestoreError.invalidData
        }
        
        let docRef = db.collection(usersCollection).document(id)
        try await docRef.setDataAsync(from: user, merge: true)
    }
    
    // MARK: - Persona Operations
    
    func getPersonas(for userId: String) async throws -> [Persona] {
        print("DEBUG: Getting personas for user \(userId)")
        let personas = try await getPersonasAsync(for: userId)
        print("DEBUG: Found \(personas.count) personas")
        return personas
    }
    
    private func getPersonasAsync(for userId: String) async throws -> [Persona] {
        print("DEBUG: Fetching personas from Firestore for \(userId)")
        print("DEBUG: Full path: \(usersCollection)/\(userId)/\(personasCollection)")
        
        do {
            // First verify the user document exists
            let userDocRef = db.collection(usersCollection).document(userId)
            let userDoc = try await userDocRef.getDocument()
            
            if !userDoc.exists {
                print("DEBUG: ⚠️ User document doesn't exist at path: \(usersCollection)/\(userId)")
                throw FirestoreError.documentNotFound
            } else {
                print("DEBUG: ✅ User document exists at path: \(usersCollection)/\(userId)")
            }
            
            print("DEBUG: Querying personas collection at path: \(usersCollection)/\(userId)/\(personasCollection)")
            let snapshot = try await db.collection(usersCollection).document(userId).collection(personasCollection).getDocuments()
            print("DEBUG: Raw document count from Firestore: \(snapshot.documents.count)")
            
            if snapshot.documents.isEmpty {
                print("DEBUG: ⚠️ No persona documents found in collection")
                print("DEBUG: This suggests the collection might not exist or is empty")
                return []
            }
            
            var results: [Persona] = []
            
            for document in snapshot.documents {
                do {
                    // Manual dictionary decoding instead of Firestore.Decoder()
                    let data = document.data()
                    print("DEBUG: Processing document \(document.documentID) with data: \(data)")
                    
                    // Extract values manually
                    guard let name = data["name"] as? String else {
                        print("DEBUG: ❌ Missing required field 'name'")
                        continue
                    }
                    
                    // Bio (formerly description) - now treat as optional
                    let bio = data["bio"] as? String ?? data["description"] as? String // Try both fields for backward compatibility
                    
                    // UserID is no longer needed in our Persona model
                    
                    // Optional values with defaults
                    let imageURL = data["imageURL"] as? String ?? data["avatarURL"] as? String // Try both fields for backward compatibility
                    print("DEBUG: Found imageURL: \(imageURL ?? "nil")")
                    
                    // These fields are no longer needed in our simplified Persona model
                    let age = data["age"] as? Int
                    let breed = data["breed"] as? String
                    let interests = data["interests"] as? [String]
                    let isPremium = data["isPremium"] as? Bool ?? false
                    
                    // Timestamps can be tricky, handle them carefully
                    var createdAt = Timestamp()
                    if let timestamp = data["createdAt"] as? Timestamp {
                        createdAt = timestamp
                    }
                    
                    // Create persona manually
                    let persona = Persona(
                        id: document.documentID,
                        name: name,
                        bio: bio,
                        imageURL: imageURL,
                        age: age,
                        breed: breed,
                        interests: interests,
                        isPremium: isPremium,
                        createdAt: createdAt
                    )
                    
                    print("DEBUG: ✅ Successfully created persona manually: \(persona.name) with ID \(persona.id ?? "nil")")
                    results.append(persona)
                } catch {
                    print("DEBUG: ❌ Failed to create persona from document \(document.documentID): \(error.localizedDescription)")
                    print("DEBUG: Raw data: \(document.data())")
                }
            }
            
            print("DEBUG: ✅ Successfully loaded \(results.count) personas out of \(snapshot.documents.count) documents")
            return results
        } catch {
            print("DEBUG: ❌ Error fetching personas: \(error.localizedDescription)")
            print("DEBUG: Full error: \(error)")
            throw error
        }
    }
    
    func getPersona(_ id: String, for userID: String) async throws -> Persona? {
        let docRef = db.collection(usersCollection).document(userID).collection(personasCollection).document(id)
        let document = try await docRef.getDocument()
        
        guard document.exists else {
            print("DEBUG: ❌ Persona document does not exist: \(id) for user \(userID)")
            return nil
        }
        
        // Manual construction instead of using Firestore.Decoder
        let data = document.data() ?? [:]
        print("DEBUG: Retrieved persona document data: \(data)")
        
        guard let name = data["name"] as? String else {
            print("DEBUG: ❌ Missing required field 'name' in persona document")
            return nil
        }
        
        // Extract other fields manually
        let bio = data["bio"] as? String ?? data["description"] as? String
        let imageURL = data["imageURL"] as? String ?? data["avatarURL"] as? String
        print("DEBUG: Found image URL: \(imageURL ?? "nil")")
        
        // Optional fields
        let age = data["age"] as? Int
        let breed = data["breed"] as? String
        let interests = data["interests"] as? [String]
        let isPremium = data["isPremium"] as? Bool ?? false
        
        // Handle timestamp
        var createdAt = Timestamp()
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp
        }
        
        // Create persona manually
        let persona = Persona(
            id: document.documentID,
            name: name,
            bio: bio,
            imageURL: imageURL,
            age: age,
            breed: breed,
            interests: interests,
            isPremium: isPremium,
            createdAt: createdAt
        )
        
        print("DEBUG: ✅ Successfully retrieved persona: \(persona.name) with image: \(persona.imageURL ?? "nil")")
        return persona
    }
    
    func createPersona(_ persona: Persona, for userID: String) async throws -> String {
        do {
            print("DEBUG: Creating new enhanced persona \(persona.name) for user \(userID)")
            
            // First verify the user document exists
            let userDocRef = db.collection(usersCollection).document(userID)
            let userDoc = try await userDocRef.getDocument()
            
            if !userDoc.exists {
                print("DEBUG: ⚠️ User document doesn't exist, creating it now")
                // Create the user document first
                let userData: [String: Any] = [
                    "displayName": Auth.auth().currentUser?.displayName ?? "User",
                    "email": Auth.auth().currentUser?.email ?? "",
                    "photoURL": Auth.auth().currentUser?.photoURL?.absoluteString ?? "",
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                
                try await userDocRef.setData(userData)
                print("DEBUG: ✅ Created user document for \(userID)")
            } else {
                print("DEBUG: ✅ User document exists")
            }
            
            // Now create the persona in the subcollection
            print("DEBUG: Creating enhanced persona in subcollection at path: users/\(userID)/personas")
            let docRef = db.collection(usersCollection).document(userID).collection(personasCollection).document()
            var personaCopy = persona
            personaCopy.id = docRef.documentID
            
            // Encode activity preferences to dictionaries
            let activityPreferencesData = persona.activityPreferences.map { preference -> [String: Any] in
                return [
                    "activityType": preference.activityType,
                    "preferenceLevel": preference.preferenceLevel,
                    "notes": preference.notes ?? NSNull()
                ]
            }
            
            // Encode visibility settings
            let visibilitySettingsData: [String: Any] = [
                "visibleToPartner": persona.visibilitySettings.visibleToPartner,
                "visibleToFriends": persona.visibilitySettings.visibleToFriends,
                "visibleInPublicProfile": persona.visibilitySettings.visibleInPublicProfile
            ]
            
            // Create a dictionary with all required fields to ensure they are correctly saved
            let personaData: [String: Any] = [
                "name": personaCopy.name,
                "bio": personaCopy.bio ?? NSNull(),
                "imageURL": personaCopy.imageURL ?? NSNull(),
                "age": personaCopy.age ?? NSNull(),
                "breed": personaCopy.breed ?? NSNull(),
                "interests": personaCopy.interests ?? NSNull(),
                "isPremium": personaCopy.isPremium,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "isDefault": personaCopy.isDefault,
                "friendGroupIDs": personaCopy.friendGroupIDs,
                "activityPreferences": activityPreferencesData,
                "visibilitySettings": visibilitySettingsData,
                "tags": personaCopy.tags
            ]
            
            // Use direct dictionary instead of Codable conversion
            print("DEBUG: Setting data for enhanced persona document: \(docRef.documentID)")
            try await docRef.setData(personaData)
            
            // Verify the document was created
            let verifyDoc = try await docRef.getDocument()
            if verifyDoc.exists {
                print("DEBUG: ✅ Verified enhanced persona document exists at: \(docRef.path)")
            } else {
                print("DEBUG: ❌ ERROR: Enhanced persona document was not created at: \(docRef.path)")
                throw FirestoreError.failedToCreate
            }
            
            print("DEBUG: ✅ Successfully created enhanced persona with ID \(docRef.documentID)")
            return docRef.documentID
        } catch {
            print("DEBUG: ❌ ERROR in createPersona: \(error.localizedDescription)")
            print("DEBUG: Full error: \(error)")
            throw FirestoreError.failedToCreate
        }
    }
    
    func updatePersona(_ persona: Persona, for userID: String) async throws {
        guard let id = persona.id else {
            throw FirestoreError.invalidData
        }
        
        print("DEBUG: Updating persona \(persona.name) with ID \(id)")
        print("DEBUG: Persona data: name=\(persona.name), bio=\(persona.bio ?? "nil"), imageURL=\(persona.imageURL ?? "nil")")
        
        // Create a dictionary with all fields to ensure they are correctly updated
        let personaData: [String: Any] = [
            "name": persona.name,
            "bio": persona.bio ?? NSNull(),
            "imageURL": persona.imageURL ?? NSNull(),
            "age": persona.age ?? NSNull(),
            "breed": persona.breed ?? NSNull(),
            "interests": persona.interests ?? NSNull(),
            "isPremium": persona.isPremium,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        let docRef = db.collection(usersCollection).document(userID).collection(personasCollection).document(id)
        
        // Use direct dictionary instead of Codable conversion
        try await docRef.setData(personaData, merge: true)
        print("DEBUG: Successfully updated persona")
    }
    
    func deletePersona(_ id: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("DEBUG: Failed to delete persona - No current user")
            throw FirestoreError.notAuthenticated
        }
        
        do {
            print("DEBUG: Deleting persona \(id) for user \(userId)")
            // Fix: Use the correct path with the user's collection
            try await db.collection(usersCollection).document(userId).collection(personasCollection).document(id).delete()
            print("DEBUG: Successfully deleted persona")
        } catch {
            print("DEBUG: Failed to delete persona: \(error.localizedDescription)")
            throw FirestoreError.failedToDelete
        }
    }
    
    // MARK: - Hangout Operations
    
    func getHangouts(for userID: String) async throws -> [Hangout] {
        print("🔍 GETTING HANGOUTS for user: \(userID)")
        do {
            let creatorSnapshot = try await db.collection(hangoutsCollection)
                .whereField("creatorID", isEqualTo: userID)
                .getDocuments()
            
            print("📥 Found \(creatorSnapshot.documents.count) hangouts where user is creator")
            
            let inviteeSnapshot = try await db.collection(hangoutsCollection)
                .whereField("inviteeID", isEqualTo: userID)
                .getDocuments()
            
            print("📥 Found \(inviteeSnapshot.documents.count) hangouts where user is invitee")
            
            var hangouts = creatorSnapshot.documents.compactMap { try? $0.data(as: Hangout.self) }
            hangouts += inviteeSnapshot.documents.compactMap { try? $0.data(as: Hangout.self) }
            
            // Log each hangout for debugging
            for hangout in hangouts {
                print("📋 Hangout: ID=\(hangout.id ?? "nil"), Status=\(hangout.status.rawValue), Creator=\(hangout.creatorID), Invitee=\(hangout.inviteeID)")
            }
            
            // Remove duplicates (in case user is both creator and invitee somehow)
            return Array(Set(hangouts)).sorted { $0.startDate < $1.startDate }
        } catch {
            print("❌ ERROR fetching hangouts: \(error.localizedDescription)")
            throw FirestoreError.failedToFetch
        }
    }
    
    func getHangout(_ id: String) async throws -> Hangout? {
        let docRef = db.collection(hangoutsCollection).document(id)
        let document = try await docRef.getDocument()
        
        guard document.exists else {
            return nil
        }
        
        // Explicitly create Hangout to avoid type inference issues
        let data = document.data() ?? [:]
        var hangout = try Firestore.Decoder().decode(Hangout.self, from: data)
        hangout.id = document.documentID
        return hangout
    }
    
    func createHangout(_ hangout: Hangout) async throws -> String {
        do {
            let docRef = db.collection(hangoutsCollection).document()
            var hangoutCopy = hangout
            hangoutCopy.id = docRef.documentID
            
            print("🔶 FirestoreService: Creating hangout with ID: \(docRef.documentID)")
            print("🔶 Creator: \(hangoutCopy.creatorID), Invitee: \(hangoutCopy.inviteeID)")
            print("🔶 Status: \(hangoutCopy.status.rawValue)")
            
            // Convert Date to Timestamp - startDate and endDate are non-optional in the Hangout model
            let startTimestamp = Timestamp(date: hangout.startDate)
            let endTimestamp = Timestamp(date: hangout.endDate)
            
            // Create a dictionary with required fields
            let hangoutData: [String: Any] = [
                "title": hangoutCopy.title,
                "description": hangoutCopy.description,
                "location": hangoutCopy.location ?? NSNull(),
                "creatorID": hangoutCopy.creatorID,
                "creatorPersonaID": hangoutCopy.creatorPersonaID,
                "inviteeID": hangoutCopy.inviteeID,
                "inviteePersonaID": hangoutCopy.inviteePersonaID,
                "startDate": startTimestamp,
                "endDate": endTimestamp,
                "status": hangoutCopy.status.rawValue,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            print("🔍 FirestoreService: About to call setData for hangout")
            try await docRef.setData(hangoutData)
            print("✅ FirestoreService: Successfully called setData")
            
            // Verify the hangout was created
            print("🔶 Verifying hangout creation in Firestore...")
            let verification = try await docRef.getDocument()
            if verification.exists {
                print("✅ Hangout document verified in Firestore with ID: \(docRef.documentID)")
                
                // Print the actual content to verify status was saved correctly
                if let data = verification.data() {
                    print("📝 Hangout data in Firestore:")
                    print("  - Title: \(data["title"] as? String ?? "Missing")")
                    print("  - Status: \(data["status"] as? String ?? "Missing")")
                    print("  - Creator: \(data["creatorID"] as? String ?? "Missing")")
                    print("  - Invitee: \(data["inviteeID"] as? String ?? "Missing")")
                }
            } else {
                print("❌ ERROR: Hangout document not found after creation!")
            }
            
            // Also run a direct query to verify it can be found via queries
            print("🔍 Running verification query for pending hangouts...")
            let querySnapshot = try await db.collection(hangoutsCollection)
                .whereField("inviteeID", isEqualTo: hangoutCopy.inviteeID)
                .whereField("status", isEqualTo: "pending")
                .getDocuments()
            
            let pendingCount = querySnapshot.documents.count
            print("📊 Found \(pendingCount) pending hangouts for invitee \(hangoutCopy.inviteeID)")
            
            return docRef.documentID
        } catch {
            print("❌ ERROR creating hangout: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            
            // If we have a Firestore error, try to get more details
            if let firestoreError = error as NSError? {
                print("❌ Firestore error code: \(firestoreError.code)")
                print("❌ Firestore error domain: \(firestoreError.domain)")
                print("❌ Firestore error user info: \(firestoreError.userInfo)")
            }
            
            throw FirestoreError.failedToSave
        }
    }
    
    func updateHangout(_ hangout: Hangout) async throws {
        guard let id = hangout.id else {
            throw FirestoreError.invalidData
        }
        
        let docRef = db.collection(hangoutsCollection).document(id)
        try await docRef.setDataAsync(from: hangout, merge: true)
    }
    
    func deleteHangout(_ id: String) async throws {
        do {
            print("DEBUG: Deleting hangout with ID \(id)")
            try await db.collection(hangoutsCollection).document(id).delete()
            print("DEBUG: Successfully deleted hangout")
        } catch {
            print("DEBUG: Failed to delete hangout: \(error.localizedDescription)")
            throw FirestoreError.failedToDelete
        }
    }
    
    // MARK: - Friends Operations - Not needed for two-user app
    
    func getFriends(for userID: String) async throws -> [AppUser] {
        // For our two-user app, we just get the other user
        do {
            let snapshot = try await db.collection(usersCollection).getDocuments()
            return snapshot.documents
                .compactMap { try? $0.data(as: AppUser.self) }
                .filter { $0.id != userID }
        } catch {
            throw FirestoreError.failedToFetch
        }
    }
    
    func getFriendRequests(for userID: String) async throws -> [QueryDocumentSnapshot] {
        // Not needed in two-user app, but using an async operation for proper syntax
        do {
            // Performing a dummy async operation to satisfy compiler
            let snapshot = try await db.collection("friendRequests").whereField("receiverId", isEqualTo: userID).getDocuments()
            return snapshot.documents
        } catch {
            return []
        }
    }
    
    func sendFriendRequest(from senderID: String, to email: String) async throws {
        // Not needed in two-user app, but using an async operation for proper syntax
        let dummyData = ["sender": senderID, "receiver": email]
        try await db.collection("friendRequests").addDocument(data: dummyData)
    }
    
    func respondToFriendRequest(requestId: String, receiverId: String, senderId: String, accept: Bool) async throws {
        // Not needed in two-user app, but using an async operation for proper syntax
        try await db.collection("friendRequests").document(requestId).delete()
    }
    
    func removeFriend(userId: String, friendId: String) async throws {
        // Not needed in two-user app, but using an async operation for proper syntax
        try await db.collection("friendships").document("\(userId)_\(friendId)").delete()
    }
    
    // Update addFriend to use the async wrapper
    func addFriend(userId: String, friendId: String) async throws {
        let friendship = Friendship(userId: userId, friendId: friendId)
        let docRef = db.collection(friendshipsCollection).document("\(userId)_\(friendId)")
        
        try await docRef.setDataAsync(from: friendship)
    }
    
    // MARK: - FCM Token Management
    
    func saveFCMToken(_ token: String, for userId: String) async throws {
        do {
            print("DEBUG: Saving FCM token for user \(userId)")
            let userDocRef = db.collection(usersCollection).document(userId)
            try await userDocRef.updateData([
                "fcmToken": token,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            print("DEBUG: Successfully saved FCM token")
        } catch {
            print("DEBUG: Failed to save FCM token: \(error.localizedDescription)")
            
            // Try to create the user document if it doesn't exist
            do {
                let userDocRef = db.collection(usersCollection).document(userId)
                try await userDocRef.setData([
                    "fcmToken": token,
                    "id": userId,
                    "displayName": Auth.auth().currentUser?.displayName ?? "User",
                    "email": Auth.auth().currentUser?.email ?? "",
                    "photoURL": Auth.auth().currentUser?.photoURL?.absoluteString ?? "",
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                print("DEBUG: Created new user document with FCM token")
            } catch {
                print("DEBUG: Failed to create user document with FCM token: \(error.localizedDescription)")
                throw FirestoreError.failedToSave
            }
        }
    }
    
    // MARK: - User Data
    
    func saveUserData(_ userData: [String: Any], for userId: String) async throws {
        try await db.collection("users").document(userId).setData(userData, merge: true)
    }
    
    func getUserData(for userId: String) async throws -> [String: Any]? {
        let document = try await db.collection("users").document(userId).getDocument()
        return document.data()
    }
    
    // MARK: - FCM Tokens
    
    func getFCMToken(for userId: String) async throws -> String? {
        let userData = try await getUserData(for: userId)
        return userData?["fcmToken"] as? String
    }
    
    // MARK: - Personas
    
    func getPersona(id: String, userId: String) async throws -> Persona? {
        do {
            let document = try await db.collection("users").document(userId).collection("personas").document(id).getDocument()
            
            guard document.exists else {
                print("Persona document does not exist")
                return nil
            }
            
            return try document.data(as: Persona.self)
        } catch {
            print("Error getting persona: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Hangouts
    
    func createHangout(_ hangoutData: [String: Any]) async throws -> String {
        let docRef = try await db.collection("hangouts").addDocument(data: hangoutData)
        return docRef.documentID
    }
    
    func updateHangout(id: String, data: [String: Any]) async throws {
        try await db.collection("hangouts").document(id).setData(data, merge: true)
    }
    
    func getHangout(id: String) async throws -> [String: Any]? {
        let document = try await db.collection("hangouts").document(id).getDocument()
        return document.data()
    }
    
    // MARK: - Enhanced Persona Methods
    
    // Update persona with specific activity preferences
    func updatePersonaActivityPreferences(_ personaId: String, preferences: [ActivityPreference], for userId: String) async throws {
        print("DEBUG: Updating activity preferences for persona \(personaId)")
        
        do {
            let docRef = db.collection(usersCollection).document(userId).collection(personasCollection).document(personaId)
            
            // Verify the persona exists
            let document = try await docRef.getDocument()
            guard document.exists else {
                print("DEBUG: ❌ Persona document does not exist: \(personaId)")
                throw FirestoreError.documentNotFound
            }
            
            // Encode preferences to a dictionary
            let preferencesData = preferences.map { preference -> [String: Any] in
                return [
                    "activityType": preference.activityType,
                    "preferenceLevel": preference.preferenceLevel,
                    "notes": preference.notes ?? NSNull()
                ]
            }
            
            // Update the field
            try await docRef.updateData([
                "activityPreferences": preferencesData,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            print("DEBUG: ✅ Successfully updated activity preferences for persona \(personaId)")
        } catch {
            print("DEBUG: ❌ Failed to update activity preferences: \(error.localizedDescription)")
            throw FirestoreError.failedToUpdate
        }
    }
    
    // Associate persona with friend groups
    func updatePersonaFriendGroups(_ personaId: String, friendGroupIds: [String], for userId: String) async throws {
        print("DEBUG: Updating friend groups for persona \(personaId)")
        
        do {
            let docRef = db.collection(usersCollection).document(userId).collection(personasCollection).document(personaId)
            
            // Update the field
            try await docRef.updateData([
                "friendGroupIDs": friendGroupIds,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            print("DEBUG: ✅ Successfully updated friend groups for persona \(personaId)")
        } catch {
            print("DEBUG: ❌ Failed to update friend groups: \(error.localizedDescription)")
            throw FirestoreError.failedToUpdate
        }
    }
    
    // Update persona visibility settings
    func updatePersonaVisibility(_ personaId: String, visibilitySettings: VisibilitySettings, for userId: String) async throws {
        print("DEBUG: Updating visibility settings for persona \(personaId)")
        
        do {
            let docRef = db.collection(usersCollection).document(userId).collection(personasCollection).document(personaId)
            
            // Convert visibility settings to a dictionary
            let visibilityData: [String: Any] = [
                "visibleToPartner": visibilitySettings.visibleToPartner,
                "visibleToFriends": visibilitySettings.visibleToFriends,
                "visibleInPublicProfile": visibilitySettings.visibleInPublicProfile
            ]
            
            // Update the field
            try await docRef.updateData([
                "visibilitySettings": visibilityData,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            print("DEBUG: ✅ Successfully updated visibility settings for persona \(personaId)")
        } catch {
            print("DEBUG: ❌ Failed to update visibility settings: \(error.localizedDescription)")
            throw FirestoreError.failedToUpdate
        }
    }
    
    // Update persona tags
    func updatePersonaTags(_ personaId: String, tags: [String], for userId: String) async throws {
        print("DEBUG: Updating tags for persona \(personaId)")
        
        do {
            let docRef = db.collection(usersCollection).document(userId).collection(personasCollection).document(personaId)
            
            // Update the field
            try await docRef.updateData([
                "tags": tags,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            print("DEBUG: ✅ Successfully updated tags for persona \(personaId)")
        } catch {
            print("DEBUG: ❌ Failed to update tags: \(error.localizedDescription)")
            throw FirestoreError.failedToUpdate
        }
    }
    
    // Get all personas visible to the current user's partner
    func getPartnerVisiblePersonas(for partnerId: String) async throws -> [Persona] {
        print("DEBUG: Getting partner-visible personas for partner \(partnerId)")
        
        do {
            let snapshot = try await db.collection(usersCollection)
                .document(partnerId)
                .collection(personasCollection)
                .whereField("visibilitySettings.visibleToPartner", isEqualTo: true)
                .getDocuments()
            
            print("DEBUG: Found \(snapshot.documents.count) partner-visible personas")
            
            var results: [Persona] = []
            
            for document in snapshot.documents {
                do {
                    // Extract the base data
                    let data = document.data()
                    guard let name = data["name"] as? String else { continue }
                    
                    // Extract other basic fields
                    let bio = data["bio"] as? String ?? data["description"] as? String
                    let imageURL = data["imageURL"] as? String ?? data["avatarURL"] as? String
                    let age = data["age"] as? Int
                    let breed = data["breed"] as? String
                    let interests = data["interests"] as? [String]
                    let isPremium = data["isPremium"] as? Bool ?? false
                    
                    // Handle timestamp
                    var createdAt = Timestamp()
                    if let timestamp = data["createdAt"] as? Timestamp {
                        createdAt = timestamp
                    }
                    
                    // Extract enhanced fields
                    var friendGroupIDs: [String] = []
                    if let groups = data["friendGroupIDs"] as? [String] {
                        friendGroupIDs = groups
                    }
                    
                    // Activity preferences
                    var activityPreferences: [ActivityPreference] = []
                    if let prefsData = data["activityPreferences"] as? [[String: Any]] {
                        for prefData in prefsData {
                            if let activityType = prefData["activityType"] as? String,
                               let preferenceLevel = prefData["preferenceLevel"] as? Int {
                                let notes = prefData["notes"] as? String
                                let pref = ActivityPreference(
                                    activityType: activityType,
                                    preferenceLevel: preferenceLevel,
                                    notes: notes
                                )
                                activityPreferences.append(pref)
                            }
                        }
                    }
                    
                    // Visibility settings
                    var visibilitySettings = VisibilitySettings()
                    if let visibilityData = data["visibilitySettings"] as? [String: Any] {
                        visibilitySettings.visibleToPartner = visibilityData["visibleToPartner"] as? Bool ?? true
                        visibilitySettings.visibleToFriends = visibilityData["visibleToFriends"] as? Bool ?? true
                        visibilitySettings.visibleInPublicProfile = visibilityData["visibleInPublicProfile"] as? Bool ?? false
                    }
                    
                    // Tags
                    var tags: [String] = []
                    if let tagsData = data["tags"] as? [String] {
                        tags = tagsData
                    }
                    
                    // Create the enhanced persona
                    let persona = Persona(
                        id: document.documentID,
                        name: name,
                        bio: bio,
                        imageURL: imageURL,
                        age: age,
                        breed: breed,
                        interests: interests,
                        isPremium: isPremium,
                        createdAt: createdAt,
                        isDefault: data["isDefault"] as? Bool ?? false,
                        userID: partnerId,
                        friendGroupIDs: friendGroupIDs,
                        activityPreferences: activityPreferences,
                        visibilitySettings: visibilitySettings,
                        tags: tags
                    )
                    
                    results.append(persona)
                } catch {
                    print("DEBUG: Failed to parse partner persona: \(error.localizedDescription)")
                }
            }
            
            return results
        } catch {
            print("DEBUG: Failed to fetch partner personas: \(error.localizedDescription)")
            throw FirestoreError.failedToFetch
        }
    }
}

// Add an async wrapper for the setData method
extension DocumentReference {
    func setDataAsync<T: Encodable>(from value: T, merge: Bool = false) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try self.setData(from: value, merge: merge) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
} 
