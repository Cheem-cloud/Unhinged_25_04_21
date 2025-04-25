import Foundation
import Combine
import SwiftUI

/// Manages callbacks consistently throughout the app
public class CallbackManager {
    // MARK: - Singleton Instance
    
    /// Shared instance of the callback manager
    public static let shared = CallbackManager()
    
    // MARK: - Type Aliases
    
    /// Simple callback with no parameters
    public typealias SimpleCallback = () -> Void
    
    /// Callback with a generic parameter
    public typealias Callback<T> = (T) -> Void
    
    /// Callback with a generic parameter and a result
    public typealias ResultCallback<T, U> = (T) -> U
    
    /// Async callback with no parameters
    public typealias AsyncCallback = () async -> Void
    
    /// Async callback with a generic parameter
    public typealias AsyncParamCallback<T> = (T) async -> Void
    
    /// Async callback with a generic parameter and result
    public typealias AsyncResultCallback<T, U> = (T) async -> U
    
    /// Throwing callback with no parameters
    public typealias ThrowingCallback = () throws -> Void
    
    /// Throwing callback with a generic parameter
    public typealias ThrowingParamCallback<T> = (T) throws -> Void
    
    /// Async throwing callback with no parameters
    public typealias AsyncThrowingCallback = () async throws -> Void
    
    /// Async throwing callback with a generic parameter
    public typealias AsyncThrowingParamCallback<T> = (T) async throws -> Void
    
    /// Completion handler with a result type
    public typealias CompletionResult<T> = Result<T, Error>
    
    /// Completion handler with a result type
    public typealias Completion<T> = (CompletionResult<T>) -> Void
    
    // MARK: - Callback Wrapper Structures
    
    /// Wrapper for simple callbacks that maintains weak references to prevent retain cycles
    public class WeakCallback<Owner: AnyObject> {
        private weak var owner: Owner?
        private let callback: (Owner) -> Void
        
        /// Initialize with an owner and callback
        /// - Parameters:
        ///   - owner: The owning object that contains the callback
        ///   - callback: The callback to execute, passing the owner as a parameter
        public init(owner: Owner, callback: @escaping (Owner) -> Void) {
            self.owner = owner
            self.callback = callback
        }
        
        /// Execute the callback if the owner is still available
        /// - Returns: Whether the callback was executed
        @discardableResult
        public func execute() -> Bool {
            if let owner = owner {
                callback(owner)
                return true
            }
            return false
        }
    }
    
    /// Wrapper for callbacks with a parameter that maintains weak references to prevent retain cycles
    public class WeakParamCallback<Owner: AnyObject, Param> {
        private weak var owner: Owner?
        private let callback: (Owner, Param) -> Void
        
        /// Initialize with an owner and callback
        /// - Parameters:
        ///   - owner: The owning object that contains the callback
        ///   - callback: The callback to execute, passing the owner and parameter
        public init(owner: Owner, callback: @escaping (Owner, Param) -> Void) {
            self.owner = owner
            self.callback = callback
        }
        
        /// Execute the callback if the owner is still available
        /// - Parameter param: The parameter to pass to the callback
        /// - Returns: Whether the callback was executed
        @discardableResult
        public func execute(with param: Param) -> Bool {
            if let owner = owner {
                callback(owner, param)
                return true
            }
            return false
        }
    }
    
    // MARK: - Callback to Publisher Conversion
    
    /// Convert a callback-based API to a publisher
    /// - Parameter callback: A function that takes a completion handler and performs an operation
    /// - Returns: A publisher that emits the result of the operation
    public static func createPublisher<T>(
        from callback: @escaping (@escaping Completion<T>) -> Void
    ) -> AnyPublisher<T, Error> {
        return Future<T, Error> { promise in
            callback { result in
                promise(result)
            }
        }.eraseToAnyPublisher()
    }
    
