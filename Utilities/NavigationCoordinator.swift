import SwiftUI

/// Manages app navigation and screen transitions
public class NavigationCoordinator: ObservableObject {
    /// Shared instance for app-wide navigation
    public static let shared = NavigationCoordinator()
    
    /// Published active screen for binding in views
    @Published public var activeScreen: Screen = .home
    
    /// Navigation path for deep linking and complex navigation flows
    @Published public var navigationPath = NavigationPath()
    
    /// Tracks previous screens for back navigation
    private var screenHistory: [Screen] = []
    
    /// Private initializer for singleton pattern
    private init() {}
    
    /// Available screens in the app
    public enum Screen: String, Identifiable {
        case home
        case profile
        case settings
        case calendar
        case hangouts
        case hangoutDetail
        case createHangout
        case partners
        case partnerPersonas
        case notifications
        case availability
        case onboarding
        case auth
        
        public var id: String { rawValue }
    }
    
    /// Navigate to a specific screen
    /// - Parameter screen: The screen to navigate to
    public func navigate(to screen: Screen) {
        screenHistory.append(activeScreen)
        activeScreen = screen
    }
    
    /// Navigate back to the previous screen
    public func navigateBack() {
        if let previousScreen = screenHistory.popLast() {
            activeScreen = previousScreen
        }
    }
    
    /// Reset navigation to the home screen
    public func navigateToHome() {
        screenHistory = []
        activeScreen = .home
    }
    
    /// Add a destination to the navigation path
    /// - Parameter destination: The destination to add
    public func push<T: Hashable>(_ destination: T) {
        navigationPath.append(destination)
    }
    
    /// Go back one level in the navigation path
    public func pop() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
    
    /// Clear the navigation path
    public func popToRoot() {
        navigationPath = NavigationPath()
    }
} 