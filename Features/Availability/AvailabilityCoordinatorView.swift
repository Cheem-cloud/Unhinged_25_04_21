import SwiftUI
import Firebase

/// Coordinator view for the Couples Availability Coordination feature
struct AvailabilityCoordinatorView: View {
    @State private var selectedTab = 0
    @State private var showHangoutsList = false
    @State private var navigateToHangoutDetails: String? = nil
    @EnvironmentObject var hangoutsViewModel: HangoutsViewModel
    
    /// The relationship ID, if provided
    var relationshipID: String?
    
    init(relationshipID: String? = nil) {
        self.relationshipID = relationshipID
    }
    
    var body: some View {
        VStack {
            // Top navigation controls
            HStack {
                Button(action: {
                    showHangoutsList = true
                }) {
                    HStack {
                        Image(systemName: "calendar")
                        Text("My Hangouts")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // Tab selection controls
                HStack {
                    TabButton(title: "Availability", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    
                    TabButton(title: "Find Time", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Tab content
            TabView(selection: $selectedTab) {
                // Availability Preferences Tab
                CoupleAvailabilityView(relationshipID: relationshipID)
                    .tag(0)
                
                // Mutual Availability Finder Tab
                MutualAvailabilityView(relationshipID: relationshipID)
                    .tag(1)
                    .environmentObject(hangoutsViewModel)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle("Couple Availability")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showHangoutsList) {
            NavigationView {
                HangoutsView()
                    .environmentObject(hangoutsViewModel)
                    .navigationBarItems(trailing: Button("Done") {
                        showHangoutsList = false
                    })
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hangoutCreated)) { notification in
            if let hangoutID = notification.userInfo?["hangoutID"] as? String {
                // Auto-navigate to the created hangout if notification is received
                navigateToHangoutDetails = hangoutID
            }
        }
        .background(
            NavigationLink(
                destination: Group {
                    if let hangoutID = navigateToHangoutDetails {
                        HangoutDetailView(hangoutID: hangoutID)
                            .environmentObject(hangoutsViewModel)
                    }
                },
                isActive: Binding(
                    get: { navigateToHangoutDetails != nil },
                    set: { if !$0 { navigateToHangoutDetails = nil } }
                )
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
}

/// Custom tab button for the coordinator
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isSelected ? Color.blue : Color.clear)
                .foregroundColor(isSelected ? .white : .blue)
                .cornerRadius(20)
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let hangoutCreated = Notification.Name("hangoutCreated")
}

struct AvailabilityCoordinatorView_Previews: PreviewProvider {
    static var previews: some View {
        AvailabilityCoordinatorView()
    }
} 