import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/// Configuration for FirestoreService
public struct FirestoreConfiguration {
    /// Default collection names
    public let collections: [String: String]
    
    /// Cache configuration
    public let cacheConfig: CacheConfig
    
    /// Whether to use persistence
    public let enablePersistence: Bool
    
    /// Retry configuration
    public let retryConfig: RetryConfig
    
    /// Cache configuration
    public struct CacheConfig {
        /// Whether to use in-memory cache
        public let useCache: Bool
        
        /// Size limit for cache in megabytes
        public let cacheSizeLimitMB: Int
        
        /// TTL for cached documents
        public let cacheTTLSeconds: TimeInterval
        
        /// Initialize with cache parameters
        /// - Parameters:
        ///   - useCache: Whether to use in-memory cache
        ///   - cacheSizeLimitMB: Size limit for cache in megabytes
        ///   - cacheTTLSeconds: TTL for cached documents
        public init(
            useCache: Bool = true,
            cacheSizeLimitMB: Int = 10,
            cacheTTLSeconds: TimeInterval = 300
        ) {
            self.useCache = useCache
            self.cacheSizeLimitMB = cacheSizeLimitMB
            self.cacheTTLSeconds = cacheTTLSeconds
        }
    }
    
    /// Retry configuration
    public struct RetryConfig {
        /// Maximum number of retries
        public let maxRetries: Int
        
        /// Initial backoff time in seconds
        public let initialBackoffSeconds: TimeInterval
        
        /// Maximum backoff time in seconds
        public let maxBackoffSeconds: TimeInterval
        
        /// Initialize with retry parameters
        /// - Parameters:
        ///   - maxRetries: Maximum number of retries
        ///   - initialBackoffSeconds: Initial backoff time in seconds
        ///   - maxBackoffSeconds: Maximum backoff time in seconds
        public init(
            maxRetries: Int = 3,
            initialBackoffSeconds: TimeInterval = 1.0,
            maxBackoffSeconds: TimeInterval = 10.0
        ) {
            self.maxRetries = maxRetries
            self.initialBackoffSeconds = initialBackoffSeconds
            self.maxBackoffSeconds = maxBackoffSeconds
        }
    }
    
    /// Initialize with configuration parameters
    /// - Parameters:
    ///   - collections: Default collection names
    ///   - cacheConfig: Cache configuration
    ///   - enablePersistence: Whether to use persistence
    ///   - retryConfig: Retry configuration
    public init(
        collections: [String: String] = [:],
        cacheConfig: CacheConfig = CacheConfig(),
        enablePersistence: Bool = true,
        retryConfig: RetryConfig = RetryConfig()
    ) {
        self.collections = collections
        self.cacheConfig = cacheConfig
        self.enablePersistence = enablePersistence
        self.retryConfig = retryConfig
    }
}

/// Standardized Firestore service implementation
public class StandardFirestoreService: BaseService, ConfigurableService, CRUDService, TransactionalService, RealtimeService {
    // MARK: - Properties
    
    /// Firestore database instance
    private let db: Firestore
    
    /// Service configuration
    private var configuration: FirestoreConfiguration?
    
    /// In-memory cache
    private var cache: [String: (data: Any, timestamp: Date)] = [:]
    
    /// Subject for emitting real-time data updates
    private let realtimeDataSubject = PassthroughSubject<(String, Any), Error>()
    
    /// Active listeners
    private var listeners: [String: ListenerRegistration] = [:]
    
    // MARK: - Type Aliases
    
    /// Entity type for CRUD operations
    public typealias Entity = [String: Any]
    
    /// Identifier type for CRUD operations
    public typealias Identifier = String
    
    /// Real-time data type
    public typealias RealtimeData = (String, Any)
    
    // MARK: - Initialization
    
    /// Initialize with optional Firestore instance
    /// - Parameter db: Firestore instance to use
    public init(db: Firestore = Firestore.firestore()) {
        self.db = db
        super.init()
    }
    
    /// Set up the service
    public override func setup() {
        super.setup()
        
        // Set up any additional Firestore settings
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = configuration?.enablePersistence ?? true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings
        
        updateState(.initialized)
    }
    
    // MARK: - ConfigurableService
    
    /// Configure the service with provided configuration
    /// - Parameter configuration: Firestore service configuration
    public func configure(with configuration: FirestoreConfiguration) throws {
        updateState(.configuring)
        
        self.configuration = configuration
        
        // Apply Firestore settings
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = configuration.enablePersistence
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings
        
        updateState(.configured)
        log("Configured Firestore service with \(configuration.collections.count) collections")
    }
    
