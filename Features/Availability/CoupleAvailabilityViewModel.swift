import Foundation
import SwiftUI
import Combine
import Firebase
import FirebaseAuth
import FirebaseFirestore

/// View model for managing couple availability preferences with real-time updates
class CoupleAvailabilityViewModel: ObservableObject {
    /// The relationship ID
    private var relationshipID: String?
    
    /// Partner user data
    @Published var partner: AppUser?
    
    /// Couple availability preferences
    @Published var coupleAvailability: CoupleAvailability?
    
    /// Available time slots for the current date range
    @Published var availableSlots: [Date: [AvailabilityTimeSlot]] = [:]
    
    /// Currently selected date
    @Published var selectedDate: Date = Date()
    
    /// Whether we're currently loading data
    @Published var isLoading = false
    
    /// Whether we're currently saving data
    @Published var isSaving = false
    
    /// Any error that occurred during operations
    @Published var error: Error?
    
    /// Whether the time range editor is in add mode
    @Published var isAddingTimeRange = false
    
    /// The time range being edited
    @Published var editingTimeRange: TimeRange?
    
    /// The selected day for editing
    @Published var selectedDay: Unhinged.Weekday = .monday
    
    /// The recurring commitment being edited
    @Published var editingCommitment: RecurringCommitment?
    
    /// Whether the commitment editor is in add mode
    @Published var isAddingCommitment = false
    
    /// Whether the commitment editor is in delete mode
    @Published var isDeletingCommitment = false
    
    /// Service for managing availability
    private let availabilityService = CoupleAvailabilityService.shared
    
    /// Calendar service for accessing calendar functionality
    private let calendarService: CalendarOperationsService
    
    /// Firestore listener for real-time updates
    private var availabilityListener: ListenerRegistration?
    
    /// Relationship service
    private let relationshipService = RelationshipService.shared
    
    /// User service
    private let userService = UserService.shared
    
    /// Calendar data fetch service
    private let calendarDataFetchService = CalendarDataFetchService.shared
    
    /// Initialize with an optional relationship ID
    /// - Parameter relationshipID: The relationship ID
    init(relationshipID: String? = nil) {
        self.relationshipID = relationshipID
        
        // Get the CalendarService from ServiceManager
        self.calendarService = ServiceManager.shared.getService(CalendarOperationsService.self)
        
        setupListeners()
    }
    
    deinit {
        // Remove Firestore listener when view model is deallocated
        availabilityListener?.remove()
    }
    
    /// Load availability with completion handler for UI updates
    func loadAvailability(completion: (() -> Void)? = nil) {
        if relationshipID == nil {
            Task {
                await loadCurrentUserRelationship()
                completion?()
            }
        } else {
            setupAvailabilityListener()
            fetchPartnerInfo()
            fetchMutualAvailability()
            completion?()
        }
    }
    
    /// Load the current user's relationship
    private func loadCurrentUserRelationship() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let relationship = try await relationshipService.getCurrentUserRelationship()
            
            await MainActor.run {
                self.relationshipID = relationship?.id
                if let relationshipID = self.relationshipID {
                    self.setupAvailabilityListener()
                    self.fetchPartnerInfo()
                    self.fetchMutualAvailability()
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            print("Could not load current user relationship: \(error.localizedDescription)")
        }
    }
    
