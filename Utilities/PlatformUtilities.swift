import Foundation
import SwiftUI

/// Utilities for platform-specific functionality
public enum PlatformUtilities {
    #if os(iOS)
    /// Open the system settings app (iOS only)
    public static func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    #else
    /// Open the system settings app (placeholder for non-iOS platforms)
    public static func openSettings() {
        print("Opening settings is only available on iOS")
    }
    #endif
    
    /// Share content using the system share sheet
    /// - Parameter items: Items to share
    public static func shareContent(_ items: [Any]) {
        #if os(iOS)
        DispatchQueue.main.async {
            let activityVC = UIActivityViewController(
                activityItems: items,
                applicationActivities: nil
            )
            
            // Find the top view controller to present from
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                var topController = rootViewController
                while let presentedViewController = topController.presentedViewController {
                    topController = presentedViewController
                }
                topController.present(activityVC, animated: true)
            }
        }
        #elseif os(macOS)
        // On macOS, logging for now
        print("Share content requested for: \(items)")
        #endif
    }
    
    /// Open a URL in the default browser
    /// - Parameter urlString: The URL to open
    /// - Returns: Whether the URL was opened successfully
    @discardableResult
    public static func openURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        #if os(iOS)
        return UIApplication.shared.open(url)
        #elseif os(macOS)
        return NSWorkspace.shared.open(url)
        #else
        return false
        #endif
    }
    
    /// Open a deep link inside the app or fallback to browser
    /// - Parameter urlString: The URL to open
    /// - Returns: Whether the URL was handled successfully
    @discardableResult
    public static func handleDeepLink(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        // Handle app-specific deep links here
        // For now, just open in browser
        return openURL(url.absoluteString)
    }
} 