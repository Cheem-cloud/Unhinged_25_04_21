import SwiftUI

struct AuthView: View {
    @StateObject var viewModel = AuthViewModel()
    @State private var email = ""
    @State private var password = ""
    @State private var showEmailSignUp = false
    
    var body: some View {
        ZStack {
            // Background using color scheme
            CustomTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                // Logo and App Title
                VStack(spacing: 8) {
                    Image("cheem-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(CustomTheme.Colors.accent, lineWidth: 1)
                        )
                    
                    // Use InterText for app title
                    InterText.title("Unhinged")
                        .fontWeight(.bold)
                        .foregroundColor(CustomTheme.Colors.text)
                    
                    // Use InterText for subtitle
                    InterText.subheadline("Hinge, but for your partner")
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
                }
                .padding(.bottom, 40)
                
                // Main authentication form
                VStack(spacing: 24) {
                    // Error message
                    if !viewModel.errorMessage.isEmpty {
                        // Use CustomText for error message
                        CustomText(viewModel.errorMessage, color: .red)
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                    }
                
                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        // Use InterText for label
                        InterText.caption("Email")
                            .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                        
                        TextField("", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .outlinedStyle()
                            .foregroundColor(CustomTheme.Colors.text)
                    }
                    
                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        // Use InterText for label
                        InterText.caption("Password")
                            .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                        
                        SecureField("", text: $password)
                            .padding()
                            .outlinedStyle()
                            .foregroundColor(CustomTheme.Colors.text)
                    }
                    
                    // Sign In Button
                    Button(action: {
                        Task {
                            await viewModel.signIn(email: email, password: password)
                        }
                    }) {
                        // Use InterText for button label
                        InterText.heading("Sign In")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .themedButtonStyle()
                    .disabled(viewModel.isLoading || email.isEmpty || password.isEmpty)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 30)
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: CustomTheme.Colors.accent))
                        .scaleEffect(1.5)
                        .padding(.top, 20)
                }
                
                Spacer()
                
                // Create account button
                Button(action: {
                    showEmailSignUp = true
                }) {
                    // Use InterText for button text
                    InterText.body("Create a new account")
                        .foregroundColor(CustomTheme.Colors.accent)
                        .padding(.vertical, 16)
                }
                .padding(.bottom, 40)
            }
            
            // Email Sign Up Sheet
            .sheet(isPresented: $showEmailSignUp) {
                EmailSignUpView(authViewModel: viewModel)
            }
        }
        .withInterFont() // Apply Inter font to everything
    }
}

// Email Sign Up View
struct EmailSignUpView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var partnerEmail = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                CustomTheme.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                                .foregroundColor(CustomTheme.Colors.text)
                        }
                        .padding()
                        
                        Spacer()
                    }
                    
                    // Use InterText for title with proper modifiers
                    Text("Sign up")
                        .font(.custom("InterVariable", size: 22))
                        .fontWeight(.bold)
                        .foregroundColor(CustomTheme.Colors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                    
                    // Use CustomText for subtitle
                    CustomText("Become a member.", color: CustomTheme.Colors.text.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    
                    VStack(spacing: 20) {
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            // Use InterText for label
                            InterText.caption("Name")
                                .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                            
                            TextField("", text: $name)
                                .padding()
                                .outlinedStyle()
                                .foregroundColor(CustomTheme.Colors.text)
                        }
                        .padding(.horizontal)
                        
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            // Use InterText for label
                            InterText.caption("Email")
                                .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                            
                            TextField("", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding()
                                .outlinedStyle()
                                .foregroundColor(CustomTheme.Colors.text)
                        }
                        .padding(.horizontal)
                        
                        // Partner Email field
                        VStack(alignment: .leading, spacing: 8) {
                            // Use InterText for label with required asterisk
                            HStack(spacing: 4) {
                                InterText.caption("Partner's Email")
                                    .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                                Text("*")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            
                            TextField("", text: $partnerEmail)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding()
                                .outlinedStyle()
                                .foregroundColor(CustomTheme.Colors.text)
                            
                            CustomText("Required: Your partner's email is needed to create a couple account", 
                                      size: 12, 
                                      color: CustomTheme.Colors.text.opacity(0.6))
                                .padding(.top, 4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal)
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            // Use InterText for label
                            InterText.caption("Password")
                                .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                            
                            HStack {
                                if showPassword {
                                    TextField("", text: $password)
                                        .foregroundColor(CustomTheme.Colors.text)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                } else {
                                    SecureField("", text: $password)
                                        .foregroundColor(CustomTheme.Colors.text)
                                    }
                                    
                                    Button(action: {
                                        showPassword.toggle()
                                    }) {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundColor(CustomTheme.Colors.text.opacity(0.5))
                                    }
                                }
                                .padding()
                                .outlinedStyle()
                                
                                if !password.isEmpty {
                                    // Use CustomText for password requirements with line limit to prevent text from running off screen
                                    CustomText("Your password must be at least 6 characters long. For better security, include a mix of upper & lowercase letters, numbers and symbols.", 
                                              size: 12, 
                                              color: CustomTheme.Colors.text.opacity(0.6))
                                        .padding(.top, 4)
                                        .fixedSize(horizontal: false, vertical: true) // Allow the text to wrap
                                        .lineLimit(3) // Set a reasonable line limit
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Confirm Password field
                        VStack(alignment: .leading, spacing: 8) {
                            // Use InterText for label
                            InterText.caption("Confirm Password")
                                .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                            
                            HStack {
                                if showPassword {
                                    TextField("", text: $confirmPassword)
                                        .foregroundColor(CustomTheme.Colors.text)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                } else {
                                    SecureField("", text: $confirmPassword)
                                        .foregroundColor(CustomTheme.Colors.text)
                                }
                                
                                Button(action: {
                                    showPassword.toggle()
                                }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(CustomTheme.Colors.text.opacity(0.5))
                                }
                            }
                            .padding()
                            .outlinedStyle()
                            
                            if !confirmPassword.isEmpty && confirmPassword != password {
                                CustomText("Passwords do not match", 
                                          size: 12, 
                                          color: Color.red)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if !authViewModel.errorMessage.isEmpty {
                        // Use CustomText for error message
                        CustomText(authViewModel.errorMessage, size: 14, color: .red)
                            .padding(.horizontal)
                            .padding(.top, 20)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            if password == confirmPassword {
                                if partnerEmail.isEmpty {
                                    authViewModel.errorMessage = "Partner's email is required"
                                    return
                                }
                                
                                // Check if we're trying to invite ourselves
                                if email.lowercased() == partnerEmail.lowercased() {
                                    authViewModel.errorMessage = "You cannot enter your own email as your partner's email"
                                    return
                                }
                                
                                // Proceed with signup including partner email
                                await authViewModel.signUpWithPartner(email: email, password: password, name: name, partnerEmail: partnerEmail)
                                if authViewModel.user != nil {
                                    dismiss()
                                }
                            } else {
                                authViewModel.errorMessage = "Passwords do not match"
                            }
                        }
                    }) {
                        // Use InterText for button label
                        InterText.heading("SIGN UP")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hexString: "3A291B"))
                            .cornerRadius(CustomTheme.Layout.buttonCornerRadius)
                    }
                    .disabled(authViewModel.isLoading || 
                              password.count < 6 || 
                              name.isEmpty || 
                              email.isEmpty || 
                              partnerEmail.isEmpty || 
                              password != confirmPassword)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                
                if authViewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: CustomTheme.Colors.accent))
                }
            }
            .navigationBarHidden(true)
            .withInterFont() // Apply Inter font to everything
        }
    }
#Preview {
    AuthView()
}
