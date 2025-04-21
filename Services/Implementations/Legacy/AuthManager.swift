import Foundation
import Firebase
import FirebaseAuth
import GoogleSignIn

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var user: User?
    @Published var isSignedIn: Bool = false
    @Published var errorMessage: String = ""
    @Published var isLoading: Bool = false
    
    init() {
        // Set up auth state listener
        Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            guard let self = self else { return }
            self.user = user
            self.isSignedIn = user != nil
        }
    }
    
    func signInWithGoogle() async {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            self.errorMessage = "Firebase configuration not found"
            return
        }
        
        // Create Google Sign In configuration object
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        do {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                DispatchQueue.main.async {
                    self.errorMessage = "No root view controller found"
                    self.isLoading = false
                }
                return
            }
            
            // Start the sign in flow
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            let user = result.user
            
            guard let idToken = user.idToken?.tokenString else {
                DispatchQueue.main.async {
                    self.errorMessage = "ID token missing"
                    self.isLoading = false
                }
                return
            }
            
            // Create Firebase credential with Google ID token
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            // Authenticate with Firebase using the credential
            try await Auth.auth().signIn(with: credential)
            
            // Sign in successful
            DispatchQueue.main.async {
                self.errorMessage = ""
                self.isLoading = false
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
} 