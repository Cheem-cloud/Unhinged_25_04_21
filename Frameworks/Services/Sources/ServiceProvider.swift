import Foundation
import Core

/// Service provider for accessing service implementations
public class ServiceProvider {
    /// Shared instance of the service provider
    public static let shared = ServiceProvider()
    
    // Private services cache
    private var services: [String: Any] = [:]
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// Register a service implementation for a protocol
    /// - Parameters:
    ///   - service: The service instance to register
    ///   - forProtocol: The protocol type the service implements
    public func register<T>(_ service: Any, forProtocol: T.Type) {
        let key = String(describing: T.self)
        services[key] = service
    }
    
    /// Get a service implementation for a protocol
    /// - Parameter protocol: The protocol type to get an implementation for
    /// - Returns: The service implementation
    public func get<T>(_ protocol: T.Type) -> T? {
        let key = String(describing: T.self)
        return services[key] as? T
    }
    
    /// Set up standard services with their implementations
    public func setupServices() {
        // Create and register services
        let authService = FirebaseAuthService()
        let userService = FirebaseUserService(authService: authService)
        
        // Register services
        register(authService, forProtocol: AuthService.self)
        register(userService, forProtocol: UserService.self)
        
        print("ServiceProvider: Standard services initialized")
    }
} 