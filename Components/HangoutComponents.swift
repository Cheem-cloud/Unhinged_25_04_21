import SwiftUI

/// Card component for displaying a hangout summary
public struct HangoutCard: View {
    let hangout: Hangout
    let onTap: () -> Void
    
    public init(hangout: Hangout, onTap: @escaping () -> Void) {
        self.hangout = hangout
        self.onTap = onTap
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and status indicator
            HStack {
                Text(hangout.title ?? "Unnamed Hangout")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HangoutStatusBadge(status: hangout.status)
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

/// Status badge for hangouts
public struct HangoutStatusBadge: View {
    let status: HangoutStatus?
    
    public init(status: HangoutStatus?) {
        self.status = status
    }
    
    public var body: some View {
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