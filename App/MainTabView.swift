import SwiftUI
import FirebaseAuth
import FirebaseFirestore
// Removed // Removed: import Unhinged.Utilities

// Add Tab enum to better track selected tab
enum Tab: Int {
    case date = 0
    case friends = 1
    case calendar = 2
}

// For the date tab sub-section toggle
enum DateSubSection {
    case date
    case review
}

// Custom toolbar modifier to resolve ambiguity
struct MainToolbarModifier: ViewModifier {
    let title: String
    let menuAction: () -> Void
    let profileAction: () -> Void
    
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: menuAction) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.custom("InterVariable", size: 18).weight(.black))
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: profileAction) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                }
            }
    }
}

// Simple close button toolbar
struct CloseToolbarModifier: ViewModifier {
    let closeAction: () -> Void
    
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close", action: closeAction)
                        .font(.custom("InterVariable", size: 16))
                }
            }
    }
}

extension View {
    func mainToolbar(title: String, menuAction: @escaping () -> Void, profileAction: @escaping () -> Void) -> some View {
        self.modifier(MainToolbarModifier(title: title, menuAction: menuAction, profileAction: profileAction))
    }
    
    func closeToolbar(action: @escaping () -> Void) -> some View {
        self.modifier(CloseToolbarModifier(closeAction: action))
    }
}

