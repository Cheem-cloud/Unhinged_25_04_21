import SwiftUI
import FirebaseAuth
import Kingfisher
import FirebaseFirestore
import Firebase

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingCreatePersona = false
    @State private var showingEditPersona: Persona? = nil
    @State private var showingCalendarSettings = false
    
    var body: some View {
        NavigationView {
            ProfileContentView(
                viewModel: viewModel,
                authViewModel: authViewModel,
                showingCreatePersona: $showingCreatePersona,
                showingEditPersona: $showingEditPersona,
                showingCalendarSettings: $showingCalendarSettings
            )
            .withThemedFonts()
            .alert(item: $viewModel.alertItem) { alertItem in
                Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                viewModel.loadPersonas()
                
                // Show observer for notification permission alerts
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("ShowNotificationPermissionAlert"),
                    object: nil,
                    queue: .main
                ) { notification in
                    if let message = notification.userInfo?["message"] as? String {
                        viewModel.showAlert(title: "Notification Permission", message: message)
                    }
                }
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(alignment: .center, spacing: 12) {
            if let user = Auth.auth().currentUser,
               let photoURL = user.photoURL {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .empty:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    case .failure:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.gray)
            }
            
            // Use InterText factory for user name
            InterText.title(Auth.auth().currentUser?.displayName ?? "User")
                .fontWeight(.semibold)
            
            // Use InterText factory for email
            InterText.subheadline(Auth.auth().currentUser?.email ?? "")
                .foregroundColor(.secondary)
            
            // Font samples to demonstrate InterVariable
            fontSamplesView
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // Font samples with various weights
    private var fontSamplesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().padding(.vertical, 8)
            
            // Use InterText for the header
            InterText.caption("Inter Variable Font Samples:")
                .foregroundColor(.secondary)
            
            // Use CustomText for all the samples
            CustomText("Regular weight", size: 14)
            
            CustomText("Medium weight", size: 14, weight: .medium)
            
            CustomText("Semibold weight", size: 14, weight: .semibold)
            
            CustomText("Bold weight", size: 14, weight: .bold)
                
            // Use direct font for italic 
            Text("Italic style")
                .font(.custom("InterVariableItalic", size: 14).weight(.regular))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
    
    // MARK: - Notification Test Section
    
    private var notificationTestSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Use InterText for headers
            InterText.heading("Push Notification Test")
                .padding(.bottom, 4)
            
            // Use InterText for subheadline
            InterText.subheadline("Use this button to test push notifications. You should see:")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                bulletPoint(text: "A local notification immediately")
                bulletPoint(text: "Console logs showing FCM token status")
                bulletPoint(text: "A push notification if your Firebase setup is correct")
            }
            .padding(.bottom, 8)
            
            testNotificationButton
            
            Divider()
                .padding(.vertical, 8)
            
            firebaseSetupSteps
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var testNotificationButton: some View {
        Button(action: {
            NotificationService.shared.sendTestNotification()
        }) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .font(.interSystem(size: 18))
                CustomText("Test Notifications", weight: .semibold)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(Color.mutedGold)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
    
    private var firebaseSetupSteps: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Use InterText for headers
            InterText.heading("Firebase Cloud Functions Setup")
                .padding(.bottom, 4)
            
            // Use InterText for subheadline
            InterText.subheadline("For push notifications to work, you need to set up Firebase:")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                bulletPoint(text: "Create firebase-functions directory in project root")
                bulletPoint(text: "Copy function code from GitHub or documentation")
                bulletPoint(text: "Deploy functions with Firebase CLI")
                bulletPoint(text: "Configure APNs in Firebase Console")
            }
        }
    }
    
    private func bulletPoint(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            CustomText("•", size: 12, color: .mutedGold)
            CustomText(text, size: 12, color: .secondary)
        }
    }
    
    // Test function to create a persona directly
    private func createTestPersona() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            do {
                print("DEBUG: Creating test persona directly for user \(userId)")
                
                let db = Firestore.firestore()
                let personaRef = db.collection("users").document(userId).collection("personas").document()
                
                let timestamp = Timestamp(date: Date())
                let testPersona: [String: Any] = [
                    "name": "Test Direct \(Int(Date().timeIntervalSince1970))",
                    "description": "Created directly for testing",
                    "userID": userId,
                    "isDefault": false,
                    "createdAt": timestamp,
                    "updatedAt": timestamp
                ]
                
                // Write directly to Firestore
                try await personaRef.setData(testPersona)
                print("DEBUG: Successfully created test persona with ID: \(personaRef.documentID)")
                
                // Force reload personas
                viewModel.loadPersonas()
                
                // Manually verify if persona exists by direct read
                let snapshot = try await db.collection("users").document(userId).collection("personas").getDocuments()
                print("DEBUG: Direct verification found \(snapshot.documents.count) personas")
                for doc in snapshot.documents {
                    print("DEBUG: Found persona: \(doc.documentID) - \(doc.data()["name"] ?? "unnamed")")
                }
            } catch {
                print("DEBUG: Error creating test persona: \(error.localizedDescription)")
            }
        }
    }
    
    // Test function that creates a persona using the app's standard path
    private func testAppPathPersonaCreation() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            do {
                print("DEBUG: Testing persona creation through app path for user \(userId)")
                
                // Create a test persona using the app's standard path through FirestoreService
                let testPersona = Persona(
                    id: nil,
                    name: "App Path Test \(Int(Date().timeIntervalSince1970))",
                    bio: "Created using app path for testing",
                    imageURL: nil,
                    isDefault: false,
                    userID: userId
                )
                
                // Use the FirestoreService to create the persona
                let firestoreService = FirestoreService()
                let personaId = try await firestoreService.createPersona(testPersona, for: userId)
                print("DEBUG: Successfully created persona through app path with ID: \(personaId)")
                
                // Verify the path was correct
                let db = Firestore.firestore()
                print("DEBUG: Verifying persona exists at path: users/\(userId)/personas/\(personaId)")
                let docRef = db.collection("users").document(userId).collection("personas").document(personaId)
                let docSnapshot = try await docRef.getDocument()
                
                if docSnapshot.exists {
                    print("DEBUG: ✅ SUCCESS! Persona document exists at correct path")
                    print("DEBUG: Document data: \(docSnapshot.data() ?? [:])")
                } else {
                    print("DEBUG: ❌ ERROR! Persona document does NOT exist at path")
                }
                
                // Force reload personas
                viewModel.loadPersonas()
                
                // Check entire persona collection
                let collectionRef = db.collection("users").document(userId).collection("personas")
                print("DEBUG: Checking entire personas collection at path: users/\(userId)/personas")
                let snapshot = try await collectionRef.getDocuments()
                print("DEBUG: Found \(snapshot.documents.count) total personas in collection")
                
                for doc in snapshot.documents {
                    print("DEBUG: ▶️ Persona: \(doc.documentID) - \(doc.data()["name"] ?? "unnamed")")
                }
            } catch {
                print("DEBUG: ❌ ERROR creating persona through app path: \(error.localizedDescription)")
                print("DEBUG: Full error: \(error)")
            }
        }
    }
}

