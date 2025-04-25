import SwiftUI
import Core
import Services

/// Coordinator for authentication flow
public class AuthCoordinator: ObservableObject {
    // Auth view model
    private let authViewModel: AuthViewModel
    
    // Navigation state
    @Published public var showSignUp = false
    @Published public var showForgotPassword = false
    
    /// Initialize with service provider
    public init(serviceProvider: ServiceProvider = ServiceProvider.shared) {
        // Get services
        guard let authService = serviceProvider.get(AuthService.self),
              let userService = serviceProvider.get(UserService.self) else {
            fatalError("Required services not registered in ServiceProvider")
        }
        
        // Create view model
        self.authViewModel = AuthViewModel(authService: authService, userService: userService)
    }
    
    /// Get the login view
    public func makeLoginView() -> some View {
        LoginView(viewModel: authViewModel)
    }
    
    /// Get the sign up view
    public func makeSignUpView() -> some View {
        SignUpView(viewModel: authViewModel)
    }
    
    /// Get the authentication flow container view
    public func makeAuthFlowView() -> some View {
        AuthFlowContainerView(coordinator: self)
    }
}

/// Container view for authentication flow
public struct AuthFlowContainerView: View {
    @ObservedObject var coordinator: AuthCoordinator
    
    public init(coordinator: AuthCoordinator) {
        self.coordinator = coordinator
    }
    
    public var body: some View {
        NavigationStack {
            coordinator.makeLoginView()
                .navigationDestination(isPresented: $coordinator.showSignUp) {
                    coordinator.makeSignUpView()
                }
        }
    }
} 