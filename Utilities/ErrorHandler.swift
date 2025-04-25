import Foundation
import SwiftUI
import Combine

// MARK: - Error Handler

/// UI components and helpers for error handling
/// 
/// This file contains UI-specific error handling components.
/// Core error types and protocols are defined in ErrorHandling.swift

// Import the CustomTheme from the same module
// This is needed for the ErrorBanner view

/// Global error handler for centralized error management
public class UIErrorHandler: ObservableObject {
    /// Shared instance for global access
    public static let shared = UIErrorHandler()
    
    /// Current error being displayed
    @Published public var currentError: (any AppError)?
    
    /// Publisher for whether the error is being shown
    @Published public var isShowingError: Bool = false
    
    /// Publisher for the error showing state
    public var isShowingErrorPublisher: AnyPublisher<Bool, Never> {
        $isShowingError.eraseToAnyPublisher()
    }
    
    /// Collection of error handlers for specific error types
    private var errorHandlers: [String: (Error) -> Bool] = [:]
    
    /// Private initializer for singleton
    private init() {}
    
    /// Handle an error
    /// - Parameter error: The error to handle
    public func handle(_ error: Error) {
        // Check if any registered handler can handle this error
        for (_, handler) in errorHandlers {
            if handler(error) {
                return // Error was handled by a specific handler
            }
        }
        
        // If not handled by a specific handler, show it
        showError(error)
    }
    
    /// Show an error to the user
    /// - Parameter error: The error to show
    public func showError(_ error: Error) {
        // Convert to AppError if not already
        if let appError = error as? any AppError {
            currentError = appError
        } else {
            // Create a generic app error
            currentError = GeneralError(error: error) 
        }
        
        isShowingError = true
    }
    
    /// Register a handler for a specific error type
    /// - Parameters:
    ///   - key: A unique key for this handler
    ///   - handler: The handler function
    public func registerHandler(forKey key: String, handler: @escaping (Error) -> Bool) {
        errorHandlers[key] = handler
    }
    
    /// Unregister a handler
    /// - Parameter key: The key of the handler to remove
    public func unregisterHandler(forKey key: String) {
        errorHandlers.removeValue(forKey: key)
    }
    
    /// Clear the current error
    public func clearError() {
        currentError = nil
        isShowingError = false
    }
}

/// View modifier for presenting errors with the centralized error handler
public struct HandleErrorViewModifier: ViewModifier {
    @ObservedObject private var errorHandler: UIErrorHandler
    
    public init(errorHandler: UIErrorHandler = UIErrorHandler.shared) {
        self.errorHandler = errorHandler
    }
    
    public func body(content: Content) -> some View {
        content
            .alert(
                errorHandler.currentError?.errorTitle ?? "Error",
                isPresented: .init(
                    get: { errorHandler.isShowingError },
                    set: { if !$0 { errorHandler.clearError() } }
                ),
                actions: {
                    if let actions = errorHandler.currentError?.recoveryActions {
                        ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                            Button(action.title) {
                                action.action()
                                // Only dismiss if not explicitly handled by the action
                                if !action.title.lowercased().contains("try again") &&
                                   !action.title.lowercased().contains("retry") {
                                    errorHandler.clearError()
                                }
                            }
                        }
                    }
                    
                    Button("Dismiss", role: .cancel) {
                        errorHandler.clearError()
                    }
                },
                message: {
                    VStack {
                        if let description = errorHandler.currentError?.errorDescription {
                            Text(description)
                        }
                        
                        if let suggestion = errorHandler.currentError?.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption)
                                .padding(.top, 4)
                        }
                    }
                }
            )
    }
}

public extension View {
    func handleAppErrors(errorHandler: UIErrorHandler = UIErrorHandler.shared) -> some View {
        modifier(HandleErrorViewModifier(errorHandler: errorHandler))
    }
}

// MARK: - CustomTheme for ErrorBanner
public enum CustomColors {
    public static let background = Color(UIColor.systemBackground)
    public static let primary = Color.blue
    public static let secondary = Color.gray
    public static let accent = Color.orange
    public static let error = Color.red
    public static let warning = Color.yellow
    public static let success = Color.green
    public static let info = Color.blue
}

// MARK: - ErrorBanner View for custom error UI
public struct ErrorBanner: View {
    let error: any AppError
    let onDismiss: () -> Void
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: error.severity.icon)
                    .foregroundColor(error.severity.color)
                
                Text(error.errorTitle)
                    .font(.headline)
                    .foregroundColor(error.severity.color)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                }
            }
            
            if let description = error.errorDescription {
                Text(description)
                    .font(.subheadline)
            }
            
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !error.recoveryActions.isEmpty {
                HStack {
                    ForEach(0..<min(error.recoveryActions.count, 3), id: \.self) { index in
                        let action = error.recoveryActions[index]
                        Button(action: {
                            action.action()
                            if !action.title.lowercased().contains("try again") &&
                               !action.title.lowercased().contains("retry") {
                                onDismiss()
                            }
                        }) {
                            Label(action.title, systemImage: action.icon)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .if(action.isPrimary) { view in
                            view.buttonStyle(.borderedProminent)
                        }
                        
                        if index < min(error.recoveryActions.count, 3) - 1 {
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(CustomColors.background)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
}

// MARK: - Custom View Modifier for Custom Error Banner
public struct CustomErrorBannerModifier: ViewModifier {
    @ObservedObject private var errorHandler: UIErrorHandler
    @State private var showBanner = false
    
    public init(errorHandler: UIErrorHandler = UIErrorHandler.shared) {
        self.errorHandler = errorHandler
    }
    
    public func body(content: Content) -> some View {
        ZStack {
            content
            
            VStack {
                if showBanner, let error = errorHandler.currentError {
                    ErrorBanner(error: error) {
                        withAnimation {
                            showBanner = false
                            // Short delay before completely removing the error
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                errorHandler.clearError()
                            }
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                }
                
                Spacer()
            }
            .animation(.easeInOut, value: showBanner)
        }
        .onChange(of: errorHandler.isShowingError) { newValue in
            withAnimation {
                showBanner = newValue
            }
        }
    }
}

public extension View {
    func customErrorBanner(errorHandler: UIErrorHandler = UIErrorHandler.shared) -> some View {
        modifier(CustomErrorBannerModifier(errorHandler: errorHandler))
    }
}

// MARK: - Helper for conditional modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
} 