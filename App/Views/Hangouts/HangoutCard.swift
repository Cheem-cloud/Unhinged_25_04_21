import SwiftUI

// This file is now just a wrapper around the centralized HangoutCard component
// The original implementation has been moved to Components/HangoutComponents.swift
// This wrapper ensures backward compatibility with existing code

// We need to re-implement as a lightweight wrapper instead of using typealias
struct HangoutCard: View {
    private let hangout: Hangout
    private let onTap: () -> Void
    
    init(hangout: Hangout, onTap: @escaping () -> Void) {
        self.hangout = hangout
        self.onTap = onTap
    }
    
    var body: some View {
        // Forward to the Components/HangoutComponents.swift implementation
        ForwardingHangoutCard(hangout: hangout, onTap: onTap)
    }
}

// Internal forwarding to decouple the implementation
private struct ForwardingHangoutCard: View {
    let hangout: Hangout
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and status indicator
            HStack {
                Text(hangout.title ?? "Unnamed Hangout")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Use a simple status indicator until we fix the modules
                Text(statusText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor)
                    .cornerRadius(20)
            }
            
            // Date and time
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                
                Text(formatDate(hangout.startDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Time duration
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                
                Text(formatTimeRange(start: hangout.startDate, end: hangout.endDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Location if available
            if let location = hangout.location, !location.isEmpty {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.red)
                    
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    // Status text based on hangout status
    private var statusText: String {
        guard let status = hangout.status else { return "Unknown" }
        
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
    
    // Helper to get status color for outline
    private var statusColor: Color {
        guard let status = hangout.status else { return .gray }
        
        switch status {
        case .pending: return .orange
        case .accepted, .confirmed: return .green
        case .declined, .cancelled: return .red
        case .completed: return .blue
        }
    }
    
    // Helper for formatting date
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "No date set" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // Helper for formatting time range
    private func formatTimeRange(start: Date?, end: Date?) -> String {
        guard let start = start, let end = end else { return "No time set" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// This preview provider is kept for local testing
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
            .padding()
            .previewLayout(.sizeThatFits)
    }
} 