    /// Get the current configuration
    public func getConfiguration() -> FirestoreConfiguration? {
        return configuration
    }
    
    // MARK: - CRUD Operations
    
    /// Create a new entity
    /// - Parameter entity: The entity to create
    /// - Returns: The identifier of the created entity
    public func create(_ entity: Entity) async throws -> Identifier {
        guard isAvailable() else {
            throw ServiceError.notInitialized
        }
        
        updateState(.running)
        
        // Determine the collection to use
        guard let collection = entity["collection"] as? String else {
            throw FirestoreError.invalidData("No collection specified for entity")
        }
        
        // Remove collection from entity data
        var entityData = entity
        entityData.removeValue(forKey: "collection")
        
        // Add timestamps
        var dataWithTimestamps = entityData
        dataWithTimestamps["createdAt"] = FieldValue.serverTimestamp()
        dataWithTimestamps["updatedAt"] = FieldValue.serverTimestamp()
        
        do {
            // Create document with auto-generated ID
            let docRef = db.collection(collection).document()
            try await docRef.setData(dataWithTimestamps)
            
            // Clear cache for the collection
            clearCacheForCollection(collection)
            
            log("Created document with ID: \(docRef.documentID) in collection: \(collection)")
            return docRef.documentID
        } catch {
            log("Failed to create document: \(error.localizedDescription)", level: .error)
            throw FirestoreError.createFailed(error.localizedDescription)
        }
    }
    
    /// Read an entity by its identifier
    /// - Parameters:
    ///   - id: The identifier of the entity to read
    ///   - collection: The collection to read from
    /// - Returns: The entity if found, nil otherwise
    public func read(_ id: Identifier) async throws -> Entity? {
        guard isAvailable() else {
            throw ServiceError.notInitialized
        }
        
        // Extract collection and ID
        let components = id.components(separatedBy: "/")
        guard components.count >= 2 else {
            throw FirestoreError.invalidIdentifier("Invalid identifier format. Expected 'collection/id'")
        }
        
        let collection = components[0]
        let documentID = components[1]
        
        // Check cache if enabled
        if let configuration = configuration, configuration.cacheConfig.useCache {
            let cacheKey = "\(collection)/\(documentID)"
            if let cached = cache[cacheKey] {
                let now = Date()
                if now.timeIntervalSince(cached.timestamp) <= configuration.cacheConfig.cacheTTLSeconds {
                    log("Retrieved document from cache: \(cacheKey)", level: .debug)
                    return cached.data as? Entity
                } else {
                    // Cache expired
                    cache.removeValue(forKey: cacheKey)
                }
            }
        }
        
        updateState(.running)
        
        do {
            let docRef = db.collection(collection).document(documentID)
            let document = try await docRef.getDocument()
            
            guard document.exists else {
                return nil
            }
            
            guard var data = document.data() else {
                return nil
            }
            
            // Add ID to data
            data["id"] = documentID
            
            // Cache the result if caching is enabled
            if let configuration = configuration, configuration.cacheConfig.useCache {
                let cacheKey = "\(collection)/\(documentID)"
                cache[cacheKey] = (data: data, timestamp: Date())
                
                // Trim cache if it's too large
                trimCacheIfNeeded()
            }
            
            log("Read document with ID: \(documentID) from collection: \(collection)")
            return data
        } catch {
            log("Failed to read document: \(error.localizedDescription)", level: .error)
            throw FirestoreError.readFailed(error.localizedDescription)
        }
    }
    
    /// Update an entity
    /// - Parameters:
    ///   - id: The identifier of the entity to update
    ///   - entity: The updated entity
    public func update(_ id: Identifier, with entity: Entity) async throws {
        guard isAvailable() else {
            throw ServiceError.notInitialized
        }
        
        // Extract collection and ID
        let components = id.components(separatedBy: "/")
        guard components.count >= 2 else {
            throw FirestoreError.invalidIdentifier("Invalid identifier format. Expected 'collection/id'")
        }
        
        let collection = components[0]
        let documentID = components[1]
        
        updateState(.running)
        
        // Remove collection from entity data if present
        var entityData = entity
        entityData.removeValue(forKey: "collection")
        entityData.removeValue(forKey: "id")
        
        // Add updated timestamp
        var dataWithTimestamp = entityData
        dataWithTimestamp["updatedAt"] = FieldValue.serverTimestamp()
        
        do {
            let docRef = db.collection(collection).document(documentID)
            try await docRef.updateData(dataWithTimestamp)
            
            // Update cache if it exists
            let cacheKey = "\(collection)/\(documentID)"
            if let cachedData = cache[cacheKey]?.data as? [String: Any] {
                var updatedCache = cachedData
                for (key, value) in entityData {
                    updatedCache[key] = value
                }
                updatedCache["updatedAt"] = Date()
                cache[cacheKey] = (data: updatedCache, timestamp: Date())
            } else {
                // Remove from cache to force a fresh read next time
                cache.removeValue(forKey: cacheKey)
            }
            
            log("Updated document with ID: \(documentID) in collection: \(collection)")
        } catch {
            log("Failed to update document: \(error.localizedDescription)", level: .error)
            throw FirestoreError.updateFailed(error.localizedDescription)
        }
    }
    
