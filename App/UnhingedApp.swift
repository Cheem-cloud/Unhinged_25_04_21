import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import FirebaseMessaging
import UIKit
import CoreText
import ObjectiveC

@main
struct UnhingedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var personaManager = PersonaManager.shared
    @StateObject var authManager = AuthManager.shared
    @StateObject private var authViewModel = AuthViewModel()
    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        print("UnhingedApp: Initializing app")
        
        // Register custom fonts
        registerFonts()
        
        // Override UIKit default fonts to use our variable font
        overrideSystemFonts()
        
        // Configure Firebase - this must be the first thing we do
        FirebaseApp.configure()
        print("UnhingedApp: Firebase configured")
        
        // Check if we can get the client ID (to verify Firebase config)
        if let clientID = FirebaseApp.app()?.options.clientID {
            print("UnhingedApp: Firebase clientID found: \(clientID)")
        } else {
            print("UnhingedApp: ERROR - Firebase clientID not found")
        }
        
        // Check if user is already signed in
        if let user = Auth.auth().currentUser {
            print("UnhingedApp: User already signed in: \(user.uid)")
        } else {
            print("UnhingedApp: No signed-in user found")
        }
        
        // Set up notifications
        NotificationService.shared.setupNotifications()
        
        // Apply theme
        configureTheme()
    }
    
    // Register fonts programmatically to ensure they load
    private func registerFonts() {
        print("🔤 ATTEMPTING VARIABLE FONT REGISTRATION")
        let variableFonts = ["InterVariable", "InterVariable-Italic"]
        let fontNames = ["InterVariable", "InterVariableItalic"] // Font family names (no hyphen in italic)
        
        // List all .ttf files in the bundle for debugging
        print("🔤 TTF FILES IN BUNDLE:")
        for path in Bundle.main.paths(forResourcesOfType: "ttf", inDirectory: nil) {
            print("   • \(path)")
        }
        
        // Register each variable font
        for (index, fontFile) in variableFonts.enumerated() {
            if let fontURL = Bundle.main.url(forResource: fontFile, withExtension: "ttf") {
                print("🔤 FOUND FONT FILE: \(fontFile).ttf")
                
                // Make sure we're using the correct font family name
                let fontFamilyName = fontNames[index]
                print("🔤 REGISTERING AS: \(fontFamilyName)")
                
                if registerFontFromURL(fontURL) {
                    print("✅ Successfully registered variable font: \(fontFamilyName)")
                } else {
                    print("❌ Failed to register font: \(fontFamilyName)")
                }
            } else {
                print("❌ FONT FILE NOT FOUND: \(fontFile).ttf")
            }
        }
    }
    
    private func registerFontFromURL(_ fontURL: URL) -> Bool {
        guard let fontData = try? Data(contentsOf: fontURL) else {
            print("❌ Failed to load font data from URL: \(fontURL.path)")
            return false
        }
        
        guard let provider = CGDataProvider(data: fontData as CFData),
              let font = CGFont(provider) else {
            print("❌ Failed to create font from data at: \(fontURL.path)")
            return false
        }
        
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterGraphicsFont(font, &error) {
            if let error = error?.takeRetainedValue() {
                print("❌ Error registering font: \(error)")
            } else {
                print("❌ Unknown error registering font")
            }
            return false
        }
        
        print("✅ Successfully registered font: \(fontURL.lastPathComponent)")
        return true
    }
    
    // Override all UIKit system fonts to use our variable font
    private func overrideSystemFonts() {
        // Make sure Inter variable font is available first
        guard let _ = UIFont(name: "InterVariable", size: 17) else {
            print("❌ WARNING: InterVariable font not available for system font override")
            return
        }
        
        print("🔤 APPLYING UIKIT FONT OVERRIDES TO USE INTERVARIABLE")
        
        // NOTE: Method swizzling approach temporarily disabled due to ambiguity issues
        // Instead, we're using Font.interSystem() directly in views
        
        print("✅ Font overrides applied through direct Font extensions")
    }
    
    var body: some Scene {
        WindowGroup {
            // Restore regular app flow with font inspector
            if showSplash {
                SplashView()
                    .environmentObject(authViewModel)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        print("UnhingedApp: SplashView appeared")
                        // Decrease splash screen timeout for testing
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                print("UnhingedApp: Dismissing splash screen")
                                showSplash = false
                            }
                        }
                    }
            } else {
                ContentView()
                    .environmentObject(authViewModel)
                    .onOpenURL { url in
                        print("UnhingedApp: Handling URL: \(url)")
                        print("UnhingedApp: URL scheme: \(url.scheme ?? "none")")
                        print("UnhingedApp: URL host: \(url.host ?? "none")")
                        print("UnhingedApp: URL path: \(url.path)")
                        
                        // First try our custom deep link handler
                        if url.scheme == "cheemhang" {
                            if NavigationCoordinator.shared.handleDeepLink(url) {
                                print("UnhingedApp: URL handled by NavigationCoordinator")
                                return
                            }
                        }
                        
                        // Check if this is a Google Sign-in callback URL
                        if url.scheme?.contains("googleusercontent") == true || 
                           url.scheme?.starts(with: "com.googleusercontent") == true {
                            print("UnhingedApp: Detected Google Sign-in URL, passing to GIDSignIn")
                            GIDSignIn.sharedInstance.handle(url)
                        } else {
                            print("UnhingedApp: URL not recognized as Google Sign-in URL")
                        }
                    }
                    .onAppear {
                        print("UnhingedApp: ContentView appeared")
                    }
                    .preferredColorScheme(.dark) // Force dark mode for better contrast with colors
            }
            
            // Access FontVerificationView at any time via:
            // FontVerificationView()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Show splash screen whenever app becomes active
                print("UnhingedApp: App became active, showing splash screen")
                showSplash = true
                
                // Dismiss splash after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        print("UnhingedApp: Dismissing splash screen after app active")
                        showSplash = false
                    }
                }
            }
        }
    }
    
    private func configureTheme() {
        // Configure the appearance of navigation bars
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithTransparentBackground()
        navigationBarAppearance.backgroundColor = UIColor.clear
        navigationBarAppearance.shadowColor = .clear
        
        // Set title text attributes
        navigationBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(CustomTheme.Colors.text)
        ]
        navigationBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(CustomTheme.Colors.text)
        ]
        
        // Apply to UINavigationBar
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        UINavigationBar.appearance().tintColor = UIColor(CustomTheme.Colors.accent)
        
        // Configure the appearance of tab bars
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = UIColor(CustomTheme.Colors.background)
        tabBarAppearance.shadowColor = .clear
        
        // Apply to UITabBar
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = UIColor(CustomTheme.Colors.button)
        
        // Form controls appearance
        UITextField.appearance().tintColor = UIColor(CustomTheme.Colors.button)
        UITextView.appearance().tintColor = UIColor(CustomTheme.Colors.button)
        
        // Segmented controls
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(CustomTheme.Colors.button)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(CustomTheme.Colors.text)], for: .normal)
        
        // Switch appearance
        UISwitch.appearance().onTintColor = UIColor(CustomTheme.Colors.button)
        UISwitch.appearance().thumbTintColor = UIColor.white
        
        // Button appearance
        UIButton.appearance().tintColor = UIColor(CustomTheme.Colors.button)
    }
} 