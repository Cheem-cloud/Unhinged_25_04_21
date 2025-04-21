import SwiftUI
import FirebaseAuth
import FirebaseStorage
import PhotosUI
import FirebaseFirestore

struct PersonaFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    
    // For editing an existing persona
    var persona: Persona?
    let onComplete: () -> Void
    
    // Form fields
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var makeDefault: Bool = false
    @State private var existingImageURL: String?
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var activityPreferences: [ActivityPreference] = []
    @State private var visibilitySettings = VisibilitySettings()
    
    // UI state
    @State private var showingActivityPreferencesSheet = false
    @State private var showingVisibilitySettingsSheet = false
    
    // Photo picker
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    
    // Form state
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showingDeleteConfirmation = false
    
    private var isEditing: Bool {
        persona != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Persona Details") {
                    TextField("Name", text: $name)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(5)
                }
                
                Section("Avatar") {
                    VStack {
                        if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                            // Show selected image
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 150, height: 150)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.secondary, lineWidth: 1))
                        } else if let existingImageURL, !existingImageURL.isEmpty {
                            // Show existing image with error handling
                            AsyncImage(url: URL(string: existingImageURL)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 150, height: 150)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 150, height: 150)
                                        .clipShape(Circle())
                                case .failure(_):
                                    // Show a placeholder if image fails to load
                                    Image(systemName: "exclamationmark.circle")
                                        .resizable()
                                        .padding(40)
                                        .foregroundColor(.red)
                                        .frame(width: 150, height: 150)
                                        .background(Color.gray.opacity(0.2))
                                        .clipShape(Circle())
                                @unknown default:
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .frame(width: 150, height: 150)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.secondary, lineWidth: 1))
                        } else {
                            // Show placeholder
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 150, height: 150)
                                .foregroundColor(.gray)
                        }
                        
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text(existingImageURL != nil || selectedImageData != nil ? "Change Photo" : "Select Photo")
                        }
                        .padding(.top, 8)
                        .onChange(of: selectedItem) { oldValue, newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                // Enhanced persona features
                
                // Tags
                Section(header: Text("Tags"), footer: Text("Add tags to better describe this persona")) {
                    ForEach(tags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                            
                            Spacer()
                            
                            Button {
                                if let index = tags.firstIndex(of: tag) {
                                    tags.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("New Tag", text: $newTag)
                        
                        Button {
                            if !newTag.isEmpty && !tags.contains(newTag) {
                                withAnimation {
                                    tags.append(newTag)
                                    newTag = ""
                                }
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled(newTag.isEmpty || tags.contains(newTag))
                    }
                }
                
                // Activity Preferences
                Section {
                    Button {
                        showingActivityPreferencesSheet = true
                    } label: {
                        HStack {
                            Text("Activity Preferences")
                            
                            Spacer()
                            
                            if activityPreferences.isEmpty {
                                Text("None")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(activityPreferences.count) activities")
                                    .foregroundColor(.secondary)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .sheet(isPresented: $showingActivityPreferencesSheet) {
                        if let viewModel = viewModel as? PersonasViewModel {
                            ActivityPreferencesView(
                                viewModel: viewModel,
                                persona: Persona(
                                    id: persona?.id,
                                    name: name,
                                    bio: description,
                                    imageURL: existingImageURL,
                                    isDefault: makeDefault,
                                    activityPreferences: activityPreferences
                                )
                            )
                        }
                    }
                }
                
                // Visibility Settings
                Section {
                    Button {
                        showingVisibilitySettingsSheet = true
                    } label: {
                        HStack {
                            Text("Visibility Settings")
                            
                            Spacer()
                            
                            // Show a summary of visibility settings
                            HStack(spacing: 4) {
                                if visibilitySettings.visibleToPartner {
                                    Image(systemName: "person.2.fill")
                                        .foregroundColor(.blue)
                                }
                                
                                if visibilitySettings.visibleToFriends {
                                    Image(systemName: "person.3.fill")
                                        .foregroundColor(.green)
                                }
                                
                                if visibilitySettings.visibleInPublicProfile {
                                    Image(systemName: "globe")
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .sheet(isPresented: $showingVisibilitySettingsSheet) {
                        if let viewModel = viewModel as? PersonasViewModel {
                            VisibilitySettingsView(
                                viewModel: viewModel,
                                persona: Persona(
                                    id: persona?.id,
                                    name: name,
                                    bio: description,
                                    imageURL: existingImageURL,
                                    isDefault: makeDefault,
                                    visibilitySettings: visibilitySettings
                                )
                            )
                        }
                    }
                } footer: {
                    Text("Control who can see this persona")
                }
                
                Section {
                    Toggle("Set as Default Persona", isOn: $makeDefault)
                        .disabled(isEditing && persona?.isDefault == true)
                }
                
                if !isEditing {
                    Section {
                        Button("Create Persona") {
                            savePersona()
                        }
                        .disabled(name.isEmpty || isLoading)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    Section {
                        Button("Update Persona") {
                            savePersona()
                        }
                        .disabled(name.isEmpty || isLoading)
                        .frame(maxWidth: .infinity)
                    }
                    
                    Section {
                        Button("Delete Persona") {
                            showingDeleteConfirmation = true
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Persona" : "New Persona")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .alert("Error", isPresented: .init(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
            .alert("Delete Persona", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deletePersona()
                }
            } message: {
                Text("Are you sure you want to delete this persona? This action cannot be undone.")
            }
            .onAppear {
                if let persona = persona {
                    name = persona.name
                    description = persona.bio ?? ""
                    makeDefault = persona.isDefault
                    existingImageURL = persona.imageURL
                    tags = persona.tags
                    activityPreferences = persona.activityPreferences
                    visibilitySettings = persona.visibilitySettings
                } else {
                    // Set default values for new persona
                    makeDefault = viewModel.personas.isEmpty
                    
                    // Default visibility settings
                    visibilitySettings = VisibilitySettings(
                        visibleToPartner: true,
                        visibleToFriends: true,
                        visibleInPublicProfile: false
                    )
                }
            }
        }
    }
    
    private func savePersona() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        print("DEBUG: Starting savePersona flow - isEditing: \(isEditing)")
        
        Task {
            do {
                // Get avatar URL if there's a selected image
                var avatarURL: String? = existingImageURL
                
                if let imageData = selectedImageData {
                    print("DEBUG: Starting image upload process...")
                    
                    // Print the Storage bucket URL for debugging
                    let storage = Storage.storage()
                    print("DEBUG: Firebase Storage bucket: \(storage.reference().bucket)")
                    
                    // Resize image before upload to reduce size
                    guard let uiImage = UIImage(data: imageData),
                          let compressedData = uiImage.jpegData(compressionQuality: 0.5) else {
                        print("DEBUG: Failed to compress image")
                        throw NSError(domain: "ProfileError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
                    }
                    
                    // Create a file path
                    let imageName = "\(UUID().uuidString).jpg"
                    let personaImagesRef = Storage.storage().reference().child("personas/\(imageName)")
                    
                    // Create metadata
                    let metadata = StorageMetadata()
                    metadata.contentType = "image/jpeg"
                    
                    // Upload image to Firebase Storage
                    print("DEBUG: Uploading image to path: personas/\(imageName)")
                    
                    // Create a task and handle completion using continuation
                    let downloadURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                        _ = personaImagesRef.putData(compressedData, metadata: metadata) { metadata, error in
                            if let error = error {
                                print("DEBUG: Image upload failed: \(error.localizedDescription)")
                                continuation.resume(throwing: error)
                                return
                            }
                            
                            // Image uploaded successfully, now get download URL
                            personaImagesRef.downloadURL { url, error in
                                if let error = error {
                                    print("DEBUG: Failed to get download URL: \(error.localizedDescription)")
                                    continuation.resume(throwing: error)
                                    return
                                }
                                
                                guard let downloadURL = url else {
                                    print("DEBUG: Download URL is nil")
                                    continuation.resume(throwing: NSError(domain: "ProfileError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"]))
                                    return
                                }
                                
                                print("DEBUG: Image uploaded successfully. Download URL: \(downloadURL.absoluteString)")
                                continuation.resume(returning: downloadURL)
                            }
                        }
                        
                        print("DEBUG: Upload task started")
                    }
                    
                    // Set the avatar URL to the download URL
                    avatarURL = downloadURL.absoluteString
                    print("DEBUG: Avatar URL set to: \(avatarURL ?? "nil")")
                } else {
                    print("DEBUG: No new image selected, keeping existing URL: \(existingImageURL ?? "nil")")
                }
                
                // Final persona data
                print("DEBUG: Final avatarURL before saving persona: \(avatarURL ?? "nil")")
                
                if isEditing, let personaId = persona?.id {
                    print("DEBUG: Updating existing persona")
                    // Create a Persona object with the updated values
                    let updatedPersona = Persona(
                        id: personaId,
                        name: name,
                        bio: description,
                        imageURL: avatarURL,
                        isDefault: makeDefault,
                        userID: userId,
                        friendGroupIDs: persona?.friendGroupIDs ?? [],
                        activityPreferences: activityPreferences,
                        visibilitySettings: visibilitySettings,
                        tags: tags
                    )
                    
                    if let viewModel = viewModel as? PersonasViewModel {
                        try await viewModel.updatePersona(
                            updatedPersona,
                            name: name,
                            description: description,
                            avatarURL: avatarURL,
                            makeDefault: makeDefault,
                            activityPreferences: activityPreferences,
                            visibilitySettings: visibilitySettings,
                            tags: tags
                        )
                    } else {
                        try await FirestoreService().updatePersona(updatedPersona, for: userId)
                    }
                    
                    print("DEBUG: Updated existing persona with ID: \(personaId)")
                } else {
                    print("DEBUG: Creating new persona")
                    print("DEBUG: New persona data - name: \(name), description: \(description), avatarURL: \(avatarURL ?? "nil")")
                    
                    // Create a new Persona object with enhanced fields
                    let newPersona = Persona(
                        id: nil,
                        name: name,
                        bio: description,
                        imageURL: avatarURL,
                        isDefault: makeDefault,
                        userID: userId,
                        activityPreferences: activityPreferences,
                        visibilitySettings: visibilitySettings,
                        tags: tags
                    )
                    
                    if let viewModel = viewModel as? PersonasViewModel {
                        try await viewModel.createPersona(
                            name: name,
                            description: description,
                            avatarURL: avatarURL,
                            makeDefault: makeDefault,
                            activityPreferences: activityPreferences,
                            visibilitySettings: visibilitySettings,
                            tags: tags
                        )
                    } else {
                        if makeDefault {
                            print("DEBUG: Creating new persona as default")
                            print("DEBUG: Setting persona as default: \(name)")
                            do {
                                print("DEBUG: This is a new persona, creating it first")
                                let newPersonaId = try await FirestoreService().createPersona(newPersona, for: userId)
                                print("DEBUG: Created new persona with ID: \(newPersonaId)")
                            } catch {
                                print("DEBUG: Failed to create persona: \(error.localizedDescription)")
                                print("DEBUG: Error setting default persona: \(error)")
                            }
                        } else {
                            print("DEBUG: Creating new persona (not default)")
                            let newPersonaId = try await FirestoreService().createPersona(newPersona, for: userId)
                            print("DEBUG: Created new persona with ID: \(newPersonaId)")
                        }
                    }
                }
                
                // Success! Dismiss the sheet and reload personas
                print("DEBUG: Persona saved successfully, calling onComplete")
                await MainActor.run {
                    isLoading = false
                    // Call onComplete after a slight delay to ensure the sheet is dismissed first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("DEBUG: Calling onComplete after delay")
                        self.onComplete()
                        print("DEBUG: Create persona onComplete called")
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    self.error = error
                    print("DEBUG: Error saving persona: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func deletePersona() {
        guard let personaId = persona?.id else { return }
        
        isLoading = true
        
        Task {
            print("DEBUG: Deleting persona with ID: \(personaId)")
            await viewModel.deletePersona(personaId)
            
            DispatchQueue.main.async {
                print("DEBUG: Persona deleted, calling onComplete and dismissing")
                isLoading = false
                // Call viewModel.loadPersonas directly
                viewModel.loadPersonas()
                onComplete()
                // Give a small delay before dismissing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    PersonaFormView(viewModel: ProfileViewModel(), onComplete: {})
} 