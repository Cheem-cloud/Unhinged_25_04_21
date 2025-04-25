import Foundation

/// Protocol defining operations for crash and error reporting in the application
public protocol CrashReportingService {
    /// Initializes the crash reporting service
    /// - Parameters:
    ///   - userId: Optional user identifier for associating crashes with users
    ///   - additionalInfo: Optional dictionary of additional information to include in crash reports
    func initialize(userId: String?, additionalInfo: [String: Any]?) async throws
    
    /// Records a non-fatal error that occurred in the application
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - context: Additional contextual information about where/when the error occurred
    func recordError(_ error: Error, context: CrashContext) async
    
    /// Records a custom exception that occurred in the application
    /// - Parameters:
    ///   - name: Name of the exception
    ///   - reason: Reason the exception occurred
    ///   - stackTrace: Optional array of stack trace elements
    ///   - context: Additional contextual information about where/when the exception occurred
    func recordException(name: String, reason: String, stackTrace: [String]?, context: CrashContext) async
    
    /// Sets a custom key-value pair that will be included in crash reports
    /// - Parameters:
    ///   - key: The key for the custom value
    ///   - value: The value to set
    func setCustomValue(_ value: Any, forKey key: String) async
    
    /// Sets the user identifier for crash reports
    /// - Parameter userId: The user identifier
    func setUserId(_ userId: String?) async
    
    /// Logs a message that will be included in crash reports
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The severity level of the message
    func log(_ message: String, level: CrashLogLevel) async
    
    /// Gets the crash-free users percentage over the last period
    /// - Parameter days: Number of days to analyze
    /// - Returns: Percentage of users who haven't experienced crashes
    func getCrashFreeUsersPercentage(days: Int) async throws -> Double
    
    /// Gets the crash-free sessions percentage over the last period
    /// - Parameter days: Number of days to analyze
    /// - Returns: Percentage of sessions without crashes
    func getCrashFreeSessionsPercentage(days: Int) async throws -> Double
    
    /// Gets statistics about crashes in the application
    /// - Parameter days: Number of days to analyze
    /// - Returns: Crash statistics object
    func getCrashStatistics(days: Int) async throws -> CrashStatistics
}

/// Context information for crashes and errors
public struct CrashContext {
    /// The screen or view where the error occurred
    public var screen: String?
    
    /// The specific action being performed when the error occurred
    public var action: String?
    
    /// Current app state information
    public var appState: [String: Any]?
    
    /// Current device state information
    public var deviceState: [String: Any]?
    
    /// User information (non-identifiable) that may be relevant
    public var userInfo: [String: Any]?
    
    /// Value indicating if the issue is likely to be fatal for app stability
    public var isFatal: Bool
    
    public init(
        screen: String? = nil,
        action: String? = nil,
        appState: [String: Any]? = nil,
        deviceState: [String: Any]? = nil,
        userInfo: [String: Any]? = nil,
        isFatal: Bool = false
    ) {
        self.screen = screen
        self.action = action
        self.appState = appState
        self.deviceState = deviceState
        self.userInfo = userInfo
        self.isFatal = isFatal
    }
}

/// Severity levels for crash log messages
public enum CrashLogLevel: String {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case fatal = "fatal"
}

/// Statistics about application crashes
public struct CrashStatistics {
    /// Percentage of crash-free users
    public var crashFreeUsers: Double
    
    /// Percentage of crash-free sessions
    public var crashFreeSessions: Double
    
    /// Total number of crashes
    public var totalCrashes: Int
    
    /// Total number of affected users
    public var affectedUsers: Int
    
    /// Most common crash types by count
    public var crashTypeBreakdown: [String: Int]
    
    /// Most common device models experiencing crashes
    public var deviceModelBreakdown: [String: Int]
    
    /// Most common OS versions experiencing crashes
    public var osVersionBreakdown: [String: Int]
    
    /// Most common app versions experiencing crashes
    public var appVersionBreakdown: [String: Int]
    
    public init(
        crashFreeUsers: Double,
        crashFreeSessions: Double,
        totalCrashes: Int,
        affectedUsers: Int,
        crashTypeBreakdown: [String: Int],
        deviceModelBreakdown: [String: Int],
        osVersionBreakdown: [String: Int],
        appVersionBreakdown: [String: Int]
    ) {
        self.crashFreeUsers = crashFreeUsers
        self.crashFreeSessions = crashFreeSessions
        self.totalCrashes = totalCrashes
        self.affectedUsers = affectedUsers
        self.crashTypeBreakdown = crashTypeBreakdown
        self.deviceModelBreakdown = deviceModelBreakdown
        self.osVersionBreakdown = osVersionBreakdown
        self.appVersionBreakdown = appVersionBreakdown
    }
} 