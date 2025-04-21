import Foundation
import FirebaseFirestore
import AuthenticationServices
import FirebaseAuth

/// Service for interacting with Microsoft Graph API (Outlook)
class MicrosoftGraphService {
    static let shared = MicrosoftGraphService()
    
    private let baseURL = "https://graph.microsoft.com/v1.0"
    private let db = Firestore.firestore()
    private var authSession: ASWebAuthenticationSession?
    
    // MARK: - Authentication
    
    /// Get Microsoft OAuth authorization URL
    func getAuthorizationURL() -> URL? {
        let baseURL = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
        
        // Define scopes for calendar access
        let scopes = ["Calendars.Read", "Calendars.ReadWrite"]
        let scopesString = scopes.joined(separator: " ")
        
        // Get configuration
        let clientID = Bundle.main.infoDictionary?["OUTLOOK_CLIENT_ID"] as? String ?? ""
        let redirectURI = Bundle.main.infoDictionary?["OUTLOOK_REDIRECT_URI"] as? String ?? "com.cheemhang.app://outlook-callback"
        
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
    
    /// Authenticate with Microsoft/Outlook
    func authenticate() async throws -> (String, String?) {
        guard let authURL = getAuthorizationURL() else {
            throw CalendarServiceError.invalidResponse
        }
        
        // Get top view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "com.cheemhang.calendar", code: 500, 
                  userInfo: [NSLocalizedDescriptionKey: "Could not get root view controller"])
        }
        
