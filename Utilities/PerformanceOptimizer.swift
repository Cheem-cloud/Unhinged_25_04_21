import Foundation
import FirebaseFirestore

/// Utility for optimizing performance across the app
class PerformanceOptimizer {
    static let shared = PerformanceOptimizer()
    
    private init() {}
    
    // MARK: - Batch Processing

    /// Execute a Firestore batch write operation
    /// - Parameter operations: Closure that defines the batch operations
    func executeBatchWrite(_ operations: @escaping (WriteBatch) -> Void) async throws {
        let db = Firestore.firestore()
        let batch = db.batch()
        
        // Define operations on the batch
        operations(batch)
        
        // Commit the batch
        try await batch.commit()
    }
    
    /// Execute multiple Firestore operations in parallel
    /// - Parameter operations: Array of async operations to execute
    /// - Returns: Array of results in the same order as the operations
    func executeParallelOperations<T>(_ operations: [() async throws -> T]) async throws -> [T] {
        try await withThrowingTaskGroup(of: (Int, T).self) { group in
            for (index, operation) in operations.enumerated() {
                group.addTask {
                    let result = try await operation()
                    return (index, result)
                }
            }
            
            // Collect and order results
            var results = [(Int, T)]()
            for try await result in group {
                results.append(result)
            }
            
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
    
    // MARK: - Data Prefetching
    
    /// Prefetch data that will likely be needed soon
    /// - Parameter userId: User ID to prefetch data for
    func prefetchUserData(for userId: String) {
        Task {
            async let user = Firestore.firestore().collection("users").document(userId).getDocument()
            async let relationships = Firestore.firestore().collection("relationships")
                .whereField("userIds", arrayContains: userId)
                .limit(to: 1)
                .getDocuments()
            
            // We're not using the results directly, just warming up the cache
            _ = try? await (user, relationships)
        }
    }
    
    // MARK: - Cache Management
    
    private var memoryCache = NSCache<NSString, AnyObject>()
    
    /// Store an object in memory cache
    /// - Parameters:
    ///   - object: Object to cache
    ///   - key: Cache key
    func cacheObject<T: AnyObject>(_ object: T, forKey key: String) {
        memoryCache.setObject(object, forKey: key as NSString)
    }
    
    /// Retrieve an object from memory cache
    /// - Parameter key: Cache key
    /// - Returns: Cached object or nil if not found
    func cachedObject<T: AnyObject>(forKey key: String) -> T? {
        return memoryCache.object(forKey: key as NSString) as? T
    }
    
    /// Clear cached object
    /// - Parameter key: Cache key to clear
    func clearCachedObject(forKey key: String) {
        memoryCache.removeObject(forKey: key as NSString)
    }
    
    // MARK: - Performance Monitoring
    
    /// Measure execution time of a task
    /// - Parameters:
    ///   - taskName: Name of the task being measured
    ///   - task: Task to execute and measure
    /// - Returns: Result of the task
    func measurePerformance<T>(of taskName: String, task: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try task()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        print("⏱️ \(taskName) completed in \(String(format: "%.4f", timeElapsed))s")
        
        // Log slow operations for investigation
        if timeElapsed > 0.5 {
            print("⚠️ Warning: \(taskName) took more than 500ms to complete (\(String(format: "%.4f", timeElapsed * 1000))ms)")
        }
        
        return result
    }
    
    /// Measure execution time of an async task
    /// - Parameters:
    ///   - taskName: Name of the task being measured
    ///   - task: Async task to execute and measure
    /// - Returns: Result of the task
    func measureAsyncPerformance<T>(of taskName: String, task: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await task()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        print("⏱️ \(taskName) completed in \(String(format: "%.4f", timeElapsed))s")
        
        // Log slow operations for investigation
        if timeElapsed > 1.0 {
            print("⚠️ Warning: Async \(taskName) took more than 1s to complete (\(String(format: "%.4f", timeElapsed * 1000))ms)")
        }
        
        return result
    }
} 