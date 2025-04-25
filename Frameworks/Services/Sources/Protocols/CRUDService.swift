import Foundation

/// A protocol defining basic CRUD operations for a service
public protocol CRUDService {
    /// Create a new document
    /// - Parameters:
    ///   - data: The data to create
    ///   - collection: The collection to create in
    /// - Returns: The ID of the created document
    func create<T: Encodable>(_ data: T, in collection: String) async throws -> String
    
    /// Read a document by ID
    /// - Parameters:
    ///   - id: The document ID
    ///   - collection: The collection to read from
    /// - Returns: The decoded document data
    func read<T: Decodable>(_ id: String, from collection: String) async throws -> T?
    
    /// Update a document
    /// - Parameters:
    ///   - id: The document ID
    ///   - data: The data to update
    ///   - collection: The collection to update in
    func update<T: Encodable>(_ id: String, with data: T, in collection: String) async throws
    
    /// Delete a document
    /// - Parameters:
    ///   - id: The document ID
    ///   - collection: The collection to delete from
    func delete(_ id: String, from collection: String) async throws
    
    /// Query documents
    /// - Parameters:
    ///   - collection: The collection to query
    ///   - field: The field to filter on
    ///   - value: The value to filter by
    /// - Returns: Array of decoded documents
    func query<T: Decodable, V: Any>(_ collection: String, field: String, isEqualTo value: V) async throws -> [T]
    
    /// Query documents with multiple conditions
    /// - Parameters:
    ///   - collection: The collection to query
    ///   - conditions: Dictionary of field-value pairs to filter by
    /// - Returns: Array of decoded documents
    func queryWhere<T: Decodable>(_ collection: String, conditions: [String: Any]) async throws -> [T]
    
    /// Batch update multiple documents
    /// - Parameters:
    ///   - updates: Dictionary mapping document IDs to their update data
    ///   - collection: The collection to update in
    func batchUpdate<T: Encodable>(_ updates: [String: T], in collection: String) async throws
} 