import SwiftUI
import Combine

// MARK: - Hangout Navigation State

/// Navigation state for the hangout coordination flow
public enum HangoutRoute: Hashable {
    case home
    case availability
    case findTime(String?) // Optional friend relationship ID
    case hangoutsList
    case createHangout(TimeSlot, String) // TimeSlot and friend relationship ID
    case hangoutDetails(String) // Hangout ID
    case calendarIntegration // Calendar integration state
    
    var depth: Int {
        switch self {
        case .home:
            return 0
        case .availability, .hangoutsList, .calendarIntegration, .findTime:
            return 1
        case .createHangout, .hangoutDetails:
            return 2
        }
    }
    
    var title: String {
        switch self {
        case .home:
            return "Unhinged"
        case .availability:
            return "Couple Availability"
        case .findTime:
            return "Find Time"
        case .hangoutsList:
            return "My Hangouts"
        case .createHangout:
            return "Create Hangout"
        case .hangoutDetails:
            return "Hangout Details"
        case .calendarIntegration:
            return "Calendar Integration"
        }
    }
}

// MARK: - Hangout Navigation Manager

/// Handles navigation state and transitions for the hangout feature
public class HangoutNavigationManager: ObservableObject {
    @Published public var currentRoute: HangoutRoute = .home
    @Published public var previousRoute: HangoutRoute?
    @Published public var transitionDirection: TransitionDirection = .forward
    
    public enum TransitionDirection {
        case forward
        case backward
    }
    
    public init(initialRoute: HangoutRoute = .home) {
        self.currentRoute = initialRoute
    }
    
    public func navigateTo(_ route: HangoutRoute) {
        // Save current state as previous state
        previousRoute = currentRoute
        
        // Determine if we're going forward or backward for animation
        transitionDirection = route.depth > currentRoute.depth ? .forward : .backward
        
        // Update state
        currentRoute = route
    }
    
    public func navigateBack() {
        if let previous = previousRoute {
            transitionDirection = .backward
            currentRoute = previous
            previousRoute = nil
        } else {
            transitionDirection = .backward
            currentRoute = .home
        }
    }
    
    public func transitionFor(direction: TransitionDirection) -> AnyTransition {
        switch direction {
        case .forward:
            return AnyTransition.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        case .backward:
            return AnyTransition.asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            )
        }
    }
}

// MARK: - Hangout Navigation Header Component

/// Reusable navigation header for the hangout feature
public struct HangoutNavigationHeaderView: View {
    @ObservedObject var navigationManager: HangoutNavigationManager
    
    public init(navigationManager: HangoutNavigationManager) {
        self.navigationManager = navigationManager
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Back button when not on home
            if navigationManager.currentRoute != .home {
                Button(action: { navigationManager.navigateBack() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Title
            Text(navigationManager.currentRoute.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Home button when not on home
            if navigationManager.currentRoute != .home {
                Button(action: {
                    navigationManager.navigateTo(.home)
                }) {
                    Image(systemName: "house")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Hangout Home Navigation Components

/// Navigation button used in the hangout home screen
public struct HangoutNavigationButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    public init(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(color)
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Calendar Integration Feature

/// A placeholder view for the Calendar Integration feature
public struct CalendarIntegrationFeature: View {
    let onBackTapped: () -> Void
    
    public init(onBackTapped: @escaping () -> Void) {
        self.onBackTapped = onBackTapped
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Calendar Integration")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Connect and manage your calendar providers")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding()
            
            Button("Coming Soon") {
                onBackTapped()
            }
            .padding()
            .foregroundColor(.white)
            .background(Color.blue)
            .cornerRadius(10)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
} 