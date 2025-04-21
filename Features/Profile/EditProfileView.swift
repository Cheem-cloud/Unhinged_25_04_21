import SwiftUI
import PhotosUI
import FirebaseAuth

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = EditProfileViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isNameFocused: Bool = false
    @State private var isBioFocused: Bool = false
    @State private var isEmailFocused: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profilePhotoSection
                
                profileInfoSection
                
                saveButton
            }
            .padding()
        }
        .navigationTitle("Edit Profile")
        .background(Color.white.edgesIgnoringSafeArea(.all))
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
    }
    
    // MARK: - UI Components
    
    private var profilePhotoSection: some View {
        VStack(spacing: 8) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                profilePhotoView
            }
            .onChange(of: selectedPhotoItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        viewModel.setProfilePhoto(data: data)
                        
                        // Preview the selected image
                        selectedPhotoItem = nil
                    }
                }
            }
            
            Text("Tap to change photo")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.top)
    }
    
    private var profilePhotoView: some View {
        ZStack {
            // Show either the selected new photo, the existing photo, or default placeholder
            if viewModel.isPhotoChanged, let selectedData = viewModel.selectedPhotoData,
               let uiImage = UIImage(data: selectedData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(radius: 3)
            } else if let photoURL = viewModel.photoURL {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "person.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(20)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                .shadow(radius: 3)
            } else {
                Image(systemName: "person.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(20)
                    .frame(width: 120, height: 120)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(radius: 3)
                    .foregroundColor(.gray)
            }
            
            // Camera icon overlay
            Image(systemName: "camera.fill")
                .padding(8)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Circle())
                .shadow(radius: 2)
                .offset(x: 40, y: 40)
        }
    }
    
    private var profileInfoSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Name")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Your display name", text: $viewModel.displayName)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .onTapGesture {
                        isNameFocused = true
                        isBioFocused = false
                        isEmailFocused = false
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isNameFocused ? Color.blue : Color.clear, lineWidth: 2)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Your email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .onTapGesture {
                        isNameFocused = false
                        isBioFocused = false
                        isEmailFocused = true
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isEmailFocused ? Color.blue : Color.clear, lineWidth: 2)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Bio")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextEditor(text: $viewModel.bio)
                    .frame(minHeight: 100)
                    .padding(4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .onTapGesture {
                        isNameFocused = false
                        isBioFocused = true
                        isEmailFocused = false
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isBioFocused ? Color.blue : Color.clear, lineWidth: 2)
                    )
            }
        }
    }
    
    private var saveButton: some View {
        Button(action: {
            Task {
                let success = await viewModel.updateProfile()
                if success {
                    // Wait a moment to show success message then dismiss
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    dismiss()
                }
            }
        }) {
            Text("Save Changes")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
        }
        .padding(.top, 10)
        .disabled(viewModel.isLoading)
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Updating profile...")
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
    NavigationView {
        EditProfileView()
    }
} 