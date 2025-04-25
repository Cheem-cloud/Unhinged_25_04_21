import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Protocol for handling file storage operations
public protocol StorageService {
    /// Upload data to storage
    /// - Parameters:
    ///   - data: The data to upload
    ///   - path: The path where the file should be stored
    ///   - metadata: Optional metadata for the file
    /// - Returns: Download URL of the uploaded file
    func uploadData(_ data: Data, to path: String, metadata: [String: String]?) async throws -> URL
    
    #if canImport(UIKit)
    /// Upload an image to storage
    /// - Parameters:
    ///   - image: The image to upload
    ///   - path: The path where the image should be stored
    ///   - compressionQuality: JPEG compression quality (0.0 to 1.0)
    ///   - metadata: Optional metadata for the image
    /// - Returns: Download URL of the uploaded image
    func uploadImage(_ image: UIImage, to path: String, compressionQuality: CGFloat, metadata: [String: String]?) async throws -> URL
    #endif
    
    /// Download data from storage
    /// - Parameter path: The path of the file to download
    /// - Returns: The downloaded data
    func downloadData(from path: String) async throws -> Data
    
    /// Get download URL for a file
    /// - Parameter path: The path of the file
    /// - Returns: The download URL
    func getDownloadURL(for path: String) async throws -> URL
    
    /// Delete a file from storage
    /// - Parameter path: The path of the file to delete
    func deleteFile(at path: String) async throws
    
    /// Check if a file exists at the given path
    /// - Parameter path: The path to check
    /// - Returns: Whether the file exists
    func fileExists(at path: String) async throws -> Bool
    
    /// List all files in a directory
    /// - Parameter directory: The directory path
    /// - Returns: Array of file names
    func listFiles(in directory: String) async throws -> [String]
    
    /// Get metadata for a file
    /// - Parameter path: The path of the file
    /// - Returns: The file metadata as a dictionary
    func getMetadata(for path: String) async throws -> [String: Any]
    
    /// Update metadata for a file
    /// - Parameters:
    ///   - path: The path of the file
    ///   - metadata: The new metadata
    func updateMetadata(for path: String, metadata: [String: String]) async throws
    
    /// Generate a unique filename for storage
    /// - Parameter fileExtension: The file extension
    /// - Returns: A unique filename
    func generateUniqueFilename(with fileExtension: String) -> String
} 