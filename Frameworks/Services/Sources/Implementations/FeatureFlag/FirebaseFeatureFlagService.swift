import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth


/// Firebase implementation of the FeatureFlagService protocol
public class FirebaseFeatureFlagService: FeatureFlagService {
    /// Firebase Firestore database
    private let db = Firestore.firestore()
    
    /// Collection reference for feature flags
    private let featureFlagsCollection = "featureFlags"
    
    /// Local cache of feature flags
    private var featureFlagsCache: [String: FeatureFlag] = [:]
    
    /// Last sync time
    private var lastSyncTime: Date?
    
    /// Flag to indicate if sync is in progress
    private var isSyncing = false
    
    /// Queue for synchronizing access to the cache
    private let cacheQueue = DispatchQueue(label: "com.unhinged.featureflags.cache", attributes: .concurrent)
    
    public init() {
        print("📱 FirebaseFeatureFlagService initialized")
    }
    
    public func getAllFeatureFlags() async throws -> [String: FeatureFlag] {
        // Check if we need to sync (if cache is empty or sync hasn't happened recently)
        if featureFlagsCache.isEmpty || shouldSyncCache() {
            await syncFeatureFlags(completion: nil)
        }
        
        // Return the cached flags
        return cacheQueue.sync { featureFlagsCache }
    }
    
    public func getFeatureFlag(key: String) async throws -> FeatureFlag? {
        // Try to get from cache first
        if let cachedFlag = cacheQueue.sync(execute: { featureFlagsCache[key] }) {
            return cachedFlag
        }
        
        // If not in cache, try to get directly from Firestore
        let query = db.collection(featureFlagsCollection).whereField("key", isEqualTo: key)
        let snapshot = try await query.getDocuments()
        
        guard let document = snapshot.documents.first else {
            return nil
        }
        
        var featureFlag = try FirestoreDecoder().decode(FeatureFlag.self, from: document.data())
        if featureFlag.id == nil {
            featureFlag.id = document.documentID
        }
        
        // Add to cache
        cacheQueue.async(flags: .barrier) {
            self.featureFlagsCache[key] = featureFlag
        }
        
        return featureFlag
    }
    
    public func isFeatureEnabled(key: String, defaultValue: Bool) async -> Bool {
        do {
            // Try to get the feature flag
            guard let flag = try await getFeatureFlag(key: key) else {
                return defaultValue
            }
            
            // Check if globally enabled
            if flag.isEnabled {
                // Check if user-specific disabling applies
                if let currentUserID = Auth.auth().currentUser?.uid,
                   let disabledUserIDs = flag.disabledUserIDs,
                   disabledUserIDs.contains(currentUserID) {
                    return false
                }
                
                // Check rollout percentage if specified
                if let rolloutPercentage = flag.rolloutPercentage {
                    if rolloutPercentage >= 100 {
                        return true
                    } else if rolloutPercentage <= 0 {
                        return false
                    } else {
                        // Calculate random percentage based on user ID or device ID
                        let userOrDeviceID = Auth.auth().currentUser?.uid ?? UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
                        let hash = userOrDeviceID.hashValue
                        let normalizedHash = abs(hash) % 100
                        return normalizedHash < rolloutPercentage
                    }
                }
                
                return true
            } else {
                // Check if user-specific enabling applies
                if let currentUserID = Auth.auth().currentUser?.uid,
                   let enabledUserIDs = flag.enabledUserIDs,
                   enabledUserIDs.contains(currentUserID) {
                    return true
                }
                
                return false
            }
        } catch {
            print("Error checking feature flag: \(error.localizedDescription)")
            return defaultValue
        }
    }
    
    public func isFeatureEnabledForUser(key: String, userID: String, defaultValue: Bool) async -> Bool {
        do {
            // Try to get the feature flag
            guard let flag = try await getFeatureFlag(key: key) else {
                return defaultValue
            }
            
            // Check if user is specifically disabled
            if let disabledUserIDs = flag.disabledUserIDs, disabledUserIDs.contains(userID) {
                return false
            }
            
            // Check if user is specifically enabled
            if let enabledUserIDs = flag.enabledUserIDs, enabledUserIDs.contains(userID) {
                return true
            }
            
            // If no user-specific rules, return the global setting
            if let rolloutPercentage = flag.rolloutPercentage {
                if rolloutPercentage >= 100 {
                    return true
                } else if rolloutPercentage <= 0 {
                    return false
                } else {
                    // Calculate based on user ID
                    let hash = userID.hashValue
                    let normalizedHash = abs(hash) % 100
                    return normalizedHash < rolloutPercentage
                }
            }
            
            return flag.isEnabled
        } catch {
            print("Error checking feature flag for user: \(error.localizedDescription)")
            return defaultValue
        }
    }
    
