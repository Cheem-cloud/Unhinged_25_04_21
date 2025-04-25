import Foundation

/// Protocol for basic CRUD operations on services
public protocol CRUDService: BaseService {
    /// Create a new record
    /// - Parameter model: The model to create
    /// - Returns: The ID of the created record
    func create<T: Codable & Identifiable>(_ model: T) async throws -> String
    
    /// Read a record by ID
    /// - Parameter id: The ID of the record to read
    /// - Returns: The model object
    func read<T: Codable & Identifiable>(_ id: String) async throws -> T
    
    /// Update an existing record
    /// - Parameter model: The model to update
    func update<T: Codable & Identifiable>(_ model: T) async throws
    
    /// Delete a record
    /// - Parameter model: The model to delete
    func delete<T: Codable & Identifiable>(_ model: T) async throws
    
    /// List all records of a given type
    /// - Returns: Array of model objects
    func list<T: Codable & Identifiable>() async throws -> [T]
}

/// Base service protocol with initialization requirements
public protocol BaseService: ServiceProtocol {
    /// Initialize with default values
    init()
    
    /// Initialize with an identifier
    /// - Parameter identifier: Service identifier
    init(identifier: String)
}

/// Foundation protocol for all services
public protocol ServiceProtocol: AnyObject {
    /// The type of service provided
    var serviceType: String { get }
}

/// Extension to provide default implementations
extension ServiceProtocol {
    public var serviceType: String {
        return String(describing: type(of: self))
    }
} 