// Break out the main content into a separate view
struct ProfileContentView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var showingCreatePersona: Bool
    @Binding var showingEditPersona: Persona?
    @Binding var showingCalendarSettings: Bool
    @State private var showingRelationshipView: Bool = false
    @State private var showingInvitePartnerView: Bool = false
    @State private var showingCoupleProfileView: Bool = false
    @StateObject private var relationshipViewModel = RelationshipViewModel()
    
    var body: some View {
        ZStack {
            // Background color to match other pages
            CustomTheme.Colors.background
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                mainContentView
            }
        }
        .navigationTitle("Your Profiles")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                toolbarButtons
            }
        }
        .sheet(isPresented: $showingCreatePersona, onDismiss: {
            viewModel.loadPersonas()
        }) {
            PersonaFormView(viewModel: viewModel, persona: nil, onComplete: {
                print("DEBUG: Create persona onComplete called")
                viewModel.loadPersonas()
            })
        }
        .sheet(item: $showingEditPersona, onDismiss: {
            print("DEBUG: Edit persona sheet dismissed")
            viewModel.loadPersonas()
        }) { persona in
            PersonaFormView(viewModel: viewModel, persona: persona, onComplete: {
                print("DEBUG: Edit persona onComplete called")
                viewModel.loadPersonas()
            })
        }
        .sheet(isPresented: $showingCalendarSettings) {
            GoogleCalendarAuthView()
        }
        .sheet(isPresented: $showingRelationshipView) {
            RelationshipView()
        }
        .sheet(isPresented: $showingInvitePartnerView) {
            InvitePartnerView()
        }
        .sheet(isPresented: $showingCoupleProfileView) {
            CoupleProfileView()
        }
        .onAppear {
            viewModel.loadPersonas()
            relationshipViewModel.loadRelationship()
            
            // Show observer for notification permission alerts
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowNotificationPermissionAlert"),
                object: nil,
                queue: .main
            ) { notification in
                if let message = notification.userInfo?["message"] as? String {
                    viewModel.showAlert(title: "Notification Permission", message: message)
                }
            }
        }
        .onChange(of: viewModel.personas.count) { oldCount, newCount in
            print("DEBUG: Personas count changed from \(oldCount) to \(newCount)")
        }
        .alert(
            "Error", 
            isPresented: Binding<Bool>(
                get: { viewModel.error != nil },
                set: { newValue in
                    if !newValue {
                        viewModel.error = nil
                    }
                }
            )
        ) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    // Break up the UI into smaller components using computed properties
    private var mainContentView: some View {
        VStack(spacing: 24) {
            personasContent
            calendarIntegrationButton
            testNotificationButton
            signOutButton
            partnerSection
        }
        // Remove excess top padding
        .padding(.top, 8)
        .padding(.bottom, 40) // Add bottom padding to prevent hiding behind nav bar
    }
    
    private var personasContent: some View {
        Group {
            if viewModel.personas.isEmpty && !viewModel.isLoading {
                EmptyProfileState()
            } else {
                if viewModel.isLoading {
                    ProgressView("Loading personas...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .padding()
                } else {
                    personasList
                }
            }
        }
        .padding(.top, 4) // Add minimal top padding
    }
    
    private var personasList: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.personas) { persona in
                ProfilePersonaView(persona: persona, onTap: {
                    showingEditPersona = persona
                })
            }
        }
        .padding(.horizontal)
    }
    
    private var calendarIntegrationButton: some View {
        Button {
            showingCalendarSettings = true
        } label: {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(CustomTheme.Colors.accent)
                Text("CALENDAR INTEGRATION")
                    .font(.custom("InterVariable", size: 16, fallback: .body))
                    .fontWeight(.medium)
                    .foregroundColor(CustomTheme.Colors.accent)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(CustomTheme.Colors.accent.opacity(0.7))
            }
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(CustomTheme.Colors.accent, lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }
    
    // Test notification button
    private var testNotificationButton: some View {
        Button {
            NotificationService.shared.sendTestNotification()
        } label: {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(CustomTheme.Colors.accent)
                Text("TEST PUSH NOTIFICATION")
                    .font(.custom("InterVariable", size: 16, fallback: .body))
                    .fontWeight(.medium)
                    .foregroundColor(CustomTheme.Colors.accent)
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(CustomTheme.Colors.accent.opacity(0.7))
            }
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(CustomTheme.Colors.accent, lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }
    
    private var signOutButton: some View {
        Button {
            authViewModel.signOut()
        } label: {
            Text("SIGN OUT")
                .font(.custom("InterVariable", size: 16, fallback: .body))
                .fontWeight(.medium)
                .foregroundColor(CustomTheme.Colors.accent)
                .padding()
                .frame(maxWidth: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(CustomTheme.Colors.accent, lineWidth: 1)
                )
        }
        .padding(.horizontal)
    }
    
    private var toolbarButtons: some View {
        Button {
            showingCreatePersona = true
        } label: {
            Image(systemName: "plus.circle")
                .foregroundColor(.white)
        }
    }
    
    // New section for partner/relationship
    private var partnerSection: some View {
        PartnerSectionView(
            relationshipViewModel: relationshipViewModel,
            showingRelationshipView: $showingRelationshipView,
            showingInvitePartnerView: $showingInvitePartnerView,
            showingCoupleProfileView: $showingCoupleProfileView
        )
    }
}

// Removed duplicate PersonaCard struct - already defined in App/Views/Partner/PersonaCard.swift

struct PersonaCardDetailed: View {
    let persona: Persona
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                if let avatarURL = persona.imageURL, !avatarURL.isEmpty {
                    KFImage(URL(string: avatarURL))
                        .placeholder {
                            Image(systemName: "person.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .foregroundColor(.gray)
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                        .frame(width: 80, height: 80)
                        .background(Color.softPink)
                        .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(persona.name)
                            .font(.headline)
                        
                        if persona.isDefault {
                            Text("Default")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.deepRed)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    
                    Text(persona.bio ?? "")
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.7))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.burgundy)
        .cornerRadius(12)
    }
}

