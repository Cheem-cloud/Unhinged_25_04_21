import UIKit
import Firebase
import FirebaseAuth
import FirebaseMessaging
import UserNotifications
import GoogleSignIn
import Foundation
import FirebaseCore
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Setup crash reporting
        setupCrashReporting()
        
        // Configure settings
        configureSettings()
        
        // Setup logging
        setupLogging()
        
        // Initialize services
        initializeServices()
        
        // Configure remote config
        configureRemoteConfig()
        
        // Check for updates
        checkForAppUpdates()
        
        // Log user session
        logUserSession()
        
        return true
    }
    
    // Handle URL scheme callbacks for Google Sign-In
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("AppDelegate: Received URL: \(url)")
        
        // Check if the URL is a Google Sign-In callback
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    // MARK: - Private Methods
    
    /// Initialize services that the app will use
    private func initializeServices() {
        // Register service adapters with ServiceManager
        FirestoreServiceAdapter.registerWithServiceManager()
        
        // Register calendar services
        registerCalendarServices()
        
        // Register notification services
        registerNotificationServices()
        
        // Start background services
        let serviceManager = ServiceManager.shared
        serviceManager.log("Services initialized")
        
        // Start data synchronizer
        startDataSynchronizer()
    }
    
    /// Register calendar services
    private func registerCalendarServices() {
        // Create services
        let firestoreService = FirestoreService.shared
        
        // Create the CalendarOperationsServiceImpl implementation
        let calendarOpsService = CalendarOperationsServiceImpl()
        
        // Register the implementation
        ServiceManager.shared.registerServiceInstance(CalendarOperationsService.self, instance: calendarOpsService)
        
        // Create the adapter that provides backward compatibility
        let calendarAdapter = CalendarServiceAdapter(calendarOpsService: calendarOpsService)
        
        // Register adapter as CRUDService
        ServiceManager.shared.registerServiceInstance(CRUDService.self, instance: calendarAdapter)
        
        ServiceManager.shared.log("Calendar services registered using new architecture")
    }
    
    /// Register notification services
    private func registerNotificationServices() {
        // Create the notification adapter
        let notificationAdapter = NotificationServiceAdapter()
        ServiceManager.shared.registerServiceInstance(NotificationServiceAdapter.self, instance: notificationAdapter)
        ServiceManager.shared.log("Notification services registered")
    }
    
    /// Start data synchronizer
    private func startDataSynchronizer() {
        // Check if user is logged in
        if let currentUserId = Auth.auth().currentUser?.uid {
            let firestoreService = FirestoreService.shared
            let calendarService = ServiceManager.shared.getService(CRUDService.self) as! CalendarServiceAdapter
            let notificationService = NotificationServiceAdapter()
            
            // Create data synchronizer
            let dataSynchronizer = DataSynchronizer(
                firestoreService: firestoreService,
                calendarService: calendarService,
                notificationService: notificationService
            )
            
            // Run initial synchronization
            Task {
                do {
                    try await dataSynchronizer.runFullSynchronization(for: currentUserId)
                    print("Initial data synchronization completed for user: \(currentUserId)")
                } catch {
                    print("Error during initial data synchronization: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Configure app settings
    private func configureSettings() {
        // App-wide settings
    }
    
    /// Setup crash reporting
    private func setupCrashReporting() {
        // Configure Firebase Crashlytics
    }
    
    /// Setup logging system
    private func setupLogging() {
        // Configure logging preferences
    }
    
    /// Configure remote config
    private func configureRemoteConfig() {
        // Set up Firebase remote config
    }
    
    /// Check for app updates
    private func checkForAppUpdates() {
        // Check App Store for updates
    }
    
    /// Log user session start
    private func logUserSession() {
        // Log user session for analytics
        if let userId = Auth.auth().currentUser?.uid {
            print("User session started: \(userId)")
        } else {
            print("Anonymous session started")
        }
    }
    
    // MARK: - Service Architecture Setup
    
    private func setupServiceArchitecture() {
        print("📱 AppDelegate: Initializing Service Architecture")
        
        // Register core service implementations directly
        let firestoreService = FirestoreService.shared
        ServiceManager.shared.registerServiceInstance(FirestoreService.self, instance: firestoreService)
        
        // Register CalendarOperationsService
        let calendarOpsService = CalendarOperationsServiceImpl()
        ServiceManager.shared.registerServiceInstance(CalendarOperationsService.self, instance: calendarOpsService)
        
        // Register notification service
        let notificationService = NotificationService.shared
        ServiceManager.shared.registerServiceInstance(NotificationService.self, instance: notificationService)
        
        // Register other services
        registerServices()
        
        // Initialize data synchronizer with direct service references
        let dataSynchronizer = DataSynchronizer.shared
        
        // Start data synchronization if user is logged in
        if let currentUserId = Auth.auth().currentUser?.uid {
            Task {
                try? await dataSynchronizer.runFullSynchronization(for: currentUserId)
            }
        }
        
        print("📱 AppDelegate: Service Architecture initialized")
    }
    
    private func registerServices() {
        // Register direct service implementations
        let serviceManager = ServiceManager.shared
        
        // Register the core service implementations
        serviceManager.registerServiceInstance(FirestoreService.self, instance: FirestoreService.shared)
        
        // Register application services with their direct implementations
        serviceManager.registerServiceInstance(AuthenticationService.self, instance: AuthenticationManager())
        serviceManager.registerServiceInstance(RelationshipService.self, instance: RelationshipManager())
        serviceManager.registerServiceInstance(CoupleProfileService.self, instance: CoupleProfileManager())
        serviceManager.registerServiceInstance(HangoutService.self, instance: HangoutManager())
        serviceManager.registerServiceInstance(NotificationService.self, instance: NotificationService.shared)
        serviceManager.registerServiceInstance(AnalyticsService.self, instance: AnalyticsManager())
        serviceManager.registerServiceInstance(SchedulingService.self, instance: SchedulingManager())
        serviceManager.registerServiceInstance(PreferencesService.self, instance: PreferencesManager())
    }
    
    func setupNotifications(_ application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permission
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if let error = error {
                    print("Error requesting notification permissions: \(error.localizedDescription)")
                }
                print("Notification permission granted: \(granted)")
            }
        )
        
        application.registerForRemoteNotifications()
    }
    
    // Handle device token for APNs
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        
        // Convert to string for debugging
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("APNs device token: \(token)")
    }
    
    // Handle failure to register for notifications
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // Handle FCM token refresh
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            print("✅ Firebase registration token: \(token)")
            NotificationService.shared.saveDeviceToken(token)
        } else {
            print("❌ FCM token is nil")
        }
    }
    
    // Handle foreground notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("Received notification in foreground: \(userInfo)")
        
        // Extract notification type and ID if available
        let notificationType = userInfo["type"] as? String
        let notificationId = (userInfo["notificationId"] as? String) ?? 
                            (userInfo["data"] as? [String: Any])?["notificationId"] as? String
        
        print("Notification type: \(notificationType ?? "none"), ID: \(notificationId ?? "none")")
        
        // Track received notification IDs to prevent duplicates
        if let notificationId = notificationId {
            // Use a static set to track processed notification IDs (would normally use a proper storage system)
            struct Storage {
                static var processedIds = Set<String>()
            }
            
            // Check if we've already processed this notification
            if Storage.processedIds.contains(notificationId) {
                print("⚠️ Duplicate notification detected and filtered: \(notificationId)")
                completionHandler([]) // Don't show duplicate
                return
            }
            
            // Add to processed IDs
            Storage.processedIds.insert(notificationId)
            
            // Clean up old IDs (keep only the most recent 100)
            if Storage.processedIds.count > 100 {
                // Remove oldest elements by converting to array, sorting, and removing
                var processedArray = Array(Storage.processedIds)
                processedArray.sort() // Sort by string value as we don't have timestamps
                let itemsToRemove = processedArray.prefix(Storage.processedIds.count - 100)
                itemsToRemove.forEach { Storage.processedIds.remove($0) }
            }
        }
        
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("Handling notification tap: \(userInfo)")
        
        // Track notification IDs to prevent duplicate handling
        let notificationId = (userInfo["notificationId"] as? String) ?? 
                           (userInfo["data"] as? [String: Any])?["notificationId"] as? String
        
        if let notificationId = notificationId {
            struct Storage {
                static var processedTapIds = Set<String>()
            }
            
            // Check if we've already processed this notification tap
            if Storage.processedTapIds.contains(notificationId) {
                print("⚠️ Duplicate notification tap detected and filtered: \(notificationId)")
                completionHandler()
                return
            }
            
            // Add to processed IDs
            Storage.processedTapIds.insert(notificationId)
            
            // Clean up old IDs (keep only the most recent 100)
            if Storage.processedTapIds.count > 100 {
                // Remove oldest elements by converting to array, sorting, and removing
                var processedArray = Array(Storage.processedTapIds)
                processedArray.sort() // Sort by string value as we don't have timestamps
                let itemsToRemove = processedArray.prefix(Storage.processedTapIds.count - 100)
                itemsToRemove.forEach { Storage.processedTapIds.remove($0) }
            }
        }
        
        // Process notification data
        let hangoutID = (userInfo["hangoutID"] as? String) ?? 
                       (userInfo["data"] as? [String: Any])?["hangoutId"] as? String
        
        if let hangoutID = hangoutID {
            print("Notification for hangout: \(hangoutID)")
            
            // Post notification to handle navigation
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToHangout"),
                object: nil,
                userInfo: ["hangoutID": hangoutID]
            )
        }
        
        completionHandler()
    }
    
    // MARK: - Firebase Auth Setup
    
    private func setupFirebaseAuth() {
        print("AppDelegate: Setting up Firebase Auth")
        Auth.auth().addStateDidChangeListener { (auth, user) in
            if let user = user {
                print("AppDelegate: User signed in: \(user.uid)")
            } else {
                print("AppDelegate: No user signed in")
            }
        }
    }
    
    // MARK: - Firebase Messaging Setup
    
    private func setupMessaging(application: UIApplication) {
        print("AppDelegate: Setting up Firebase Messaging")
        
        // Set up Firebase Messaging
        Messaging.messaging().delegate = self
        
        // Set up notifications
        setupNotifications(application)
    }
    
    // MARK: - Integration Utilities Setup
    
    private func setupIntegrationUtilities() {
        // Initialize ErrorHandler (already a static utility)
        print("📱 AppDelegate: Initializing integration utilities")
        
        // Run initial data synchronization for current user if logged in
        if let currentUserId = Auth.auth().currentUser?.uid {
            print("📱 AppDelegate: Running initial data synchronization for user \(currentUserId)")
            Task {
                await DataSynchronizer.shared.runFullSynchronization(for: currentUserId)
            }
        }
        
        // Set up notification handlers for data synchronization events
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppForeground()
        }
    }
    
    private func handleAppForeground() {
        // When app comes to foreground, synchronize data for current user
        if let currentUserId = Auth.auth().currentUser?.uid {
            print("📱 AppDelegate: App entered foreground, synchronizing data for user \(currentUserId)")
            Task {
                await DataSynchronizer.shared.runFullSynchronization(for: currentUserId)
            }
        }
    }
} 