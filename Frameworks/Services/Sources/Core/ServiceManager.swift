import Foundation

/// A manager for registering and retrieving services
public class ServiceManager {
    /// Shared instance of the service manager
    public static let shared = ServiceManager()
    
    /// Dictionary of services by type
    private var services: [String: Any] = [:]
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// Register a service instance for a protocol type
    /// - Parameters:
    ///   - instance: The service instance
    ///   - type: The protocol type
    public func register<T>(_ instance: Any, for type: T.Type) {
        let key = String(describing: type)
        services[key] = instance
    }
    
    /// Get a service instance for a protocol type
    /// - Parameter type: The protocol type
    /// - Returns: The service instance
    public func getService<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        
        guard let service = services[key] as? T else {
            fatalError("Service not registered for type: \(key)")
        }
        
        return service
    }
    
    /// Check if a service is registered for a protocol type
    /// - Parameter type: The protocol type
    /// - Returns: Whether the service is registered
    public func hasService<T>(_ type: T.Type) -> Bool {
        let key = String(describing: type)
        return services[key] != nil
    }
    
    /// Remove a service for a protocol type
    /// - Parameter type: The protocol type
    public func removeService<T>(_ type: T.Type) {
        let key = String(describing: type)
        services.removeValue(forKey: key)
    }
} 