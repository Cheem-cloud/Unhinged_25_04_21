import Foundation
import Combine
import SwiftUI
// Removed // Removed: import Unhinged.Utilities

/// Base protocol for all view models to ensure consistency
protocol BaseViewModel: ObservableObject {
    /// Loading state
    var isLoading: Bool { get set }
    
    /// Error state
    var error: Error? { get set }
    
    /// Whether there's an error
    var hasError: Bool { get }
    
    /// Clear error state
    func clearError()
}

/// Default implementation for BaseViewModel
extension BaseViewModel {
    var hasError: Bool {
        return error != nil
    }
    
    func clearError() {
        error = nil
    }
}

/// Default error handling for view models
extension BaseViewModel {
    /// Handle errors in a consistent way
    /// - Parameter error: The error to handle
    func handleError(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        self.error = error
        
        // Log the error
        let fileName = (file as NSString).lastPathComponent
        print("❌ ERROR: \(error.localizedDescription) in \(fileName):\(line) - \(function)")
        
        // Use the centralized error handler
        ErrorHandler.shared.handle(error)
    }
}

/// Base class for all view models to inherit from
class MVVMViewModel: BaseViewModel {
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    /// Cancellables for managing subscriptions
    var cancellables = Set<AnyCancellable>()
    
    /// Reset the view model state
    func reset() {
        isLoading = false
        error = nil
    }
    
    /// Perform an async operation with loading and error handling
    /// - Parameter operation: The async operation to perform
    func performAsyncOperation<T>(_ operation: @escaping () async throws -> T) async -> T? {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let result = try await operation()
            
            await MainActor.run {
                isLoading = false
            }
            
            return result
        } catch {
            await MainActor.run {
                handleError(error)
                isLoading = false
            }
            return nil
        }
    }
}

// MARK: - View Extensions

/// Extension on View to provide consistent error alert handling
extension View {
    /// Add an error alert to a view
    /// - Parameters:
    ///   - error: Binding to the error
    ///   - buttonTitle: Title for the dismiss button
    ///   - onDismiss: Action to perform when the alert is dismissed
    /// - Returns: View with error alert
    func errorAlert<T: Error>(
        error: Binding<T?>,
        buttonTitle: String = "OK",
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        let localizedError = error.wrappedValue?.localizedDescription ?? "Unknown error"
        return alert(isPresented: .init(
            get: { error.wrappedValue != nil },
            set: { if !$0 { error.wrappedValue = nil }}
        )) {
            Alert(
                title: Text("Error"),
                message: Text(localizedError),
                dismissButton: .default(Text(buttonTitle)) {
                    error.wrappedValue = nil
                    onDismiss?()
                }
            )
        }
    }
    
    /// Add a standardized error alert that uses the central error handler
    func centralizedErrorAlert(isPresented: Binding<Bool>) -> some View {
        self.errorAlert(isPresented: isPresented)
    }
    
    /// Add a loading overlay to a view
    /// - Parameters:
    ///   - isLoading: Binding to the loading state
    ///   - message: Message to display while loading
    /// - Returns: View with loading overlay
    func loadingOverlay(_ isLoading: Bool, message: String = "Loading...") -> some View {
        self.overlay(
            Group {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.2)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text(message)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .font(AppTheme.Typography.callout)
                        }
                        .padding()
                        .background(AppTheme.Colors.secondaryBackground)
                        .cornerRadius(AppTheme.Layout.standardCornerRadius)
                        .shadow(radius: 10)
                    }
                }
            }
        )
        .disabled(isLoading)
    }
} 