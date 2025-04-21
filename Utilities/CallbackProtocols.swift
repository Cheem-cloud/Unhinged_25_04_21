import Foundation
import Combine
import SwiftUI

/// Protocol for objects that can delegate work through callbacks
public protocol CallbackDelegate: AnyObject {
    /// The callback to be executed when an operation completes
    var onComplete: CallbackManager.SimpleCallback? { get set }
    
    /// The callback to be executed when an operation fails
    var onError: CallbackManager.Callback<Error>? { get set }
    
    /// The callback to be executed when the object's state changes
    var onStateChange: CallbackManager.SimpleCallback? { get set }
}

/// Protocol for objects that can delegate work through callbacks with a parameter
public protocol ParameterizedCallbackDelegate<T>: AnyObject {
    /// The type of parameter passed in the callbacks
    associatedtype T
    
    /// The callback to be executed when an operation completes with a result
    var onSuccess: CallbackManager.Callback<T>? { get set }
    
    /// The callback to be executed when an operation fails
    var onError: CallbackManager.Callback<Error>? { get set }
    
    /// The callback to be executed when the object's state changes
    var onStateChange: CallbackManager.SimpleCallback? { get set }
}

/// Protocol for objects that handle asynchronous operations with callbacks
public protocol AsyncCallbackHandler {
    /// Execute an asynchronous operation with callbacks for success and failure
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - onSuccess: The callback to execute when the operation succeeds
    ///   - onError: The callback to execute when the operation fails
    func executeAsync<T>(
        _ operation: @escaping () async throws -> T,
        onSuccess: @escaping CallbackManager.Callback<T>,
        onError: @escaping CallbackManager.Callback<Error>
    )
    
    /// Execute an asynchronous operation with a completion callback
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - completion: The completion callback
    func executeAsync<T>(
        _ operation: @escaping () async throws -> T,
        completion: @escaping CallbackManager.Completion<T>
    )
}

/// Default implementation of AsyncCallbackHandler
public extension AsyncCallbackHandler {
    func executeAsync<T>(
        _ operation: @escaping () async throws -> T,
        onSuccess: @escaping CallbackManager.Callback<T>,
        onError: @escaping CallbackManager.Callback<Error>
    ) {
        Task {
            do {
                let result = try await operation()
                await MainActor.run {
                    onSuccess(result)
                }
            } catch {
                await MainActor.run {
                    onError(error)
                }
            }
        }
    }
    
    func executeAsync<T>(
        _ operation: @escaping () async throws -> T,
        completion: @escaping CallbackManager.Completion<T>
    ) {
        Task {
            do {
                let result = try await operation()
                await MainActor.run {
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
}

/// Protocol for view models that use callbacks
public protocol CallbackViewModel: ObservableObject, CallbackDelegate, AsyncCallbackHandler {
    /// The published property for loading state
    var isLoading: Bool { get set }
    
    /// The published property for error state
    var error: Error? { get set }
    
    /// Reset all callbacks
    func resetCallbacks()
}

/// Default implementation of CallbackViewModel
public extension CallbackViewModel {
    func resetCallbacks() {
        onComplete = nil
        onError = nil
        onStateChange = nil
    }
    
    func handleError(_ error: Error) {
        self.error = error
        onError?(error)
    }
    
    func handleCompletion() {
        onComplete?()
    }
    
    func notifyStateChange() {
        onStateChange?()
    }
} 