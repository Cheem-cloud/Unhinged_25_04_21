// Core Module - Foundation Types and Models
// This file serves as the main entry point for the Core module

import Foundation
import SwiftUI

// Re-export key types for convenience
@_exported import struct Foundation.Date
@_exported import struct Foundation.URL
@_exported import struct Foundation.UUID
@_exported import struct Foundation.Data
@_exported import class Foundation.DateFormatter
@_exported import class Foundation.JSONEncoder
@_exported import class Foundation.JSONDecoder
@_exported import struct SwiftUI.Color
@_exported import struct SwiftUI.Font

// Public API
public struct Core {
    // Version information
    public static let version = "1.0.0"
    
    // Module initialization (if needed)
    public static func initialize() {
        print("Core module initialized")
    }
}
