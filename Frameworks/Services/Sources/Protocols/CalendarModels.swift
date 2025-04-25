import Foundation

// MARK: - Calendar Provider Types

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

// MARK: - Calendar Settings Models

/// Settings for a calendar provider
public struct CalendarProviderSettings: Codable {
    public var userID: String
    public var providerType: CalendarProviderType
    public var name: String
    public var accessToken: String?
    public var refreshToken: String?
    public var tokenExpirationDate: Date?
    public var useForEvents: Bool
    public var useForAvailability: Bool
    public var isDefault: Bool
    public var selectedCalendarIds: [String]
    
    public init(
        providerType: CalendarProviderType,
        userID: String,
        name: String = "",
        accessToken: String? = nil,
        refreshToken: String? = nil,
        tokenExpirationDate: Date? = nil,
        useForEvents: Bool = true,
        useForAvailability: Bool = true,
        isDefault: Bool = false,
        selectedCalendarIds: [String] = []
    ) {
        self.providerType = providerType
        self.userID = userID
        self.name = name.isEmpty ? providerType.displayName : name
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExpirationDate = tokenExpirationDate
        self.useForEvents = useForEvents
        self.useForAvailability = useForAvailability
        self.isDefault = isDefault
        self.selectedCalendarIds = selectedCalendarIds
    }
}

public struct CalendarSettings: Codable {
    public var userID: String
    public var defaultCalendarProvider: CalendarProviderType
    public var syncEnabled: Bool
    public var reminderNotificationsEnabled: Bool
    public var defaultReminderTime: Int // minutes
    
    public init(
        userID: String,
        defaultCalendarProvider: CalendarProviderType = .google,
        syncEnabled: Bool = true,
        reminderNotificationsEnabled: Bool = true,
        defaultReminderTime: Int = 15
    ) {
        self.userID = userID
        self.defaultCalendarProvider = defaultCalendarProvider
        self.syncEnabled = syncEnabled
        self.reminderNotificationsEnabled = reminderNotificationsEnabled
        self.defaultReminderTime = defaultReminderTime
    }
}

// MARK: - Availability Models

/// Represents a period of time where the user is busy
public struct BusyTimePeriod: Identifiable, Codable {
    public var id = UUID()
    public var startTime: Date
    public var endTime: Date
    public var title: String?
    public var isAllDay: Bool
    
    public init(start: Date, end: Date, title: String? = nil, isAllDay: Bool = false) {
        self.startTime = start
        self.endTime = end
        self.title = title
        self.isAllDay = isAllDay
    }
}

/// Busy time slot
public struct BusyTimeSlot: Identifiable, Codable {
    public var id = UUID()
    public var startTime: Date
    public var endTime: Date
    public var title: String?
    public var isAllDay: Bool
    public var source: String?
    public var calendarId: String?
    
    public init(startTime: Date, endTime: Date, title: String? = nil, isAllDay: Bool = false, source: String? = nil, calendarId: String? = nil) {
        self.startTime = startTime
        self.endTime = endTime
        self.title = title
        self.isAllDay = isAllDay
        self.source = source
        self.calendarId = calendarId
    }
}

/// Rating for availability time slots
public enum AvailabilityRating: String, Codable {
    case excellent  // Long, uninterrupted availability
    case good       // Decent availability
    case fair       // Limited availability
}

/// Available time slot
public struct AvailabilityTimeSlot: Identifiable, Codable {
    public var id = UUID()
    public var startTime: Date
    public var endTime: Date
    public var availabilityRating: AvailabilityRating
    
    public init(startTime: Date, endTime: Date, availabilityRating: AvailabilityRating = .good) {
        self.startTime = startTime
        self.endTime = endTime
        self.availabilityRating = availabilityRating
    }
}

/// User preferences for availability scheduling
public struct AvailabilityPreferences: Codable {
    public var minDuration: Int // minutes
    public var maxDuration: Int // minutes
    public var preferredDaysOfWeek: [Int] // 1 = Sunday, 7 = Saturday
    public var preferredTimeRanges: [TimeRange]
    public var excludeWeekends: Bool
    
    public init(
        minDuration: Int = 30,
        maxDuration: Int = 240,
        preferredDaysOfWeek: [Int] = [2, 3, 4, 5],
        preferredTimeRanges: [TimeRange] = [],
        excludeWeekends: Bool = true
    ) {
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        self.preferredDaysOfWeek = preferredDaysOfWeek
        self.preferredTimeRanges = preferredTimeRanges
        self.excludeWeekends = excludeWeekends
    }
}

/// Time range for preferred availability
public struct TimeRange: Codable {
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int
    
    public init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }
}

/// Alias for backward compatibility
public typealias AvailabilitySlot = AvailabilityTimeSlot 