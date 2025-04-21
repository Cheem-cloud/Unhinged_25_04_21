import SwiftUI
// Remove unnecessary imports
// import Unhinged
// // Removed: // Removed: import Unhinged.TimeSlotComponents
// // Removed: // Removed: import Unhinged.Components
// // Removed: // Removed: import Unhinged.DatePickers
// Removed // Removed: import Unhinged.Utilities
import Combine

/// View for finding and displaying mutual availability between couples
public struct MutualAvailabilityView: View {
    @StateObject private var viewModel = MutualAvailabilityViewModel()
    @Environment(\.dismiss) private var dismiss
    
    // Sheets and navigation
    @State private var showFriendPicker = false
    @State private var showDateRangePicker = false
    @State private var showDurationPicker = false
    @State private var showCreateHangout = false
    @State private var showHangoutNavigationLink = false
    @State private var createdHangoutID: String? = nil
    
    // Error alert
    @State private var showErrorAlert = false
    
    // Cancellables for storing subscriptions
    @State private var cancellables = Set<AnyCancellable>()
    
    // Callbacks and actions
    private var timeSlotSelectedCallback: Callback<TimeSlot> {
        viewModel.createTimeSlotSelectedCallback()
    }
    
    private var findAvailabilityAction: Action {
        viewModel.createFindAvailabilityAction()
    }
    
    private var retryAction: Action {
        viewModel.createRetryAction()
    }
    
    private var createHangoutAction: Action {
        Action { [weak viewModel] in
            guard let selectedTimeSlot = viewModel?.selectedTimeSlot,
                  let friendID = viewModel?.friendRelationshipID else { return }
            showCreateHangout = true
        }
    }
    
    private var onHangoutCreatedCallback: Callback<String> {
        Callback { [weak self] hangoutID in
            self?.createdHangoutID = hangoutID
            self?.showHangoutNavigationLink = true
        }
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            MutualAvailabilityFeature(
                state: viewModel.state,
                selectedTimeSlot: viewModel.selectedTimeSlot,
                availableTimes: viewModel.availableTimeSlots,
                startDate: viewModel.startDate,
                endDate: viewModel.endDate,
                duration: viewModel.duration,
                friendRelationshipID: viewModel.friendRelationshipID,
                error: viewModel.error,
                onSelectTimeSlot: timeSlotSelectedCallback,
                onFindAvailableTimes: findAvailabilityAction,
                onRetry: retryAction,
                onCreateHangout: { title, description, location, hangoutType in
                    viewModel.createHangout(
                        title: title,
                        description: description,
                        location: location,
                        type: hangoutType
                    )
                    showCreateHangout = false
                },
                onHangoutCreated: onHangoutCreatedCallback
            )
            .navigationTitle("Mutual Availability")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showHangoutNavigationLink) {
                if let hangoutID = createdHangoutID {
                    HangoutDetailView(hangoutID: hangoutID)
                        .navigationBarBackButtonHidden(true)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    showHangoutNavigationLink = false
                                    dismiss()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                        Text("Back")
                                    }
                                }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showFriendPicker) {
            FriendPickerView(onFriendSelected: { friendID in
                viewModel.friendRelationshipID = friendID
                showFriendPicker = false
            })
        }
        .sheet(isPresented: $showDateRangePicker) {
            DateRangePickerView(
                startDate: viewModel.startDate,
                endDate: viewModel.endDate,
                onDatesSelected: { start, end in
                    viewModel.startDate = start
                    viewModel.endDate = end
                    showDateRangePicker = false
                }
            )
        }
        .sheet(isPresented: $showDurationPicker) {
            DurationPickerView(
                duration: viewModel.duration,
                onDurationSelected: { duration in
                    viewModel.duration = duration
                    showDurationPicker = false
                }
            )
        }
        .sheet(isPresented: $showCreateHangout) {
            if let timeSlot = viewModel.selectedTimeSlot,
               let friendID = viewModel.friendRelationshipID {
                MutualAvailabilityCreateHangoutView(
                    selectedTime: timeSlot,
                    friendRelationshipID: friendID,
                    onCreateHangout: { title, description, location, hangoutType in
                        viewModel.createHangout(
                            title: title,
                            description: description,
                            location: location,
                            type: hangoutType
                        )
                        showCreateHangout = false
                    },
                    onCancel: {
                        showCreateHangout = false
                    }
                )
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.error?.localizedDescription ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
        .onReceive(NotificationManager.publisher(for: .showFriendPicker)) { _ in
            showFriendPicker = true
        }
        .onReceive(NotificationManager.publisher(for: .showDateRangePicker)) { _ in
            showDateRangePicker = true
        }
        .onReceive(NotificationManager.publisher(for: .showDurationPicker)) { _ in
            showDurationPicker = true
        }
        .onReceive(NotificationManager.publisher(for: .showCreateHangout)) { _ in
            showCreateHangout = true
        }
        .onReceive(NotificationManager.publisher(for: .resetError)) { _ in
            viewModel.error = nil
            viewModel.availableTimeSlots = []
        }
        .onAppear {
            // Set up Combine subscriptions
            setupSubscriptions()
            
            viewModel.initialize()
        }
        .onDisappear {
            // Clean up subscriptions
            cancellables.removeAll()
        }
    }
    
    /// Set up Combine subscriptions for reactive updates
    private func setupSubscriptions() {
        // Subscribe to state changes
        viewModel.statePublisher
            .receive(on: RunLoop.main)
            .sink { state in
                switch state {
                case .success(let hangoutID):
                    createdHangoutID = hangoutID
                    // Only auto-navigate if the user hasn't explicitly handled the ID
                    if !showHangoutNavigationLink {
                        showHangoutNavigationLink = true
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to error changes
        viewModel.$error
            .receive(on: RunLoop.main)
            .sink { error in
                showErrorAlert = error != nil
            }
            .store(in: &cancellables)
    }
}

internal struct MutualAvailabilityView_Previews: PreviewProvider {
    static var previews: some View {
        MutualAvailabilityView()
    }
} 