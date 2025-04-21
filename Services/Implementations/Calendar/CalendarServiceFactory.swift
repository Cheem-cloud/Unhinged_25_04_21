import Foundation

/// Factory for creating calendar service instances
class CalendarServiceFactory {
    /// Shared instance of the factory
    static let shared = CalendarServiceFactory()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// Create a CalendarService instance
    /// - Returns: An instance of CalendarService
    func createCalendarService() -> CRUDService {
        // Get the CalendarServiceAdapter from ServiceManager
        return ServiceManager.shared.getService(CRUDService.self)
    }
    
    /// Get a calendar provider for the specified type
    /// - Parameter type: The type of calendar provider
    /// - Returns: A calendar provider instance
    func getProvider(for type: CalendarProviderType) -> CalendarProviderProtocol {
        switch type {
        case .google:
            return GoogleCalendarProvider()
        case .outlook:
            return OutlookCalendarProvider()
        case .apple:
            return AppleCalendarProvider()
        }
    }
    
    /// Get all available calendar providers
    /// - Returns: Array of calendar providers
    func getAllProviders() -> [CalendarProviderProtocol] {
        let providers: [CalendarProviderProtocol] = [
            getProvider(for: .google),
            getProvider(for: .outlook),
            getProvider(for: .apple)
        ]
        
        return providers
    }
    
    /// Get a calendar provider from provider settings
    /// - Parameter settings: The calendar provider settings
    /// - Returns: A calendar provider instance
    func getProviderFromSettings(_ settings: CalendarProviderSettings) -> CalendarProviderProtocol {
        let provider = getProvider(for: settings.providerType)
        
        // Configure the provider with settings if needed
        if let accessToken = settings.accessToken {
            provider.configure(accessToken: accessToken, refreshToken: settings.refreshToken)
        }
        
        return provider
    }
} 