    /// Convert an async operation to a publisher
    /// - Parameter operation: An async operation that returns a value
    /// - Returns: A publisher that emits the result of the operation
    public static func createPublisher<T>(
        from operation: @escaping () async throws -> T
    ) -> AnyPublisher<T, Error> {
        return Future<T, Error> { promise in
            Task {
                do {
                    let result = try await operation()
                    promise(.success(result))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - Callback Composition
    
    /// Chain multiple callbacks together
    /// - Parameter callbacks: The callbacks to chain
    /// - Returns: A single callback that executes all the provided callbacks
    public static func chain(_ callbacks: SimpleCallback...) -> SimpleCallback {
        return {
            callbacks.forEach { $0() }
        }
    }
    
    /// Chain multiple callbacks with a parameter together
    /// - Parameter callbacks: The callbacks to chain
    /// - Returns: A single callback that executes all the provided callbacks with the parameter
    public static func chain<T>(_ callbacks: Callback<T>...) -> Callback<T> {
        return { param in
            callbacks.forEach { $0(param) }
        }
    }
    
    // MARK: - Safe Callback Execution
    
    /// Safely execute a callback on the main thread
    /// - Parameter callback: The callback to execute
    public static func executeOnMain(_ callback: @escaping SimpleCallback) {
        if Thread.isMainThread {
            callback()
        } else {
            DispatchQueue.main.async {
                callback()
            }
        }
    }
    
    /// Safely execute a callback with a parameter on the main thread
    /// - Parameters:
    ///   - callback: The callback to execute
    ///   - param: The parameter to pass to the callback
    public static func executeOnMain<T>(_ callback: @escaping Callback<T>, with param: T) {
        if Thread.isMainThread {
            callback(param)
        } else {
            DispatchQueue.main.async {
                callback(param)
            }
        }
    }
    
    // MARK: - Debounce and Throttle
    
    /// Returns a debounced version of the callback
    /// - Parameters:
    ///   - interval: The time interval to wait before executing the callback
    ///   - callback: The callback to debounce
    /// - Returns: A debounced callback
    public static func debounce(interval: TimeInterval, callback: @escaping SimpleCallback) -> SimpleCallback {
        var workItem: DispatchWorkItem?
        
        return {
            workItem?.cancel()
            
            let newWorkItem = DispatchWorkItem {
                callback()
            }
            
            workItem = newWorkItem
            
            DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: newWorkItem)
        }
    }
    
    /// Returns a throttled version of the callback
    /// - Parameters:
    ///   - interval: The minimum time interval between executions
    ///   - callback: The callback to throttle
    /// - Returns: A throttled callback
    public static func throttle(interval: TimeInterval, callback: @escaping SimpleCallback) -> SimpleCallback {
        var lastExecutionTime: Date = .distantPast
        
        return {
            let now = Date()
            let timeSinceLastExecution = now.timeIntervalSince(lastExecutionTime)
            
            if timeSinceLastExecution >= interval {
                lastExecutionTime = now
                callback()
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Executes a callback when the view appears
    /// - Parameter callback: The callback to execute
    /// - Returns: A view with the callback attached
    public func onAppearCallback(perform callback: @escaping CallbackManager.SimpleCallback) -> some View {
        self.onAppear {
            callback()
        }
    }
    
    /// Executes a callback when the view disappears
    /// - Parameter callback: The callback to execute
    /// - Returns: A view with the callback attached
    public func onDisappearCallback(perform callback: @escaping CallbackManager.SimpleCallback) -> some View {
        self.onDisappear {
            callback()
        }
    }
    
    /// Subscribes to a publisher and executes a callback when a value is emitted
    /// - Parameters:
    ///   - publisher: The publisher to subscribe to
    ///   - callback: The callback to execute when a value is emitted
    /// - Returns: A view with the subscription
    public func onReceiveValue<P: Publisher>(
        _ publisher: P,
        perform callback: @escaping CallbackManager.Callback<P.Output>
    ) -> some View where P.Failure == Never {
        self.onReceive(publisher) { value in
            callback(value)
        }
    }
}

// MARK: - Combine Extensions

extension Publisher where Failure == Never {
    /// Subscribes to the publisher and executes a callback when a value is emitted
    /// - Parameter callback: The callback to execute when a value is emitted
    /// - Returns: A cancellable object that can be used to cancel the subscription
    public func sinkWithCallback(receiveValue callback: @escaping CallbackManager.Callback<Output>) -> AnyCancellable {
        return self.sink(receiveValue: callback)
    }
}

extension Publisher {
    /// Subscribes to the publisher and executes callbacks for completion and values
    /// - Parameters:
    ///   - completionCallback: The callback to execute when the publisher completes
    ///   - valueCallback: The callback to execute when a value is emitted
    /// - Returns: A cancellable object that can be used to cancel the subscription
    public func sinkWithCallbacks(
        receiveCompletion completionCallback: @escaping CallbackManager.Callback<Subscribers.Completion<Failure>>,
        receiveValue valueCallback: @escaping CallbackManager.Callback<Output>
    ) -> AnyCancellable {
        return self.sink(
            receiveCompletion: completionCallback,
            receiveValue: valueCallback
        )
    }
} 