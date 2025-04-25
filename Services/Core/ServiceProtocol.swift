import Foundation
import Combine

/// Base protocol that all services must implement
public protocol ServiceProtocol {
    /// The identifier of the service
    var identifier: String { get }
    
    /// Initialize the service
    init()
    
    /// Verify the service is in a usable state
    func isAvailable() -> Bool
    
    /// Reset the service state
    func reset() async throws
    
    /// Publisher for service events
    var serviceEventPublisher: AnyPublisher<ServiceEvent, Never> { get }
    
    /// Publisher for service state changes
    var statePublisher: AnyPublisher<ServiceState, Never> { get }
}

/// Protocol for services that support configuration
public protocol ConfigurableService: ServiceProtocol {
    /// The configuration type for this service
    associatedtype Configuration
    
    /// Configure the service with the provided configuration
    /// - Parameter configuration: The configuration to apply
    func configure(with configuration: Configuration) throws
    
    /// Get the current configuration
    func getConfiguration() -> Configuration?
}

/// Protocol for services that emit events
public protocol EventEmittingService: ServiceProtocol {
    /// The event type for this service
    associatedtype Event
    
    /// Publisher for events emitted by this service
    var eventPublisher: AnyPublisher<Event, Never> { get }
}

/// Protocol for services that require authentication
public protocol AuthenticatedService: ServiceProtocol {
    /// Whether the service is currently authenticated
    var isAuthenticated: Bool { get }
    
    /// Authenticate the service
    /// - Parameters:
    ///   - credentials: The credentials to use for authentication
    ///   - completion: Completion handler called when authentication is complete
    func authenticate(credentials: [String: Any], completion: @escaping (Result<Bool, Error>) -> Void)
    
    /// Sign out of the service
    func signOut() throws
    
    /// Refresh the authentication credentials
    func refreshAuthentication() async throws
}

/// Protocol for services that perform networking operations
public protocol NetworkService: ServiceProtocol {
    /// Get the response for a request
    /// - Parameter request: The request to send
    /// - Returns: The response data and metadata
    func sendRequest(_ request: URLRequest) async throws -> (Data, URLResponse)
    
    /// Get a publisher for the response of a request
    /// - Parameter request: The request to send
    /// - Returns: A publisher that emits the response data or an error
    func sendRequestPublisher(_ request: URLRequest) -> AnyPublisher<Data, Error>
}

/// Protocol for services that use caching
public protocol CachingService: ServiceProtocol {
    /// The entity type for this service
    associatedtype CachedEntity
    
    /// Cache an entity
    /// - Parameters:
    ///   - entity: The entity to cache
    ///   - key: The key to use for caching
    func cache(_ entity: CachedEntity, forKey key: String) throws
    
    /// Get a cached entity
    /// - Parameter key: The key of the cached entity
    /// - Returns: The cached entity if found, nil otherwise
    func getCached(forKey key: String) -> CachedEntity?
    
    /// Clear the cache
    func clearCache() throws
    
    /// Remove a specific entry from the cache
    /// - Parameter key: The key of the entry to remove
    func removeCached(forKey key: String) throws
}

/// Protocol for services that handle transactions
public protocol TransactionalService: ServiceProtocol {
    /// Begin a transaction
    /// - Returns: A transaction identifier
    func beginTransaction() async throws -> String
    
    /// Commit a transaction
    /// - Parameter transactionId: The identifier of the transaction to commit
    func commitTransaction(_ transactionId: String) async throws
    
    /// Rollback a transaction
    /// - Parameter transactionId: The identifier of the transaction to rollback
    func rollbackTransaction(_ transactionId: String) async throws
}

/// Protocol for services that handle batch operations
public protocol BatchService: ServiceProtocol {
    /// The operation type for this service
    associatedtype Operation
    
    /// Execute a batch of operations
    /// - Parameter operations: The operations to execute
    /// - Returns: The results of the operations
    func executeBatch(_ operations: [Operation]) async throws -> [Result<Any, Error>]
}

/// Protocol for services that monitor status
public protocol MonitoringService: ServiceProtocol {
    /// The status type for this service
    associatedtype Status
    
    /// Get the current status of the service
    var status: Status { get }
    
    /// Start monitoring the service status
    func startMonitoring()
    
    /// Stop monitoring the service status
    func stopMonitoring()
    
    /// Publisher for status updates
    var statusPublisher: AnyPublisher<Status, Never> { get }
}

/// Protocol for services that handle real-time data
public protocol RealtimeService: ServiceProtocol {
    /// The data type for this service
    associatedtype RealtimeData
    
    /// Subscribe to real-time updates for a specific path
    /// - Parameter path: The path to subscribe to
    /// - Returns: A publisher that emits updates
    func subscribe(to path: String) -> AnyPublisher<RealtimeData, Error>
    
    /// Unsubscribe from real-time updates for a specific path
    /// - Parameter path: The path to unsubscribe from
    func unsubscribe(from path: String)
    
    /// Publish data to a specific path
    /// - Parameters:
    ///   - data: The data to publish
    ///   - path: The path to publish to
    func publish(_ data: RealtimeData, to path: String) async throws
}

/// Protocol for services that require logging
public protocol LoggingService: ServiceProtocol {
    /// Log an informational message
    /// - Parameter message: The message to log
    func logInfo(_ message: String)
    
    /// Log a warning message
    /// - Parameter message: The message to log
    func logWarning(_ message: String)
    
    /// Log an error message
    /// - Parameter message: The message to log
    func logError(_ message: String)
    
    /// Log a debug message
    /// - Parameter message: The message to log
    func logDebug(_ message: String)
}

/// Factory protocol for creating service instances
public protocol ServiceFactory {
    /// Get a service instance
    /// - Parameter serviceType: The type of service to get
    /// - Returns: The service instance
    func getService<T: ServiceProtocol>(_ serviceType: T.Type) -> T
    
    /// Register a service implementation
    /// - Parameters:
    ///   - serviceType: The type of service to register
    ///   - factory: A factory function that creates the service
    func registerService<T: ServiceProtocol>(_ serviceType: T.Type, factory: @escaping () -> T)
}

/// Service event struct
public struct ServiceEvent {
    /// Event type
    public let type: EventType
    
    /// Event timestamp
    public let timestamp: Date
    
    /// Event data
    public let data: [String: Any]
    
    /// Event types
    public enum EventType {
        case stateChanged
        case configChanged
        case authChanged
        case dataChanged
        case error
        case logMessage
        case custom(String)
    }
    
    /// Initialize with type and data
    /// - Parameters:
    ///   - type: Event type
    ///   - data: Event data
    public init(type: EventType, data: [String: Any] = [:]) {
        self.type = type
        self.data = data
        self.timestamp = Date()
    }
}

/// Service state enum
public enum ServiceState: Equatable {
    case initialized
    case configuring
    case configured
    case starting
    case running
    case pausing
    case paused
    case stopping
    case stopped
    case resetting
    case terminated
    case error(String)
    
    public static func == (lhs: ServiceState, rhs: ServiceState) -> Bool {
        switch (lhs, rhs) {
        case (.initialized, .initialized),
             (.configuring, .configuring),
             (.configured, .configured),
             (.starting, .starting),
             (.running, .running),
             (.pausing, .pausing),
             (.paused, .paused),
             (.stopping, .stopping),
             (.stopped, .stopped),
             (.resetting, .resetting),
             (.terminated, .terminated):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
} 