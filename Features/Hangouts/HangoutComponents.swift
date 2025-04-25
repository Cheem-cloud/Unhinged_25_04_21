import SwiftUI

/// Detail view for a specific hangout
public struct HangoutDetailFeature: View {
    let hangout: Hangout
    let onBack: () -> Void
    let onEdit: () -> Void
    
    public init(hangout: Hangout, onBack: @escaping () -> Void, onEdit: @escaping () -> Void) {
        self.hangout = hangout
        self.onBack = onBack
        self.onEdit = onEdit
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Button(action: onEdit) {
                        Text("Edit")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.bottom)
                
                // Title
                Text(hangout.title ?? "Unnamed Hangout")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Status badge
                HangoutStatusIndicator(status: hangout.status)
                
                // Date and time
                if let date = hangout.date {
                    DetailRow(icon: "calendar.badge.clock", title: "Date & Time", value: formattedDateTime(date))
                }
                
                // Location
                if let location = hangout.location, !location.isEmpty {
                    DetailRow(icon: "mappin.circle", title: "Location", value: location)
                }
                
                // Notes
                if let notes = hangout.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        
                        Text(notes)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Participants
                if let participants = hangout.participants, !participants.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Participants")
                            .font(.headline)
                        
                        ForEach(participants, id: \.self) { participant in
                            HStack {
                                Image(systemName: "person.circle")
                                    .foregroundColor(.blue)
                                
                                Text(participant)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationBarHidden(true)
    }
    
    private func formattedDateTime(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: date)
    }
}

/// Small reusable component for displaying a detail row with icon
private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                
                Text(value)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// Renamed to avoid conflict with HangoutStatusBadge
private struct HangoutStatusIndicator: View {
    let status: HangoutStatus?
    
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