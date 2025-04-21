import SwiftUI

/// Main component for the home screen
public struct HomeFeature: View {
    @ObservedObject private var viewModel: HangoutsViewModel
    private let onNavigate: (HangoutRoute) -> Void
    
    public init(viewModel: HangoutsViewModel, onNavigate: @escaping (HangoutRoute) -> Void) {
        self.viewModel = viewModel
        self.onNavigate = onNavigate
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header welcome section
                WelcomeBannerView()
                
                // Main options
                HomeNavigationOptions(onNavigate: onNavigate)
                
                // Recent hangouts section
                if !viewModel.upcomingHangouts.isEmpty {
                    UpcomingHangoutsSection(
                        hangouts: viewModel.upcomingHangouts,
                        onSelectHangout: { hangoutID in
                            onNavigate(.hangoutDetails(hangoutID))
                        },
                        onViewAll: {
                            onNavigate(.hangoutsList)
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            viewModel.loadHangouts()
        }
    }
}

/// Welcome banner for the home screen
private struct WelcomeBannerView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Welcome to Unhinged")
                .font(.title)
                .fontWeight(.bold)
            
            Text("What would you like to do today?")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }
}

/// Navigation options for the home screen
private struct HomeNavigationOptions: View {
    let onNavigate: (HangoutRoute) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // View Hangouts Button
            HangoutNavigationButton(
                icon: "calendar",
                title: "My Hangouts",
                subtitle: "View your scheduled and pending hangouts",
                color: .blue
            ) {
                onNavigate(.hangoutsList)
            }
            
            // Set Availability Button
            HangoutNavigationButton(
                icon: "clock",
                title: "Set Availability",
                subtitle: "Update your couple's availability preferences",
                color: .green
            ) {
                onNavigate(.availability)
            }
            
            // Find Time Button
            HangoutNavigationButton(
                icon: "calendar.badge.clock",
                title: "Find Time",
                subtitle: "Schedule a hangout with another couple",
                color: .orange
            ) {
                onNavigate(.findTime(nil))
            }
            
            // Calendar Integration Button
            HangoutNavigationButton(
                icon: "rectangle.stack.badge.plus",
                title: "Calendar Integration",
                subtitle: "Connect and manage your external calendars",
                color: .purple
            ) {
                onNavigate(.calendarIntegration)
            }
        }
    }
}

/// Section that displays upcoming hangouts with a view all button
private struct UpcomingHangoutsSection: View {
    let hangouts: [Hangout]
    let onSelectHangout: (String) -> Void
    let onViewAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Hangouts")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(hangouts.prefix(3)) { hangout in
                HangoutCard(hangout: hangout) {
                    if let hangoutID = hangout.id {
                        onSelectHangout(hangoutID)
                    }
                }
                .padding(.horizontal)
            }
            
            if hangouts.count > 3 {
                Button(action: onViewAll) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding()
            }
        }
    }
} 