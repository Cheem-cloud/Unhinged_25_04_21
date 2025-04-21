import Foundation
import SwiftUI
import Combine

/// Protocol for all app-specific errors to conform to
public protocol AppError: Error, LocalizedError {
    var domain: String { get }
    var errorTitle: String { get }
    var errorDescription: String? { get }
    var recoverySuggestion: String? { get }
    var severity: ErrorSeverity { get }
    var recoveryActions: [ErrorRecoveryAction] { get }
}

/// Standardized severity levels for errors
public enum ErrorSeverity {
    case info
    case warning
    case error
    case critical
    
    var color: Color {
        switch self {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "exclamationmark.circle"
        case .critical:
            return "xmark.octagon"
        }
    }
}

/// Standard error recovery action model
public struct ErrorRecoveryAction {
    let title: String
    let icon: String
    let isPrimary: Bool
    let action: () -> Void
    
    public init(title: String, icon: String, isPrimary: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isPrimary = isPrimary
        self.action = action
    }
}

/// Central error handling system for the app
public class ErrorHandler: ObservableObject {
    public static let shared = ErrorHandler()
    
    @Published public var currentError: AppError?
    @Published public var isShowingError = false
    
    private init() {}
    
    public func handle(_ error: Error) {
        DispatchQueue.main.async {
            // Convert to AppError if needed
            if let appError = error as? AppError {
                self.currentError = appError
            } else if let nsError = error as NSError? {
                // Check if we have domain-specific error handlers
                if nsError.domain.contains("Hangout") || nsError.domain == "com.cheemhang.hangoutsviewmodel" {
                    self.currentError = HangoutError(from: nsError)
                } else if nsError.domain.contains("Availability") {
                    self.currentError = AvailabilityError(from: nsError)
                } else {
                    // Create a generic app error for unhandled error types
                    self.currentError = GenericAppError(from: nsError)
                }
            }
            
            self.isShowingError = true
            
            // Log the error (could integrate with analytics/logging service)
            print("Error handled: \(error.localizedDescription)")
        }
    }
    
    public func dismissError() {
        self.isShowingError = false
        self.currentError = nil
    }
}

/// Generic error for handling non-domain-specific errors
struct GenericAppError: AppError {
    private let error: Error
    private let customMessage: String?
    
    init(from error: Error, customMessage: String? = nil) {
        self.error = error
        self.customMessage = customMessage
    }
    
    var domain: String {
        return "General"
    }
    
    var errorTitle: String {
        return "Error"
    }
    
    var errorDescription: String? {
        return customMessage ?? error.localizedDescription
    }
    
    var recoverySuggestion: String? {
        if let localizedError = error as? LocalizedError {
            return localizedError.recoverySuggestion
        }
        return "Please try again later."
    }
    
    var severity: ErrorSeverity {
        return .warning
    }
    
    var recoveryActions: [ErrorRecoveryAction] {
        return [
            ErrorRecoveryAction(
                title: "Dismiss",
                icon: "xmark.circle",
                isPrimary: true,
                action: {
                    ErrorHandler.shared.dismissError()
                }
            )
        ]
    }
}

/// View modifier for presenting errors with the centralized error handler
public struct HandleErrorViewModifier: ViewModifier {
    @ObservedObject private var errorHandler = ErrorHandler.shared
    
    public func body(content: Content) -> some View {
        content
            .alert(
                errorHandler.currentError?.errorTitle ?? "Error",
                isPresented: $errorHandler.isShowingError,
                actions: {
                    if let actions = errorHandler.currentError?.recoveryActions {
                        ForEach(0..<actions.count, id: \.self) { index in
                            let action = actions[index]
                            Button(action.title) {
                                action.action()
                                // Only dismiss if not explicitly handled by the action
                                if !action.title.lowercased().contains("try again") &&
                                   !action.title.lowercased().contains("retry") {
                                    errorHandler.dismissError()
                                }
                            }
                        }
                    }
                    
                    Button("Dismiss", role: .cancel) {
                        errorHandler.dismissError()
                    }
                },
                message: {
                    if let suggestion = errorHandler.currentError?.recoverySuggestion,
                       let description = errorHandler.currentError?.errorDescription {
                        Text("\(description)\n\n\(suggestion)")
                    } else if let description = errorHandler.currentError?.errorDescription {
                        Text(description)
                    }
                }
            )
    }
}

public extension View {
    func handleAppErrors() -> some View {
        modifier(HandleErrorViewModifier())
    }
}

// MARK: - ErrorBanner View for custom error UI
public struct ErrorBanner: View {
    let error: AppError
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
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
}

// Helper for conditional modifier
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

// MARK: - Custom View Modifier for Custom Error Banner
public struct CustomErrorBannerModifier: ViewModifier {
    @ObservedObject private var errorHandler = ErrorHandler.shared
    @State private var showBanner = false
    
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
                                errorHandler.dismissError()
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
    func customErrorBanner() -> some View {
        modifier(CustomErrorBannerModifier())
    }
} 