    /// Fetch partner's user info
    private func fetchPartnerInfo() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            do {
                // Get relationship data
                let relationshipID = self.relationshipID ?? ""
                guard let relationshipData = try? await relationshipService.getRelationship(id: relationshipID) else {
                    print("Relationship not found")
                    return
                }
                
                // Get partner ID (the one that's not the current user)
                let partnerId = relationshipData.initiatorID == userId ? relationshipData.partnerID : relationshipData.initiatorID
                
                // Get partner user data
                if let partnerData = try await userService.getUser(id: partnerId) {
                    await MainActor.run {
                        self.partner = partnerData
                    }
                }
            } catch {
                print("Error fetching partner info: \(error.localizedDescription)")
            }
        }
    }
    
    /// Set up real-time listener for couple availability
    private func setupAvailabilityListener() {
        guard let relationshipID = relationshipID else {
            error = AvailabilityError.relationshipNotFound
            return
        }
        
        isLoading = true
        
        // Remove any existing listener
        availabilityListener?.remove()
        
        // Create a query for the availability document
        let query = Firestore.firestore().collection("coupleAvailability")
            .whereField("relationshipID", isEqualTo: relationshipID)
            .limit(to: 1)
        
        // Set up real-time listener
        availabilityListener = query.addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleError(error)
                return
            }
            
            guard let snapshot = querySnapshot else {
                self.isLoading = false
                return
            }
            
            if let document = snapshot.documents.first,
               let availability = CoupleAvailability.fromFirestore(document) {
                self.coupleAvailability = availability
                self.isLoading = false
                
                // Update mutual availability based on new settings
                self.fetchMutualAvailability()
                
            } else if snapshot.documents.isEmpty {
                // No availability record found, create a new one
                if let relationshipID = self.relationshipID {
                    self.coupleAvailability = CoupleAvailability(relationshipID: relationshipID)
                }
                self.isLoading = false
            }
        }
    }
    
    /// Fetch mutual availability based on calendars
    func fetchMutualAvailability() {
        guard let relationshipID = relationshipID,
              let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Get relationship data to find partner ID
                guard let relationshipData = try? await relationshipService.getRelationship(id: relationshipID) else {
                    throw AvailabilityError.relationshipNotFound
                }
                
                // Get partner ID (the one that's not the current user)
                let partnerId = relationshipData.initiatorID == userId ? relationshipData.partnerID : relationshipData.initiatorID
                
                // Calculate date range - next 30 days
                let startDate = Date()
                let calendar = Calendar.current
                let endDate = calendar.date(byAdding: .day, value: 30, to: startDate) ?? startDate
                
                // Get mutual availability from the service
                let mutualAvailability = try await availabilityService.getMutualAvailability(
                    userId: userId,
                    partnerId: partnerId,
                    startDate: startDate,
                    endDate: endDate
                )
                
                await MainActor.run {
                    self.availableSlots = mutualAvailability
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                    print("Error fetching mutual availability: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Check if there is availability for a specific date
    func hasAvailabilityFor(date: Date) -> Bool {
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: date)
        return availableSlots[dateKey]?.isEmpty == false
    }
    
    /// Handle errors from Firestore
    private func handleError(_ error: Error) {
        self.isLoading = false
        
        if let nsError = error as NSError?, nsError.domain == FirestoreErrorDomain {
            switch nsError.code {
            case FirestoreErrorCode.unavailable.rawValue:
                self.error = AvailabilityError.networkTimeout
            case FirestoreErrorCode.permissionDenied.rawValue:
                self.error = AvailabilityError.permissionDenied
            default:
                self.error = error
            }
        } else {
            self.error = error
        }
    }
    
    /// Schedule a meeting at the given time slot
    func scheduleMeeting(at slot: AvailabilityTimeSlot) {
        // Create a new calendar event
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        Task {
            do {
                // Create a new event
                let eventTitle = "Meeting with \(partner?.displayName ?? "Partner")"
                
                let event = CalendarEventModel(
                    id: UUID().uuidString,
                    title: eventTitle,
                    description: "Scheduled via Unhinged",
                    startDate: slot.startTime,
                    endDate: slot.endTime,
                    isAllDay: false,
                    location: nil,
                    colorHex: "#4285F4",
                    calendarID: "",
                    calendarName: "",
                    provider: .google,  // Default to Google, this should be based on user preference
                    availability: .busy,
                    status: .confirmed
                )
                
                // Get calendar settings
                let settings = try await calendarService.getCalendarSettings(for: userId)
                
                // Find a provider that's used for events
                var eventProvider: CalendarProviderProtocol? = nil
                for providerSettings in settings {
                    if providerSettings.useForEvents {
                        // Directly assign the provider since getProviderFromSettings returns a non-optional
                        eventProvider = CalendarServiceFactory.shared.getProviderFromSettings(providerSettings)
                        break
                    }
                }
                
                if let provider = eventProvider {
                    // Create the event
                    let eventId = try await provider.createEvent(event: event, userID: userId)
                    
                    // Refresh availability after creating event
                    await fetchMutualAvailability()
                    
                    await MainActor.run {
                        self.isLoading = false
                    }
                    
                    print("Successfully created event with ID: \(eventId)")
                } else {
                    throw CalendarError.notImplemented
                }
                
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
                print("Failed to schedule meeting: \(error.localizedDescription)")
            }
        }
    }
    
    /// Force refresh availability data
    func refreshAvailability() {
        fetchMutualAvailability()
    }
    
    /// Save availability preferences
    func saveAvailability() {
        guard let availability = coupleAvailability else { return }
        
        isSaving = true
        
        Task {
            do {
                let updatedAvailability = try await availabilityService.saveAvailability(availability)
                
                await MainActor.run {
                    self.isSaving = false
                    // No need to update the local coupleAvailability as the listener will do it
                }
            } catch {
                await MainActor.run {
                    self.handleError(error)
                    self.isSaving = false
                }
            }
        }
    }
    
    /// Get the availability settings for a specific day
    func getDayAvailability(for weekday: Unhinged.Weekday) -> DayAvailability? {
        guard let availability = coupleAvailability else { return nil }
        return availability.dayAvailability.first { $0.day == weekday }
    }
    
    /// Toggle a day's overall availability
    func toggleDayAvailability(weekday: Unhinged.Weekday) {
        guard var availability = coupleAvailability else { return }
        
        if let index = availability.dayAvailability.firstIndex(where: { $0.day == weekday }) {
            var day = availability.dayAvailability[index]
            // Update logic for day availability toggling
            availability.dayAvailability[index] = day
            coupleAvailability = availability
        }
    }
    
    /// Start adding a new time range
    func startAddingTimeRange() {
        isAddingTimeRange = true
        editingTimeRange = TimeRange(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
    }
    
    /// Start editing a time range
    /// - Parameter timeRange: The time range to edit
    func editTimeRange(_ timeRange: TimeRange) {
        isAddingTimeRange = false
        editingTimeRange = timeRange
    }
    
    /// Cancel time range edit
    func cancelTimeRangeEdit() {
        isAddingTimeRange = false
        editingTimeRange = nil
        selectedDay = .monday // Default to Monday instead of nil
    }
    
    /// Add a time range to a day's availability
    func addTimeRange(_ timeRange: TimeRange, to weekday: Unhinged.Weekday?) {
        guard var availability = coupleAvailability else { return }
        let dayWeekday = weekday ?? selectedDay
        
        if let index = availability.dayAvailability.firstIndex(where: { $0.day == dayWeekday }) {
            var day = availability.dayAvailability[index]
            day.timeRanges.append(timeRange)
            availability.dayAvailability[index] = day
            coupleAvailability = availability
        }
    }
    
    /// Update a time range for a specific day
    func updateTimeRange(_ newTimeRange: TimeRange, replacing originalTimeRange: TimeRange, for weekday: Unhinged.Weekday?) {
        guard var availability = coupleAvailability else { return }
        let dayWeekday = weekday ?? selectedDay
        
        if let dayIndex = availability.dayAvailability.firstIndex(where: { $0.day == dayWeekday }),
           let rangeIndex = availability.dayAvailability[dayIndex].timeRanges.firstIndex(of: originalTimeRange) {
            availability.dayAvailability[dayIndex].timeRanges[rangeIndex] = newTimeRange
            coupleAvailability = availability
        }
    }
    
    /// Remove a time range from a day's availability
    func removeTimeRange(_ timeRange: TimeRange, from weekday: Unhinged.Weekday) {
        guard var availability = coupleAvailability else { return }
        
        if let dayIndex = availability.dayAvailability.firstIndex(where: { $0.day == weekday }) {
            availability.dayAvailability[dayIndex].timeRanges.removeAll { $0 == timeRange }
            coupleAvailability = availability
        }
    }
    
    /// Start adding a new commitment
    func startAddingCommitment() {
        isAddingCommitment = true
        editingCommitment = RecurringCommitment(
            title: "New Commitment", 
            day: .monday,
            startTime: Date(), 
            endTime: Date().addingTimeInterval(3600), 
            isSharedWithPartner: true
        )
    }
    
    /// Start editing a commitment
    /// - Parameter commitment: The commitment to edit
    func editCommitment(_ commitment: RecurringCommitment) {
        isAddingCommitment = false
        editingCommitment = commitment
    }
    
    /// Cancel commitment edit
    func cancelCommitmentEdit() {
        isAddingCommitment = false
        editingCommitment = nil
    }
    
    /// Add a commitment
    /// - Parameter commitment: The commitment to add
    func addCommitment(_ commitment: RecurringCommitment) {
        guard var availability = coupleAvailability else { return }
        
        availability.recurringCommitments.append(commitment)
        coupleAvailability = availability
    }
    
    /// Update a commitment
    /// - Parameters:
    ///   - newCommitment: The new commitment
    ///   - originalCommitment: The original commitment to replace
    func updateCommitment(_ newCommitment: RecurringCommitment, replacing originalCommitment: RecurringCommitment) {
        guard var availability = coupleAvailability else { return }
        
        if let index = availability.recurringCommitments.firstIndex(where: { $0.id == originalCommitment.id }) {
            availability.recurringCommitments[index] = newCommitment
            coupleAvailability = availability
        }
    }
    
    /// Remove a commitment
    /// - Parameter commitment: The commitment to remove
    func removeCommitment(_ commitment: RecurringCommitment) {
        guard var availability = coupleAvailability else { return }
        
        availability.recurringCommitments.removeAll { $0.id == commitment.id }
        coupleAvailability = availability
    }
    
    /// Get commitments for a specific day
    func getCommitments(for weekday: Unhinged.Weekday) -> [RecurringCommitment] {
        guard let availability = coupleAvailability else { return [] }
        return availability.recurringCommitments.filter { $0.day == weekday }
    }
    
    /// Update availability settings
    /// - Parameters:
    ///   - useCalendars: Whether to use calendars for availability
    ///   - requireBothFree: Whether to require both partners to be free
    ///   - minimumAdvanceNotice: Minimum advance notice in hours
    ///   - maximumAdvanceDays: Maximum days in advance to allow scheduling
    ///   - preferredDuration: Preferred hangout duration in minutes
    func updateSettings(
        useCalendars: Bool? = nil,
        requireBothFree: Bool? = nil,
        minimumAdvanceNotice: Int? = nil,
        maximumAdvanceDays: Int? = nil,
        preferredDuration: Int? = nil
    ) {
        guard var availability = coupleAvailability else { return }
        
        if let useCalendars = useCalendars {
            availability.useCalendars = useCalendars
        }
        
        if let requireBothFree = requireBothFree {
            availability.requireBothFree = requireBothFree
        }
        
        if let minimumAdvanceNotice = minimumAdvanceNotice {
            availability.minimumAdvanceNotice = minimumAdvanceNotice
        }
        
        if let maximumAdvanceDays = maximumAdvanceDays {
            availability.maximumAdvanceDays = maximumAdvanceDays
        }
        
        if let preferredDuration = preferredDuration {
            availability.preferredHangoutDuration = preferredDuration
        }
        
        coupleAvailability = availability
    }
} 