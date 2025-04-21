import Foundation
import SwiftUI
import Combine
import Firebase
import FirebaseFirestore
import FirebaseAuth
// Removed // Removed: import Unhinged.Utilities

/// View model for finding and displaying mutual availability between couples
class MutualAvailabilityViewModel: ObservableObject {
    /// The primary relationship ID
    @Published var relationshipID: String?
    
    /// The friend relationship ID
    @Published var friendRelationshipID: String?
    
    /// Available time slots
    @Published var availableTimeSlots: [TimeSlot] = []
    
    /// Selected time slot
    @Published var selectedTimeSlot: TimeSlot?
    
    /// Whether we're currently loading data
    @Published var isLoading = false
    
    /// Loading progress (0.0 to 1.0) if available
    @Published var loadingProgress: Double?
    
    /// Any error that occurred during operations
    @Published var error: Error?
    
    /// Start date for availability search
    @Published var startDate = Date()
    
    /// End date for availability search
    @Published var endDate: Date
    
    /// Duration in minutes
    @Published var duration = 120
    
    /// Whether a hangout was created
    @Published var hangoutCreated = false
    
    /// The created hangout ID
    @Published var createdHangoutID: String?
    
    /// Navigation state for coordination
    @Published var navigationState: MutualAvailabilityNavigationState = .findingTime
    
    /// Service for managing availability
    private let availabilityService = CoupleAvailabilityService.shared
    
    /// Relationship service
    private let relationshipService = RelationshipService.shared
    
    /// Hangout service
    private let hangoutService = HangoutsService.shared
    
    /// Calendar service
    private let calendarService: CalendarServiceAdapter
    
    /// Firestore listener for relationship1 availability
    private var relationship1Listener: ListenerRegistration?
    
    /// Firestore listener for relationship2 availability
    private var relationship2Listener: ListenerRegistration?
    
    /// Error types specific to mutual availability
    enum MutualAvailabilityError: LocalizedError {
        case noFriendCoupleSelected
        case noMutualAvailabilityFound
        case calendarPermissionRequired
        case searchRangeTooNarrow
        case internalError(String)
        case networkError
        
        var errorDescription: String? {
            switch self {
            case .noFriendCoupleSelected:
                return "Please select a friend couple first"
            case .noMutualAvailabilityFound:
                return "No mutual availability found. Try adjusting your date range or duration."
            case .calendarPermissionRequired:
                return "Calendar access is required to check availability. Please grant permission in Settings."
            case .searchRangeTooNarrow:
                return "Search range is too narrow. Try extending the date range or shortening the duration."
            case .internalError(let message):
                return "Internal error: \(message)"
            case .networkError:
                return "Network error. Please check your connection and try again."
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .noFriendCoupleSelected:
                return "Tap 'Select Friend Couple' to choose a couple to hang out with."
            case .noMutualAvailabilityFound:
                return "Consider different days, times, or shortening the duration."
            case .calendarPermissionRequired:
                return "You can either grant calendar access in Settings or use manual availability."
            case .searchRangeTooNarrow:
                return "Try a wider date range or shorter duration."
            case .internalError:
                return "Try again later or contact support if the issue persists."
            case .networkError:
                return "Check your internet connection and try again."
            }
        }
    }
    
    /// Navigation states for the mutual availability flow
    enum MutualAvailabilityNavigationState {
        case selectingFriend
        case findingTime
        case creatingHangout
        case hangoutDetails
    }
    
    /// Initialize with a relationship ID and optional friend relationship ID
    /// - Parameters:
    ///   - relationshipID: The primary relationship ID
    ///   - friendRelationshipID: The friend relationship ID (optional)
    init(relationshipID: String? = nil, friendRelationshipID: String? = nil) {
        // Set end date to 14 days from now
        let calendar = Calendar.current
        self.endDate = calendar.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        
        // Get CalendarServiceAdapter from ServiceManager
        self.calendarService = ServiceManager.shared.getService(CRUDService.self) as! CalendarServiceAdapter
        
        self.relationshipID = relationshipID
        self.friendRelationshipID = friendRelationshipID
        
        if let relationshipID = relationshipID {
            if friendRelationshipID == nil {
                loadCurrentUserRelationship()
            } else {
                setupRealTimeListeners()
            }
        } else {
            // Try to load current user's relationship
            loadCurrentUserRelationship()
        }
        
        // Set initial navigation state
        if self.friendRelationshipID == nil {
            self.navigationState = .selectingFriend
        } else {
            self.navigationState = .findingTime
        }
    }
    
