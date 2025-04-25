import SwiftUI
import FirebaseAuth
import GoogleSignIn
import EventKit
import Firebase
import Authentication
import Core

struct OnboardingView: View {
    // Whether this is a new user
    var isNewUser: Bool
    
    // Completion handler
    var onComplete: () -> Void
    
    // View model for auth to send invitations
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // View model for calendar authorization
    @StateObject private var calendarViewModel = FullCalendarAuthViewModel()
    
    // Current question index
    @State private var currentQuestionIndex = 0
    
    // User profile info
    @State private var name: String = ""
    
    // Current user (using proper adapter for conversion)
    @State private var appUser: AppUser?
    
    // Persona creation
    @State private var personaName: String = ""
    @State private var personaDescription: String = ""
    @State private var selectedPersonaIcon: String = "person.fill"
    @State private var personaIconOptions = ["person.fill", "heart.fill", "star.fill", "sparkles", "leaf.fill", "flame.fill", "bolt.fill", "moon.fill", "sun.max.fill"]
    @State private var isPersonaSaved = false
    
    // Partner invitation
    @State private var partnerEmail: String = ""
    @State private var invitationMessage: String = ""
    @State private var isInvitationSent = false
    
    // Relationship name (couple name)
    @State private var coupleName: String = ""
    @State private var isCoupleSaved = false
    
    // Calendar connections
    @State private var showCalendarOptions = false
    
    // Questions list
    var questions: [OnboardingQuestion] {
        var result = [
            OnboardingQuestion(
                id: "welcome",
                title: "Welcome to Unhinged!",
                subtitle: "Let's set up your profile to get started",
                type: .intro
            )
        ]
        
        if !UserDefaults.standard.bool(forKey: "partnerInvitationSent") {
            result.append(OnboardingQuestion(
                id: "partner",
                title: "Who's your partner?",
                subtitle: "Enter their email to connect",
                type: .partnerEmail
            ))
        } else {
            result.append(OnboardingQuestion(
                id: "partner-confirmed",
                title: "Your partner invitation is on its way!",
                subtitle: "We'll notify you when they join",
                type: .partnerConfirmed
            ))
        }
        
        result.append(contentsOf: [
            OnboardingQuestion(
                id: "calendar",
                title: "Connect your calendar",
                subtitle: "This helps us find the best times for hangouts",
                type: .calendar
            ),
            OnboardingQuestion(
                id: "persona",
                title: "Create your first persona",
                subtitle: "Personas help organize different parts of your life",
                type: .persona
            ),
            OnboardingQuestion(
                id: "couple",
                title: "Name your relationship",
                subtitle: "Give your couple profile a name",
                type: .coupleName
            ),
            OnboardingQuestion(
                id: "complete",
                title: "All set!",
                subtitle: "You're ready to start using Unhinged",
                type: .complete
            )
        ])
        
        return result
    }
    
    var currentQuestion: OnboardingQuestion {
        questions[currentQuestionIndex]
    }
    
    var body: some View {
        ZStack {
            // Background
            CustomTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress bar
                ProgressBar(current: currentQuestionIndex, total: questions.count)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Question content
                VStack(spacing: 40) {
                    questionHeader
                    
                    scrollableContent
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Navigation buttons
                navigationButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            if let currentUser = Auth.auth().currentUser {
                name = currentUser.displayName ?? ""
                // Convert Firebase user to AppUser using the adapter
                let firebaseAuthUser = FirebaseAuthUser(
                    uid: currentUser.uid,
                    email: currentUser.email,
                    displayName: currentUser.displayName,
                    photoURL: currentUser.photoURL
                )
                appUser = AppUser.fromFirebaseUser(firebaseAuthUser)
            }
        }
    }
    
    // Question header with title and subtitle
    var questionHeader: some View {
        VStack(spacing: 12) {
            Text(currentQuestion.title)
                .font(.custom("InterVariable", size: 26))
                .fontWeight(.bold)
                .foregroundColor(CustomTheme.Colors.text)
                .multilineTextAlignment(.center)
                .padding(.top, 40)
            
            Text(currentQuestion.subtitle)
                .font(.custom("InterVariable", size: 17))
                .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
    
    // Main scrollable content area
    var scrollableContent: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Question content changes based on question type
                switch currentQuestion.type {
                case .intro:
                    introContent
                case .partnerEmail:
                    partnerEmailContent
                case .partnerConfirmed:
                    partnerConfirmedContent
                case .calendar:
                    calendarContent
                case .persona:
                    personaContent
                case .coupleName:
                    coupleNameContent
                case .complete:
                    completeContent
                }
            }
            .padding(.bottom, 60)
        }
    }
    
