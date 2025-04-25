import Foundation
import Combine

/// Base class for all services implementing the ServiceProtocol
open class BaseService: ServiceProtocol {
    /// The identifier of the service
    public let identifier: String
    
    /// Subject for emitting service events
    internal let eventSubject = PassthroughSubject<ServiceEvent, Never>()
    
    /// Publisher for service events
    public var serviceEventPublisher: AnyPublisher<ServiceEvent, Never> {
        return eventSubject.eraseToAnyPublisher()
    }
    
    /// Service state
    internal var state: ServiceState = .initialized
    
    /// Publisher for service state changes
    public var statePublisher: AnyPublisher<ServiceState, Never> {
        return stateSubject.eraseToAnyPublisher()
    }
    
    /// Subject for emitting service state changes
    private let stateSubject = CurrentValueSubject<ServiceState, Never>(.initialized)
    
    /// Set of cancellables for managing subscriptions
    internal var cancellables = Set<AnyCancellable>()
    
    /// Initialize with an identifier
    /// - Parameter identifier: The service identifier
    public required init(identifier: String) {
        self.identifier = identifier
        self.setup()
    }
    
    /// Required initializer - uses the class name as identifier
    public required init() {
        self.identifier = String(describing: type(of: self))
        self.setup()
    }
    
    /// Setup the service
    open func setup() {
        // Override in subclasses to perform initialization
    }
    
    /// Update the service state
    /// - Parameter newState: The new state
    internal func updateState(_ newState: ServiceState) {
        self.state = newState
        self.stateSubject.send(newState)
    }
    
    /// Verify that the service is in a usable state
    /// - Returns: Whether the service is available
    open func isAvailable() -> Bool {
        if case .error(_) = state {
            return false
        }
        return state != .terminated
    }
    
    /// Reset the service state
    /// - Throws: ServiceError if the service cannot be reset
    open func reset() async throws {
        updateState(.resetting)
        
        // Clear any resources
        cancellables.removeAll()
        
        updateState(.initialized)
    }
    
    /// Emit a service event
    /// - Parameter event: The event to emit
    internal func emit(_ event: ServiceEvent) {
        eventSubject.send(event)
    }
    
    /// Log a message to console
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    internal func log(_ message: String, level: LogLevel = .info) {
        let formattedMessage = "[\(identifier)|\(level.rawValue)] \(message)"
        
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
        
        emit(ServiceEvent(type: .logMessage, data: ["message": message, "level": level.rawValue]))
    }
}

/// Log levels for service logging
public enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
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