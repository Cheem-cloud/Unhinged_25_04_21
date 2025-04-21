import SwiftUI
import FirebaseAuth
// Removed // Removed: import Unhinged.Utilities
// Removed: // Removed: import Unhinged.Navigation

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isShowingError = false
    
    var body: some View {
        ZStack {
            Group {
                if let user = Auth.auth().currentUser {
                    // User is signed in, show main app content with the new navigation system
                    AppNavigationView()
                        .transition(.opacity)
                } else {
                    // No user signed in, show authentication view
                    AuthView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: Auth.auth().currentUser != nil)
        }
        // Use our custom error overlay for a more polished experience
        .errorOverlay(isPresented: $isShowingError) { error in
            // You can add additional actions when an error is dismissed
            print("Error dismissed: \(error.errorTitle)")
        }
        // Also use the background error monitor to catch any errors from deeper in the app
        .monitorErrors(isPresented: $isShowingError)
        .onAppear {
            // Initialize the centralized error handler when the app starts
            _ = ErrorHandler.shared
            
            // Initialize the navigation coordinator
            _ = NavigationCoordinator.shared
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
} 