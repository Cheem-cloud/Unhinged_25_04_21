import SwiftUI
import Combine

/// A typed callback wrapper that provides a structured way to handle callbacks
/// This reduces nested closures and makes callback handling more consistent
public struct Callback<Value> {
    private let _callback: (Value) -> Void
    
    /// Initialize with a callback function
    /// - Parameter callback: The function to call when triggered
    public init(_ callback: @escaping (Value) -> Void) {
        self._callback = callback
    }
    
    /// Call the wrapped callback function
    /// - Parameter value: The value to pass to the callback
    public func callAsFunction(_ value: Value) {
        _callback(value)
    }
    
    /// Call the wrapped callback function with a transformed value
    /// - Parameters:
    ///   - value: The original value
    ///   - transform: A function to transform the value
    public func callAsFunction<T>(_ value: T, transform: (T) -> Value) {
        _callback(transform(value))
    }
    
    /// Create a new callback that transforms the input
    /// - Parameter transform: A function to transform the input
    /// - Returns: A new callback with transformed input
    public func map<T>(_ transform: @escaping (T) -> Value) -> Callback<T> {
        return Callback<T> { value in
            self._callback(transform(value))
        }
    }
}

/// A callback wrapper for actions without parameters
public struct Action {
    private let _action: () -> Void
    
    /// Initialize with an action function
    /// - Parameter action: The function to call when triggered
    public init(_ action: @escaping () -> Void) {
        self._action = action
    }
    
    /// Call the wrapped action function
    public func callAsFunction() {
        _action()
    }
    
    /// Return a void callback that executes this action
    /// - Returns: A callback that ignores its input and executes this action
    public func asVoidCallback() -> Callback<Void> {
        return Callback<Void> { _ in self._action() }
    }
    
    /// Return a callback of any type that executes this action
    /// - Returns: A callback that ignores its input and executes this action
    public func asCallback<T>() -> Callback<T> {
        return Callback<T> { _ in self._action() }
    }
}

// MARK: - Combine Extensions

extension Callback {
    /// Convert a callback to a Combine subject
    /// - Returns: A PassthroughSubject that emits the callback value
    public func asSubject() -> PassthroughSubject<Value, Never> {
        let subject = PassthroughSubject<Value, Never>()
        return subject
    }
    
    /// Create a callback that sends values to a subject
    /// - Parameter subject: The subject to send values to
    /// - Returns: A callback that sends values to the subject
    public static func fromSubject(_ subject: PassthroughSubject<Value, Never>) -> Callback<Value> {
        return Callback<Value> { value in
            subject.send(value)
        }
    }
}

// MARK: - Memory Management

/// A weak wrapper for callbacks to prevent retain cycles
public struct WeakCallback<Value> {
    private let _callback: (Value) -> Void
    
    /// Initialize with an object and callback method
    /// - Parameters:
    ///   - object: The object that owns the callback
    ///   - callback: The method to call on the object
    public init<T: AnyObject>(object: T, callback: @escaping (T, Value) -> Void) {
        _callback = { [weak object] value in
            guard let object = object else { return }
            callback(object, value)
        }
    }
    
    /// Call the wrapped callback function
    /// - Parameter value: The value to pass to the callback
    public func callAsFunction(_ value: Value) {
        _callback(value)
    }
    
    /// Convert to a regular callback
    /// - Returns: A Callback instance
    public func asCallback() -> Callback<Value> {
        return Callback<Value>(_callback)
    }
}

/// A weak wrapper for actions to prevent retain cycles
public struct WeakAction {
    private let _action: () -> Void
    
    /// Initialize with an object and action method
    /// - Parameters:
    ///   - object: The object that owns the action
    ///   - action: The method to call on the object
    public init<T: AnyObject>(object: T, action: @escaping (T) -> Void) {
        _action = { [weak object] in
            guard let object = object else { return }
            action(object)
        }
    }
    
    /// Call the wrapped action function
    public func callAsFunction() {
        _action()
    }
    
    /// Convert to a regular action
    /// - Returns: An Action instance
    public func asAction() -> Action {
        return Action(_action)
    }
} 