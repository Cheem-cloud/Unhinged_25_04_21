import SwiftUI
import FirebaseAuth

struct MainProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingPreferencesSheet = false
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileHeaderSection
                
                divider
                
                profileMenuSection
                
                if !viewModel.personas.isEmpty {
                    divider
                    
                    personasSection
                }
            }
            .padding()
        }
        .navigationTitle("Profile")
        .background(Color.gray.opacity(0.05).edgesIgnoringSafeArea(.all))
        .onAppear {
            viewModel.loadUserData()
        }
        .alert(item: $viewModel.alertItem) { alertItem in
            Alert(
                title: Text(alertItem.title),
                message: Text(alertItem.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .overlay {
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .sheet(isPresented: $showingPreferencesSheet) {
            UserPreferencesView(
                preferences: viewModel.user?.preferences ?? UserPreferences(),
                onSave: { savedPreferences in
                    // Handle saved preferences
                    showingPreferencesSheet = false
                }
            )
        }
        .refreshable {
            viewModel.loadUserData()
        }
    }
    
    // MARK: - View Components
    
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Profile photo
            if let photoURLString = viewModel.user?.photoURL, let photoURL = URL(string: photoURLString) {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .empty:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .foregroundColor(.gray)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                            .shadow(radius: 3)
                    case .failure:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .foregroundColor(.gray)
            }
            
            // User info
            VStack(spacing: 4) {
                Text(viewModel.user?.displayName ?? "User")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(viewModel.user?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let bio = viewModel.user?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            
            // Edit profile button
            Button(action: {
                navigationCoordinator.navigate(to: .editProfile)
            }) {
                Text("Edit Profile")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var profileMenuSection: some View {
        VStack(spacing: 0) {
            // Preferences option
            Button(action: {
                showingPreferencesSheet = true
            }) {
                menuItem(
                    icon: "gear",
                    title: "Preferences",
                    subtitle: "Notifications, theme, language"
                )
            }
            
            divider
            
            // Settings option
            Button(action: {
                navigationCoordinator.navigate(to: .settings)
            }) {
                menuItem(
                    icon: "slider.horizontal.3",
                    title: "Settings",
                    subtitle: "App settings and configuration"
                )
            }
            
            divider
            
            // Sign out option
            Button(action: {
                viewModel.signOut { success in
                    if success {
                        // Handle successful sign out
                        // This might trigger an app-level navigation change
                    }
                }
            }) {
                menuItem(
                    icon: "arrow.right.square",
                    title: "Sign Out",
                    subtitle: "Log out of your account",
                    iconColor: .red
                )
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var personasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("Your Personas")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                NavigationLink(value: .personasView) {
                    Text("Manage")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Persona list
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.personas.prefix(4)) { persona in
                        personaCard(persona: persona)
                    }
                    
                    // Add new persona button
                    if viewModel.personas.count < 5 {
                        addPersonaButton
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .padding(.vertical)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func personaCard(persona: Persona) -> some View {
        VStack(spacing: 8) {
            // Persona image
            if let imageURL = persona.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholderImage
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    case .failure:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
                .frame(width: 80, height: 80)
            } else {
                placeholderImage
            }
            
            // Persona name
            Text(persona.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Default indicator
            if persona.isDefault {
                Text("Default")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green)
                    .cornerRadius(10)
            }
        }
        .frame(width: 100)
        .padding(.vertical, 8)
    }
    
    private var placeholderImage: some View {
        Image(systemName: "person.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(12)
            .frame(width: 80, height: 80)
            .background(Color.gray.opacity(0.2))
            .clipShape(Circle())
            .foregroundColor(.gray)
    }
    
    private var addPersonaButton: some View {
        Button(action: {
            navigationCoordinator.navigate(to: .createPersona)
        }) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                
                Text("New Persona")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.blue)
            .frame(width: 100, height: 100)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func menuItem(icon: String, title: String, subtitle: String, iconColor: Color = .blue) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .contentShape(Rectangle())
    }
    
    private var divider: some View {
        Divider()
            .padding(.horizontal)
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .padding(25)
                .background(Color.gray.opacity(0.8))
                .cornerRadius(15)
        }
    }
}

#Preview {
    NavigationStack {
        MainProfileView()
            .environmentObject(NavigationCoordinator())
    }
} 