    deinit {
        // Remove any active listeners when view model is deallocated
        relationship1Listener?.remove()
        relationship2Listener?.remove()
    }
    
    /// Load the current user's relationship
    /// - Note: This is called automatically during initialization
    func loadCurrentUserRelationship() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            do {
                let relationship = try await relationshipService.getCurrentUserRelationship()
                
                await MainActor.run {
                    self.relationshipID = relationship?.id ?? ""
                }
            } catch {
                print("Could not load current user relationship: \(error.localizedDescription)")
            }
        }
    }
    
    /// Set up real-time listeners for availability changes
    func setupRealTimeListeners() {
        guard let relationshipID = relationshipID, 
              let friendRelationshipID = friendRelationshipID else {
            return
        }
        
        // Remove any existing listeners
        relationship1Listener?.remove()
        relationship2Listener?.remove()
        
        // Set up listener for relationship1
        let query1 = Firestore.firestore().collection("coupleAvailability")
            .whereField("relationshipID", isEqualTo: relationshipID)
            .limit(to: 1)
        
        relationship1Listener = query1.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if error != nil || snapshot?.documentChanges.isEmpty == false {
                // Refresh availability data when changes occur
                self.findMutualAvailability()
            }
        }
        
        // Set up listener for relationship2
        let query2 = Firestore.firestore().collection("coupleAvailability")
            .whereField("relationshipID", isEqualTo: friendRelationshipID)
            .limit(to: 1)
        
        relationship2Listener = query2.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if error != nil || snapshot?.documentChanges.isEmpty == false {
                // Refresh availability data when changes occur
                self.findMutualAvailability()
            }
        }
    }
    
    /// Find mutual availability between current user's couple and friend couple
    func findMutualAvailability() {
        navigationState = .findingTime
        
        guard let relationshipID = relationshipID else {
            let error = MutualAvailabilityError.internalError("Missing relationship information")
            handleErrorWithCentralizedSystem(error)
            return
        }
        
        guard let friendRelationshipID = friendRelationshipID else {
            let error = MutualAvailabilityError.noFriendCoupleSelected
            handleErrorWithCentralizedSystem(error)
            return
        }
        
        // Validate date range
        if Calendar.current.startOfDay(for: endDate) <= Calendar.current.startOfDay(for: startDate) {
            let error = MutualAvailabilityError.searchRangeTooNarrow
            handleErrorWithCentralizedSystem(error)
            return
        }
        
        // Check if duration fits within a day
        if duration > 12 * 60 { // More than 12 hours
            let error = MutualAvailabilityError.searchRangeTooNarrow
            handleErrorWithCentralizedSystem(error)
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let timeSlots = try await availabilityService.findMutualAvailability(
                    relationship1ID: relationshipID,
                    relationship2ID: friendRelationshipID,
                    startDate: startDate,
                    endDate: endDate,
                    duration: duration
                )
                
                await MainActor.run {
                    self.availableTimeSlots = timeSlots
                    self.isLoading = false
                    
                    // Setup real-time listeners if they aren't already set up
                    if self.relationship1Listener == nil || self.relationship2Listener == nil {
                        self.setupRealTimeListeners()
                    }
                }
            } catch {
                await MainActor.run {
                    self.handleAvailabilityError(error)
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Handle errors using the centralized error handling system
    private func handleErrorWithCentralizedSystem(_ error: Error) {
        if let mutualError = error as? MutualAvailabilityError {
            // Convert MutualAvailabilityError to centralized AvailabilityError
            let appError = AvailabilityError(legacyError: mutualError)
            ErrorHandler.shared.showError(appError)
            self.error = mutualError
        } else if let availabilityError = error as? AvailabilityError {
            // Use existing AvailabilityError directly
            ErrorHandler.shared.showError(availabilityError)
            // Also update local error property with equivalent MutualAvailabilityError
            switch availabilityError.errorType {
            case .noMutualAvailabilityFound:
                self.error = MutualAvailabilityError.noMutualAvailabilityFound
            case .calendarPermissionRequired:
                self.error = MutualAvailabilityError.calendarPermissionRequired
            case .searchRangeTooNarrow:
                self.error = MutualAvailabilityError.searchRangeTooNarrow
            case .networkError:
                self.error = MutualAvailabilityError.networkError
            case .internalError(let message):
                self.error = MutualAvailabilityError.internalError(message)
            default:
                self.error = MutualAvailabilityError.internalError(availabilityError.localizedDescription)
            }
        } else {
            // For other errors, use centralized error handler but maintain local error property
            ErrorHandler.shared.handle(error)
            self.error = MutualAvailabilityError.internalError(error.localizedDescription)
        }
    }
    
    /// Handle errors from the availability service
    private func handleAvailabilityError(_ error: Error) {
        if let availabilityError = error as? AvailabilityError {
            switch availabilityError {
            case .invalidTimeRange, .invalidDuration:
                let appError = AvailabilityError(errorType: .searchRangeTooNarrow, underlyingError: error)
                ErrorHandler.shared.showError(appError)
                self.error = MutualAvailabilityError.searchRangeTooNarrow
            case .calendarSyncFailed:
                let appError = AvailabilityError(errorType: .calendarPermissionRequired, underlyingError: error)
                ErrorHandler.shared.showError(appError)
                self.error = MutualAvailabilityError.calendarPermissionRequired
            case .relationshipNotFound:
                let appError = AvailabilityError(errorType: .internalError("Relationship not found"), underlyingError: error)
                ErrorHandler.shared.showError(appError)
                self.error = MutualAvailabilityError.internalError("Relationship not found")
            case .preferenceConflict, .unavailableTimePeriod:
                let appError = AvailabilityError(errorType: .noMutualAvailabilityFound, underlyingError: error)
                ErrorHandler.shared.showError(appError)
                self.error = MutualAvailabilityError.noMutualAvailabilityFound
            case .networkTimeout:
                let appError = AvailabilityError(errorType: .networkError, underlyingError: error)
                ErrorHandler.shared.showError(appError)
                self.error = MutualAvailabilityError.networkError
            default:
                let appError = AvailabilityError(errorType: .internalError(availabilityError.localizedDescription), underlyingError: error)
                ErrorHandler.shared.showError(appError)
                self.error = MutualAvailabilityError.internalError(availabilityError.localizedDescription)
            }
        } else if let mutualError = error as? MutualAvailabilityError {
            // Use the centralized error system but also update the local error property
            let appError = AvailabilityError(legacyError: mutualError)
            ErrorHandler.shared.showError(appError)
            self.error = mutualError
        } else {
            // For unknown errors, show a generic error in the centralized system
            ErrorHandler.shared.handle(error)
            self.error = MutualAvailabilityError.internalError(error.localizedDescription)
        }
    }
    
    /// Select a time slot
    /// - Parameter timeSlot: The time slot to select
    func selectTimeSlot(_ timeSlot: TimeSlot) {
        self.selectedTimeSlot = timeSlot
    }
    
    /// Clear the selected time slot
    func clearSelectedTimeSlot() {
        self.selectedTimeSlot = nil
    }
    
    /// Begin the create hangout flow
    func beginCreateHangout() {
        if selectedTimeSlot != nil && friendRelationshipID != nil {
            navigationState = .creatingHangout
        }
    }
    
    /// Navigate to hangout details
    func navigateToHangoutDetails() {
        if createdHangoutID != nil {
            navigationState = .hangoutDetails
        }
    }
    
    /// Reset to find time state
    func resetToFindTime() {
        hangoutCreated = false
        availableTimeSlots = []
        selectedTimeSlot = nil
        createdHangoutID = nil
        navigationState = .findingTime
    }
    
    /// Get time slots grouped by day
    /// - Returns: Dictionary of time slots grouped by day
    func getTimeSlotsGroupedByDay() -> [String: [TimeSlot]] {
        let calendar = Calendar.current
        var groupedSlots: [String: [TimeSlot]] = [:]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMM d"
        
        for slot in availableTimeSlots {
            let day = dateFormatter.string(from: slot.startTime)
            if groupedSlots[day] == nil {
                groupedSlots[day] = []
            }
            groupedSlots[day]?.append(slot)
        }
        
        // Sort time slots within each day
        for (day, slots) in groupedSlots {
            groupedSlots[day] = slots.sorted { $0.startTime < $1.startTime }
        }
        
        return groupedSlots
    }
    
    /// Get sorted days for displaying grouped time slots
    /// - Returns: Array of days in chronological order
    func getSortedDays() -> [String] {
        let groupedSlots = getTimeSlotsGroupedByDay()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMM d"
        
        return groupedSlots.keys.sorted { day1, day2 in
            if let date1 = dateFormatter.date(from: day1),
               let date2 = dateFormatter.date(from: day2) {
                return date1 < date2
            }
            return day1 < day2
        }
    }
    
    /// Add this helper method for getting personas
    private func getPersonasForUser(userId: String) async throws -> [Persona] {
        // Create a reference to the personas collection for the user
        let personasRef = Firestore.firestore().collection("users").document(userId).collection("personas")
        
        // Get the personas
        let snapshot = try await personasRef.getDocuments()
        
        // Convert to Persona objects
        return snapshot.documents.compactMap { document in
            try? document.data(as: Persona.self)
        }
    }
    
    /// Method to create a hangout
    func createHangout(title: String, description: String, location: String?, hangoutType: HangoutType) {
        guard let selectedSlot = selectedTimeSlot,
              let friendRelationshipID = friendRelationshipID else {
            let error = MutualAvailabilityError.internalError("Missing required information")
            handleErrorWithCentralizedSystem(error)
            return
        }
        
        isLoading = true
        navigationState = .creatingHangout
        
        Task {
            do {
                guard let userId = Auth.auth().currentUser?.uid else {
                    throw NSError(domain: "MutualAvailabilityViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
                }
                
                // Get current relationship info
                guard let relationship = try await relationshipService.getCurrentUserRelationship() else {
                    throw NSError(domain: "MutualAvailabilityViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not load current user relationship"])
                }
                
                // Get friend relationship
                let friendRelationship = try await relationshipService.getRelationship(id: friendRelationshipID)
                
                // Get a valid persona ID from the current user
                let personas = try await getPersonasForUser(userId: userId)
                let creatorPersonaID = personas.first?.id ?? ""
                
                // Get a valid persona ID for the invitee
                let inviteeID = friendRelationship.initiatorID.isEmpty ? friendRelationship.partnerID : friendRelationship.initiatorID
                let inviteePersonas = try await getPersonasForUser(userId: inviteeID)
                let inviteePersonaID = inviteePersonas.first?.id ?? ""
                
                // Create a hangout object using the constructor matching the Hangout model
                let hangout = Hangout(
                    title: title,
                    description: description,
                    startDate: selectedSlot.startTime,
                    endDate: selectedSlot.endTime,
                    location: location,
                    creatorID: userId,
                    creatorPersonaID: creatorPersonaID,
                    inviteeID: inviteeID,
                    inviteePersonaID: inviteePersonaID
                )
                
                // Create the hangout using HangoutsService
                let hangoutId = try await hangoutService.createHangout(hangout)
                
                // Create calendar events for all participants
                do {
                    let calendarEvent = CalendarEventModel(
                        id: UUID().uuidString,
                        title: title,
                        description: description,
                        startDate: selectedSlot.startTime,
                        endDate: selectedSlot.endTime,
                        location: location,
                        provider: .google
                    )
                    
                    // Create calendar event using our adapter - it will handle creating events across all providers
                    try? await calendarService.create(calendarEvent)
                } catch {
                    print("Error with calendar: \(error.localizedDescription)")
                    // Continue even if calendar integration fails
                }
                
                await MainActor.run {
                    self.createdHangoutID = hangoutId
                    self.hangoutCreated = true
                    self.isLoading = false
                    self.navigationState = .hangoutDetails
                    
                    // Post notification that a hangout was created
                    NotificationCenter.default.post(
                        name: .hangoutCreated,
                        object: nil,
                        userInfo: ["hangoutID": hangoutId]
                    )
                }
            } catch {
                await MainActor.run {
                    self.handleErrorWithCentralizedSystem(error)
                    self.isLoading = false
                    self.navigationState = .findingTime
                }
            }
        }
    }
    
    /// Suggest alternative times when no mutual availability is found
    func suggestAlternativeTimes() {
        guard let relationshipID = relationshipID, let friendRelationshipID = friendRelationshipID else {
            let error = MutualAvailabilityError.internalError("Missing relationship information")
            handleErrorWithCentralizedSystem(error)
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let alternativeSlots = try await availabilityService.suggestAlternativeTimeSlots(
                    relationship1ID: relationshipID,
                    relationship2ID: friendRelationshipID,
                    startDate: startDate,
                    endDate: endDate,
                    duration: duration
                )
                
                await MainActor.run {
                    if alternativeSlots.isEmpty {
                        let error = MutualAvailabilityError.noMutualAvailabilityFound
                        handleErrorWithCentralizedSystem(error)
                    } else {
                        self.availableTimeSlots = alternativeSlots
                        self.error = nil
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.handleAvailabilityError(error)
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Handle a calendar permission error by suggesting alternatives
    func handleCalendarPermissionError() {
        // Clear the error
        self.error = nil
        
        // No need to show loading state here
        self.isLoading = true
        
        // Attempt to find availability without using calendars
        Task {
            do {
                guard let relationshipID = relationshipID, let friendRelationshipID = friendRelationshipID else {
                    await MainActor.run {
                        let error = MutualAvailabilityError.internalError("Missing relationship information")
                        handleErrorWithCentralizedSystem(error)
                        self.isLoading = false
                    }
                    return
                }
                
                // Get availability for both relationships
                var avail1 = try await availabilityService.getAvailability(relationshipID: relationshipID) 
                    ?? CoupleAvailability(relationshipID: relationshipID)
                var avail2 = try await availabilityService.getAvailability(relationshipID: friendRelationshipID)
                    ?? CoupleAvailability(relationshipID: friendRelationshipID)
                
                // Temporarily disable calendar usage
                avail1.useCalendars = false
                avail2.useCalendars = false
                
                // Save the modified preferences
                let _ = try await availabilityService.saveAvailability(avail1)
                let _ = try await availabilityService.saveAvailability(avail2)
                
                // Now try to find availability without calendars
                let timeSlots = try await availabilityService.findMutualAvailability(
                    relationship1ID: relationshipID,
                    relationship2ID: friendRelationshipID,
                    startDate: startDate,
                    endDate: endDate,
                    duration: duration
                )
                
                await MainActor.run {
                    self.availableTimeSlots = timeSlots
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.handleAvailabilityError(error)
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Update the selected friend relationship ID
    /// - Parameter relationshipID: The friend relationship ID
    func updateFriendRelationshipID(_ relationshipID: String) {
        self.friendRelationshipID = relationshipID
        
        // Remove existing listeners and set up new ones
        relationship1Listener?.remove()
        relationship2Listener?.remove()
        relationship1Listener = nil
        relationship2Listener = nil
        
        // Search for mutual availability with the new friend
        findMutualAvailability()
    }
} 