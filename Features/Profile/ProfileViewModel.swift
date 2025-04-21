import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Foundation
import FirebaseMessaging
import Speech
import AVFoundation
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // User data
    @Published var user: UserData?
    @Published var personas: [Persona] = []
    
    // UI state
    @Published var isLoading = false
    @Published var error: Error?
    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var bio: String = ""
    @Published var alertItem: AlertItem?
    
    @Published var isVoiceCommandActive = false
    @Published var lastVoiceCommand: String?
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    // MARK: - Private Properties
    
    private let firestoreService = FirestoreService()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    // Services
    private let authService = AuthenticationService.shared
    private let userService = UserService.shared
    private let calendarService: CalendarOperationsService
    
    // MARK: - Initialization
    
    init() {
        // Get CalendarOperationsService from ServiceManager
        self.calendarService = ServiceManager.shared.getService(CalendarOperationsService.self)
        
        setupBindings()
        loadUserData()
    }
    
    // MARK: - Public Methods
    
    /// Load user data from Firebase
    func loadUserData() {
        guard let currentUser = Auth.auth().currentUser else {
            alertItem = AlertItem(title: "Error", message: "No user logged in")
            return
        }
        
        isLoading = true
        
        // Create basic user object from Auth
        user = UserData(
            id: currentUser.uid,
            displayName: currentUser.displayName ?? "User",
            email: currentUser.email ?? "",
            photoURL: currentUser.photoURL?.absoluteString
        )
        
        // Get additional data from Firestore
        db.collection("users").document(currentUser.uid).getDocument { [weak self] snapshot, error in
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
                
                // Update user with Firestore data
                self.user?.bio = data["bio"] as? String
                self.user?.isPremium = data["isPremium"] as? Bool ?? false
                
                // Load preferences
                if let prefsData = data["preferences"] as? [String: Any] {
                    var prefs = UserPreferences()
                    prefs.emailNotifications = prefsData["emailNotifications"] as? Bool ?? true
                    prefs.pushNotifications = prefsData["pushNotifications"] as? Bool ?? true
                    prefs.inAppNotifications = prefsData["inAppNotifications"] as? Bool ?? true
                    prefs.theme = prefsData["theme"] as? String ?? "system"
                    prefs.language = prefsData["language"] as? String ?? "en"
                    
                    self.user?.preferences = prefs
                }
            }
        }
        
        // Load personas
        loadPersonas()
    }
    
    /// Load user personas from Firestore
    func loadPersonas() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        print("DEBUG: ProfileViewModel - Starting loadPersonas() for user \(userId)")
        isLoading = true
        personas = [] // Clear current personas while loading
        
        // Force UI update immediately to show loading state
        Task { @MainActor in
            do {
                // First ensure the user document exists
                let _ = await ensureUserDocumentExists()
                
                print("DEBUG: ProfileViewModel - Calling firestoreService.getPersonas()")
                let fetchedPersonas = try await firestoreService.getPersonas(for: userId)
                
                print("DEBUG: ProfileViewModel - Got \(fetchedPersonas.count) personas from Firestore")
                self.personas = fetchedPersonas
                self.isLoading = false
                print("DEBUG: ProfileViewModel - UI updated with \(self.personas.count) personas")
                
                // Debug dump the actual personas
                for persona in fetchedPersonas {
                    print("DEBUG: Loaded persona: \(persona.name) (ID: \(persona.id ?? "nil"), Default: \(persona.isDefault))")
                }
            } catch {
                print("DEBUG: ProfileViewModel - Error loading personas: \(error.localizedDescription)")
                self.error = error
                self.isLoading = false
                print("DEBUG: ProfileViewModel - Updated error state")
            }
        }
    }
    
    /// Sign the user out
    func signOut(completion: @escaping (Bool) -> Void) {
        do {
            try Auth.auth().signOut()
            self.user = nil
            completion(true)
        } catch {
            alertItem = AlertItem(title: "Error", message: "Failed to sign out: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    /// Show an alert to the user
    func showAlert(title: String, message: String) {
        alertItem = AlertItem(title: title, message: message)
    }
    
    // Add a new method to ensure user document exists
    func ensureUserDocumentExists() async -> Bool {
        guard let user = Auth.auth().currentUser else {
            print("DEBUG: Cannot create user document - No user logged in")
            return false
        }
        
        print("DEBUG: Ensuring user document exists for \(user.uid)")
        
        do {
            // Check if user document exists
            let db = Firestore.firestore()
            let docRef = db.collection("users").document(user.uid)
            let doc = try await docRef.getDocument()
            
            if !doc.exists {
                print("DEBUG: User document doesn't exist - creating it now")
                
                // Create basic user document
                let userData: [String: Any] = [
                    "displayName": user.displayName ?? "User",
                    "email": user.email ?? "",
                    "photoURL": user.photoURL?.absoluteString ?? "",
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                
                try await docRef.setData(userData)
                print("DEBUG: Created user document for \(user.uid)")
                
                // Create initial persona subcollection
                if try await firestoreService.getPersonas(for: user.uid).isEmpty {
                    print("DEBUG: No personas exist - creating default persona")
                    
                    let defaultPersona = Persona(
                        id: nil,
                        name: "Default Persona",
                        bio: "My primary persona",
                        imageURL: nil,
                        isDefault: true,
                        userID: user.uid
                    )
                    
                    let personaId = try await firestoreService.createPersona(defaultPersona, for: user.uid)
                    print("DEBUG: Created default persona with ID: \(personaId)")
                }
                
                return true
            } else {
                print("DEBUG: User document already exists")
                return true
            }
        } catch {
            print("DEBUG: Error checking/creating user document: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
            }
            return false
        }
    }
    
    func deletePersona(_ personaId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Check if it's the default persona and if there are others
            if let persona = personas.first(where: { $0.id == personaId }),
               persona.isDefault && personas.count > 1 {
                
                // Find another persona to make default
                if let newDefault = personas.first(where: { $0.id != personaId }) {
                    var updatedPersona = newDefault
                    updatedPersona.isDefault = true
                    try await firestoreService.updatePersona(updatedPersona, for: userId)
                }
            }
            
            try await firestoreService.deletePersona(personaId)
            
            DispatchQueue.main.async {
                self.loadPersonas()
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
        }
    }
    
    func setAsDefault(_ persona: Persona) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        print("DEBUG: Setting persona as default: \(persona.name)")
        
        do {
            // If this is a new persona without an ID, create it first
            var updatedPersona = persona
            if persona.id == nil {
                print("DEBUG: This is a new persona, creating it first")
                let newId = try await firestoreService.createPersona(persona, for: userId)
                updatedPersona.id = newId
                print("DEBUG: Created new persona with ID: \(newId)")
            }
            
            // First, update the current default
            let currentDefault = personas.first(where: { $0.isDefault && $0.id != updatedPersona.id })
            if let current = currentDefault, let _ = current.id {
                print("DEBUG: Unsetting current default: \(current.name)")
                var updatedCurrent = current
                updatedCurrent.isDefault = false
                try await firestoreService.updatePersona(updatedCurrent, for: userId)
            }
            
            // Set the new default
            updatedPersona.isDefault = true
            print("DEBUG: Updating persona to be default: \(updatedPersona.name)")
            if let _ = updatedPersona.id {
                try await firestoreService.updatePersona(updatedPersona, for: userId)
                print("DEBUG: Successfully updated persona as default")
            }
            
            // Refresh the personas list
            await MainActor.run {
                print("DEBUG: Refreshing personas list after setting default")
                self.loadPersonas()
            }
        } catch {
            print("DEBUG: Error setting default persona: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    func updateProfile(name: String, email: String, bio: String) async {
        guard let user = Auth.auth().currentUser else { return }
        
        isLoading = true
        
        do {
            // Update Firebase Auth profile
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
            
            // Update Firestore user document
            var userData: [String: Any] = [
                "displayName": name,
                "bio": bio,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            if email != user.email {
                // Use the new recommended method instead of updateEmail
                try await user.sendEmailVerification(beforeUpdatingEmail: email)
                userData["email"] = email
            }
            
            // Get current FCM token and add to update if available
            if let fcmToken = Messaging.messaging().fcmToken {
                userData["fcmToken"] = fcmToken
                print("DEBUG: Including FCM token in profile update: \(fcmToken)")
            }
            
            let db = Firestore.firestore()
            try await db.collection("users").document(user.uid).updateData(userData)
            
            DispatchQueue.main.async {
                self.displayName = name
                self.email = email
                self.bio = bio
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    // Add a test feature function for development purposes
    func testFeature() {
        print("DEBUG: Voice-to-text calendar feature triggered")
        
        // Create SpeechRecognizer instance when necessary
        if speechRecognizer == nil {
            setupSpeechRecognition()
        }
        
        // If we're already recording, stop it
        if audioEngine?.isRunning ?? false {
            stopRecording()
            return
        }
        
        // Otherwise, start recording
        startRecording()
    }
    
    // MARK: - Speech Recognition
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    private func setupSpeechRecognition() {
        // Request authorization first
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("DEBUG: Speech recognition authorized")
                    self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
                    self.audioEngine = AVAudioEngine()
                    
                    // Show alert confirming we're ready to record
                    self.showAlert(
                        title: "Ready to Record",
                        message: "Tap the button again to start recording your meeting request. Say something like 'Set up a meeting with Sam on Tuesday at 10am'"
                    )
                case .denied:
                    self.showAlert(
                        title: "Speech Recognition Denied",
                        message: "To use voice commands, please enable Speech Recognition in Settings."
                    )
                case .restricted, .notDetermined:
                    self.showAlert(
                        title: "Speech Recognition Not Available",
                        message: "Speech recognition is not available on this device at this time."
                    )
                @unknown default:
                    self.showAlert(
                        title: "Speech Recognition Error",
                        message: "An unknown error occurred with speech recognition."
                    )
                }
            }
        }
    }
    
    private func startRecording() {
        // Clear any previous tasks
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Set up audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("DEBUG: Failed to set up audio session: \(error.localizedDescription)")
            showAlert(
                title: "Audio Error",
                message: "Could not set up audio recording. Please try again."
            )
            return
        }
        
        // Set up recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest,
              let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            showAlert(
                title: "Speech Recognition Unavailable",
                message: "Speech recognition is not available right now. Please try again later."
            )
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recording
        inputNode = audioEngine?.inputNode
        
        guard let inputNode = inputNode,
              let audioEngine = audioEngine else {
            showAlert(
                title: "Audio Error",
                message: "Could not access microphone. Please check your settings."
            )
            return
        }
        
        // Show alert that recording has started
        showAlert(
            title: "Recording...",
            message: "Speak your request now. For example: 'Set up a meeting with Sam on Tuesday at 10am'"
        )
        
        // Install tap on input node
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("DEBUG: Failed to start audio engine: \(error.localizedDescription)")
            showAlert(
                title: "Audio Error", 
                message: "Could not start recording. Please try again."
            )
            return
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                isFinal = result.isFinal
                print("DEBUG: Speech recognized: \(result.bestTranscription.formattedString)")
                
                if isFinal {
                    // Process the final speech result
                    let speechText = result.bestTranscription.formattedString
                    self.processVoiceCommand(speechText)
                }
            }
            
            if error != nil || isFinal {
                // Stop recording
                self.stopRecording()
            }
        }
    }
    
    private func stopRecording() {
        // Stop audio engine and remove tap
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        
        // End recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("DEBUG: Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
    
    private func processVoiceCommand(_ command: String) {
        print("DEBUG: Processing voice command: \(command)")
        
        // Show alert with recognized command
        showAlert(
            title: "Recognized Command",
            message: command
        )
        
        // Simple parsing logic for now
        // Look for patterns like "meeting with [name] on [day] at [time]"
        var attendee: String?
        var day: String?
        var time: String?
        var duration: TimeInterval = 3600 // Default 1 hour
        
        // Extract attendee
        if command.contains("with") {
            let components = command.components(separatedBy: "with")
            if components.count >= 2 {
                let afterWith = components[1]
                if let endRange = afterWith.range(of: " on ") ?? afterWith.range(of: " at ") {
                    attendee = String(afterWith[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        // Extract day
        if command.contains("on") {
            let components = command.components(separatedBy: "on")
            if components.count >= 2 {
                let afterOn = components[1]
                if let endRange = afterOn.range(of: " at ") {
                    day = String(afterOn[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        // Extract time
        if command.contains("at") {
            let components = command.components(separatedBy: "at")
            if components.count >= 2 {
                let afterAt = components[1]
                // Extract everything up to the next keyword or end of string
                if let endRange = afterAt.range(of: " for ") {
                    time = String(afterAt[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    time = afterAt.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        // Extract duration if specified
        if command.contains("for") {
            let components = command.components(separatedBy: "for")
            if components.count >= 2 {
                let afterFor = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if afterFor.contains("hour") {
                    if let hourString = afterFor.components(separatedBy: " ").first,
                       let hours = Double(hourString) {
                        duration = hours * 3600
                    } else {
                        duration = 3600 // 1 hour default
                    }
                } else if afterFor.contains("minute") {
                    if let minuteString = afterFor.components(separatedBy: " ").first,
                       let minutes = Double(minuteString) {
                        duration = minutes * 60
                    } else {
                        duration = 1800 // 30 minutes default
                    }
                }
            }
        }
        
        // Create calendar event if we have enough info
        if let day = day, let time = time {
            createCalendarEventFromVoice(
                title: "Meeting" + (attendee != nil ? " with \(attendee!)" : ""),
                attendeeEmail: parseEmailFromName(attendee),
                day: day,
                time: time,
                durationSeconds: duration
            )
        } else {
            showAlert(
                title: "Missing Information",
                message: "Please specify a day and time for the meeting."
            )
        }
    }
    
    private func parseEmailFromName(_ name: String?) -> String? {
        // Hardcoded email mapping for specific users
        guard let name = name?.lowercased() else { return nil }
        
        // Very simple name matching
        if name.contains("sam") {
            return "samcrocker09@gmail.com"
        } else if name.contains("kendall") {
            return "kendall.m.crocker@gmail.com"
        }
        
        return nil
    }
    
    private func createCalendarEventFromVoice(title: String, attendeeEmail: String?, day: String, time: String, durationSeconds: TimeInterval) {
        // Convert day and time to Date objects
        guard let eventDate = parseDateTime(day: day, time: time) else {
            showAlert(
                title: "Date Error",
                message: "Could not understand the date and time. Please try again with a clearer date format."
            )
            return
        }
        
        let endDate = eventDate.addingTimeInterval(durationSeconds)
        
        print("DEBUG: Creating calendar event: \(title) on \(eventDate) to \(endDate)")
        
        // Use CalendarService to create the event
        Task {
            do {
                guard let userId = Auth.auth().currentUser?.uid else {
                    await MainActor.run {
                        showAlert(
                            title: "Error",
                            message: "You must be logged in to create calendar events."
                        )
                    }
                    return
                }
                
                // Use CalendarAuthService instead of legacyCalendarService
                let calendarAuth = CalendarAuthService.shared
                let calendarToken = try await calendarAuth.getCalendarToken(for: userId)
                
                // Create attendees array if we have an email
                var attendees: [String]? = nil
                if let email = attendeeEmail {
                    attendees = [email]
                }
                
                // Create the calendar event using our adapter
                let calendarEvent = CalendarEventModel(
                    title: title,
                    description: "Created via voice command",
                    startDate: eventDate,
                    endDate: endDate,
                    location: nil,
                    provider: .google
                )
                
                // Use our adapter to create the event
                let eventId = try await calendarService.create(calendarEvent)
                
                await MainActor.run {
                    showAlert(
                        title: "Calendar Event Created",
                        message: "Your meeting has been scheduled for \(formatDate(eventDate))."
                    )
                }
            } catch {
                print("DEBUG: Error creating calendar event: \(error.localizedDescription)")
                await MainActor.run {
                    showAlert(
                        title: "Calendar Error",
                        message: "Could not create calendar event: \(error.localizedDescription)"
                    )
                }
            }
        }
    }
    
    private func parseDateTime(day: String, time: String) -> Date? {
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.timeZone = TimeZone.current
        
        // Parse day
        let lowercaseDay = day.lowercased()
        let today = calendar.startOfDay(for: Date())
        
        if lowercaseDay.contains("today") {
            dateComponents.year = calendar.component(.year, from: today)
            dateComponents.month = calendar.component(.month, from: today)
            dateComponents.day = calendar.component(.day, from: today)
        } else if lowercaseDay.contains("tomorrow") {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
            dateComponents.year = calendar.component(.year, from: tomorrow)
            dateComponents.month = calendar.component(.month, from: tomorrow)
            dateComponents.day = calendar.component(.day, from: tomorrow)
        } else if lowercaseDay.contains("monday") || lowercaseDay.contains("mon") {
            dateComponents = nextWeekday(1)
        } else if lowercaseDay.contains("tuesday") || lowercaseDay.contains("tue") {
            dateComponents = nextWeekday(2)
        } else if lowercaseDay.contains("wednesday") || lowercaseDay.contains("wed") {
            dateComponents = nextWeekday(3)
        } else if lowercaseDay.contains("thursday") || lowercaseDay.contains("thu") {
            dateComponents = nextWeekday(4)
        } else if lowercaseDay.contains("friday") || lowercaseDay.contains("fri") {
            dateComponents = nextWeekday(5)
        } else if lowercaseDay.contains("saturday") || lowercaseDay.contains("sat") {
            dateComponents = nextWeekday(6)
        } else if lowercaseDay.contains("sunday") || lowercaseDay.contains("sun") {
            dateComponents = nextWeekday(7)
        } else {
            // Could not parse day
            return nil
        }
        
        // Parse time
        let lowercaseTime = time.lowercased()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        
        // Try various time formats
        if let timeDate = timeFormatter.date(from: lowercaseTime) {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute
        } else if lowercaseTime.contains("morning") {
            dateComponents.hour = 9
            dateComponents.minute = 0
        } else if lowercaseTime.contains("noon") {
            dateComponents.hour = 12
            dateComponents.minute = 0
        } else if lowercaseTime.contains("afternoon") {
            dateComponents.hour = 14
            dateComponents.minute = 0
        } else if lowercaseTime.contains("evening") {
            dateComponents.hour = 18
            dateComponents.minute = 0
        } else {
            // Try to extract hour from simple patterns like "10am" or "3pm"
            var hour: Int? = nil
            var isAM = true
            
            if lowercaseTime.contains("am") {
                isAM = true
                if let timeString = lowercaseTime.components(separatedBy: "am").first?.trimmingCharacters(in: .whitespaces),
                   let timeInt = Int(timeString) {
                    hour = timeInt
                }
            } else if lowercaseTime.contains("pm") {
                isAM = false
                if let timeString = lowercaseTime.components(separatedBy: "pm").first?.trimmingCharacters(in: .whitespaces),
                   let timeInt = Int(timeString) {
                    hour = timeInt
                }
            } else if let timeInt = Int(lowercaseTime.trimmingCharacters(in: .whitespaces)) {
                // Just a number, assume working hours (8am-6pm)
                if timeInt >= 1 && timeInt <= 6 {
                    hour = timeInt
                    isAM = false  // Assume afternoon for 1-6 without am/pm
                } else {
                    hour = timeInt
                    isAM = true   // Assume morning for other times
                }
            }
            
            if let hour = hour {
                // Convert to 24-hour format if PM
                dateComponents.hour = isAM ? hour : (hour == 12 ? 12 : hour + 12)
                dateComponents.minute = 0
            } else {
                // Could not parse time
                return nil
            }
        }
        
        return calendar.date(from: dateComponents)
    }
    
    private func nextWeekday(_ weekday: Int) -> DateComponents {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = calendar.component(.weekday, from: today)
        
        // Calculate days to add
        let daysToAdd = (weekday - todayWeekday + 7) % 7
        // If today is the target weekday, add 7 days to get next week's
        let daysToAddAdjusted = daysToAdd == 0 ? 7 : daysToAdd
        
        // Get the next occurrence of the weekday
        let nextWeekday = calendar.date(byAdding: .day, value: daysToAddAdjusted, to: today)!
        
        // Extract components
        var components = DateComponents()
        components.year = calendar.component(.year, from: nextWeekday)
        components.month = calendar.component(.month, from: nextWeekday)
        components.day = calendar.component(.day, from: nextWeekday)
        
        return components
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Helper Models

struct UserData {
    var id: String
    var displayName: String
    var email: String
    var photoURL: String?
    var bio: String?
    var isPremium: Bool = false
    var preferences: UserPreferences = UserPreferences()
}

struct UserPreferences: Codable {
    var emailNotifications: Bool = true
    var pushNotifications: Bool = true
    var inAppNotifications: Bool = true
    var theme: String = "system"
    var language: String = "en"
} 