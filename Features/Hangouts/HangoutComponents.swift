import SwiftUI

/// Card component for displaying a hangout summary
struct HangoutCard: View {
    let hangout: Hangout
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hangout.title ?? "Unnamed Hangout")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        
                        Text(formattedDate(from: hangout.date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let location = hangout.location, !location.isEmpty {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.red)
                            
                            Text(location)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Circle()
                    .fill(statusColor(for: hangout.status))
                    .frame(width: 12, height: 12)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formattedDate(from date: Date?) -> String {
        guard let date = date else { return "No date set" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func statusColor(for status: HangoutStatus?) -> Color {
        guard let status = status else { return .gray }
        
        switch status {
        case .pending:
            return .orange
        case .confirmed:
            return .green
        case .cancelled:
            return .red
        case .completed:
            return .blue
        }
    }
}

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
                HangoutStatusBadge(status: hangout.status)
                
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

/// Status badge for hangouts
struct HangoutStatusBadge: View {
    let status: HangoutStatus?
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.8))
        .cornerRadius(20)
    }
    
    private var statusText: String {
        guard let status = status else { return "Unknown" }
        
        switch status {
        case .pending:
            return "Pending"
        case .confirmed:
            return "Confirmed"
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
        case .confirmed:
            return .green
        case .cancelled:
            return .red
        case .completed:
            return .blue
        }
    }
} 