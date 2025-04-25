// Services Module
// This file serves as the main entry point for the Services module

import Foundation
import Combine
import Core

// Public API
public struct Services {
    // Version information
    public static let version = "1.0.0"
    
    // Module initialization
    public static func initialize() {
        print("Services module initialized")
        
        // Initialize required subsystems
        ServiceManager.shared.setup()
    }
    
    // Convenience functions to get common services
    public static func getCRUDService() -> CRUDService? {
        return ServiceManager.shared.getService(CRUDService.self)
    }
}

/// Singleton service manager for registering and retrieving services
public final class ServiceManager {
    /// Shared instance
    public static let shared = ServiceManager()
    
    /// Private dictionary of service factories
    private var serviceFactories: [String: () -> Any] = [:]
    
    /// Private dictionary of service instances
    private var serviceInstances: [String: Any] = [:]
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// Initialize the service manager
    public func setup() {
        print("ServiceManager initialized")
    }
    
    /// Register a service factory
    /// - Parameters:
    ///   - serviceType: The type of service to register
    ///   - factory: A function that creates the service
    public func registerService<T>(_ serviceType: T.Type, factory: @escaping () -> T) {
        let key = String(describing: serviceType)
        serviceFactories[key] = factory
    }
    
    /// Register a service instance directly
    /// - Parameters:
    ///   - serviceType: The type of service to register
    ///   - instance: The service instance
    public func registerServiceInstance<T>(_ serviceType: T.Type, instance: T) {
        let key = String(describing: serviceType)
        serviceInstances[key] = instance
    }
    
    /// Get a service instance
    /// - Parameter serviceType: The type of service to get
    /// - Returns: The service instance
    public func getService<T>(_ serviceType: T.Type) -> T {
        let key = String(describing: serviceType)
        
        // Return existing instance if available
        if let instance = serviceInstances[key] as? T {
            return instance
        }
        
        // Create new instance if factory is available
        if let factory = serviceFactories[key] as? () -> T {
            let instance = factory()
            serviceInstances[key] = instance
            return instance
        }
        
        fatalError("Could not create service of type \(serviceType)")
    }
    
    /// Clear all service instances
    public func reset() {
        serviceInstances.removeAll()
    }
}
