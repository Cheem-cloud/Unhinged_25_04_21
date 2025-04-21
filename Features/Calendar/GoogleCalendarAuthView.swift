import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn

class GoogleCalendarViewModel: ObservableObject {
    @Published var isConnecting = false
    @Published var isCalendarConnected = false
    @Published var error: Error?
    
    private let calendarService: CalendarServiceAdapter
    private let calendarAuthService = CalendarAuthService.shared
    
    init() {
        self.calendarService = ServiceManager.shared.getService(CRUDService.self) as! CalendarServiceAdapter
        
        Task {
            await checkCalendarConnection()
        }
    }
    
    @MainActor
    func checkCalendarConnection() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        self.isCalendarConnected = await calendarService.hasCalendarAccess(for: userId)
    }
    
    @MainActor
    func connectCalendar() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            error = NSError(domain: "com.cheemhang.calendar", code: 401, 
                    userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            return
        }
        
        print("Starting Google Calendar connection process for user: \(userId)")
        isConnecting = true
        
        do {
            print("About to call authenticateAndSaveCalendarAccess")
            try await calendarService.authenticateAndSaveCalendarAccess(for: userId)
            print("Authentication successful, checking connection status")
            await checkCalendarConnection() // Refresh connection status
            print("Successfully connected to Google Calendar")
        } catch {
            print("Error connecting to Google Calendar: \(error)")
            print("Error details: \(error.localizedDescription)")
            self.error = error
        }
        
        isConnecting = false
    }
    
    @MainActor
    func disconnectCalendar() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isConnecting = true
        
        do {
            // Remove token from Firestore
            let db = Firestore.firestore()
            let docRef = db.collection("users").document(userId).collection("tokens").document("calendar")
            try await docRef.delete()
            
            // Sign out of Google (but maintain Firebase auth)
            GIDSignIn.sharedInstance.signOut()
            
            isCalendarConnected = false
            print("Successfully disconnected from Google Calendar")
        } catch {
            print("Error disconnecting from Google Calendar: \(error.localizedDescription)")
            self.error = error
        }
        
        isConnecting = false
    }
    
    @MainActor
    func connectCalendarAlternative() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            error = NSError(domain: "com.cheemhang.calendar", code: 401, 
                    userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            return
        }
        
        print("Starting alternative Google Calendar connection process")
        isConnecting = true
        
        do {
            // Get Google Cloud project client ID
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw NSError(domain: "com.cheemhang.calendar", code: 500, 
                      userInfo: [NSLocalizedDescriptionKey: "Could not get Firebase client ID"])
            }
            
            print("Alternative method - Using client ID: \(clientID)")
            
            // Get the top view controller
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                throw NSError(domain: "com.cheemhang.calendar", code: 500, 
                      userInfo: [NSLocalizedDescriptionKey: "Could not get root view controller"])
            }
            
            // Configure GIDSignIn
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            print("Alternative method - Starting Google Sign-In")
            
            // Sign in with Google and request calendar scope
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil, 
                additionalScopes: ["https://www.googleapis.com/auth/calendar", 
                                 "https://www.googleapis.com/auth/calendar.events"]
            )
            
            print("Alternative method - Sign-in successful")
            
            // Save the token to Firestore
            let db = Firestore.firestore()
            let docRef = db.collection("users").document(userId).collection("tokens").document("calendar")
            
            var data: [String: Any] = [
                "accessToken": result.user.accessToken.tokenString,
                "updatedAt": Timestamp(date: Date())
            ]
            
            // Add expiration date if available
            if let expirationDate = result.user.accessToken.expirationDate {
                data["expirationDate"] = Timestamp(date: expirationDate)
            }
            
            // Add refresh token (no conditional check needed)
            data["refreshToken"] = result.user.refreshToken.tokenString
            
            // Add email if available
            if let email = result.user.profile?.email {
                data["email"] = email
            }
            
            try await docRef.setData(data)
            print("Alternative method - Saved token to Firestore")
            
            // Update UI
            isCalendarConnected = true
            print("Alternative method - Success!")
        } catch {
            print("Alternative method - Error: \(error)")
            print("Alternative method - Error details: \(error.localizedDescription)")
            self.error = error
        }
        
        isConnecting = false
    }
}

struct GoogleCalendarAuthView: View {
    @StateObject private var viewModel = GoogleCalendarViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "calendar")
                    .font(.system(size: 80))
                    .foregroundColor(.deepRed)
                    .padding(.bottom, 20)
                
                Text("Google Calendar Integration")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Connect your Google Calendar to easily check availability and schedule hangouts.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                if viewModel.isCalendarConnected {
                    // Calendar is connected
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Calendar Connected")
                            .font(.headline)
                        
                        Text("Your Google Calendar is connected. We'll use it to check your availability and schedule hangouts.")
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button {
                            Task {
                                await viewModel.disconnectCalendar()
                            }
                        } label: {
                            Text("Disconnect Calendar")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                } else {
                    // Calendar is not connected
                    VStack(spacing: 16) {
                        Text("Your calendar is not connected")
                            .font(.headline)
                        
                        Text("Connect your calendar to automatically check availability when scheduling hangouts.")
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button {
                            Task {
                                await viewModel.connectCalendar()
                            }
                        } label: {
                            HStack {
                                Text("Connect Google Calendar")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.deepRed)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // Alternative direct authentication method
                        Button {
                            Task {
                                await viewModel.connectCalendarAlternative()
                            }
                        } label: {
                            HStack {
                                Text("Try Alternative Method")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                }
                
                Spacer()
                
                if viewModel.isConnecting {
                    ProgressView("Processing...")
                        .padding()
                }
            }
            .padding()
            .navigationTitle("Calendar Connection")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(error.localizedDescription)
                            .font(.headline)
                        
                        Text("Error details: \(String(describing: error))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

#Preview {
    GoogleCalendarAuthView()
} 