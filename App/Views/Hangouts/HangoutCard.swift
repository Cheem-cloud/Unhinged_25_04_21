import SwiftUI

struct HangoutCard: View {
    let hangout: Hangout
    let onTap: () -> Void
    
    // Get persona details from the HangoutsViewModel
    @EnvironmentObject private var viewModel: HangoutsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and status indicator
            HStack {
                Text(hangout.title)
                    .font(.headline)
                    .foregroundColor(.deepRed)
                
                Spacer()
                
                statusBadge
            }
            
            // Date and time
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.mutedGold)
                
                Text(formatDate(hangout.startDate))
                    .font(.subheadline)
                    .foregroundColor(.black.opacity(0.7))
            }
            
            // Time duration
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.mutedGold)
                
                Text(formatTimeRange(start: hangout.startDate, end: hangout.endDate))
                    .font(.subheadline)
                    .foregroundColor(.black.opacity(0.7))
            }
            
            // Participants
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.mutedGold)
                
                Text(getParticipantNames())
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.7))
                    .lineLimit(1)
            }
            
            // Location if available
            if let location = hangout.location, !location.isEmpty {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.mutedGold)
                    
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    // Status badge view
    private var statusBadge: some View {
        let (statusText, color) = getStatusInfo()
        
        return Text(statusText)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(8)
    }
    
    // Helper for status text and color
    private func getStatusInfo() -> (String, Color) {
        switch hangout.status {
        case .pending:
            return ("Pending", .orange)
        case .accepted:
            return ("Accepted", .green)
        case .declined:
            return ("Declined", .red)
        case .completed:
            return ("Completed", .blue)
        case .cancelled:
            return ("Cancelled", .gray)
        }
    }
    
    // Helper to get status color for outline
    private var statusColor: Color {
        switch hangout.status {
        case .pending: return .orange
        case .accepted: return .green
        case .declined: return .red
        case .completed: return .blue
        case .cancelled: return .gray
        }
    }
    
    // Helper for formatting date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // Helper for formatting time range
    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    // Helper to get participant names
    private func getParticipantNames() -> String {
        let creatorName = viewModel.personaDetails[hangout.creatorPersonaID]?.name ?? "Unknown"
        let inviteeName = viewModel.personaDetails[hangout.inviteePersonaID]?.name ?? "Unknown"
        return "\(creatorName) & \(inviteeName)"
    }
}

struct HangoutCard_Previews: PreviewProvider {
    static var previews: some View {
        let sampleHangout = Hangout(
            title: "Coffee at the Park",
            description: "A quick coffee meetup at Central Park",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            location: "Central Park",
            creatorID: "user1",
            creatorPersonaID: "persona1",
            inviteeID: "user2",
            inviteePersonaID: "persona2"
        )
        
        return HangoutCard(hangout: sampleHangout, onTap: {})
            .environmentObject(HangoutsViewModel())
            .padding()
            .previewLayout(.sizeThatFits)
    }
} 