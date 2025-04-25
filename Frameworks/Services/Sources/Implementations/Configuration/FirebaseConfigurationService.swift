import Foundation
import Firebase
import FirebaseRemoteConfig


/// Firebase implementation of the ConfigurationService protocol
public class FirebaseConfigurationService: ConfigurationService {
    /// Remote config instance
    private let remoteConfig: RemoteConfig
    
    /// User defaults for local config storage
    private let userDefaults = UserDefaults.standard
    
    /// Local config prefix to avoid key collisions
    private let localConfigPrefix = "local_config_"
    
    /// Observer mapping
    private var observers: [String: [ObjectIdentifier: (Any?) -> Void]] = [:]
    
    public init() {
        print("⚙️ FirebaseConfigurationService initialized")
        
        // Initialize Remote Config
        remoteConfig = RemoteConfig.remoteConfig()
        
        // Configure Remote Config
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600 // 1 hour in seconds
        remoteConfig.configSettings = settings
        
        // Set default values for common configurations
        let defaultValues: [String: NSObject] = [
            ConfigKey.appEnvironment.key: "development" as NSObject,
            ConfigKey.debugModeEnabled.key: false as NSObject,
            ConfigKey.apiBaseURL.key: "https://api.unhinged.app" as NSObject,
            ConfigKey.enableAnalytics.key: true as NSObject
        ]
        
        remoteConfig.setDefaults(defaultValues)
        
        // Fetch remote config on initialization
        Task {
            _ = await fetchRemoteConfig(expirationDuration: 0)
        }
    }
    
    public func getBoolValue(for key: String, defaultValue: Bool) async -> Bool {
        // Check local config first
        let localKey = localConfigPrefix + key
        if userDefaults.object(forKey: localKey) != nil {
            return userDefaults.bool(forKey: localKey)
        }
        
        // Then check remote config
        return remoteConfig.configValue(forKey: key).boolValue
    }
    
    public func getStringValue(for key: String, defaultValue: String) async -> String {
        // Check local config first
        let localKey = localConfigPrefix + key
        if let localValue = userDefaults.string(forKey: localKey) {
            return localValue
        }
        
        // Then check remote config
        let value = remoteConfig.configValue(forKey: key).stringValue
        return value ?? defaultValue
    }
    
    public func getNumberValue(for key: String, defaultValue: Double) async -> Double {
        // Check local config first
        let localKey = localConfigPrefix + key
        if userDefaults.object(forKey: localKey) != nil {
            return userDefaults.double(forKey: localKey)
        }
        
        // Then check remote config
        return remoteConfig.configValue(forKey: key).numberValue?.doubleValue ?? defaultValue
    }
    
    public func getDictionaryValue(for key: String, defaultValue: [String: Any]) async -> [String: Any] {
        // Check local config first
        let localKey = localConfigPrefix + key
        if let localDict = userDefaults.dictionary(forKey: localKey) {
            return localDict
        }
        
        // Then check remote config
        if let jsonData = remoteConfig.configValue(forKey: key).dataValue {
            do {
                if let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    return jsonDict
                }
            } catch {
                print("Error deserializing dictionary for key \(key): \(error.localizedDescription)")
            }
        }
        
        return defaultValue
    }
    
    public func getDataValue(for key: String, defaultValue: Data) async -> Data {
        // Check local config first
        let localKey = localConfigPrefix + key
        if let localData = userDefaults.data(forKey: localKey) {
            return localData
        }
        
        // Then check remote config
        return remoteConfig.configValue(forKey: key).dataValue ?? defaultValue
    }
    
    public func getObjectValue<T>(for key: String, as type: T.Type, defaultValue: T) async -> T where T: Decodable {
        // Check local config first
        let localKey = localConfigPrefix + key
        if let localData = userDefaults.data(forKey: localKey) {
            do {
                let object = try JSONDecoder().decode(type, from: localData)
                return object
            } catch {
                print("Error decoding local object for key \(key): \(error.localizedDescription)")
            }
        }
        
        // Then check remote config
        if let jsonData = remoteConfig.configValue(forKey: key).dataValue {
            do {
                let object = try JSONDecoder().decode(type, from: jsonData)
                return object
            } catch {
                print("Error decoding remote object for key \(key): \(error.localizedDescription)")
            }
        }
        
        return defaultValue
    }
    
    public func setLocalValue(_ value: Any, for key: String) async {
        let localKey = localConfigPrefix + key
        userDefaults.set(value, forKey: localKey)
        
        // Notify observers
        notifyObservers(for: key, value: value)
    }
    
    public func fetchRemoteConfig(expirationDuration: TimeInterval) async -> Bool {
        return await withCheckedContinuation { continuation in
            remoteConfig.fetch(withExpirationDuration: expirationDuration) { [weak self] status, error in
                if status == .success {
                    print("Config fetched successfully")
                    self?.remoteConfig.activate { changed, error in
                        continuation.resume(returning: (error == nil))
                    }
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    public func activateRemoteConfig() async -> Bool {
        return await withCheckedContinuation { continuation in
            remoteConfig.activate { changed, error in
                continuation.resume(returning: (error == nil))
            }
        }
    }
    
    public func getAllConfigurationKeys() async -> [String] {
        var keys = Set(ConfigKey.allCases.map { $0.key })
        
        // Add keys from remote config
        for key in remoteConfig.allKeys(from: .remote) {
            keys.insert(key)
        }
        
        // Add keys from local config
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.hasPrefix(localConfigPrefix) {
                let configKey = String(key.dropFirst(localConfigPrefix.count))
                keys.insert(configKey)
            }
        }
        
        return Array(keys)
    }
    
    public func resetLocalConfigurations() async {
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix(localConfigPrefix) {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    public func addObserver(for key: String, observer: AnyObject, handler: @escaping (Any?) -> Void) {
        let identifier = ObjectIdentifier(observer)
        
        if observers[key] == nil {
            observers[key] = [:]
        }
        
        observers[key]?[identifier] = handler
    }
    
    public func removeObserver(_ observer: AnyObject) {
        let identifier = ObjectIdentifier(observer)
        
        for key in observers.keys {
            observers[key]?[identifier] = nil
        }
    }
    
    // MARK: - Private Methods
    
    /// Notify all observers of a configuration change
    private func notifyObservers(for key: String, value: Any?) {
        if let handlers = observers[key]?.values {
            for handler in handlers {
                handler(value)
            }
        }
    }
} 