// Empty state view with updated styles
struct EmptyProfileState: View {
    @State private var showingCreatePersona = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.interSystem(size: 80))
                .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
            
            Text("NO PERSONAS FOUND")
                .font(.custom("InterVariable", size: 24, fallback: .title2))
                .fontWeight(.bold)
                .foregroundColor(CustomTheme.Colors.text)
            
            Text("Create personas to represent different facets of yourself when meeting with others.")
                .font(.custom("InterVariable", size: 16, fallback: .body))
                .multilineTextAlignment(.center)
                .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
                .padding(.horizontal, 32)
            
            Button {
                showingCreatePersona = true
            } label: {
                Text("CREATE YOUR FIRST PERSONA")
                    .font(.custom("InterVariable", size: 16, fallback: .headline))
                    .fontWeight(.medium)
                    .foregroundColor(CustomTheme.Colors.accent)
                    .padding()
                    .frame(maxWidth: 280)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(CustomTheme.Colors.accent, lineWidth: 1)
                    )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 400)
        .sheet(isPresented: $showingCreatePersona) {
            PersonaFormView(viewModel: ProfileViewModel(), persona: nil, onComplete: {})
        }
    }
}

// Updated persona card to a horizontal bar with image on right
struct ProfilePersonaView: View {
    let persona: Persona
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Content on the left
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(persona.name.uppercased())
                            .font(.custom("InterVariable", size: 18, fallback: .headline))
                            .fontWeight(.semibold)
                            .foregroundColor(CustomTheme.Colors.text)
                        