    public func updateFeatureFlag(
        key: String,
        isEnabled: Bool,
        description: String? = nil,
        rolloutPercentage: Int? = nil,
        enabledUserIDs: [String]? = nil,
        disabledUserIDs: [String]? = nil
    ) async throws {
        // Check authentication
        guard Auth.auth().currentUser != nil else {
            throw NSError(domain: "FirebaseFeatureFlagService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required to update feature flags"])
        }
        
        // Validate rollout percentage
        if let percentage = rolloutPercentage, (percentage < 0 || percentage > 100) {
            throw NSError(domain: "FirebaseFeatureFlagService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Rollout percentage must be between 0 and 100"])
        }
        
        // Check if the flag already exists
        let query = db.collection(featureFlagsCollection).whereField("key", isEqualTo: key)
        let snapshot = try await query.getDocuments()
        
        if let document = snapshot.documents.first {
            // Update existing flag
            var featureFlag = try FirestoreDecoder().decode(FeatureFlag.self, from: document.data())
            
            // Update fields
            featureFlag.isEnabled = isEnabled
            if let description = description {
                featureFlag.description = description
            }
            featureFlag.rolloutPercentage = rolloutPercentage
            if let enabledUserIDs = enabledUserIDs {
                featureFlag.enabledUserIDs = enabledUserIDs
            }
            if let disabledUserIDs = disabledUserIDs {
                featureFlag.disabledUserIDs = disabledUserIDs
            }
            featureFlag.updatedAt = Date()
            
            // Save to Firestore
            let flagData = try FirestoreEncoder().encode(featureFlag) as? [String: Any] ?? [:]
            try await db.collection(featureFlagsCollection).document(document.documentID).setData(flagData)
            
            // Update cache
            cacheQueue.async(flags: .barrier) {
                self.featureFlagsCache[key] = featureFlag
            }
        } else {
            // Create new flag
            let featureFlag = FeatureFlag(
                key: key,
                isEnabled: isEnabled,
                description: description,
                rolloutPercentage: rolloutPercentage,
                enabledUserIDs: enabledUserIDs,
                disabledUserIDs: disabledUserIDs,
                createdAt: Date(),
                updatedAt: Date(),
                isTesting: false,
                environment: .all
            )
            
            // Save to Firestore
            let flagData = try FirestoreEncoder().encode(featureFlag) as? [String: Any] ?? [:]
            let docRef = try await db.collection(featureFlagsCollection).addDocument(data: flagData)
            
            // Update cache with ID
            var flagWithID = featureFlag
            flagWithID.id = docRef.documentID
            cacheQueue.async(flags: .barrier) {
                self.featureFlagsCache[key] = flagWithID
            }
        }
    }
    
    public func deleteFeatureFlag(key: String) async throws {
        // Check authentication
        guard Auth.auth().currentUser != nil else {
            throw NSError(domain: "FirebaseFeatureFlagService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required to delete feature flags"])
        }
        
        // Find the flag
        let query = db.collection(featureFlagsCollection).whereField("key", isEqualTo: key)
        let snapshot = try await query.getDocuments()
        
        guard let document = snapshot.documents.first else {
            throw NSError(domain: "FirebaseFeatureFlagService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Feature flag not found"])
        }
        
        // Delete from Firestore
        try await db.collection(featureFlagsCollection).document(document.documentID).delete()
        
        // Remove from cache
        cacheQueue.async(flags: .barrier) {
            self.featureFlagsCache.removeValue(forKey: key)
        }
    }
    
    public func syncFeatureFlags(completion: ((Error?) -> Void)?) async {
        // Prevent multiple syncs from running simultaneously
        if isSyncing {
            completion?(nil)
            return
        }
        
        isSyncing = true
        
        do {
            // Fetch all feature flags from Firestore
            let snapshot = try await db.collection(featureFlagsCollection).getDocuments()
            
            // Update cache with new data
            var newCache: [String: FeatureFlag] = [:]
            
            for document in snapshot.documents {
                do {
                    var featureFlag = try FirestoreDecoder().decode(FeatureFlag.self, from: document.data())
                    if featureFlag.id == nil {
                        featureFlag.id = document.documentID
                    }
                    newCache[featureFlag.key] = featureFlag
                } catch {
                    print("Error decoding feature flag: \(error.localizedDescription)")
                }
            }
            
            // Update cache and sync time
            cacheQueue.async(flags: .barrier) {
                self.featureFlagsCache = newCache
                self.lastSyncTime = Date()
                self.isSyncing = false
                
                DispatchQueue.main.async {
                    completion?(nil)
                }
            }
        } catch {
            print("Error syncing feature flags: \(error.localizedDescription)")
            isSyncing = false
            DispatchQueue.main.async {
                completion?(error)
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Check if we should sync the cache (if it's been more than 15 minutes)
    private func shouldSyncCache() -> Bool {
        guard let lastSync = lastSyncTime else {
            return true
        }
        
        // Sync if last sync was more than 15 minutes ago
        return Date().timeIntervalSince(lastSync) > 900
    }
} 