    /// Delete an entity
    /// - Parameter id: The identifier of the entity to delete
    public func delete(_ id: Identifier) async throws {
        guard isAvailable() else {
            throw ServiceError.notInitialized
        }
        
        // Extract collection and ID
        let components = id.components(separatedBy: "/")
        guard components.count >= 2 else {
            throw FirestoreError.invalidIdentifier("Invalid identifier format. Expected 'collection/id'")
        }
        
        let collection = components[0]
        let documentID = components[1]
        
        updateState(.running)
        
        do {
            let docRef = db.collection(collection).document(documentID)
            try await docRef.delete()
            
            // Remove from cache
            let cacheKey = "\(collection)/\(documentID)"
            cache.removeValue(forKey: cacheKey)
            
            log("Deleted document with ID: \(documentID) from collection: \(collection)")
        } catch {
            log("Failed to delete document: \(error.localizedDescription)", level: .error)
            throw FirestoreError.deleteFailed(error.localizedDescription)
        }
    }
    
    /// List all entities in a collection
    /// - Parameters:
    ///   - collection: Collection to list entities from
    ///   - filter: Optional filter to apply
    /// - Returns: Array of entities matching the filter
    public func list(filter: [String: Any]? = nil) async throws -> [Entity] {
        guard isAvailable() else {
            throw ServiceError.notInitialized
        }
        
        guard let collection = filter?["collection"] as? String else {
            throw FirestoreError.invalidData("No collection specified in filter")
        }
        
        updateState(.running)
        
        // Build query
        var query: Query = db.collection(collection)
        
        // Apply filters if provided
        if let filter = filter {
            for (key, value) in filter {
                if key != "collection" && key != "limit" && key != "orderBy" && key != "descending" {
                    query = query.whereField(key, isEqualTo: value)
                }
            }
            
            // Apply order if provided
            if let orderBy = filter["orderBy"] as? String {
                let descending = filter["descending"] as? Bool ?? false
                query = descending ? query.order(by: orderBy, descending: true) : query.order(by: orderBy)
            }
            
            // Apply limit if provided
            if let limit = filter["limit"] as? Int {
                query = query.limit(to: limit)
            }
        }
        
        do {
            let querySnapshot = try await query.getDocuments()
            
            var results: [Entity] = []
            
            for document in querySnapshot.documents {
                var data = document.data()
                data["id"] = document.documentID
                results.append(data)
            }
            
            log("Listed \(results.count) documents from collection: \(collection)")
            return results
        } catch {
            log("Failed to list documents: \(error.localizedDescription)", level: .error)
            throw FirestoreError.queryFailed(error.localizedDescription)
        }
    }
    
    // MARK: - TransactionalService
    
    /// Begin a transaction
    /// - Returns: A transaction identifier
    public func beginTransaction() async throws -> String {
        guard isAvailable() else {
            throw ServiceError.notInitialized
        }
        
        updateState(.running)
        
        do {
            let transaction = try await db.transaction()
            let transactionId = UUID().uuidString
            
            // Store transaction in UserDefaults temporarily
            UserDefaults.standard.set(true, forKey: "firestore_transaction_\(transactionId)")
            
            log("Started transaction with ID: \(transactionId)")
            return transactionId
        } catch {
            log("Failed to begin transaction: \(error.localizedDescription)", level: .error)
            throw FirestoreError.transactionFailed(error.localizedDescription)
        }
    }
    
