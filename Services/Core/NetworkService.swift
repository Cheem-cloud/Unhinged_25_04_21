import Foundation
import Combine

/// Configuration for the NetworkService
public struct NetworkServiceConfiguration {
    /// Base URL for requests
    public let baseURL: URL?
    
    /// Default headers to include in all requests
    public let defaultHeaders: [String: String]
    
    /// Default request timeout interval
    public let timeoutInterval: TimeInterval
    
    /// Whether to use caching
    public let useCache: Bool
    
    /// Cache policy to use
    public let cachePolicy: URLRequest.CachePolicy
    
    /// Initialize with configuration parameters
    /// - Parameters:
    ///   - baseURL: Base URL for requests
    ///   - defaultHeaders: Default headers to include in all requests
    ///   - timeoutInterval: Default request timeout interval
    ///   - useCache: Whether to use caching
    ///   - cachePolicy: Cache policy to use
    public init(
        baseURL: URL? = nil,
        defaultHeaders: [String: String] = [:],
        timeoutInterval: TimeInterval = 60.0,
        useCache: Bool = true,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.timeoutInterval = timeoutInterval
        self.useCache = useCache
        self.cachePolicy = cachePolicy
    }
}

/// Standard NetworkService implementation
public class StandardNetworkService: BaseService, NetworkService, ConfigurableService {
    /// Configuration for the network service
    private var configuration: NetworkServiceConfiguration?
    
    /// URLSession for making requests
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration?.timeoutInterval ?? 60.0
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 5
        config.requestCachePolicy = configuration?.cachePolicy ?? .useProtocolCachePolicy
        return URLSession(configuration: config)
    }()
    
    /// Initialize with configuration
    /// - Parameter configuration: Network service configuration
    public convenience init(configuration: NetworkServiceConfiguration) {
        self.init()
        try? configure(with: configuration)
    }
    
    /// Configure the service with the provided configuration
    /// - Parameter configuration: The configuration to apply
    public func configure(with configuration: NetworkServiceConfiguration) throws {
        updateState(.configuring)
        
        self.configuration = configuration
        self.session = {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = configuration.timeoutInterval
            config.waitsForConnectivity = true
            config.httpMaximumConnectionsPerHost = 5
            config.requestCachePolicy = configuration.cachePolicy
            return URLSession(configuration: config)
        }()
        
        updateState(.configured)
        log("Configured with baseURL: \(configuration.baseURL?.absoluteString ?? "none")")
    }
    
    /// Get the current configuration
    public func getConfiguration() -> NetworkServiceConfiguration? {
        return configuration
    }
    
    /// Send a request and get the response
    /// - Parameter request: Request to send
    /// - Returns: Response data and metadata
    public func sendRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        if !isAvailable() {
            throw ServiceError.notInitialized
        }
        
        var modifiedRequest = request
        
        // Apply default headers from configuration
        if let configuration = configuration {
            for (key, value) in configuration.defaultHeaders {
                if modifiedRequest.value(forHTTPHeaderField: key) == nil {
                    modifiedRequest.setValue(value, forHTTPHeaderField: key)
                }
            }
        }
        
        // Log request
        log("Sending \(modifiedRequest.httpMethod ?? "GET") request to \(modifiedRequest.url?.absoluteString ?? "unknown URL")", level: .debug)
        
        do {
            let (data, response) = try await session.data(for: modifiedRequest)
            
            // Log response
            if let httpResponse = response as? HTTPURLResponse {
                log("Received response with status code \(httpResponse.statusCode) for \(modifiedRequest.url?.absoluteString ?? "unknown URL")", level: .debug)
                
                // Check for error status codes
                if httpResponse.statusCode >= 400 {
                    let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                    throw NetworkError(statusCode: httpResponse.statusCode, responseBody: responseBody)
                }
            }
            
            return (data, response)
        } catch let error as NetworkError {
            log("Network error: \(error.localizedDescription)", level: .error)
            emit(ServiceEvent(type: .error, data: ["error": error, "request": modifiedRequest]))
            throw error
        } catch {
            log("Request failed: \(error.localizedDescription)", level: .error)
            let networkError = NetworkError.urlError(error)
            emit(ServiceEvent(type: .error, data: ["error": networkError, "request": modifiedRequest]))
            throw networkError
        }
    }
    
    /// Get a publisher for the response of a request
    /// - Parameter request: The request to send
    /// - Returns: A publisher that emits the response data or an error
    public func sendRequestPublisher(_ request: URLRequest) -> AnyPublisher<Data, Error> {
        return Future<Data, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(ServiceError.notInitialized))
                return
            }
            
            Task {
                do {
                    let (data, _) = try await self.sendRequest(request)
                    promise(.success(data))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Send a GET request to a URL
    /// - Parameters:
    ///   - url: URL to request
    ///   - headers: Additional headers to include
    /// - Returns: Response data and metadata
    public func get(url: URL, headers: [String: String]? = nil) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        return try await sendRequest(request)
    }
    
    /// Send a POST request with JSON body
    /// - Parameters:
    ///   - url: URL to request
    ///   - body: JSON body to send
    ///   - headers: Additional headers to include
    /// - Returns: Response data and metadata
    public func post<T: Encodable>(url: URL, body: T, headers: [String: String]? = nil) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            log("Failed to encode request body: \(error.localizedDescription)", level: .error)
            throw NetworkError.encodingError(error)
        }
        
        return try await sendRequest(request)
    }
    
    /// Send a PUT request with JSON body
    /// - Parameters:
    ///   - url: URL to request
    ///   - body: JSON body to send
    ///   - headers: Additional headers to include
    /// - Returns: Response data and metadata
    public func put<T: Encodable>(url: URL, body: T, headers: [String: String]? = nil) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            log("Failed to encode request body: \(error.localizedDescription)", level: .error)
            throw NetworkError.encodingError(error)
        }
        
        return try await sendRequest(request)
    }
    
    /// Send a DELETE request
    /// - Parameters:
    ///   - url: URL to request
    ///   - headers: Additional headers to include
    /// - Returns: Response data and metadata
    public func delete(url: URL, headers: [String: String]? = nil) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        return try await sendRequest(request)
    }
    
    /// Build a URL from a path and query parameters
    /// - Parameters:
    ///   - path: Path to append to the base URL
    ///   - queryItems: Query parameters to include
    /// - Returns: Built URL
    public func buildURL(path: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        guard let baseURL = configuration?.baseURL else {
            throw ServiceError.configurationError("Base URL not configured")
        }
        
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        
        // Handle path
        if !path.isEmpty {
            let currentPath = components?.path ?? ""
            let separator = currentPath.hasSuffix("/") || path.hasPrefix("/") ? "" : "/"
            components?.path = currentPath + separator + path
        }
        
        // Add query items
        if let queryItems = queryItems {
            components?.queryItems = queryItems
        }
        
        guard let url = components?.url else {
            throw ServiceError.configurationError("Failed to build URL")
        }
        
        return url
    }
}

/// Network error
public typealias NetworkError = Utilities.NetworkError

/// Keep the following error handling methods
public extension NetworkError {
    static func decodingError(_ error: Error) -> NetworkError {
        return NetworkError(nsError: error as NSError)
    }
    
    static func encodingError(_ error: Error) -> NetworkError {
        return NetworkError(nsError: error as NSError)
    }
} 