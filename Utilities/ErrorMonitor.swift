import SwiftUI
import Combine

/// A view component that monitors the centralized error handler and displays errors
public struct ErrorMonitor: ViewModifier {
    @ObservedObject var errorHandler = ErrorHandler.shared
    @Binding var isPresented: Bool
    var onDismiss: ((any AppError) -> Void)?
    
    public init(
        isPresented: Binding<Bool>,
        onDismiss: ((any AppError) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.onDismiss = onDismiss
    }
    
    public func body(content: Content) -> some View {
        content
            .onChange(of: errorHandler.isShowingError) { isShowing in
                isPresented = isShowing
            }
            .onChange(of: isPresented) { isShowing in
                // When isPresented is set to false by binding, dismiss the error
                if !isShowing && errorHandler.isShowingError {
                    if let error = errorHandler.currentError {
                        onDismiss?(error)
                    }
                    errorHandler.dismissError()
                }
            }
            .alert(
                errorHandler.currentError?.errorTitle ?? "Error",
                isPresented: $isPresented,
                actions: { 
                    // Add recovery actions if available
                    if let error = errorHandler.currentError,
                       !error.recoveryActions.isEmpty {
                        ForEach(error.recoveryActions, id: \.title) { action in
                            Button(action.title, role: action.isPrimary ? .none : .cancel) {
                                action.action()
                                errorHandler.dismissError()
                            }
                        }
                    } else {
                        Button("OK", role: .cancel) {
                            errorHandler.dismissError()
                        }
                    }
                },
                message: {
                    if let error = errorHandler.currentError,
                       let description = error.errorDescription {
                        Text(description)
                        
                        if let recoverySuggestion = error.recoverySuggestion {
                            Text("\n\(recoverySuggestion)")
                        }
                    } else {
                        Text("An unknown error occurred")
                    }
                }
            )
    }
}

public extension View {
    /// Attach error monitoring to the view
    /// - Parameters:
    ///   - isPresented: Binding to track error presentation state
    ///   - onDismiss: Optional action to perform when error is dismissed
    /// - Returns: A view with the error monitor attached
    func monitorErrors(
        isPresented: Binding<Bool>,
        onDismiss: ((any AppError) -> Void)? = nil
    ) -> some View {
        self.modifier(
            ErrorMonitor(
                isPresented: isPresented,
                onDismiss: onDismiss
            )
        )
    }
}

/// A more advanced error display using a custom view instead of an alert
public struct ErrorOverlayView: View {
    @ObservedObject var errorHandler = ErrorHandler.shared
    @Binding var isPresented: Bool
    var onDismiss: ((any AppError) -> Void)?
    
    public init(
        isPresented: Binding<Bool>,
        onDismiss: ((any AppError) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        if isPresented, let error = errorHandler.currentError {
            VStack(spacing: 16) {
                // Header with icon based on severity
                HStack {
                    severityIcon(for: error.severity)
                        .font(.title)
                    
                    Text(error.errorTitle)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        if let error = errorHandler.currentError {
                            onDismiss?(error)
                        }
                        errorHandler.dismissError()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Error description
                if let description = error.errorDescription {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                // Recovery suggestion
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                // Recovery actions
                if !error.recoveryActions.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(error.recoveryActions, id: \.title) { action in
                            Button(action: {
                                action.action()
                                errorHandler.dismissError()
                            }) {
                                HStack {
                                    if !action.icon.isEmpty {
                                        Image(systemName: action.icon)
                                    }
                                    Text(action.title)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(action.isPrimary ? Color.accentColor : Color.secondary.opacity(0.1))
                                .foregroundColor(action.isPrimary ? Color.white : Color.primary)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(100) // Ensure it's on top of other views
        }
    }
    
    private func severityIcon(for severity: ErrorSeverity) -> some View {
        switch severity {
        case .error:
            return Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        case .warning:
            return Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
        case .info:
            return Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
        }
    }
}

public extension View {
    /// Attach a custom error overlay to the view
    /// - Parameters:
    ///   - isPresented: Binding to track error presentation state
    ///   - onDismiss: Optional action to perform when error is dismissed
    /// - Returns: A view with the error overlay attached
    func errorOverlay(
        isPresented: Binding<Bool>,
        onDismiss: ((any AppError) -> Void)? = nil
    ) -> some View {
        ZStack {
            self
            
            ErrorOverlayView(
                isPresented: isPresented,
                onDismiss: onDismiss
            )
        }
        .onChange(of: ErrorHandler.shared.isShowingError) { isShowing in
            isPresented = isShowing
        }
        .onChange(of: isPresented) { isShowing in
            // When isPresented is set to false by binding, dismiss the error
            if !isShowing && ErrorHandler.shared.isShowingError {
                if let error = ErrorHandler.shared.currentError {
                    onDismiss?(error)
                }
                ErrorHandler.shared.dismissError()
            }
        }
    }
} 