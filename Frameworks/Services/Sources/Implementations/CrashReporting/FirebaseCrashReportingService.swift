import Foundation
import FirebaseCore
import FirebaseCrashlytics
import FirebaseAnalytics

/// Firebase implementation of the CrashReportingService protocol using Firebase Crashlytics
public class FirebaseCrashReportingService: CrashReportingService {
    /// Reference to the Crashlytics instance
    private let crashlytics = Crashlytics.crashlytics()
    
    /// Map to store crash statistics for caching purposes
    private var statisticsCache: [Int: CrashStatistics] = [:]
    
    /// Cache expiration time
    private let cacheExpirationTime: TimeInterval = 3600 // 1 hour
    
    /// Last cache update timestamp by days parameter
    private var lastCacheUpdate: [Int: Date] = [:]
    
    /// Initializes a new Firebase crash reporting service
    public init() {}
    
    /// Initializes the crash reporting service
    /// - Parameters:
    ///   - userId: Optional user identifier for associating crashes with users
    ///   - additionalInfo: Optional dictionary of additional information to include in crash reports
    public func initialize(userId: String?, additionalInfo: [String: Any]?) async throws {
        if let userId = userId {
            crashlytics.setUserID(userId)
        }
        
        if let additionalInfo = additionalInfo {
            for (key, value) in additionalInfo {
                crashlytics.setCustomValue(value, forKey: key)
            }
        }
        
        // Enable collection based on user consent (this is where we would check for user consent)
        // For now, we'll assume the user has consented since they're using the app
        crashlytics.setCrashlyticsCollectionEnabled(true)
    }
    
    /// Records a non-fatal error that occurred in the application
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - context: Additional contextual information about where/when the error occurred
    public func recordError(_ error: Error, context: CrashContext) async {
        let nsError = error as NSError
        
        // Add contextual information as custom keys
        await setContextKeys(context)
        
        // Create user info with context
        var userInfo = nsError.userInfo
        if let screen = context.screen {
            userInfo["screen"] = screen
        }
        if let action = context.action {
            userInfo["action"] = action
        }
        
        // Record the error
        let enrichedError = NSError(
            domain: nsError.domain,
            code: nsError.code,
            userInfo: userInfo
        )
        
        crashlytics.record(error: enrichedError)
    }
    
    /// Records a custom exception that occurred in the application
    /// - Parameters:
    ///   - name: Name of the exception
    ///   - reason: Reason the exception occurred
    ///   - stackTrace: Optional array of stack trace elements
    ///   - context: Additional contextual information about where/when the exception occurred
    public func recordException(name: String, reason: String, stackTrace: [String]?, context: CrashContext) async {
        // Add contextual information as custom keys
        await setContextKeys(context)
        
        // Create an exception model
        let exception = ExceptionModel(name: name, reason: reason)
        
        // Add stack frames if provided
        if let stackTrace = stackTrace {
            var frames: [StackFrame] = []
            for (index, line) in stackTrace.enumerated() {
                let frame = StackFrame()
                frame.fileName = "frame_\(index)"
                frame.lineNumber = UInt(index)
                frame.symbol = line
                frames.append(frame)
            }
            exception.stackTrace = frames
        }
        
        // Record the exception
        crashlytics.record(exceptionModel: exception)
    }
    
    /// Sets a custom key-value pair that will be included in crash reports
    /// - Parameters:
    ///   - key: The key for the custom value
    ///   - value: The value to set
    public func setCustomValue(_ value: Any, forKey key: String) async {
        crashlytics.setCustomValue(value, forKey: key)
    }
    
    /// Sets the user identifier for crash reports
    /// - Parameter userId: The user identifier
    public func setUserId(_ userId: String?) async {
        if let userId = userId {
            crashlytics.setUserID(userId)
        } else {
            // Clear user ID by setting an empty string
            crashlytics.setUserID("")
        }
    }
    
