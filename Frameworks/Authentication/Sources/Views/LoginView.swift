import SwiftUI
import Core
import Services

/// Login view with email/password and Google sign-in
public struct LoginView: View {
    @ObservedObject private var viewModel: AuthViewModel
    
    public init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Sign In")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 30)
            
            // Error message
            if !viewModel.errorMessage.isEmpty {
                Text(viewModel.errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Email field
            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            
            // Password field
            SecureField("Password", text: $viewModel.password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            
            // Sign In button
            Button(action: {
                viewModel.signIn()
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Sign In")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 50)
            .background(Color.blue)
            .cornerRadius(8)
            .padding(.horizontal)
            .disabled(viewModel.isLoading)
            
            Text("OR")
                .foregroundColor(.secondary)
            
            // Google Sign In button
            Button(action: {
                Task {
                    await viewModel.signInWithGoogle()
                }
            }) {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text("Sign in with Google")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .background(Color.red)
            .cornerRadius(8)
            .padding(.horizontal)
            .disabled(viewModel.isLoading)
            
            Spacer()
            
            // Sign Up link
            HStack {
                Text("Don't have an account?")
                    .foregroundColor(.secondary)
                
                Button(action: {
                    // Navigate to sign up view would go here
                }) {
                    Text("Sign Up")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom, 30)
        }
        .padding()
    }
} 