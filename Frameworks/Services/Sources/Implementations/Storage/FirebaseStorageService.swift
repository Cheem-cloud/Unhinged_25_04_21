import Foundation
import Firebase
import FirebaseStorage
#if canImport(UIKit)
import UIKit
#endif


/// Firebase implementation of the StorageService protocol
public class FirebaseStorageService: StorageService {
    /// Firebase Storage reference
    private let storage = Storage.storage().reference()
    
    /// Maximum file size for download (50MB)
    private let maxDownloadSize: Int64 = 50 * 1024 * 1024
    
    public init() {
        print("📱 FirebaseStorageService initialized")
    }
    
    public func uploadData(_ data: Data, to path: String, metadata: [String: String]? = nil) async throws -> URL {
        let storageRef = storage.child(path)
        
        var storageMetadata: StorageMetadata?
        if let metadata = metadata {
            storageMetadata = StorageMetadata()
            for (key, value) in metadata {
                storageMetadata?.customMetadata?[key] = value
            }
            
            // Set content type if provided
            if let contentType = metadata["contentType"] {
                storageMetadata?.contentType = contentType
            }
        }
        
        _ = try await storageRef.putDataAsync(data, metadata: storageMetadata)
        return try await storageRef.downloadURL()
    }
    
    public func uploadImage(_ image: UIImage, to path: String, compressionQuality: CGFloat = 0.8, metadata: [String: String]? = nil) async throws -> URL {
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            throw NSError(domain: "FirebaseStorageService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG data"])
        }
        
        var updatedMetadata = metadata ?? [:]
        updatedMetadata["contentType"] = "image/jpeg"
        
        return try await uploadData(imageData, to: path, metadata: updatedMetadata)
    }
    
    public func downloadData(from path: String) async throws -> Data {
        let storageRef = storage.child(path)
        return try await storageRef.data(maxSize: maxDownloadSize)
    }
    
    public func getDownloadURL(for path: String) async throws -> URL {
        let storageRef = storage.child(path)
        return try await storageRef.downloadURL()
    }
    
    public func deleteFile(at path: String) async throws {
        let storageRef = storage.child(path)
        try await storageRef.delete()
    }
    
    public func fileExists(at path: String) async throws -> Bool {
        let storageRef = storage.child(path)
        
        do {
            _ = try await storageRef.getMetadata()
            return true
        } catch {
            // Check if the error is because the file doesn't exist
            if let error = error as NSError {
                if error.domain == StorageErrorDomain,
                   error.code == StorageErrorCode.objectNotFound.rawValue {
                    return false
                }
            }
            // If it's another error, rethrow it
            throw error
        }
    }
    
    public func listFiles(in directory: String) async throws -> [String] {
        let storageRef = storage.child(directory)
        let result = try await storageRef.listAll()
        
        // Extract names of items
        return result.items.map { $0.name }
    }
    
    public func getMetadata(for path: String) async throws -> [String: Any] {
        let storageRef = storage.child(path)
        let metadata = try await storageRef.getMetadata()
        
        var result: [String: Any] = [
            "name": metadata.name ?? "",
            "path": metadata.path ?? "",
            "size": metadata.size,
            "creationTime": metadata.timeCreated?.timeIntervalSince1970 ?? 0,
            "updatedTime": metadata.updated?.timeIntervalSince1970 ?? 0,
            "contentType": metadata.contentType ?? ""
        ]
        
        // Add custom metadata
        if let customMetadata = metadata.customMetadata {
            for (key, value) in customMetadata {
                result[key] = value
            }
        }
        
        return result
    }
    
    public func updateMetadata(for path: String, metadata: [String: String]) async throws {
        let storageRef = storage.child(path)
        let storageMetadata = StorageMetadata()
        
        // Set content type if provided
        if let contentType = metadata["contentType"] {
            storageMetadata.contentType = contentType
        }
        
        // Set custom metadata
        for (key, value) in metadata {
            if key != "contentType" {
                storageMetadata.customMetadata?[key] = value
            }
        }
        
        _ = try await storageRef.updateMetadata(storageMetadata)
    }
    
    public func generateUniqueFilename(with fileExtension: String) -> String {
        let uuid = UUID().uuidString
        let cleanExtension = fileExtension.starts(with: ".") ? fileExtension : ".\(fileExtension)"
        return "\(uuid)\(cleanExtension)"
    }
} 