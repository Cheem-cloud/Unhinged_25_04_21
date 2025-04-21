import Foundation
import SwiftUI
import Combine

// MARK: - Combine Extensions for MutualAvailabilityViewModel

extension MutualAvailabilityViewModel {
    
    /// State of the mutual availability feature
    public enum State: Equatable {
        case empty
        case loading(progress: Float?)
        case results
        case error
        case success(hangoutID: String)
        
        public static func == (lhs: MutualAvailabilityViewModel.State, rhs: MutualAvailabilityViewModel.State) -> Bool {
            switch (lhs, rhs) {
            case (.empty, .empty):
                return true
            case (.results, .results):
                return true
            case (.error, .error):
                return true
            case let (.loading(progress1), .loading(progress2)):
                return progress1 == progress2
            case let (.success(id1), .success(id2)):
                return id1 == id2
            default:
                return false
            }
        }
    }
    
    /// Main state publisher for the view model
    public var statePublisher: AnyPublisher<State, Never> {
        Publishers.CombineLatest4(
            $isLoading,
            $availableTimeSlots,
            $error,
            $createdHangoutID
        )
        .map { isLoading, availableTimeSlots, error, createdHangoutID in
            if let hangoutID = createdHangoutID, !hangoutID.isEmpty {
                return .success(hangoutID: hangoutID)
            }
            
            if isLoading {
                return .loading(progress: nil)
            }
            
            if error != nil {
                return .error
            }
            
            if availableTimeSlots.isEmpty {
                return .empty
            }
            
            return .results
        }
        .eraseToAnyPublisher()
    }
    
    /// Current state based on the view model's properties
    public var state: State {
        if let hangoutID = createdHangoutID, !hangoutID.isEmpty {
            return .success(hangoutID: hangoutID)
        }
        
        if isLoading {
            return .loading(progress: nil)
        }
        
        if error != nil {
            return .error
        }
        
        if availableTimeSlots.isEmpty {
            return .empty
        }
        
        return .results
    }
    
    /// Initialize the viewmodel
    public func initialize() {
        loadCurrentUserRelationship()
    }
    
    /// Create a time slot selected callback
    /// - Returns: A callback that selects the given time slot
    public func createTimeSlotSelectedCallback() -> Callback<TimeSlot> {
        return Callback<TimeSlot> { [weak self] timeSlot in
            self?.selectedTimeSlot = timeSlot
            NotificationManager.shared.timeSlotSelected(timeSlot: timeSlot)
        }
    }
    
    /// Create a find available times action
    /// - Returns: An action that triggers finding mutual availability
    public func createFindAvailabilityAction() -> Action {
        return Action { [weak self] in
            self?.findMutualAvailability()
        }
    }
    
    /// Create a retry action
    /// - Returns: An action that handles retry based on error type
    public func createRetryAction() -> Action {
        return Action { [weak self] in
            guard let self = self else { return }
            
            if let error = self.error as? MutualAvailabilityError {
                switch error {
                case .calendarPermissionRequired:
                    self.handleCalendarPermissionError()
                case .noMutualAvailabilityFound, .searchRangeTooNarrow:
                    self.suggestAlternativeTimes()
                default:
                    self.findMutualAvailability()
                }
            } else {
                self.findMutualAvailability()
            }
        }
    }
    
    /// Create a create hangout callback
    /// - Returns: A callback that creates a hangout
    public func createHangoutCallback() -> Callback<(title: String, description: String, location: String, hangoutType: HangoutType)> {
        return Callback<(title: String, description: String, location: String, hangoutType: HangoutType)> { [weak self] params in
            self?.createHangout(
                title: params.title,
                description: params.description,
                location: params.location,
                hangoutType: params.hangoutType
            )
        }
    }
    
    /// Create a hangout created callback
    /// - Returns: A callback that handles hangout creation completion
    public func createHangoutCreatedCallback() -> Callback<String> {
        return Callback<String> { [weak self] hangoutID in
            self?.createdHangoutID = hangoutID
            self?.hangoutCreated = true
            self?.navigationState = .hangoutDetails
        }
    }
} 