    /// Logs a message that will be included in crash reports
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The severity level of the message
    public func log(_ message: String, level: CrashLogLevel) async {
        let formattedMessage = "[\(level.rawValue.uppercased())] \(message)"
        crashlytics.log(format: "%@", arguments: getVaList([formattedMessage]))
    }
    
    /// Gets the crash-free users percentage over the last period
    /// - Parameter days: Number of days to analyze
    /// - Returns: Percentage of users who haven't experienced crashes
    public func getCrashFreeUsersPercentage(days: Int) async throws -> Double {
        // Check if we have a valid cached value
        if isCacheValid(for: days) {
            return statisticsCache[days]?.crashFreeUsers ?? 0
        }
        
        // In a real implementation, we would fetch this data from Firebase
        // Here we're returning a mock value for demonstration
        let statistics = try await fetchCrashStatistics(days: days)
        return statistics.crashFreeUsers
    }
    
    /// Gets the crash-free sessions percentage over the last period
    /// - Parameter days: Number of days to analyze
    /// - Returns: Percentage of sessions without crashes
    public func getCrashFreeSessionsPercentage(days: Int) async throws -> Double {
        // Check if we have a valid cached value
        if isCacheValid(for: days) {
            return statisticsCache[days]?.crashFreeSessions ?? 0
        }
        
        // In a real implementation, we would fetch this data from Firebase
        // Here we're returning a mock value for demonstration
        let statistics = try await fetchCrashStatistics(days: days)
        return statistics.crashFreeSessions
    }
    
    /// Gets statistics about crashes in the application
    /// - Parameter days: Number of days to analyze
    /// - Returns: Crash statistics object
    public func getCrashStatistics(days: Int) async throws -> CrashStatistics {
        // Check if we have a valid cached value
        if isCacheValid(for: days) {
            if let cachedStatistics = statisticsCache[days] {
                return cachedStatistics
            }
        }
        
        // In a real implementation, we would fetch this data from Firebase
        // Here we're mocking it
        return try await fetchCrashStatistics(days: days)
    }
    
    // MARK: - Private Helper Methods
    
    /// Sets context information as custom keys in Crashlytics
    /// - Parameter context: The context to set
    private func setContextKeys(_ context: CrashContext) async {
        if let screen = context.screen {
            crashlytics.setCustomValue(screen, forKey: "screen")
        }
        
        if let action = context.action {
            crashlytics.setCustomValue(action, forKey: "action")
        }
        
        if let appState = context.appState {
            for (key, value) in appState {
                crashlytics.setCustomValue(value, forKey: "app_state_\(key)")
            }
        }
        
        if let deviceState = context.deviceState {
            for (key, value) in deviceState {
                crashlytics.setCustomValue(value, forKey: "device_state_\(key)")
            }
        }
        
        if let userInfo = context.userInfo {
            for (key, value) in userInfo {
                // Avoid including sensitive information
                if !key.contains("password") && !key.contains("token") && !key.contains("secret") {
                    crashlytics.setCustomValue(value, forKey: "user_info_\(key)")
                }
            }
        }
        
        crashlytics.setCustomValue(context.isFatal, forKey: "is_fatal")
    }
    
    /// Checks if the cache is still valid for the given days parameter
    /// - Parameter days: The days parameter to check
    /// - Returns: True if the cache is valid, false otherwise
    private func isCacheValid(for days: Int) -> Bool {
        guard let lastUpdate = lastCacheUpdate[days],
              let cachedStats = statisticsCache[days] else {
            return false
        }
        
        let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
        return timeSinceLastUpdate < cacheExpirationTime && cachedStats.totalCrashes > 0
    }
    