// Helper struct and extension are moved or removed to avoid redeclaration

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var hangoutsViewModel = HangoutsViewModel()
    @StateObject private var calendarViewModel = CalendarIntegrationViewModel()
    @State private var pendingRequestsCount = 0
    @State private var selectedTab: Tab = .date
    @State private var showingMenu = false
    @State private var showingProfile = false
    @State private var dateSection: DateSubSection = .date
    @State private var showingStyleGuide = false
    @State private var showingCoupleAvailability = false
    @State private var showingThemeSettings = false
    @State private var isShowingError = false
    let userId: String
    
    init(userId: String) {
        self.userId = userId
        // Set up floating pill-style tab bar
        if #available(iOS 15.0, *) {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithTransparentBackground()
            
            // Add a background blur
            tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            
            // Set background color using CustomTheme
            tabBarAppearance.backgroundColor = UIColor(CustomTheme.Colors.button)
            
            // Add a shadow
            tabBarAppearance.shadowColor = UIColor.black.withAlphaComponent(0.3)
            
            // Customize unselected and selected colors for contrast with gold
            tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.7)
            tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.7)]
            
            tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor.white
            tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
            
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Main content
            switch selectedTab {
            case .date:
                NavigationStack {
                    dateContentView
                        .mainToolbar(
                            title: getTitle(for: selectedTab),
                            menuAction: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showingMenu.toggle()
                                }
                            },
                            profileAction: {
                                showingProfile = true
                            }
                        )
                }
            case .friends:
                NavigationStack {
                    HangoutsView()
                        .environmentObject(hangoutsViewModel)
                        .mainToolbar(
                            title: getTitle(for: selectedTab),
                            menuAction: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showingMenu.toggle()
                                }
                            },
                            profileAction: {
                                showingProfile = true
                            }
                        )
                }
            case .calendar:
                NavigationStack {
                    CalendarIntegrationView()
                        .environmentObject(calendarViewModel)
                        .mainToolbar(
                            title: getTitle(for: selectedTab),
                            menuAction: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showingMenu.toggle()
                                }
                            },
                            profileAction: {
                                showingProfile = true
                            }
                        )
                }
            }
            
            // Menu overlay if showing - positioned at top leading corner
            if showingMenu {
                menuOverlay
                    .transition(.move(edge: .leading))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingMenu)
                    .zIndex(100) // Ensure it's above everything else
            }
        }
        .withInterFont() // Use our custom modifier to apply Inter font to all text
        .onAppear {
            // Check for pending requests when the view appears
            hangoutsViewModel.loadHangouts()
            
            // Set up timer to update badge count
            updatePendingRequestCount()
            
            // Set up timer to periodically refresh
            let timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                updatePendingRequestCount()
            }
            
            // Store the timer so it can be invalidated when appropriate
            NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
                timer.invalidate()
            }
            
            // Log any analytics or perform setup
            print("MainTabView appeared for user: \(userId)")
        }
        .sheet(isPresented: $showingProfile) {
            NavigationStack {
                ProfileView()
                    .environmentObject(authViewModel)
            }
        }
        .sheet(isPresented: $showingStyleGuide) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Design Guide")
                                .font(.custom("InterVariable", size: 28).weight(.bold))
                            
                            Text("Unhinged Design System")
                                .font(.custom("InterVariable", size: 18))
                                .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                        
                        // Colors
                        colorSection
                        
                        // Typography
                        typographySection
                        
                        // Components
                        componentsSection
                    }
                    .padding(.bottom, 40)
                }
                .background(CustomTheme.Colors.background.edgesIgnoringSafeArea(.all))
                .navigationTitle("Style Guide")
                .closeToolbar(action: {
                    showingStyleGuide = false
                })
            }
        }
        .sheet(isPresented: $showingCoupleAvailability) {
            NavigationStack {
                CoupleAvailabilityView()
                    .navigationTitle("Couple Availability")
                    .closeToolbar(action: {
                        showingCoupleAvailability = false
                    })
            }
        }
        .sheet(isPresented: $showingThemeSettings) {
            ThemeSettingsView()
        }
        .sheet(isPresented: $authViewModel.showPartnerInvitation) {
            if let invitation = authViewModel.pendingPartnerInvitation {
                PartnerInvitationResponseView(invitation: invitation) {
                    // Reload profile data after handling invitation
                }
            }
        }
        // Connect to the centralized error handling system
        .monitorErrors(isPresented: $isShowingError)
    }
    
    // MARK: - Date Tab Content
    
    private var dateContentView: some View {
        ZStack(alignment: .bottom) {
            // Main content
            VStack(spacing: 0) {
                // Content area
                if dateSection == .date {
                    PartnerPersonasView()
                } else {
                    SwipeableRequestsView()
                        .environmentObject(hangoutsViewModel)
                }
            }
            
            // Bottom pill navigation - wider to fit text on one line
            HStack(spacing: 24) { // Added space between buttons
                dateTabButton(title: "DATE", icon: "plus.circle", isSelected: dateSection == .date) {
                    withAnimation {
                        dateSection = .date
                    }
                }
                
                dateTabButton(title: "REVIEW", icon: "eye", isSelected: dateSection == .review) {
                    withAnimation {
                        dateSection = .review
                    }
                }
            }
            .padding(.vertical, 10) 
            .frame(width: 300) // Fixed width that's wide enough
            .background(
                Capsule()
                    .fill(CustomTheme.Colors.button)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
            )
            .padding(.bottom, 20)
        }
    }
    
    private func dateTabButton(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.interSystem(size: 16))
                
                Text(title)
                    .font(.custom("InterVariable", size: 14).weight(.medium))
                    .fixedSize(horizontal: true, vertical: false) // Prevent text wrapping
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .background(isSelected ? Color.white.opacity(0.15) : Color.clear)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Menu Components
    
    private var menuButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingMenu.toggle()
            }
        }) {
            Image(systemName: "line.3.horizontal")
                .font(.interSystem(size: 20))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var profileButton: some View {
        Button(action: {
            showingProfile = true
        }) {
            Image(systemName: "person.circle.fill")
                .font(.interSystem(size: 24))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var menuOverlay: some View {
        ZStack(alignment: .topLeading) {
            // Semi-transparent background covering only part of the screen
            Color.black.opacity(0.4)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height / 2)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingMenu = false
                    }
                }
            
            // Menu panel - 3/4 width of screen with border
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Unhinged")
                    .font(.custom("InterVariable", size: 24).weight(.black))
                    .foregroundColor(CustomTheme.Colors.text)
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                
                // Menu items with reduced spacing
                VStack(alignment: .leading, spacing: 12) {
                    menuItem(title: "Date", icon: "heart.fill", tab: .date)
                    
                    menuItem(title: "See Friends", icon: "person.2.fill", tab: .friends, 
                             showBadge: pendingRequestsCount > 0, badgeCount: pendingRequestsCount)
                    
                    menuItem(title: "Calendar", icon: "calendar", tab: .calendar)
                    
                    Divider()
                        .background(CustomTheme.Colors.text.opacity(0.2))
                        .padding(.vertical, 4)
                    
                    // Style Guide button
                    Button(action: {
                        showingStyleGuide = true
                        withAnimation {
                            showingMenu = false
                        }
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "textformat")
                                .font(.interSystem(size: 20))
                                .frame(width: 28, height: 28)
                            
                            Text("Style Guide")
                                .font(.custom("InterVariable", size: 18).weight(.medium))
                            
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .foregroundColor(CustomTheme.Colors.text)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Theme Settings button
                    Button(action: {
                        showingThemeSettings = true
                        withAnimation {
                            showingMenu = false
                        }
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "paintbrush.fill")
                                .font(.interSystem(size: 20))
                                .frame(width: 28, height: 28)
                            
                            Text("Theme Settings")
                                .font(.custom("InterVariable", size: 18).weight(.medium))
                            
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .foregroundColor(CustomTheme.Colors.text)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Couple Availability button
                    Button(action: {
                        showingCoupleAvailability = true
                        withAnimation {
                            showingMenu = false
                        }
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.interSystem(size: 20))
                                .frame(width: 28, height: 28)
                            
                            Text("Couple Availability")
                                .font(.custom("InterVariable", size: 18).weight(.medium))
                            
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .foregroundColor(CustomTheme.Colors.text)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .frame(width: UIScreen.main.bounds.width * 0.75, height: UIScreen.main.bounds.height / 2)
            .background(CustomTheme.Colors.background.opacity(0.95))
            .cornerRadius(12) // Use standard cornerRadius
            .overlay(
                Rectangle()
                    .frame(width: 1)
                    .foregroundColor(CustomTheme.Colors.text.opacity(0.2))
                    .offset(x: UIScreen.main.bounds.width * 0.75 / 2 - 0.5),
                alignment: .trailing
            )
            .offset(y: 56) // Offset below the navigation bar
        }
    }
    
    private func menuItem(title: String, icon: String, tab: Tab, showBadge: Bool = false, badgeCount: Int = 0) -> some View {
        Button(action: {
            selectedTab = tab
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingMenu = false
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.interSystem(size: 20))
                    .frame(width: 28, height: 28)
                
                Text(title)
                    .font(.custom("InterVariable", size: 18).weight(.medium))
                
                Spacer()
                
                if showBadge && badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.custom("InterVariable", size: 14).weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CustomTheme.Colors.accent)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 10)
            .foregroundColor(selectedTab == tab ? CustomTheme.Colors.accent : CustomTheme.Colors.text)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Style Guide Sections
    
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("COLORS")
                .font(.custom("InterVariable", size: 24).weight(.semibold))
                .padding(.horizontal)
            
            VStack(spacing: 24) {
                // Main colors
                colorGroup(
                    title: "MAIN COLORS",
                    colors: [
                        ("Background", "BAB9A8", CustomTheme.Colors.background),
                        ("Text", "28391A", CustomTheme.Colors.text),
                        ("Accent (Buttons)", "A949A9", CustomTheme.Colors.accent),
                        ("Dark Green", "28391A", CustomTheme.Colors.button)
                    ]
                )
                
                // Additional shades
                colorGroup(
                    title: "ADDITIONAL SHADES",
                    colors: [
                        ("Button Light", "28391A (70%)", CustomTheme.Colors.buttonLight),
                        ("Button Dark", "1C2813", CustomTheme.Colors.buttonDark),
                        ("Background Light", "BAB9A8 (50%)", CustomTheme.Colors.backgroundLight),
                        ("Background Dark", "A6A596", CustomTheme.Colors.backgroundDark)
                    ]
                )
                
                // Card and field backgrounds
                colorGroup(
                    title: "UI BACKGROUNDS",
                    colors: [
                        ("Card Background", "BAB9A8 (20%)", CustomTheme.Colors.cardBackground),
                        ("Field Background", "BAB9A8 (30%)", CustomTheme.Colors.fieldBackground)
                    ]
                )
                
                // Usage notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("COLOR USAGE")
                        .font(.custom("InterVariable", size: 18).weight(.medium))
                    
                    Text("• Accent Purple (A949A9): Use for all buttons, interactive elements")
                        .font(.custom("InterVariable", size: 14))
                        .foregroundColor(CustomTheme.Colors.text)
                    
                    Text("• Text Green (28391A): Use for all text content")
                        .font(.custom("InterVariable", size: 14))
                        .foregroundColor(CustomTheme.Colors.text)
                    
                    Text("• Background Beige (BAB9A8): Use for all screen backgrounds")
                        .font(.custom("InterVariable", size: 14))
                        .foregroundColor(CustomTheme.Colors.text)
                }
            }
            .padding()
            .background(CustomTheme.Colors.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    private func colorGroup(title: String, colors: [(String, String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.custom("InterVariable", size: 18).weight(.medium))
                .foregroundColor(CustomTheme.Colors.text)
            
            ForEach(colors, id: \.0) { name, hex, color in
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                        .frame(width: 60, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.custom("InterVariable", size: 16).weight(.medium))
                        
                        Text("#\(hex)")
                            .font(.custom("InterVariable", size: 14))
                            .foregroundColor(CustomTheme.Colors.text.opacity(0.6))
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private var typographySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TYPOGRAPHY")
                .font(.custom("InterVariable", size: 24).weight(.semibold))
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("HEADINGS")
                        .font(.custom("InterVariable", size: 18).weight(.medium))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        textSample("LARGE TITLE (38PT/BLACK) ★", font: CustomTheme.Typography.largeTitle)
                        textSample("TITLE (32PT/BOLD) ★", font: CustomTheme.Typography.title)
                        textSample("TITLE 2 (26PT/BOLD) ★", font: CustomTheme.Typography.title2)
                        textSample("TITLE 3 (24PT/SEMIBOLD)", font: CustomTheme.Typography.title3)
                        textSample("HEADLINE (22PT/MEDIUM) ★", font: CustomTheme.Typography.headline)
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("TEXT STYLES")
                        .font(.custom("InterVariable", size: 18).weight(.medium))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        textSample("Body (20pt/Regular) ★", font: CustomTheme.Typography.body)
                        textSample("Callout (20pt/Regular)", font: CustomTheme.Typography.callout)
                        textSample("Subheadline (20pt/Regular) ★", font: CustomTheme.Typography.subheadline)
                        textSample("Footnote (18pt/Regular)", font: CustomTheme.Typography.footnote)
                        textSample("Caption (18pt/Regular) ★", font: CustomTheme.Typography.caption)
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("FONT FAMILY")
                        .font(.custom("InterVariable", size: 18).weight(.medium))
                    
                    Text("InterVariable ★")
                        .font(.custom("InterVariable", size: 16))
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                    
                    Text("InterVariableItalic ★")
                        .font(.custom("InterVariableItalic", size: 16))
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                    
                    Text("★ = Used in app")
                        .font(.custom("InterVariable", size: 14))
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.6))
                        .padding(.top, 6)
                }
            }
            .padding()
            .background(CustomTheme.Colors.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    private func textSample(_ description: String, font: Font) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Aa")
                .font(font)
                .foregroundColor(CustomTheme.Colors.text)
                .frame(width: 60, alignment: .leading)
            
            Text(description)
                .font(.custom("InterVariable", size: 14))
                .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
        }
    }
    
    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("COMPONENTS")
                .font(.custom("InterVariable", size: 24).weight(.semibold))
                .padding(.horizontal)
            
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("BUTTONS")
                        .font(.custom("InterVariable", size: 18).weight(.medium))
                    
                    HStack(spacing: 16) {
                        // Outline button - primary style
                        Button("Primary") { }
                            .padding()
                            .foregroundColor(CustomTheme.Colors.accent)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(CustomTheme.Colors.accent, lineWidth: 1)
                            )
                            .frame(maxWidth: .infinity)
                        
                        // Outline button - secondary style
                        Button("Secondary") { }
                            .padding()
                            .foregroundColor(CustomTheme.Colors.accent.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(CustomTheme.Colors.accent.opacity(0.7), lineWidth: 1)
                            )
                            .frame(maxWidth: .infinity)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("TEXT FIELDS")
                        .font(.custom("InterVariable", size: 18).weight(.medium))
                    
                    TextField("Text Field", text: .constant("Sample input"))
                        .themedTextFieldStyle()
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("CARDS")
                        .font(.custom("InterVariable", size: 18).weight(.medium))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CARD TITLE")
                            .font(.custom("InterVariable", size: 18).weight(.semibold))
                        
                        Text("This is a sample card component with standard styling based on the app's design system.")
                            .font(.custom("InterVariable", size: 16))
                            .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                    }
                    .themedCardStyle()
                }
            }
            .padding()
            .background(CustomTheme.Colors.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Functions
    
    private func getTitle(for tab: Tab) -> String {
        switch tab {
        case .date:
            return "Date"
        case .friends:
            return "See Friends"
        case .calendar:
            return "Calendar"
        }
    }
    
    private func loadPendingRequestsCount() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("hangouts")
            .whereField("inviteeID", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error listening for pending requests: \(error.localizedDescription)")
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                DispatchQueue.main.async {
                    self.pendingRequestsCount = count
                }
            }
    }
    
    private func updatePendingRequestCount() {
        loadPendingRequestsCount()
    }
}

#Preview {
    MainTabView(userId: "testUserId")
        .environmentObject(AuthViewModel())
} 
