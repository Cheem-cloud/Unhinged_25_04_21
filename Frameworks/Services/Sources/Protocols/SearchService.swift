import Foundation

/// Service for handling search operations across the application
public protocol SearchService {
    /// Search for users by a query string
    /// - Parameters:
    ///   - query: Query string to search for
    ///   - limit: Maximum number of results to return
    ///   - includeCurrentUser: Whether to include the current user in results
    /// - Returns: Array of users matching the query
    func searchUsers(query: String, limit: Int, includeCurrentUser: Bool) async throws -> [AppUser]
    
    /// Search for users by tags or interests
    /// - Parameters:
    ///   - tags: Array of tags to search for
    ///   - matchAll: Whether all tags must match (AND) or any tag (OR)
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of users matching the tags
    func searchUsersByTags(tags: [String], matchAll: Bool, limit: Int) async throws -> [AppUser]
    
    /// Search for hangouts by a query string
    /// - Parameters:
    ///   - query: Query string to search for
    ///   - status: Optional filter by hangout status
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of hangouts matching the query
    func searchHangouts(query: String, status: HangoutStatus?, limit: Int) async throws -> [Hangout]
    
    /// Search for hangouts by date range
    /// - Parameters:
    ///   - startDate: Start date of the range
    ///   - endDate: End date of the range
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of hangouts within the date range
    func searchHangoutsByDateRange(startDate: Date, endDate: Date, limit: Int) async throws -> [Hangout]
    
    /// Search for personas by a query string
    /// - Parameters:
    ///   - query: Query string to search for
    ///   - userId: Optional user ID to restrict search to
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of personas matching the query
    func searchPersonas(query: String, userId: String?, limit: Int) async throws -> [Persona]
    
    /// Search for relationships by a query string
    /// - Parameters:
    ///   - query: Query string to search for
    ///   - status: Optional filter by relationship status
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of relationships matching the query
    func searchRelationships(query: String, status: RelationshipStatus?, limit: Int) async throws -> [Relationship]
    
    /// Perform a global search across multiple entities
    /// - Parameters:
    ///   - query: Query string to search for
    ///   - categories: Categories to include in search
    ///   - limit: Maximum number of results per category
    /// - Returns: Dictionary of search results by category
    func globalSearch(query: String, categories: [SearchCategory], limit: Int) async throws -> [SearchCategory: [SearchResult]]
    
    /// Get search suggestions based on a partial query
    /// - Parameters:
    ///   - partialQuery: Partial query to get suggestions for
    ///   - categories: Categories to include in suggestions
    ///   - limit: Maximum number of suggestions
    /// - Returns: Array of search suggestions
    func getSearchSuggestions(partialQuery: String, categories: [SearchCategory], limit: Int) async throws -> [SearchSuggestion]
    
    /// Get recent searches for the current user
    /// - Parameter limit: Maximum number of recent searches to return
    /// - Returns: Array of recent searches
    func getRecentSearches(limit: Int) async throws -> [RecentSearch]
    
    /// Save a search query to recent searches
    /// - Parameters:
    ///   - query: Query string to save
    ///   - category: Category of the search
    func saveRecentSearch(query: String, category: SearchCategory) async throws
    
    /// Clear recent searches for the current user
    func clearRecentSearches() async throws
}

/// Categories for search operations
public enum SearchCategory: String, Codable, CaseIterable {
    case users
    case hangouts
    case personas
    case relationships
    case all
}

/// Status of a search operation
public enum SearchStatus: String, Codable {
    case inProgress
    case completed
    case failed
    case noResults
}

/// Generic search result model
public struct SearchResult: Identifiable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var type: SearchCategory
    public var data: Any
    public var iconName: String?
    public var timestamp: Date?
    
    public init(id: String, title: String, subtitle: String? = nil, type: SearchCategory, data: Any, iconName: String? = nil, timestamp: Date? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.data = data
        self.iconName = iconName
        self.timestamp = timestamp
    }
}

/// Search suggestion model
public struct SearchSuggestion: Identifiable {
    public var id: String
    public var text: String
    public var category: SearchCategory
    public var matchType: SuggestionMatchType
    
    public init(id: String = UUID().uuidString, text: String, category: SearchCategory, matchType: SuggestionMatchType) {
        self.id = id
        self.text = text
        self.category = category
        self.matchType = matchType
    }
}

/// Match type for search suggestions
public enum SuggestionMatchType: String, Codable {
    case exact
    case prefix
    case contains
    case related
    case popular
}

/// Recent search model
public struct RecentSearch: Identifiable {
    public var id: String
    public var query: String
    public var timestamp: Date
    public var category: SearchCategory
    
    public init(id: String = UUID().uuidString, query: String, timestamp: Date = Date(), category: SearchCategory = .all) {
        self.id = id
        self.query = query
        self.timestamp = timestamp
        self.category = category
    }
}

/// Common hangout status values
public enum HangoutStatus: String, Codable {
    case pending
    case accepted
    case declined
    case cancelled
    case completed
}

/// Common relationship status values
public enum RelationshipStatus: String, Codable {
    case pending
    case active
    case inactive
    case ended
} 