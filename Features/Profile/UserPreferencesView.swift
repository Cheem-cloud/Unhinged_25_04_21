import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct UserPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    
    var preferences: UserPreferences
    var onSave: (UserPreferences) -> Void
    
    @State private var emailNotifications: Bool
    @State private var pushNotifications: Bool
    @State private var inAppNotifications: Bool
    @State private var selectedTheme: String
    @State private var selectedLanguage: String
    @State private var isLoading = false
    @State private var alertItem: AlertItem?
    
    // Available options
    private let themeOptions = ["System", "Light", "Dark"]
    private let languageOptions = ["English", "Spanish", "French", "German", "Chinese"]
    
    // Initialize with preferences
    init(preferences: UserPreferences, onSave: @escaping (UserPreferences) -> Void) {
        self.preferences = preferences
        self.onSave = onSave
        
        // Initialize state from preferences
        _emailNotifications = State(initialValue: preferences.emailNotifications)
        _pushNotifications = State(initialValue: preferences.pushNotifications)
        _inAppNotifications = State(initialValue: preferences.inAppNotifications)
        _selectedTheme = State(initialValue: preferences.theme.capitalized)
        _selectedLanguage = State(initialValue: languageDisplayName(for: preferences.language))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section(header: Text("Notifications")) {
                        Toggle("Email Notifications", isOn: $emailNotifications)
                        Toggle("Push Notifications", isOn: $pushNotifications)
                        Toggle("In-App Notifications", isOn: $inAppNotifications)
                    }
                    
                    Section(header: Text("Appearance")) {
                        Picker("Theme", selection: $selectedTheme) {
                            ForEach(themeOptions, id: \.self) { theme in
                                Text(theme)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Section(header: Text("Language")) {
                        Picker("Language", selection: $selectedLanguage) {
                            ForEach(languageOptions, id: \.self) { language in
                                Text(language)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    Section {
                        Button("Save Changes") {
                            savePreferences()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(.blue)
                    }
                }
                
                if isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("Preferences")
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
            .alert(item: $alertItem) { alertItem in
                Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func savePreferences() {
        guard let user = Auth.auth().currentUser else {
            alertItem = AlertItem(title: "Error", message: "Not logged in")
            return
        }
        
        isLoading = true
        
        // Create updated preferences
        var updatedPreferences = UserPreferences()
        updatedPreferences.emailNotifications = emailNotifications
        updatedPreferences.pushNotifications = pushNotifications
        updatedPreferences.inAppNotifications = inAppNotifications
        updatedPreferences.theme = selectedTheme.lowercased()
        updatedPreferences.language = languageCode(for: selectedLanguage)
        
        // Save to Firestore
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        
        userRef.updateData([
            "preferences": [
                "emailNotifications": updatedPreferences.emailNotifications,
                "pushNotifications": updatedPreferences.pushNotifications,
                "inAppNotifications": updatedPreferences.inAppNotifications,
                "theme": updatedPreferences.theme,
                "language": updatedPreferences.language
            ],
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    alertItem = AlertItem(title: "Error", message: error.localizedDescription)
                    return
                }
                
                // Call onSave callback with updated preferences
                onSave(updatedPreferences)
                
                // Close the sheet
                dismiss()
            }
        }
    }
    
    private func languageDisplayName(for code: String) -> String {
        switch code {
        case "en": return "English"
        case "es": return "Spanish"
        case "fr": return "French"
        case "de": return "German"
        case "zh": return "Chinese"
        default: return "English"
        }
    }
    
    private func languageCode(for displayName: String) -> String {
        switch displayName {
        case "English": return "en"
        case "Spanish": return "es"
        case "French": return "fr"
        case "German": return "de"
        case "Chinese": return "zh"
        default: return "en"
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Saving preferences...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(25)
            .background(Color.gray.opacity(0.8))
            .cornerRadius(15)
        }
    }
}

#Preview {
    UserPreferencesView(
        preferences: UserPreferences(),
        onSave: { _ in }
    )
} 