    // Navigation buttons (next, back)
    var navigationButtons: some View {
        HStack {
            // Back button
            if currentQuestionIndex > 0 {
                Button {
                    withAnimation(.spring()) {
                        currentQuestionIndex -= 1
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.custom("InterVariable", size: 16))
                    .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                    .padding(.vertical, 16)
                }
            } else {
                Spacer()
            }
            
            Spacer()
            
            // Next/Continue button
            Button {
                handleNextButtonTap()
            } label: {
                if currentQuestion.type == .complete {
                    Text("Get Started")
                        .font(.custom("InterVariable", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 150)
                        .padding(.vertical, 16)
                        .background(CustomTheme.Colors.accent)
                        .cornerRadius(30)
                        .shadow(color: CustomTheme.Colors.accent.opacity(0.3), radius: 10, x: 0, y: 5)
                } else {
                    HStack(spacing: 8) {
                        Text("Continue")
                        Image(systemName: "chevron.right")
                    }
                    .font(.custom("InterVariable", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(minWidth: 120)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(isNextButtonEnabled ? CustomTheme.Colors.accent : CustomTheme.Colors.accent.opacity(0.3))
                    .cornerRadius(30)
                    .shadow(color: isNextButtonEnabled ? CustomTheme.Colors.accent.opacity(0.3) : Color.clear, radius: 10, x: 0, y: 5)
                }
            }
            .disabled(!isNextButtonEnabled)
        }
    }
    
    // Determine if the next button should be enabled
    var isNextButtonEnabled: Bool {
        switch currentQuestion.type {
        case .intro:
            return true
        case .partnerEmail:
            return !partnerEmail.isEmpty && partnerEmail.contains("@") && !isInvitationSent
        case .partnerConfirmed:
            return true
        case .calendar:
            return true // Calendar is optional
        case .persona:
            return personaName.isEmpty || isPersonaSaved
        case .coupleName:
            return coupleName.isEmpty || isCoupleSaved
        case .complete:
            return true
        }
    }
    
    // Handle next button tap based on current question
    func handleNextButtonTap() {
        switch currentQuestion.type {
        case .partnerEmail:
            sendPartnerInvitation()
        case .persona:
            if !personaName.isEmpty && !isPersonaSaved {
                savePersona()
            } else {
                goToNextQuestion()
            }
        case .coupleName:
            if !coupleName.isEmpty && !isCoupleSaved {
                saveCouple()
            } else {
                goToNextQuestion()
            }
        case .complete:
            // Complete onboarding and exit
            authViewModel.completeOnboarding()
            onComplete()
        default:
            goToNextQuestion()
        }
    }
    
    func goToNextQuestion() {
        withAnimation(.spring()) {
            if currentQuestionIndex < questions.count - 1 {
                currentQuestionIndex += 1
            }
        }
    }
    
    // MARK: - Question Content Views
    
    var introContent: some View {
        VStack(spacing: 30) {
            // App logo
            Image("cheem-logo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(CustomTheme.Colors.accent, lineWidth: 2)
                )
                .padding(.vertical, 20)
            
            // Welcome message
            Text("Hi \(name)!")
                .font(.custom("InterVariable", size: 22))
                .fontWeight(.bold)
                .foregroundColor(CustomTheme.Colors.text)
            
            Text("We'll help you connect with your partner, set up your calendar, and create your personas.")
                .font(.custom("InterVariable", size: 17))
                .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 30)
    }
    
    var partnerEmailContent: some View {
        VStack(spacing: 25) {
            // Partner icon
            Image(systemName: "person.2.fill")
                .font(.system(size: 70))
                .foregroundColor(CustomTheme.Colors.accent)
                .padding(.vertical, 20)
            
            // Email input
            VStack(alignment: .leading, spacing: 8) {
                Text("Partner's email address")
                    .font(.custom("InterVariable", size: 14))
                    .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                
                TextField("partner@example.com", text: $partnerEmail)
                    .font(.custom("InterVariable", size: 17))
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(CustomTheme.Colors.text.opacity(0.2), lineWidth: 1)
                    )
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            // Optional message input
            VStack(alignment: .leading, spacing: 8) {
                Text("Add a personal message (optional)")
                    .font(.custom("InterVariable", size: 14))
                    .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                
                TextField("I'm joining Unhinged! Join me?", text: $invitationMessage)
                    .font(.custom("InterVariable", size: 17))
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(CustomTheme.Colors.text.opacity(0.2), lineWidth: 1)
                    )
            }
            
            if !authViewModel.errorMessage.isEmpty {
                Text(authViewModel.errorMessage)
                    .font(.custom("InterVariable", size: 14))
                    .foregroundColor(.red)
                    .padding(.top, 10)
            }
            
            if authViewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: CustomTheme.Colors.accent))
                    .padding()
            }
        }
    }
    
    var partnerConfirmedContent: some View {
        VStack(spacing: 25) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .padding(.vertical, 20)
            
            Text("Your invitation has been sent")
                .font(.custom("InterVariable", size: 20))
                .fontWeight(.semibold)
                .foregroundColor(CustomTheme.Colors.text)
            
            Text("We'll notify you when your partner joins Unhinged. You can also resend the invitation from your profile later.")
                .font(.custom("InterVariable", size: 17))
                .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    var calendarContent: some View {
        VStack(spacing: 25) {
            // Calendar icon
            Image(systemName: "calendar")
                .font(.system(size: 70))
                .foregroundColor(CustomTheme.Colors.accent)
                .padding(.vertical, 20)
            
            Text("Connect your calendars to find the best time for hangouts")
                .font(.custom("InterVariable", size: 17))
                .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Calendar options
            VStack(spacing: 16) {
                // Google Calendar
                calendarButton(
                    title: "Google Calendar",
                    icon: "g.circle.fill",
                    iconColor: .red,
                    isConnected: calendarViewModel.googleCalendarConnected
                ) {
                    Task {
                        await calendarViewModel.connectGoogleCalendar()
                    }
                }
                
                // Apple Calendar
                calendarButton(
                    title: "Apple Calendar",
                    icon: "applelogo",
                    iconColor: .gray,
                    isConnected: calendarViewModel.appleCalendarConnected
                ) {
                    Task {
                        await calendarViewModel.connectAppleCalendar()
                    }
                }
                
                // Outlook Calendar
                calendarButton(
                    title: "Outlook Calendar",
                    icon: "envelope.circle.fill",
                    iconColor: .blue,
                    isConnected: calendarViewModel.outlookCalendarConnected
                ) {
                    Task {
                        await calendarViewModel.connectOutlookCalendar()
                    }
                }
            }
            
            if calendarViewModel.isConnecting {
                ProgressView("Connecting...")
                    .progressViewStyle(CircularProgressViewStyle(tint: CustomTheme.Colors.accent))
                    .padding()
            }
            
            if let error = calendarViewModel.error {
                Text(error.localizedDescription)
                    .font(.custom("InterVariable", size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            Text("You can always connect calendars later in Settings")
                .font(.custom("InterVariable", size: 14))
                .foregroundColor(CustomTheme.Colors.text.opacity(0.6))
                .padding(.top)
        }
    }
    
    var personaContent: some View {
        VStack(spacing: 25) {
            // Persona icon
            Image(systemName: "person.crop.circle.fill.badge.plus")
                .font(.system(size: 70))
                .foregroundColor(CustomTheme.Colors.accent)
                .padding(.vertical, 20)
            
            if isPersonaSaved {
                // Success confirmation
                VStack(spacing: 15) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Persona Created!")
                        .font(.custom("InterVariable", size: 20))
                        .fontWeight(.semibold)
                        .foregroundColor(CustomTheme.Colors.text)
                    
                    Text("Your persona \"\(personaName)\" has been created.")
                        .font(.custom("InterVariable", size: 17))
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
            } else {
                // Persona form
                VStack(spacing: 20) {
                    // Persona name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Persona name")
                            .font(.custom("InterVariable", size: 14))
                            .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                        
                        TextField("e.g. Work Me, Fun Me, Family Me", text: $personaName)
                            .font(.custom("InterVariable", size: 17))
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(CustomTheme.Colors.text.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // Persona description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description (optional)")
                            .font(.custom("InterVariable", size: 14))
                            .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                        
                        TextField("Brief description of this persona", text: $personaDescription)
                            .font(.custom("InterVariable", size: 17))
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(CustomTheme.Colors.text.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // Icon selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose an icon")
                            .font(.custom("InterVariable", size: 14))
                            .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(personaIconOptions, id: \.self) { icon in
                                    Image(systemName: icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedPersonaIcon == icon ? CustomTheme.Colors.accent : CustomTheme.Colors.text.opacity(0.6))
                                        .frame(width: 50, height: 50)
                                        .background(selectedPersonaIcon == icon ? CustomTheme.Colors.accent.opacity(0.2) : Color.white.opacity(0.1))
                                        .cornerRadius(25)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedPersonaIcon == icon ? CustomTheme.Colors.accent : Color.clear, lineWidth: 2)
                                        )
                                        .onTapGesture {
                                            selectedPersonaIcon = icon
                                        }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    
                    // Save button
                    Button {
                        savePersona()
                    } label: {
                        Text("Save Persona")
                            .font(.custom("InterVariable", size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(personaName.isEmpty ? CustomTheme.Colors.accent.opacity(0.3) : CustomTheme.Colors.accent)
                            .cornerRadius(30)
                    }
                    .disabled(personaName.isEmpty)
                }
            }
            
            Text("You can create more personas later in Settings")
                .font(.custom("InterVariable", size: 14))
                .foregroundColor(CustomTheme.Colors.text.opacity(0.6))
                .padding(.top)
        }
    }
    
    var coupleNameContent: some View {
        VStack(spacing: 25) {
            // Couple icon
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(CustomTheme.Colors.accent)
                .padding(.vertical, 20)
            
            if isCoupleSaved {
                // Success confirmation
                VStack(spacing: 15) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Relationship Named!")
                        .font(.custom("InterVariable", size: 20))
                        .fontWeight(.semibold)
                        .foregroundColor(CustomTheme.Colors.text)
                    
                    Text("Your relationship \"\(coupleName)\" has been saved.")
                        .font(.custom("InterVariable", size: 17))
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
            } else {
                // Couple name form
                VStack(spacing: 20) {
                    Text("What should we call your relationship?")
                        .font(.custom("InterVariable", size: 17))
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    // Couple name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Relationship name")
                            .font(.custom("InterVariable", size: 14))
                            .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                        
                        TextField("e.g. Sam & Alex", text: $coupleName)
                            .font(.custom("InterVariable", size: 17))
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(CustomTheme.Colors.text.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // Suggestions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Or choose a suggestion:")
                            .font(.custom("InterVariable", size: 14))
                            .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            if let firstName = appUser?.displayName?.components(separatedBy: " ").first {
                                coupleSuggestionButton("\(firstName) & Partner")
                                coupleSuggestionButton("The \(firstName)s")
                            }
                            coupleSuggestionButton("Adventure Buddies")
                            coupleSuggestionButton("Dream Team")
                        }
                    }
                    
                    // Save button
                    Button {
                        saveCouple()
                    } label: {
                        Text("Save Name")
                            .font(.custom("InterVariable", size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(coupleName.isEmpty ? CustomTheme.Colors.accent.opacity(0.3) : CustomTheme.Colors.accent)
                            .cornerRadius(30)
                    }
                    .disabled(coupleName.isEmpty)
                }
            }
            
            Text("You can change this anytime in Settings")
                .font(.custom("InterVariable", size: 14))
                .foregroundColor(CustomTheme.Colors.text.opacity(0.6))
                .padding(.top)
        }
    }
    
    var completeContent: some View {
        VStack(spacing: 30) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .padding(.vertical, 20)
            
            Text("You're all set!")
                .font(.custom("InterVariable", size: 24))
                .fontWeight(.bold)
                .foregroundColor(CustomTheme.Colors.text)
            
            Text("Here's what you've accomplished:")
                .font(.custom("InterVariable", size: 17))
                .foregroundColor(CustomTheme.Colors.text)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 16) {
                completionItem(
                    icon: "person.2.fill", 
                    text: "Invited your partner to join",
                    isDone: UserDefaults.standard.bool(forKey: "partnerInvitationSent") || isInvitationSent
                )
                
                completionItem(
                    icon: "calendar", 
                    text: "Connected your calendar",
                    isDone: calendarViewModel.googleCalendarConnected || calendarViewModel.appleCalendarConnected || calendarViewModel.outlookCalendarConnected
                )
                
                completionItem(
                    icon: "person.crop.circle.fill.badge.plus", 
                    text: "Created your first persona",
                    isDone: isPersonaSaved
                )
                
                completionItem(
                    icon: "heart.circle.fill", 
                    text: "Named your relationship",
                    isDone: isCoupleSaved
                )
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            
            Text("Time to start using Unhinged!")
                .font(.custom("InterVariable", size: 17))
                .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
                .padding(.top, 10)
        }
    }
    
    // MARK: - Helper Functions
    
    // Helper to create a calendar connection button
    func calendarButton(title: String, icon: String, iconColor: Color, isConnected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 36, height: 36)
                
                Text(title)
                    .font(.custom("InterVariable", size: 16))
                    .foregroundColor(CustomTheme.Colors.text)
                
                Spacer()
                
                if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundColor(CustomTheme.Colors.accent)
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(CustomTheme.Colors.text.opacity(0.2), lineWidth: 1)
            )
        }
        .disabled(isConnected || calendarViewModel.isConnecting)
    }
    
    // Helper to create a couple name suggestion button
    func coupleSuggestionButton(_ suggestion: String) -> some View {
        Button {
            coupleName = suggestion
        } label: {
            Text(suggestion)
                .font(.custom("InterVariable", size: 15))
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(CustomTheme.Colors.accent.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    // Helper to create a completion item
    func completionItem(icon: String, text: String, isDone: Bool) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isDone ? .green : CustomTheme.Colors.text.opacity(0.6))
                .frame(width: 30)
            
            Text(text)
                .font(.custom("InterVariable", size: 16))
                .foregroundColor(CustomTheme.Colors.text)
            
            Spacer()
            
            if isDone {
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
            }
        }
    }
    
    // Send partner invitation
    func sendPartnerInvitation() {
        Task {
            if await authViewModel.invitePartner(email: partnerEmail, message: invitationMessage) {
                withAnimation {
                    isInvitationSent = true
                    
                    // Don't auto-advance immediately, show the success state first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        goToNextQuestion()
                    }
                }
            }
        }
    }
    
    // Save persona
    func savePersona() {
        guard !personaName.isEmpty else { return }
        
        // Here you would connect to your actual Persona saving logic
        withAnimation {
            isPersonaSaved = true
            
            // Don't auto-advance immediately, show the success state first
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                goToNextQuestion()
            }
        }
    }
    
    // Save couple relationship
    func saveCouple() {
        guard !coupleName.isEmpty else { return }
        
        // Here you would connect to your actual Relationship saving logic
        withAnimation {
            isCoupleSaved = true
            
            // Don't auto-advance immediately, show the success state first
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                goToNextQuestion()
            }
        }
    }
}

// MARK: - Supporting Types and Components

// Helper type representing an onboarding question
struct OnboardingQuestion: Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var type: OnboardingQuestionType
}

// Question types enum
enum OnboardingQuestionType {
    case intro
    case partnerEmail
    case partnerConfirmed
    case calendar
    case persona
    case coupleName
    case complete
}

// Progress bar component
struct ProgressBar: View {
    var current: Int
    var total: Int
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .foregroundColor(CustomTheme.Colors.text.opacity(0.1))
                    .frame(width: geometry.size.width, height: 6)
                    .cornerRadius(3)
                
                // Filled progress
                Rectangle()
                    .foregroundColor(CustomTheme.Colors.accent)
                    .frame(width: min(CGFloat(current + 1) / CGFloat(total) * geometry.size.width, geometry.size.width), height: 6)
                    .cornerRadius(3)
                    .animation(.spring(), value: current)
            }
        }
        .frame(height: 6)
    }
}

#Preview {
    OnboardingView(isNewUser: true) {
        print("Onboarding complete")
    }
} 