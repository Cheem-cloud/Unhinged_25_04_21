import Foundation

/// Types of calendar providers supported by the app
public enum CalendarProviderType: String, Codable, CaseIterable, Identifiable {
    case google
    case apple
    case outlook
    
    public var id: String {
        return self.rawValue
    }
    
    public var displayName: String {
        switch self {
        case .google:
            return "Google Calendar"
        case .apple:
            return "Apple Calendar"
        case .outlook:
            return "Microsoft Outlook"
        }
    }
    
    public var icon: String {
        switch self {
        case .google:
            return "googlecalendar-icon"
        case .apple:
            return "applecalendar-icon"
        case .outlook:
            return "outlook-icon"
        }
    }
}

/// Represents a calendar provider with its associated settings
public struct CalendarProvider: Identifiable, Codable {
    public var id: String
    public var userId: String
    public var type: CalendarProviderType
    public var isEnabled: Bool
    public var settings: CalendarProviderSettings
    public var lastSyncDate: Date?
    
    public init(id: String = UUID().uuidString,
               userId: String,
               type: CalendarProviderType,
               isEnabled: Bool = true,
               settings: CalendarProviderSettings,
               lastSyncDate: Date? = nil) {
        self.id = id
        self.userId = userId
        self.type = type
        self.isEnabled = isEnabled
        self.settings = settings
        self.lastSyncDate = lastSyncDate
    }
}

/// Settings for a calendar provider
public struct CalendarProviderSettings: Codable {
    public var accessToken: String?
    public var refreshToken: String?
    public var email: String?
    public var tokenExpirationDate: Date?
    public var selectedCalendarIds: [String]
    public var syncFrequency: SyncFrequency
    
    public init(accessToken: String? = nil,
               refreshToken: String? = nil,
               email: String? = nil,
               tokenExpirationDate: Date? = nil,
               selectedCalendarIds: [String] = [],
               syncFrequency: SyncFrequency = .manual) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.email = email
        self.tokenExpirationDate = tokenExpirationDate
        self.selectedCalendarIds = selectedCalendarIds
        self.syncFrequency = syncFrequency
    }
    
    public enum SyncFrequency: String, Codable, CaseIterable {
        case manual
        case hourly
        case daily
        case weekly
        
        public var displayText: String {
            switch self {
            case .manual:
                return "Manual"
            case .hourly:
                return "Every Hour"
            case .daily:
                return "Once a Day"
            case .weekly:
                return "Once a Week"
            }
        }
    }
}

/// Represents a busy time slot from a calendar
public struct BusyTimeSlot: Identifiable, Codable {
    public var id = UUID()
    public var startTime: Date
    public var endTime: Date
    public var source: String
    public var calendarId: String
    
    public init(startTime: Date, endTime: Date, source: String, calendarId: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.source = source
        self.calendarId = calendarId
    }
}

/// Represents a period of time where the user is busy
public struct BusyTimePeriod: Identifiable, Codable {
    public var id = UUID()
    public var startTime: Date
    public var endTime: Date
    public var userId: String
    public var slots: [BusyTimeSlot]
    
    public init(startTime: Date, endTime: Date, userId: String, slots: [BusyTimeSlot] = []) {
        self.startTime = startTime
        self.endTime = endTime
        self.userId = userId
        self.slots = slots
    }
}

/// Available time slot for scheduling
public struct AvailabilitySlot: Identifiable, Codable {
    public var id = UUID()
    public var startTime: Date
    public var endTime: Date
    
    public init(startTime: Date, endTime: Date) {
        self.startTime = startTime
        self.endTime = endTime
    }
}

/// User preferences for availability scheduling
public struct AvailabilityPreferences: Codable {
    public var minDuration: Int // minutes
    public var maxDuration: Int // minutes
    public var preferredDaysOfWeek: [Int] // 1 = Sunday, 7 = Saturday
    public var preferredTimeRanges: [TimeRange]
    public var excludeWeekends: Bool
    
    public init(minDuration: Int = 30,
               maxDuration: Int = 240,
               preferredDaysOfWeek: [Int] = [2, 3, 4, 5],
               preferredTimeRanges: [TimeRange] = [],
               excludeWeekends: Bool = true) {
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        self.preferredDaysOfWeek = preferredDaysOfWeek
        self.preferredTimeRanges = preferredTimeRanges
        self.excludeWeekends = excludeWeekends
    }
} 