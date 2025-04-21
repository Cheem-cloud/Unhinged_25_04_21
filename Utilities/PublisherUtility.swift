import Foundation
import Combine
import SwiftUI

/// Convenience methods for working with Combine publishers
public enum PublisherUtility {
    
    /// Creates a publisher that emits when an action is performed
    /// - Parameter action: The action to perform
    /// - Returns: A publisher that emits the action's result
    public static func publisher<T>(for action: @escaping () -> T) -> AnyPublisher<T, Never> {
        return Future<T, Never> { promise in
            promise(.success(action()))
        }.eraseToAnyPublisher()
    }
    
    /// Creates a publisher that emits when an asynchronous action is performed
    /// - Parameter action: The asynchronous action to perform
    /// - Returns: A publisher that emits the action's result
    public static func publisher<T>(for action: @escaping () async -> T) -> AnyPublisher<T, Error> {
        return Future<T, Error> { promise in
            Task {
                do {
                    let result = try await action()
                    promise(.success(result))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// Creates a publisher that emits when an asynchronous throwing action is performed
    /// - Parameter action: The asynchronous throwing action to perform
    /// - Returns: A publisher that emits the action's result or error
    public static func publisher<T>(for action: @escaping () async throws -> T) -> AnyPublisher<T, Error> {
        return Future<T, Error> { promise in
            Task {
                do {
                    let result = try await action()
                    promise(.success(result))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
}

// MARK: - Publisher Extensions

extension Publisher {
    /// Performs a side effect with the emitted value, useful for debugging or logging
    /// - Parameter sideEffect: The side effect to perform with the emitted value
    /// - Returns: A publisher that performs the side effect
    public func doOnNext(_ sideEffect: @escaping (Output) -> Void) -> AnyPublisher<Output, Failure> {
        return self.handleEvents(receiveOutput: { value in
            sideEffect(value)
        }).eraseToAnyPublisher()
    }
    
    /// Performs a side effect when an error is emitted, useful for debugging or logging
    /// - Parameter sideEffect: The side effect to perform with the emitted error
    /// - Returns: A publisher that performs the side effect
    public func doOnError(_ sideEffect: @escaping (Failure) -> Void) -> AnyPublisher<Output, Failure> {
        return self.handleEvents(receiveCompletion: { completion in
            if case let .failure(error) = completion {
                sideEffect(error)
            }
        }).eraseToAnyPublisher()
    }
    
    /// Performs a side effect when the publisher completes, useful for debugging or logging
    /// - Parameter sideEffect: The side effect to perform when the publisher completes
    /// - Returns: A publisher that performs the side effect
    public func doOnComplete(_ sideEffect: @escaping () -> Void) -> AnyPublisher<Output, Failure> {
        return self.handleEvents(receiveCompletion: { completion in
            if case .finished = completion {
                sideEffect()
            }
        }).eraseToAnyPublisher()
    }
}

// MARK: - SwiftUI Combine Integration

/// A view modifier that subscribes to a publisher and performs an action when a value is emitted
public struct OnReceiveModifier<P: Publisher>: ViewModifier where P.Failure == Never {
    private let publisher: P
    private let action: (P.Output) -> Void
    @State private var cancellable: AnyCancellable?
    
    public init(publisher: P, action: @escaping (P.Output) -> Void) {
        self.publisher = publisher
        self.action = action
    }
    
    public func body(content: Content) -> some View {
        content.onAppear {
            cancellable = publisher.sink(receiveValue: action)
        }
        .onDisappear {
            cancellable?.cancel()
            cancellable = nil
        }
    }
}

extension View {
    /// Subscribes to a publisher and performs an action when a value is emitted
    /// - Parameters:
    ///   - publisher: The publisher to subscribe to
    ///   - action: The action to perform with the emitted value
    /// - Returns: A view with the subscription
    public func onReceive<P: Publisher>(_ publisher: P, perform action: @escaping (P.Output) -> Void) -> some View where P.Failure == Never {
        return self.modifier(OnReceiveModifier(publisher: publisher, action: action))
    }
} 