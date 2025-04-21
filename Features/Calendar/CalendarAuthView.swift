import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn
import EventKit

class FullCalendarAuthViewModel: ObservableObject {
    @Published var isConnecting = false
    @Published var error: Error?
    @Published var googleCalendarConnected = false
    @Published var outlookCalendarConnected = false
    @Published var appleCalendarConnected = false
    
    // Replace direct reference with adapter
    private let calendarService: CalendarServiceAdapter
    private let calendarAuthService = CalendarAuthService.shared
    private let serviceFactory = CalendarServiceFactory.shared
    
    // The provider we're currently connecting
    private var currentProviderType: CalendarProviderType?
    
    init() {
        // Get CalendarServiceAdapter from ServiceManager
        self.calendarService = ServiceManager.shared.getService(CRUDService.self) as! CalendarServiceAdapter
        
        Task {
            await checkAllCalendarConnections()
        }
    }
    
    @MainActor
    func checkAllCalendarConnections() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Check Google Calendar
        self.googleCalendarConnected = await calendarAuthService.hasCalendarAccess(for: userId, providerType: .google)
        
        // Check Outlook Calendar
        self.outlookCalendarConnected = await calendarAuthService.hasCalendarAccess(for: userId, providerType: .outlook)
        
        // Check Apple Calendar
        let appleProvider = serviceFactory.getProvider(for: .apple) as? AppleCalendarProvider
        if let appleProvider = appleProvider {
            let status = appleProvider.checkAuthorizationStatus()
            self.appleCalendarConnected = status == .authorized
        }
    }
    
    @MainActor
    func connectGoogleCalendar() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            error = NSError(domain: "com.cheemhang.calendar", code: 401, 
                    userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            return
        }
        
        print("Starting Google Calendar connection process for user: \(userId)")
        isConnecting = true
        currentProviderType = .google
        
        do {
            try await calendarAuthService.authenticateAndSaveCalendarAccess(for: userId, providerType: .google)
            await checkAllCalendarConnections() // Refresh connection status
            print("Successfully connected to Google Calendar")
        } catch {
            print("Error connecting to Google Calendar: \(error)")
            self.error = error
        }
        
        isConnecting = false
        currentProviderType = nil
    }
    
    @MainActor
    func connectOutlookCalendar() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            error = NSError(domain: "com.cheemhang.calendar", code: 401, 
                    userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            return
        }
        
        print("Starting Outlook Calendar connection process for user: \(userId)")
        isConnecting = true
        currentProviderType = .outlook
        
        do {
            try await calendarAuthService.authenticateAndSaveCalendarAccess(for: userId, providerType: .outlook)
            await checkAllCalendarConnections() // Refresh connection status
            print("Successfully connected to Outlook Calendar")
        } catch {
            print("Error connecting to Outlook Calendar: \(error)")
            self.error = error
        }
        
        isConnecting = false
        currentProviderType = nil
    }
    
    @MainActor
    func connectAppleCalendar() async {
        isConnecting = true
        currentProviderType = .apple
        
        let appleProvider = serviceFactory.getProvider(for: .apple) as? AppleCalendarProvider
        if let appleProvider = appleProvider {
            // Request access to the calendar
            let granted = await appleProvider.requestAccess()
            
            if granted {
                print("Apple Calendar access granted")
                appleCalendarConnected = true
                
                // Save the fact that we're using Apple Calendar in user preferences
                if let userId = Auth.auth().currentUser?.uid {
                    let settings = CalendarProviderSettings(
                        providerType: .apple,
                        userID: userId,
                        useForAvailability: true,
                        useForEvents: true
                    )
                    
                    do {
                        try await calendarAuthService.saveCalendarSettings(settings)
                    } catch {
                        print("Error saving Apple Calendar settings: \(error)")
                        self.error = error
                    }
                }
            } else {
                print("Apple Calendar access denied")
                error = NSError(domain: "com.cheemhang.calendar", code: 403, 
                        userInfo: [NSLocalizedDescriptionKey: "Calendar access denied. Please enable in Settings."])
            }
        }
        
        isConnecting = false
        currentProviderType = nil
    }
    
    @MainActor
    func disconnectGoogleCalendar() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isConnecting = true
        
        do {
            try await calendarAuthService.disconnectCalendar(for: userId, providerType: .google)
            googleCalendarConnected = false
            print("Successfully disconnected from Google Calendar")
        } catch {
            print("Error disconnecting from Google Calendar: \(error)")
            self.error = error
        }
        
        isConnecting = false
    }
    
    @MainActor
    func disconnectOutlookCalendar() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isConnecting = true
        
        do {
            try await calendarAuthService.disconnectCalendar(for: userId, providerType: .outlook)
            outlookCalendarConnected = false
            print("Successfully disconnected from Outlook Calendar")
        } catch {
            print("Error disconnecting from Outlook Calendar: \(error)")
            self.error = error
        }
        
        isConnecting = false
    }
    
    @MainActor
    func disconnectAppleCalendar() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isConnecting = true
        
        do {
            try await calendarAuthService.disconnectCalendar(for: userId, providerType: .apple)
            appleCalendarConnected = false
            print("Successfully disconnected Apple Calendar integration")
        } catch {
            print("Error disconnecting Apple Calendar: \(error)")
            self.error = error
        }
        
        isConnecting = false
    }
}

struct CalendarAuthView: View {
    @StateObject private var viewModel = FullCalendarAuthViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    Image(systemName: "calendar")
                        .font(.interSystem(size: 80))
                        .foregroundColor(.deepRed)
                        .padding(.bottom, 20)
                    
                    Text("Calendar Integration")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Connect your calendar to automatically check availability and schedule hangouts.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Google Calendar section
                    calendarSection(
                        title: "Google Calendar",
                        icon: "g.circle.fill",
                        iconColor: .red,
                        isConnected: viewModel.googleCalendarConnected,
                        connectAction: { Task { await viewModel.connectGoogleCalendar() } },
                        disconnectAction: { Task { await viewModel.disconnectGoogleCalendar() } }
                    )
                    
                    // Outlook Calendar section
                    calendarSection(
                        title: "Outlook Calendar",
                        icon: "envelope.circle.fill",
                        iconColor: .blue,
                        isConnected: viewModel.outlookCalendarConnected,
                        connectAction: { Task { await viewModel.connectOutlookCalendar() } },
                        disconnectAction: { Task { await viewModel.disconnectOutlookCalendar() } }
                    )
                    
                    // Apple Calendar section
                    calendarSection(
                        title: "Apple Calendar",
                        icon: "applelogo",
                        iconColor: .black,
                        isConnected: viewModel.appleCalendarConnected,
                        connectAction: { Task { await viewModel.connectAppleCalendar() } },
                        disconnectAction: { Task { await viewModel.disconnectAppleCalendar() } }
                    )
                    
                    Spacer()
                    
                    if viewModel.isConnecting {
                        ProgressView("Processing...")
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Calendar Connections")
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
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    private func calendarSection(
        title: String,
        icon: String,
        iconColor: Color,
        isConnected: Bool,
        connectAction: @escaping () -> Void,
        disconnectAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            if isConnected {
                Button {
                    disconnectAction()
                } label: {
                    Text("Disconnect")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            } else {
                Button {
                    connectAction()
                } label: {
                    Text("Connect")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.deepRed)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    CalendarAuthView()
} 