                        if persona.isDefault {
                            Text("DEFAULT")
                                .font(.custom("InterVariable", size: 12, fallback: .caption))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(CustomTheme.Colors.accent.opacity(0.2))
                                .foregroundColor(CustomTheme.Colors.accent)
                                .cornerRadius(10)
                        }
                    }
                    
                    if let bio = persona.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.custom("InterVariable", size: 14, fallback: .subheadline))
                            .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
                            .lineLimit(2)
                    }
                    
                    if let breed = persona.breed {
                        Text(breed)
                            .font(.custom("InterVariable", size: 12, fallback: .caption))
                            .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Image on the right
                ZStack {
                    if let avatarURL = persona.imageURL, !avatarURL.isEmpty {
                        KFImage(URL(string: avatarURL))
                            .placeholder {
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .foregroundColor(CustomTheme.Colors.text.opacity(0.5))
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                            .frame(width: 60, height: 60)
                            .background(CustomTheme.Colors.accent.opacity(0.2))
                            .clipShape(Circle())
                            .foregroundColor(CustomTheme.Colors.accent)
                    }
                    
                    if persona.isPremium {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(CustomTheme.Colors.accent)
                            .padding(4)
                            .background(Circle().fill(Color.white))
                            .offset(x: 20, y: -20)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(CustomTheme.Colors.cardBackground)
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AuthViewModel())
    }
} 