        // Perform web authentication
        return try await withCheckedThrowingContinuation { continuation in
            let callbackScheme = "com.cheemhang.app"
            
            let authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: CalendarError.authorizationFailed)
                    return
                }
                
                // Exchange code for token
                Task {
                    do {
                        let tokens = try await self.exchangeCodeForToken(from: callbackURL)
                        continuation.resume(returning: (tokens.accessToken, tokens.refreshToken))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // Store session and present it
            self.authSession = authSession
            authSession.presentationContextProvider = MSAuthPresenter.shared
            authSession.prefersEphemeralWebBrowserSession = false
            authSession.start()
        }
    }
    
    /// Exchange authorization code for access token
    func exchangeCodeForToken(from url: URL) async throws -> (accessToken: String, refreshToken: String?) {
        // Extract code from callback URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw CalendarError.authorizationFailed
        }
        
        // Token endpoint
        let tokenURL = URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!
        
        // Get configuration
        let clientID = Bundle.main.infoDictionary?["OUTLOOK_CLIENT_ID"] as? String ?? ""
        let clientSecret = Bundle.main.infoDictionary?["OUTLOOK_CLIENT_SECRET"] as? String ?? ""
        let redirectURI = Bundle.main.infoDictionary?["OUTLOOK_REDIRECT_URI"] as? String ?? "com.cheemhang.app://outlook-callback"
        
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
            "scope": "Calendars.Read Calendars.ReadWrite"
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
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw CalendarError.tokenExchangeFailed
        }
        
        let refreshToken = json["refresh_token"] as? String
        return (accessToken: accessToken, refreshToken: refreshToken)
    }
    
    /// Refresh access token
    func refreshAccessToken(refreshToken: String) async throws -> (accessToken: String, expirationDate: Date) {
        // Token endpoint
        let tokenURL = URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!
        
        // Get configuration
        let clientID = Bundle.main.infoDictionary?["OUTLOOK_CLIENT_ID"] as? String ?? ""
        let clientSecret = Bundle.main.infoDictionary?["OUTLOOK_CLIENT_SECRET"] as? String ?? ""
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Prepare request body
        let body = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
            "scope": "Calendars.Read Calendars.ReadWrite"
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
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? TimeInterval else {
            throw CalendarError.tokenRefreshFailed
        }
        
        let expirationDate = Date().addingTimeInterval(expiresIn)
        return (accessToken: accessToken, expirationDate: expirationDate)
    }
    
    // MARK: - Calendar Operations
    
    /// Get busy times from Outlook calendar
    func getBusyTimes(accessToken: String, startDate: Date, endDate: Date) async throws -> [(start: Date, end: Date)] {
        guard !accessToken.isEmpty else {
            throw CalendarServiceError.invalidToken
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let startTimeString = dateFormatter.string(from: startDate)
        let endTimeString = dateFormatter.string(from: endDate)
        
        // Use the calendarView endpoint to get events in the date range
        let urlString = "\(baseURL)/me/calendarView?startDateTime=\(startTimeString)&endDateTime=\(endTimeString)"
        
        guard let url = URL(string: urlString) else {
            throw CalendarServiceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CalendarServiceError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                print("Microsoft Graph API error: \(responseString)")
                throw CalendarServiceError.apiError("Status code: \(httpResponse.statusCode)")
            }
            
            // Parse the response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let events = json["value"] as? [[String: Any]] else {
                throw CalendarServiceError.parseError
            }
            
            // Convert events to busy times
            return events.compactMap { event -> (start: Date, end: Date)? in
                // Skip events where show as is "free"
                if let showAs = event["showAs"] as? String, showAs.lowercased() == "free" {
                    return nil
                }
                
                guard let start = event["start"] as? [String: Any],
                      let end = event["end"] as? [String: Any],
                      let startDateTime = start["dateTime"] as? String,
                      let endDateTime = end["dateTime"] as? String,
                      let startDate = dateFormatter.date(from: startDateTime),
                      let endDate = dateFormatter.date(from: endDateTime) else {
                    return nil
                }
                
                return (start: startDate, end: endDate)
            }
        } catch {
            print("Error fetching Outlook calendar events: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Create calendar event in Outlook
    func createCalendarEvent(
        accessToken: String,
        title: String,
        description: String,
        startDate: Date,
        endDate: Date,
        location: String?,
        attendees: [String]? = nil
    ) async throws -> String {
        guard !accessToken.isEmpty else {
            throw CalendarServiceError.invalidToken
        }
        
        let url = URL(string: "\(baseURL)/me/events")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dateFormatter = ISO8601DateFormatter()
        
        var eventBody: [String: Any] = [
            "subject": title,
            "body": [
                "contentType": "text",
                "content": description
            ],
            "start": [
                "dateTime": dateFormatter.string(from: startDate),
                "timeZone": TimeZone.current.identifier
            ],
            "end": [
                "dateTime": dateFormatter.string(from: endDate),
                "timeZone": TimeZone.current.identifier
            ]
        ]
        
        // Add attendees if provided
        if let attendees = attendees, !attendees.isEmpty {
            let attendeeObjects = attendees.map { email -> [String: Any] in
                return [
                    "emailAddress": ["address": email],
                    "type": "required"
                ]
            }
            eventBody["attendees"] = attendeeObjects
        }
        
        // Add location if provided
        if let location = location, !location.isEmpty {
            eventBody["location"] = ["displayName": location]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: eventBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CalendarServiceError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                print("Microsoft Graph API error creating event: \(responseString)")
                throw CalendarServiceError.apiError("Status code: \(httpResponse.statusCode)")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let eventId = json["id"] as? String else {
                throw CalendarServiceError.parseError
            }
            
            print("Successfully created Outlook calendar event with ID: \(eventId)")
            return eventId
        } catch {
            print("Error creating Outlook calendar event: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Delete calendar event from Outlook
    func deleteCalendarEvent(accessToken: String, eventId: String) async throws {
        guard !accessToken.isEmpty else {
            throw CalendarServiceError.invalidToken
        }
        
        let url = URL(string: "\(baseURL)/me/events/\(eventId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CalendarServiceError.invalidResponse
            }
            
            // 204 is success for DELETE
            guard httpResponse.statusCode == 204 else {
                throw CalendarServiceError.apiError("Status code: \(httpResponse.statusCode)")
            }
            
            print("Successfully deleted Outlook calendar event with ID: \(eventId)")
        } catch {
            print("Error deleting Outlook calendar event: \(error.localizedDescription)")
            throw error
        }
    }
}

/// Presenter for Microsoft Auth
class MSAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = MSAuthPresenter()
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the key window
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIWindow()
    }
} 