import Foundation

/// Protocol for services that provide CRUD operations
public protocol CRUDService {
    /// The type of entity being managed
    associatedtype Entity: Identifiable
    
    /// Get an entity by ID
    /// - Parameter id: ID of the entity
    /// - Returns: The entity, or nil if not found
    func get(id: String) async throws -> Entity?
    
    /// Get all entities
    /// - Returns: An array of entities
    func getAll() async throws -> [Entity]
    
    /// Create a new entity
    /// - Parameter entity: Entity to create
    /// - Returns: The created entity
    func create(_ entity: Entity) async throws -> Entity
    
    /// Update an entity
    /// - Parameter entity: Entity to update
    /// - Returns: The updated entity
    func update(_ entity: Entity) async throws -> Entity
    
    /// Delete an entity
    /// - Parameter id: ID of the entity to delete
    /// - Returns: Success boolean
    func delete(id: String) async throws -> Bool
} 