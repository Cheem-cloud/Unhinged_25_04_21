import Foundation

/// Represents a time slot for availability
public struct TimeSlot: Identifiable, Hashable, Codable {
    /// Unique identifier
    public var id: String
    
    /// Day name (e.g., "Monday")
    public var day: String
    
    /// Date for this time slot
    public var date: Date
    
    /// Start time
    public var startTime: Date
    
    /// End time
    public var endTime: Date
    
    /// Duration in minutes
    public var durationMinutes: Int {
        return Int(endTime.timeIntervalSince(startTime) / 60)
    }
    
    /// Formatted start time
    public var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startTime)
    }
    
    /// Formatted end time
    public var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: endTime)
    }
    
    /// Formatted date
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    /// Create a new time slot
    /// - Parameters:
    ///   - id: Unique identifier (optional, defaults to UUID)
    ///   - day: Day name (e.g., "Monday")
    ///   - date: Date for this time slot
    ///   - startTime: Start time
    ///   - endTime: End time
    public init(
        id: String = UUID().uuidString,
        day: String,
        date: Date,
        startTime: Date,
        endTime: Date
    ) {
        self.id = id
        self.day = day
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
    }
    
    // Implement Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: TimeSlot, rhs: TimeSlot) -> Bool {
        return lhs.id == rhs.id
    }
} 