    /// Commit a transaction
    /// - Parameter transactionId: The identifier of the transaction to commit
    public func commitTransaction(_ transactionId: String) async throws {
        guard isAvailable() else {
            throw ServiceError.notInitialized
        }
        
        updateState(.running)
        
        // Check if transaction exists
        guard UserDefaults.standard.bool(forKey: "firestore_transaction_\(transactionId)") else {
            throw FirestoreError.transactionNotFound("Transaction not found: \(transactionId)")
        }
        
        // Clear transaction marker
        UserDefaults.standard.removeObject(forKey: "firestore_transaction_\(transactionId)")
        
        log("Committed transaction with ID: \(transactionId)")
    }
    
    /// Rollback a transaction
    /// - Parameter transactionId: The identifier of the transaction to rollback
    public func rollbackTransaction(_ transactionId: String) async throws {
        guard isAvailable() else {
            throw ServiceError.notInitialized
        }
        
        updateState(.running)
        
        // Check if transaction exists
        guard UserDefaults.standard.bool(forKey: "firestore_transaction_\(transactionId)") else {
            throw FirestoreError.transactionNotFound("Transaction not found: \(transactionId)")
        }
        
        // Clear transaction marker
        UserDefaults.standard.removeObject(forKey: "firestore_transaction_\(transactionId)")
        
        log("Rolled back transaction with ID: \(transactionId)")
    }
    
    // MARK: - RealtimeService
    
    /// Subscribe to real-time updates for a specific path
    /// - Parameter path: The path to subscribe to (collection/document)
    /// - Returns: A publisher that emits updates
    public func subscribe(to path: String) -> AnyPublisher<RealtimeData, Error> {
        guard isAvailable() else {
            return Fail(error: ServiceError.notInitialized).eraseToAnyPublisher()
        }
        
        updateState(.running)
        
        // Handle existing listener
        if listeners[path] != nil {
            log("Already subscribed to path: \(path)")
            return realtimeDataSubject
                .filter { $0.0 == path }
                .eraseToAnyPublisher()
        }
        
        // Parse path
        let components = path.components(separatedBy: "/")
        guard components.count >= 1 else {
            return Fail(error: FirestoreError.invalidPath("Invalid path format")).eraseToAnyPublisher()
        }
        
        let collection = components[0]
        let isDocument = components.count >= 2
        
        if isDocument {
            // Document listener
            let documentID = components[1]
            let docRef = db.collection(collection).document(documentID)
            
            let listener = docRef.addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.log("Error listening to document: \(error.localizedDescription)", level: .error)
                    self.realtimeDataSubject.send(completion: .failure(FirestoreError.listenerFailed(error.localizedDescription)))
                    return
                }
                
                guard let document = documentSnapshot, document.exists else {
                    self.log("Document doesn't exist at path: \(path)")
                    return
                }
                
                guard var data = document.data() else {
                    self.log("Document exists but has no data at path: \(path)")
                    return
                }
                
                // Add ID to data
                data["id"] = documentID
                
                // Cache the data
                if let configuration = self.configuration, configuration.cacheConfig.useCache {
                    let cacheKey = "\(collection)/\(documentID)"
                    self.cache[cacheKey] = (data: data, timestamp: Date())
                }
                
                self.log("Received document update at path: \(path)", level: .debug)
                self.realtimeDataSubject.send((path, data))
            }
            
