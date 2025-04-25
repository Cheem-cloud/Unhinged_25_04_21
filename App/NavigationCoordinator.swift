import Foundation
import SwiftUI

/// A coordinator class that manages navigation within the app
public class NavigationCoordinator: ObservableObject {
    // MARK: - Navigation State
    
    /// The current screen being displayed
    @Published public var currentScreen: NavigationScreen = .home
    
    /// The navigation path for deep linking
    @Published public var navigationPath = NavigationPath()
    
    /// Navigation history for back button functionality
    private var navigationHistory: [NavigationScreen] = []
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Navigation Methods
    
    /// Navigate to a specific screen
    /// - Parameter screen: The screen to navigate to
    public func navigateTo(_ screen: NavigationScreen) {
        navigationHistory.append(currentScreen)
        currentScreen = screen
    }
    
    /// Navigate back to the previous screen
    public func navigateBack() {
        if let previousScreen = navigationHistory.popLast() {
            currentScreen = previousScreen
        }
    }
    
    /// Navigate to the home screen
    public func navigateToHome() {
        navigationHistory.removeAll()
        currentScreen = .home
    }
    
    /// Navigate to a specific profile
    /// - Parameter userID: The user ID to view
    public func navigateToProfile(userID: String) {
        navigateTo(.profile(userID: userID))
    }
    
    /// Navigate to a specific hangout detail
    /// - Parameter hangoutID: The hangout ID to view
    public func navigateToHangoutDetail(hangoutID: String) {
        navigateTo(.hangoutDetail(hangoutID: hangoutID))
    }
    
    /// Navigate to a specific relationship
    /// - Parameter relationshipID: The relationship ID to view
    public func navigateToRelationship(relationshipID: String) {
        navigateTo(.relationship(relationshipID: relationshipID))
    }
    
    /// Navigate to the calendar view
    public func navigateToCalendar() {
        navigateTo(.calendar)
    }
    
    /// Navigate to the availability view
    public func navigateToAvailability() {
        navigateTo(.availability)
    }
    
    /// Navigate to the settings view
    public func navigateToSettings() {
        navigateTo(.settings)
    }
}

/// Enumeration of possible navigation screens
public enum NavigationScreen: Hashable {
    case home
    case profile(userID: String)
    case hangoutDetail(hangoutID: String)
    case relationship(relationshipID: String)
    case calendar
    case availability
    case settings
    case createHangout
    case notifications
} 