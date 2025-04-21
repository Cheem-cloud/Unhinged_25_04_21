import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Combine

@MainActor
class EditProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // Profile data
    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var bio: String = ""
    @Published var photoURL: URL?
    
    // UI State
    @Published var isLoading: Bool = false
    @Published var alertItem: AlertItem?
    @Published var selectedPhotoData: Data?
    @Published var isPhotoChanged: Bool = false
    
    // MARK: - Private Properties
    
    private var userId: String?
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        loadUserData()
    }
    
    // MARK: - Public Methods
    
    /// Load the current user's profile data
    func loadUserData() {
        guard let user = Auth.auth().currentUser else {
            alertItem = AlertItem(title: "Error", message: "Not logged in")
            return
        }
        
        userId = user.uid
        displayName = user.displayName ?? ""
        email = user.email ?? ""
        photoURL = user.photoURL
        
        // Load additional user data from Firestore
        isLoading = true
        
        db.collection("users").document(user.uid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.alertItem = AlertItem(title: "Error", message: error.localizedDescription)
                    return
                }
                
                guard let data = snapshot?.data() else {
                    return
                }
                
                self.bio = data["bio"] as? String ?? ""
            }
        }
    }
    
    /// Update the user's profile with the current values
    func updateProfile() async -> Bool {
        guard let user = Auth.auth().currentUser else {
            alertItem = AlertItem(title: "Error", message: "Not logged in")
            return false
        }
        
        isLoading = true
        
        do {
            // First upload photo if changed
            var photoURLString: String? = photoURL?.absoluteString
            
            if isPhotoChanged, let photoData = selectedPhotoData {
                let photoURLResult = try await uploadProfilePhoto(photoData)
                photoURLString = photoURLResult
            }
            
            // Update Firebase Auth profile
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            if let photoURLString = photoURLString {
                changeRequest.photoURL = URL(string: photoURLString)
            }
            try await changeRequest.commitChanges()
            
            // Update Firestore user document
            var userData: [String: Any] = [
                "displayName": displayName,
                "bio": bio,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            if let photoURLString = photoURLString {
                userData["photoURL"] = photoURLString
            }
            
            if email != user.email {
                try await user.sendEmailVerification(beforeUpdatingEmail: email)
                userData["email"] = email
            }
            
            try await db.collection("users").document(user.uid).updateData(userData)
            
            isLoading = false
            alertItem = AlertItem(title: "Success", message: "Profile updated successfully!")
            return true
            
        } catch {
            isLoading = false
            alertItem = AlertItem(title: "Error", message: error.localizedDescription)
            print("Error updating profile: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Set the profile photo from selected data
    func setProfilePhoto(data: Data?) {
        selectedPhotoData = data
        isPhotoChanged = true
    }
    
    // MARK: - Private Methods
    
    /// Upload profile photo to Firebase Storage
    private func uploadProfilePhoto(_ photoData: Data) async throws -> String {
        guard let userId = userId else {
            throw NSError(domain: "EditProfileViewModel", code: 101, userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
        }
        
        let storageRef = storage.reference()
        let profileImagesRef = storageRef.child("profile_images/\(userId)/profile.jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await profileImagesRef.putDataAsync(photoData, metadata: metadata)
        let downloadURL = try await profileImagesRef.downloadURL()
        
        return downloadURL.absoluteString
    }
} 