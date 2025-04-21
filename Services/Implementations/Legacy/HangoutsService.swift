import Foundation
import Firebase
import FirebaseFirestore

/// Service for managing hangouts
class HangoutsService {
    /// Shared instance for singleton access
    static let shared = HangoutsService()
    
    /// The CRUD service used for database operations
    private let crudService: CRUDService
    
    /// Private initializer for singleton pattern
    private init(crudService: CRUDService = ServiceManager.shared.getService(CRUDService.self)) {
        self.crudService = crudService
        print("📱 HangoutsService initialized with CRUDService")
    }
    
    /// Create a new hangout
    /// - Parameter hangout: The hangout to create
    /// - Returns: The ID of the created hangout
    func createHangout(_ hangout: Hangout) async throws -> String {
        do {
            // Convert the Hangout object to a dictionary
            var hangoutData = try FirestoreEncoder().encode(hangout) as? [String: Any] ?? [:]
            
            // Add collection name for CRUD service
            hangoutData["collection"] = "hangouts"
            
            // Use the CRUDService to create the hangout
            let path = try await crudService.create(hangoutData)
            
            // Extract hangout ID from path
            let components = path.components(separatedBy: "/")
            guard components.count >= 2 else {
                throw ServiceError.operationFailed("Invalid path returned from create operation")
            }
            
            return components[1]
        } catch {
            print("❌ Error creating hangout: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Get a hangout by ID
    /// - Parameter id: The ID of the hangout to retrieve
    /// - Returns: The hangout if found
    func getHangout(_ id: String) async throws -> Hangout {
        do {
            // Use the CRUDService to read hangout data
            let hangoutData = try await crudService.read("hangouts/\(id)")
            
            guard let hangoutData = hangoutData else {
                throw ServiceError.operationFailed("Hangout not found")
            }
            
            // Convert to Hangout object
            var hangout = try FirestoreDecoder().decode(Hangout.self, from: hangoutData)
            if hangout.id == nil {
                hangout.id = id
            }
            
            return hangout
        } catch {
            print("❌ Error getting hangout: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Update an existing hangout
    /// - Parameters:
    ///   - id: The ID of the hangout to update
    ///   - hangout: The updated hangout data
    func updateHangout(_ hangout: Hangout) async throws {
        guard let id = hangout.id else {
            throw ServiceError.invalidOperation("Hangout ID is missing")
        }
        
        do {
            // Convert the Hangout object to a dictionary
            let hangoutData = try FirestoreEncoder().encode(hangout) as? [String: Any] ?? [:]
            
            // Use the CRUDService to update the hangout
            try await crudService.update("hangouts/\(id)", with: hangoutData)
        } catch {
            print("❌ Error updating hangout: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Delete a hangout
    /// - Parameter id: The ID of the hangout to delete
    func deleteHangout(_ id: String) async throws {
        do {
            // Use the CRUDService to delete the hangout
            try await crudService.delete("hangouts/\(id)")
        } catch {
            print("❌ Error deleting hangout: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Get hangouts for a user
    /// - Parameter userId: The user ID to get hangouts for
    /// - Returns: List of hangouts for the user
    func getHangoutsForUser(userId: String) async throws -> [Hangout] {
        do {
            // Get hangouts where user is creator
            let creatorFilter: [String: Any] = [
                "collection": "hangouts",
                "creatorID": userId
            ]
            let creatorHangouts = try await crudService.list(filter: creatorFilter)
            
            // Get hangouts where user is invitee
            let inviteeFilter: [String: Any] = [
                "collection": "hangouts",
                "inviteeID": userId
            ]
            let inviteeHangouts = try await crudService.list(filter: inviteeFilter)
            
            // Combine results and convert to Hangout objects
            var hangouts: [Hangout] = []
            
            for data in creatorHangouts {
                if var hangout = try? FirestoreDecoder().decode(Hangout.self, from: data) {
                    if hangout.id == nil, let id = data["id"] as? String {
                        hangout.id = id
                    }
                    hangouts.append(hangout)
                }
            }
            
            for data in inviteeHangouts {
                if var hangout = try? FirestoreDecoder().decode(Hangout.self, from: data) {
                    if hangout.id == nil, let id = data["id"] as? String {
                        hangout.id = id
                    }
                    hangouts.append(hangout)
                }
            }
            
            // Remove duplicates
            return Array(Set(hangouts))
        } catch {
            print("❌ Error getting hangouts for user: \(error.localizedDescription)")
            throw error
        }
    }
} 