            listeners[path] = listener
        } else {
            // Collection listener
            let collectionRef = db.collection(collection)
            
            let listener = collectionRef.addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.log("Error listening to collection: \(error.localizedDescription)", level: .error)
                    self.realtimeDataSubject.send(completion: .failure(FirestoreError.listenerFailed(error.localizedDescription)))
                    return
                }
                
                guard let snapshot = querySnapshot else {
                    self.log("No snapshot received for collection: \(collection)")
                    return
                }
                
                var documents: [[String: Any]] = []
                
                for document in snapshot.documents {
                    var data = document.data()
                    data["id"] = document.documentID
                    documents.append(data)
                    
                    // Cache individual documents
                    if let configuration = self.configuration, configuration.cacheConfig.useCache {
                        let cacheKey = "\(collection)/\(document.documentID)"
                        self.cache[cacheKey] = (data: data, timestamp: Date())
                    }
                }
                
                self.log("Received collection update at path: \(path) with \(documents.count) documents", level: .debug)
                self.realtimeDataSubject.send((path, documents))
            }
            
            listeners[path] = listener
        }
        
        log("Subscribed to real-time updates at path: \(path)")
        
        return realtimeDataSubject
            .filter { $0.0 == path }
            .eraseToAnyPublisher()
    }
    
    /// Unsubscribe from real-time updates for a specific path
    /// - Parameter path: The path to unsubscribe from
    public func unsubscribe(from path: String) {
        guard let listener = listeners[path] else {
            log("No active listener found for path: \(path)")
            return
        }
        
        listener.remove()
        listeners.removeValue(forKey: path)
        log("Unsubscribed from real-time updates at path: \(path)")
    }
    
    /// Publish data to a specific path
    /// - Parameters:
    ///   - data: The data to publish
    ///   - path: The path to publish to
    public func publish(_ data: RealtimeData, to path: String) async throws {
        guard isAvailable() else {
            throw ServiceError.notInitialized
        }
        
        updateState(.running)
        
        // Parse path
        let components = path.components(separatedBy: "/")
        guard components.count >= 2 else {
            throw FirestoreError.invalidPath("Invalid path format. Expected 'collection/id'")
        }
        
        let collection = components[0]
        let documentID = components[1]
        
        guard let entityData = data.1 as? [String: Any] else {
            throw FirestoreError.invalidData("Invalid data format")
        }
        
        // Add updated timestamp
        var dataWithTimestamp = entityData
        dataWithTimestamp["updatedAt"] = FieldValue.serverTimestamp()
        
        do {
            let docRef = db.collection(collection).document(documentID)
            try await docRef.setData(dataWithTimestamp, merge: true)
            
            log("Published data to path: \(path)")
        } catch {
            log("Failed to publish data: \(error.localizedDescription)", level: .error)
            throw FirestoreError.updateFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get a collection reference with the standard name
    /// - Parameter key: The key for the collection name
    /// - Returns: The collection reference
    public func getCollection(_ key: String) -> CollectionReference? {
        guard let configuration = configuration else {
            return nil
        }
        
        guard let collectionName = configuration.collections[key] else {
            return db.collection(key)
        }
        
        return db.collection(collectionName)
    }
    
    /// Get the full path for a document
    /// - Parameters:
    ///   - collection: The collection name
    ///   - id: The document ID
    /// - Returns: The full path string
    public func getPath(collection: String, id: String) -> String {
        return "\(collection)/\(id)"
    }
    
    /// Clear cache for a specific collection
    /// - Parameter collection: The collection to clear cache for
    private func clearCacheForCollection(_ collection: String) {
        cache = cache.filter { key, _ in
            !key.hasPrefix("\(collection)/")
        }
    }
    
    /// Trim cache if it's too large
    private func trimCacheIfNeeded() {
        guard let configuration = configuration else {
            return
        }
        
        let maxCacheSize = configuration.cacheConfig.cacheSizeLimitMB * 1024 * 1024
        
        // Implement a simple LRU cache eviction policy
        if cache.count > maxCacheSize {
            // Sort entries by timestamp (oldest first)
            let sortedCache = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            
            // Remove oldest entries until below limit
            let entriesToRemove = max(10, cache.count / 4)
            for i in 0..<min(entriesToRemove, sortedCache.count) {
                cache.removeValue(forKey: sortedCache[i].key)
            }
            
            log("Trimmed cache: removed \(entriesToRemove) entries", level: .debug)
        }
    }
    
    /// Reset the service
    public override func reset() async throws {
        updateState(.resetting)
        
        // Clear cache
        cache.removeAll()
        
        // Remove all listeners
        for (path, listener) in listeners {
            listener.remove()
            log("Removed listener for path: \(path)")
        }
        listeners.removeAll()
        
        try await super.reset()
        
        log("Reset FirestoreService")
    }
}

/// Firestore-specific errors
public enum FirestoreError: Error, LocalizedError {
    case invalidData(String)
    case documentNotFound(String)
    case collectionNotFound(String)
    case createFailed(String)
    case readFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case queryFailed(String)
    case transactionFailed(String)
    case transactionNotFound(String)
    case invalidPath(String)
    case listenerFailed(String)
    case invalidIdentifier(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .documentNotFound(let message):
            return "Document not found: \(message)"
        case .collectionNotFound(let message):
            return "Collection not found: \(message)"
        case .createFailed(let message):
            return "Failed to create document: \(message)"
        case .readFailed(let message):
            return "Failed to read document: \(message)"
        case .updateFailed(let message):
            return "Failed to update document: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete document: \(message)"
        case .queryFailed(let message):
            return "Query failed: \(message)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .transactionNotFound(let message):
            return "Transaction not found: \(message)"
        case .invalidPath(let message):
            return "Invalid path: \(message)"
        case .listenerFailed(let message):
            return "Listener failed: \(message)"
        case .invalidIdentifier(let message):
            return "Invalid identifier: \(message)"
        }
    }
} 