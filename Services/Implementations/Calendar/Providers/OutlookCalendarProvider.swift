import Foundation

/// Implementation of CalendarProviderProtocol for Microsoft Outlook Calendar
class OutlookCalendarProvider: CalendarProviderProtocol {
    /// The base URL for Microsoft Graph API
    private let baseURL = "https://graph.microsoft.com/v1.0"
    
    /// Client ID for Microsoft OAuth
    private let clientID: String
    
    /// Client secret for Microsoft OAuth
    private let clientSecret: String
    
    /// Redirect URI for OAuth callback
    private let redirectURI: String
    
    /// Provider type
    var providerType: CalendarProviderType {
        return .outlook
    }
    
    private var accessToken: String?
    private var refreshToken: String?
    
    /// Initialize with OAuth credentials
    /// - Parameters:
    ///   - clientID: The Microsoft OAuth client ID
    ///   - clientSecret: The Microsoft OAuth client secret
    ///   - redirectURI: The redirect URI for OAuth callback
    init(clientID: String, clientSecret: String, redirectURI: String) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
    }
    
    /// Initialize the provider
    init() {
        // Initialize with config values
        self.clientID = CalendarConfig.Microsoft.clientID
        self.clientSecret = CalendarConfig.Microsoft.clientSecret
        self.redirectURI = CalendarConfig.Microsoft.redirectURI
    }
    
    func configure(accessToken: String, refreshToken: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
    
    /// Get user's availability by checking their Outlook Calendar
    /// - Parameters:
    ///   - userID: The user ID
    ///   - startDate: The start date to check
    ///   - endDate: The end date to check
    /// - Returns: Array of busy time slots
    func getAvailability(userID: String, startDate: Date, endDate: Date) async throws -> [BusyTimeSlot] {
        // Implement Outlook integration
        // For now, return simulated data
        return simulatedBusyTimes(startDate: startDate, endDate: endDate)
    }
    
    /// Create a calendar event in Outlook Calendar
    /// - Parameters:
    ///   - event: The event to create
    ///   - userID: The user ID
    /// - Returns: The ID of the created event
    func createEvent(event: CalendarEventModel, userID: String) async throws -> String {
        // Implementation would create the event in Outlook Calendar
        
        // For now, return a simulated event ID
        return "outlook-event-\(UUID().uuidString)"
    }
    
    /// Update an existing calendar event
    /// - Parameters:
    ///   - eventID: The ID of the event to update
    ///   - event: The updated event data
    ///   - userID: The user ID
    func updateEvent(eventID: String, event: CalendarEventModel, userID: String) async throws {
        // Implementation would update the event in Outlook Calendar
        print("Simulated update of event \(eventID) in Outlook Calendar")
    }
    
    /// Delete a calendar event
    /// - Parameters:
    ///   - eventID: The ID of the event to delete
    ///   - userID: The user ID
    func deleteEvent(eventID: String, userID: String) async throws {
        // Implement event deletion in Outlook
        print("Simulated deletion of event \(eventID) from Outlook")
    }
    
    /// Get authorization URL for Microsoft OAuth
    /// - Returns: URL to redirect the user for authorization
    func getAuthorizationURL() -> URL? {
        let baseURL = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
        
        // Join scopes with space
        let scopesString = CalendarConfig.Microsoft.scopes.joined(separator: " ")
        
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "scope", value: scopesString),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        
        return components?.url
    }
    
    /// Handle OAuth callback and exchange code for tokens
    /// - Parameter url: The callback URL with authorization code
    /// - Returns: The access and refresh tokens
    func handleAuthCallback(url: URL) async throws -> (accessToken: String, refreshToken: String) {
        // Extract authorization code from URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw CalendarError.authorizationFailed
        }
        
        // Token endpoint
        let tokenURL = URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Prepare request body
        let body = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "scope": CalendarConfig.Microsoft.scopes.joined(separator: " ")
        ]
        
        // Encode body as form data
        let bodyString = body.map { key, value in
            return "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }.joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CalendarError.tokenExchangeFailed
        }
        
        // Parse response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let accessToken = json["access_token"] as? String,
           let refreshToken = json["refresh_token"] as? String {
            return (accessToken: accessToken, refreshToken: refreshToken)
        }
        
        throw CalendarError.tokenExchangeFailed
    }
    
    /// Refresh the access token using a refresh token
    /// - Parameter refreshToken: The refresh token
    /// - Returns: The new access token and expiration date
    func refreshAccessToken(refreshToken: String) async throws -> (accessToken: String, expirationDate: Date) {
        // Token endpoint
        let tokenURL = URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Prepare request body
        let body = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
            "scope": CalendarConfig.Microsoft.scopes.joined(separator: " ")
        ]
        
        // Encode body as form data
        let bodyString = body.map { key, value in
            return "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }.joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CalendarError.tokenRefreshFailed
        }
        
        // Parse response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let accessToken = json["access_token"] as? String,
           let expiresIn = json["expires_in"] as? TimeInterval {
            let expirationDate = Date().addingTimeInterval(expiresIn)
            return (accessToken: accessToken, expirationDate: expirationDate)
        }
        
        throw CalendarError.tokenRefreshFailed
    }
    
    // MARK: - Helper Methods
    
    private func simulatedBusyTimes(startDate: Date, endDate: Date) -> [BusyTimeSlot] {
        // Generate some simulated busy times for demo purposes
        let calendar = Calendar.current
        var busyTimes: [BusyTimeSlot] = []
        
        // Create a busy slot for each day in the range
        var currentDate = startDate
        while currentDate < endDate {
            // Only create busy slots on weekdays
            let weekday = calendar.component(.weekday, from: currentDate)
            if (2...6).contains(weekday) { // Monday through Friday
                
                // Morning meeting: 10 AM - 11 AM
                if let startTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: currentDate),
                   let endTime = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: currentDate),
                   startTime >= startDate && endTime <= endDate {
                    
                    busyTimes.append(BusyTimeSlot(
                        startTime: startTime,
                        endTime: endTime,
                        title: "Team Meeting",
                        isAllDay: false
                    ))
                }
                
                // Lunch: 1 PM - 2 PM
                if let startTime = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: currentDate),
                   let endTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: currentDate),
                   startTime >= startDate && endTime <= endDate {
                    
                    busyTimes.append(BusyTimeSlot(
                        startTime: startTime,
                        endTime: endTime,
                        title: "Lunch Break",
                        isAllDay: false
                    ))
                }
            }
            
            // Move to next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        return busyTimes
    }
} 