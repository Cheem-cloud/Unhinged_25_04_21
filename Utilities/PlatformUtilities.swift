import SwiftUI

/// Utilities for handling platform-specific operations
public enum PlatformUtilities {
    
    /// Opens the system settings app
    /// - Returns: Whether the operation was successful
    public static func openSettings() -> Bool {
        #if os(iOS) || os(tvOS)
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            return UIApplication.shared.open(settingsURL)
        }
        return false
        #elseif os(macOS)
        // macOS implementation would go here
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
        return true
        #else
        // Default implementation for other platforms
        return false
        #endif
    }
    
    /// Opens a URL using the appropriate platform method
    /// - Parameter url: The URL to open
    /// - Returns: Whether the operation was successful
    public static func openURL(_ url: URL) -> Bool {
        #if os(iOS) || os(tvOS)
        return UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        return true
        #else
        return false
        #endif
    }
} 