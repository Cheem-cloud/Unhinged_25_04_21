import SwiftUI
import Firebase
import FirebaseAuth

// MARK: - HangoutDetailView
struct HangoutDetailView: View {
    let hangoutID: String
    @StateObject private var viewModel = HangoutDetailViewModel()
    @EnvironmentObject var hangoutsViewModel: HangoutsViewModel
    
    init(hangoutID: String) {
        self.hangoutID = hangoutID
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    HangoutDetailLoadingView()
                } else if let hangout = viewModel.hangout {
                    // Title and status
                    HStack {
                        Text(hangout.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        HangoutStatusBadge(status: hangout.status)
                    }
                    .padding(.bottom)
                    
                    // Date and time
                    HangoutDetailRow(
                        icon: "calendar", 
                        title: "Date", 
                        value: formatDate(hangout.startDate)
                    )
                    
                    HangoutDetailRow(
                        icon: "clock", 
                        title: "Time", 
                        value: formatTimeRange(start: hangout.startDate, end: hangout.endDate)
                    )
                    
                    // Description
                    Text("Description")
                        .font(.headline)
                        .padding(.top)
                    
                    Text(hangout.description)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    // Location if available
                    if let location = hangout.location, !location.isEmpty {
                        HangoutDetailRow(
                            icon: "mappin.and.ellipse", 
                            title: "Location", 
                            value: location
                        )
                    }
                    
                    // Participants
                    Text("Participants")
                        .font(.headline)
                        .padding(.top)
                    
                    // Creator
                    if let creatorPersona = viewModel.creatorPersona {
                        HangoutParticipantRow(
                            persona: creatorPersona,
                            role: "Creator"
                        )
                    }
                    
                    // Invitee
                    if let inviteePersona = viewModel.inviteePersona {
                        HangoutParticipantRow(
                            persona: inviteePersona,
                            role: "Invitee"
                        )
                    }
                    
                    // Action buttons for pending hangouts
                    if hangout.status == .pending {
                        HangoutActionButtons(
                            hangout: hangout,
                            onAccept: { viewModel.respondToHangout(id: hangoutID, accept: true) },
                            onDecline: { viewModel.respondToHangout(id: hangoutID, accept: false) },
                            onCancel: { viewModel.cancelHangout(id: hangoutID) }
                        )
                    }
                    
                } else {
                    HangoutDetailEmptyView()
                }
            }
            .padding()
        }
        .navigationTitle("Hangout Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadHangout(id: hangoutID)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - Supporting Components

struct HangoutDetailLoadingView: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }
}

struct HangoutDetailEmptyView: View {
    var body: some View {
        Text("Hangout not found")
            .font(.headline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
    }
}

struct HangoutDetailRow: View {
    var icon: String
    var title: String
    var value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
            }
        }
    }
}

struct HangoutParticipantRow: View {
    var persona: Persona
    var role: String
    
    var body: some View {
        HStack {
            if let imageURL = persona.avatarURL, !imageURL.isEmpty {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle")
                        .resizable()
                        .foregroundColor(.gray)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading) {
                Text(persona.name)
                    .font(.headline)
                
                Text(role)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct HangoutActionButtons: View {
    var hangout: Hangout
    var onAccept: () -> Void
    var onDecline: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        HStack {
            if hangout.inviteeID == Auth.auth().currentUser?.uid {
                // Only show accept/decline if user is the invitee
                Button(action: onAccept) {
                    Text("Accept")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: onDecline) {
                    Text("Decline")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else {
                // Creator can cancel the hangout
                Button(action: onCancel) {
                    Text("Cancel Hangout")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.top)
    }
}

// MARK: - HangoutDetailViewModel
class HangoutDetailViewModel: ObservableObject {
    @Published var hangout: Hangout?
    @Published var creatorPersona: Persona?
    @Published var inviteePersona: Persona?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let firestoreService = FirestoreService.shared
    private let calendarService: CalendarServiceAdapter
    
    init(hangout: Hangout? = nil) {
        self.hangout = hangout
        // Get CalendarServiceAdapter from ServiceManager
        self.calendarService = ServiceManager.shared.getService(CRUDService.self) as! CalendarServiceAdapter
    }
    
    func loadHangout(id: String) {
        isLoading = true
        
        Task {
            do {
                let fetchedHangout = try await firestoreService.getHangout(id)
                
                if let hangout = fetchedHangout {
                    self.creatorPersona = try? await firestoreService.getPersona(hangout.creatorPersonaID, for: hangout.creatorID)
                    self.inviteePersona = try? await firestoreService.getPersona(hangout.inviteePersonaID, for: hangout.inviteeID)
                }
                
                await MainActor.run {
                    self.hangout = fetchedHangout
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    func respondToHangout(id: String, accept: Bool) {
        guard let hangout = hangout else { return }
        
        isLoading = true
        
        Task {
            do {
                let updatedHangout = Hangout(
                    id: id,
                    title: hangout.title,
                    description: hangout.description,
                    startDate: hangout.startDate,
                    endDate: hangout.endDate,
                    location: hangout.location,
                    creatorID: hangout.creatorID,
                    creatorPersonaID: hangout.creatorPersonaID,
                    inviteeID: hangout.inviteeID,
                    inviteePersonaID: hangout.inviteePersonaID,
                    status: accept ? .accepted : .declined,
                    calendarEventID: hangout.calendarEventID
                )
                
                try await firestoreService.updateHangout(updatedHangout)
                
                // Create calendar events if accepted
                if accept {
                    let calendarEvent = CalendarEventModel(
                        id: UUID().uuidString,
                        title: hangout.title,
                        description: hangout.description,
                        startDate: hangout.startDate,
                        endDate: hangout.endDate,
                        location: hangout.location
                    )
                    
                    try? await calendarService.createCalendarEvent(
                        for: updatedHangout,
                        userIDs: [hangout.creatorID, hangout.inviteeID]
                    )
                }
                
                await MainActor.run {
                    self.hangout = updatedHangout
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    func cancelHangout(id: String) {
        guard let hangout = hangout else { return }
        
        isLoading = true
        
        Task {
            do {
                let updatedHangout = Hangout(
                    id: id,
                    title: hangout.title,
                    description: hangout.description,
                    startDate: hangout.startDate,
                    endDate: hangout.endDate,
                    location: hangout.location,
                    creatorID: hangout.creatorID,
                    creatorPersonaID: hangout.creatorPersonaID,
                    inviteeID: hangout.inviteeID,
                    inviteePersonaID: hangout.inviteePersonaID,
                    status: .cancelled,
                    calendarEventID: hangout.calendarEventID
                )
                
                try await firestoreService.updateHangout(updatedHangout)
                
                await MainActor.run {
                    self.hangout = updatedHangout
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}

// Add back the status badge component since we removed the import
struct HangoutStatusBadge: View {
    var status: HangoutStatus?
    
    var body: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor)
            .cornerRadius(20)
    }
    
    private var statusText: String {
        guard let status = status else { return "Unknown" }
        
        switch status {
        case .pending:
            return "Pending"
        case .accepted, .confirmed:
            return "Accepted"
        case .declined:
            return "Declined"
        case .cancelled:
            return "Cancelled"
        case .completed:
            return "Completed"
        }
    }
    
    private var statusColor: Color {
        guard let status = status else { return .gray }
        
        switch status {
        case .pending:
            return .orange
        case .accepted, .confirmed:
            return .green
        case .declined, .cancelled:
            return .red
        case .completed:
            return .blue
        }
    }
} 