import Foundation
import Combine
import FirebaseFirestore

/// Manager class for all services in the application
///
/// # Usage Example
///
/// Register a service with the manager:
/// ```
/// // Register the calendar service
/// let calendarService = CalendarOperationsServiceImpl()
/// ServiceManager.shared.registerService(CalendarOperationsService.self) {
///     calendarService
/// }
///
/// // For backward compatibility during transition, also register legacy service
/// ServiceManager.shared.registerService(CalendarService.self) { 
///     // Cast to Any to avoid direct dependency
///     calendarService as Any as! CalendarService
/// }
/// ```
public class ServiceManager: ServiceFactory {
    /// Shared instance (singleton)
    public static let shared = ServiceManager()
    
    /// Registry of services
    private var serviceRegistry: [String: () -> Any] = [:]
    
    /// Cached service instances
    private var serviceInstances: [String: Any] = [:]
    
    /// Subject for emitting service events
    private let serviceEventsSubject = PassthroughSubject<ServiceEvent, Never>()
    
    /// Publisher for service events from all services
    public var serviceEventsPublisher: AnyPublisher<ServiceEvent, Never> {
        return serviceEventsSubject.eraseToAnyPublisher()
    }
    
    /// Set of cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // Core service instances
    var firestoreService: FirestoreService
    
    /// Private initializer to enforce singleton pattern
    private init() {
        // Initialize core services
        self.firestoreService = FirestoreService.shared
    }
    
    /// Register a service implementation
    /// - Parameters:
    ///   - serviceType: The type of service to register
    ///   - factory: A factory function that creates the service
    public func registerService<T: ServiceProtocol>(_ serviceType: T.Type, factory: @escaping () -> T) {
        let key = String(describing: serviceType)
        serviceRegistry[key] = factory
    }
    
    /// Register a service singleton instance
    /// - Parameters:
    ///   - serviceType: The type of service to register
    ///   - instance: The service instance
    public func registerServiceInstance<T: ServiceProtocol>(_ serviceType: T.Type, instance: T) {
        let key = String(describing: serviceType)
        serviceInstances[key] = instance
        
        // Subscribe to service events
        if let baseService = instance as? BaseService {
            baseService.serviceEventPublisher
                .sink { [weak self] event in
                    self?.serviceEventsSubject.send(event)
                }
                .store(in: &cancellables)
        }
    }
    
    /// Get a service instance
    /// - Parameter serviceType: The type of service to get
    /// - Returns: The service instance
    public func getService<T: ServiceProtocol>(_ serviceType: T.Type) -> T {
        let key = String(describing: serviceType)
        
        // Return cached instance if available
        if let instance = serviceInstances[key] as? T {
            return instance
        }
        
        // Create a new instance using the factory
        guard let factory = serviceRegistry[key] as? () -> T else {
            // If no factory registered, create a new instance directly
            let instance = T()
            serviceInstances[key] = instance
            
            // Subscribe to service events if it's a BaseService
            if let baseService = instance as? BaseService {
                baseService.serviceEventPublisher
                    .sink { [weak self] event in
                        self?.serviceEventsSubject.send(event)
                    }
                    .store(in: &cancellables)
            }
            
            return instance
        }
        
        // Create and cache the instance
        let instance = factory()
        serviceInstances[key] = instance
        
        // Subscribe to service events if it's a BaseService
        if let baseService = instance as? BaseService {
            baseService.serviceEventPublisher
                .sink { [weak self] event in
                    self?.serviceEventsSubject.send(event)
                }
                .store(in: &cancellables)
        }
        
        return instance
    }
    
    /// Reset all services
    /// - Returns: Dictionary of service identifiers and reset results
    public func resetAllServices() async -> [String: Result<Void, Error>] {
        var results: [String: Result<Void, Error>] = [:]
        
        for (key, serviceInstance) in serviceInstances {
            guard let service = serviceInstance as? ServiceProtocol else {
                continue
            }
            
            do {
                try await service.reset()
                results[key] = .success(())
            } catch {
                results[key] = .failure(error)
            }
        }
        
        return results
    }
    
    /// Remove a service from the cache
    /// - Parameter serviceType: The type of service to remove
    public func removeService<T: ServiceProtocol>(_ serviceType: T.Type) {
        let key = String(describing: serviceType)
        serviceInstances.removeValue(forKey: key)
    }
    
    /// Remove all services from the cache
    public func removeAllServices() {
        serviceInstances.removeAll()
        cancellables.removeAll()
    }
    
    /// Get all registered service types
    /// - Returns: Array of service type names
    public func getRegisteredServiceTypes() -> [String] {
        return Array(serviceRegistry.keys)
    }
    
    /// Get all active service instances
    /// - Returns: Array of service instances
    public func getActiveServices() -> [ServiceProtocol] {
        return serviceInstances.values.compactMap { $0 as? ServiceProtocol }
    }
    
    /// Log a system-level message
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    public func log(_ message: String, level: LogLevel = .info) {
        let formattedMessage = "[ServiceManager|\(level.rawValue)] \(message)"
        
        switch level {
        case .debug:
            #if DEBUG
            print("🐞 \(formattedMessage)")
            #endif
        case .info:
            print("ℹ️ \(formattedMessage)")
        case .warning:
            print("⚠️ \(formattedMessage)")
        case .error:
            print("❌ \(formattedMessage)")
        case .critical:
            print("🚨 \(formattedMessage)")
        }
        
        let event = ServiceEvent(
            type: .logMessage,
            data: ["message": message, "level": level.rawValue, "source": "ServiceManager"]
        )
        serviceEventsSubject.send(event)
    }
} 