    /// Fetches crash statistics for the given number of days
    /// - Parameter days: Number of days to analyze
    /// - Returns: Crash statistics object
    private func fetchCrashStatistics(days: Int) async throws -> CrashStatistics {
        // In a real implementation, this would fetch data from Firebase
        // For this demo, we're generating mock data
        
        // Generate realistic mock data
        let totalUsers = 1000 + (days * 50)
        let totalSessions = totalUsers * 5
        let affectedUsers = Int(Double(totalUsers) * (0.05 + (Double(arc4random_uniform(40)) / 1000.0)))
        let totalCrashes = affectedUsers + Int(Double(affectedUsers) * (0.2 + (Double(arc4random_uniform(60)) / 100.0)))
        
        let crashFreeUsers = 100.0 - (Double(affectedUsers) / Double(totalUsers) * 100.0)
        let crashFreeSessions = 100.0 - (Double(totalCrashes) / Double(totalSessions) * 100.0)
        
        // Common crash types
        let crashTypes: [String: Int] = [
            "Swift Runtime Error": Int(Double(totalCrashes) * 0.25),
            "UIKit Exception": Int(Double(totalCrashes) * 0.15),
            "Network Error": Int(Double(totalCrashes) * 0.12),
            "Memory Warning": Int(Double(totalCrashes) * 0.10),
            "Database Error": Int(Double(totalCrashes) * 0.08),
            "File I/O Error": Int(Double(totalCrashes) * 0.05),
            "Other": Int(Double(totalCrashes) * 0.25)
        ]
        
        // Device models
        let deviceModels: [String: Int] = [
            "iPhone 15 Pro": Int(Double(totalCrashes) * 0.20),
            "iPhone 14": Int(Double(totalCrashes) * 0.18),
            "iPhone 13": Int(Double(totalCrashes) * 0.15),
            "iPhone 12": Int(Double(totalCrashes) * 0.12),
            "iPhone SE": Int(Double(totalCrashes) * 0.10),
            "iPad Pro": Int(Double(totalCrashes) * 0.08),
            "Other": Int(Double(totalCrashes) * 0.17)
        ]
        
        // OS versions
        let osVersions: [String: Int] = [
            "iOS 17.4": Int(Double(totalCrashes) * 0.25),
            "iOS 17.3": Int(Double(totalCrashes) * 0.20),
            "iOS 17.2": Int(Double(totalCrashes) * 0.15),
            "iOS 17.1": Int(Double(totalCrashes) * 0.12),
            "iOS 16.5": Int(Double(totalCrashes) * 0.10),
            "iOS 16.4": Int(Double(totalCrashes) * 0.08),
            "Other": Int(Double(totalCrashes) * 0.10)
        ]
        
        // App versions
        let appVersions: [String: Int] = [
            "1.5.0": Int(Double(totalCrashes) * 0.30),
            "1.4.2": Int(Double(totalCrashes) * 0.22),
            "1.4.1": Int(Double(totalCrashes) * 0.18),
            "1.4.0": Int(Double(totalCrashes) * 0.15),
            "1.3.5": Int(Double(totalCrashes) * 0.10),
            "Other": Int(Double(totalCrashes) * 0.05)
        ]
        
        let statistics = CrashStatistics(
            crashFreeUsers: crashFreeUsers,
            crashFreeSessions: crashFreeSessions,
            totalCrashes: totalCrashes,
            affectedUsers: affectedUsers,
            crashTypeBreakdown: crashTypes,
            deviceModelBreakdown: deviceModels,
            osVersionBreakdown: osVersions,
            appVersionBreakdown: appVersions
        )
        
        // Cache the results
        statisticsCache[days] = statistics
        lastCacheUpdate[days] = Date()
        
        return statistics
    }
}

/// Error types specific to crash reporting operations
public enum CrashReportingError: Error {
    case initializationFailed(String)
    case retrievalFailed(String)
    case analyzeFailed(String)
    case invalidParameters(String)
}

extension CrashReportingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "Failed to initialize crash reporting: \(message)"
        case .retrievalFailed(let message):
            return "Failed to retrieve crash data: \(message)"
        case .analyzeFailed(let message):
            return "Failed to analyze crash data: \(message)"
        case .invalidParameters(let message):
            return "Invalid parameters for crash reporting: \(message)"
        }
    }
} 