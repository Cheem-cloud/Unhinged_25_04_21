import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth


/// Firebase implementation of the SearchService protocol
public class FirebaseSearchService: SearchService {
    /// Firestore database reference
    private let db = Firestore.firestore()
    
    /// User defaults for storing recent searches
    private let userDefaults = UserDefaults.standard
    
    /// Key for recent searches in UserDefaults
    private let recentSearchesKey = "recent_searches"
    
    /// Maximum number of recent searches to store
    private let maxRecentSearches = 20
    
    public init() {
        print("🔍 FirebaseSearchService initialized")
    }
    
    public func searchUsers(query: String, limit: Int, includeCurrentUser: Bool) async throws -> [AppUser] {
        guard !query.isEmpty else {
            return []
        }
        
        // Get current user ID for filtering if needed
        let currentUserId = Auth.auth().currentUser?.uid
        
        // Create a normalized query for case-insensitive search
        let normalizedQuery = query.lowercased()
        
        // Perform the search - since Firestore doesn't support direct substring search,
        // we'll retrieve users whose displayName or email starts with the query
        var usersQuery = db.collection("users")
            .whereField("displayName_lowercase", isGreaterThanOrEqualTo: normalizedQuery)
            .whereField("displayName_lowercase", isLessThan: normalizedQuery + "\u{f8ff}")
            .limit(to: limit)
        
        // Execute the query
        var searchResults = try await executeUserSearch(usersQuery, currentUserId: currentUserId, includeCurrentUser: includeCurrentUser)
        
        // If we need more results, also search by email
        if searchResults.count < limit {
            let emailLimit = limit - searchResults.count
            let emailQuery = db.collection("users")
                .whereField("email_lowercase", isGreaterThanOrEqualTo: normalizedQuery)
                .whereField("email_lowercase", isLessThan: normalizedQuery + "\u{f8ff}")
                .limit(to: emailLimit)
            
            let emailResults = try await executeUserSearch(emailQuery, currentUserId: currentUserId, includeCurrentUser: includeCurrentUser)
            
            // Add email results while avoiding duplicates
            let existingIds = Set(searchResults.compactMap { $0.id })
            let uniqueEmailResults = emailResults.filter { !existingIds.contains($0.id ?? "") }
            searchResults.append(contentsOf: uniqueEmailResults)
        }
        
        // Save the search query to recent searches
        try await saveRecentSearch(query: query, category: .users)
        
        return searchResults
    }
    
    public func searchUsersByTags(tags: [String], matchAll: Bool, limit: Int) async throws -> [AppUser] {
        guard !tags.isEmpty else {
            return []
        }
        
        let currentUserId = Auth.auth().currentUser?.uid
        
        // Different query strategies for matchAll vs matchAny
        if matchAll {
            // For matchAll, we need to find documents that contain all tags
            // This requires more complex querying that Firestore doesn't directly support
            // We'll fetch documents that have at least one tag and filter client-side
            
            // Start with the first tag
            var query = db.collection("users").whereField("tags", arrayContains: tags[0])
            
            // Execute the query
            var results = try await executeUserSearch(query, currentUserId: currentUserId, includeCurrentUser: true)
            
            // Filter for users that have all the required tags
            if tags.count > 1 {
                results = results.filter { user in
                    let userTags = user.tags ?? []
                    return Set(tags).isSubset(of: Set(userTags))
                }
            }
            
            return Array(results.prefix(limit))
        } else {
            // For matchAny, we need separate queries for each tag
            var allResults: [AppUser] = []
            var seenUserIds = Set<String>()
            
            for tag in tags {
                if allResults.count >= limit {
                    break
                }
                
                let tagQuery = db.collection("users").whereField("tags", arrayContains: tag)
                let tagResults = try await executeUserSearch(tagQuery, currentUserId: currentUserId, includeCurrentUser: true)
                
                // Add unique results
                for user in tagResults {
                    if let userId = user.id, !seenUserIds.contains(userId) {
                        allResults.append(user)
                        seenUserIds.insert(userId)
                        
                        if allResults.count >= limit {
                            break
                        }
                    }
                }
            }
            
            return allResults
        }
    }
    
    public func searchHangouts(query: String, status: HangoutStatus?, limit: Int) async throws -> [Hangout] {
        guard !query.isEmpty else {
            return []
        }
        
        // Create a normalized query for case-insensitive search
        let normalizedQuery = query.lowercased()
        
        // Start building the query
        var hangoutQuery = db.collection("hangouts")
            .whereField("title_lowercase", isGreaterThanOrEqualTo: normalizedQuery)
            .whereField("title_lowercase", isLessThan: normalizedQuery + "\u{f8ff}")
        
        // Add status filter if provided
        if let status = status {
            hangoutQuery = hangoutQuery.whereField("status", isEqualTo: status.rawValue)
        }
        
        // Apply limit
        hangoutQuery = hangoutQuery.limit(to: limit)
        
        // Execute the query
        let snapshot = try await hangoutQuery.getDocuments()
        var hangouts: [Hangout] = []
        
        for document in snapshot.documents {
            do {
                var hangout = try Firestore.Decoder().decode(Hangout.self, from: document.data())
                hangout.id = document.documentID
                hangouts.append(hangout)
            } catch {
                print("Error decoding hangout document: \(error.localizedDescription)")
            }
        }
        
        // If we need more results, also search by description
        if hangouts.count < limit {
            let descriptionLimit = limit - hangouts.count
            var descriptionQuery = db.collection("hangouts")
                .whereField("description_lowercase", isGreaterThanOrEqualTo: normalizedQuery)
                .whereField("description_lowercase", isLessThan: normalizedQuery + "\u{f8ff}")
            
            // Add status filter if provided
            if let status = status {
                descriptionQuery = descriptionQuery.whereField("status", isEqualTo: status.rawValue)
            }
            
            descriptionQuery = descriptionQuery.limit(to: descriptionLimit)
            
            let descSnapshot = try await descriptionQuery.getDocuments()
            
            // Add description results while avoiding duplicates
            let existingIds = Set(hangouts.compactMap { $0.id })
            
            for document in descSnapshot.documents {
                if !existingIds.contains(document.documentID) {
                    do {
                        var hangout = try Firestore.Decoder().decode(Hangout.self, from: document.data())
                        hangout.id = document.documentID
                        hangouts.append(hangout)
                    } catch {
                        print("Error decoding hangout from description search: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Save the search query to recent searches
        try await saveRecentSearch(query: query, category: .hangouts)
        
        return hangouts
    }
    
    public func searchHangoutsByDateRange(startDate: Date, endDate: Date, limit: Int) async throws -> [Hangout] {
        guard startDate < endDate else {
            throw NSError(domain: "FirebaseSearchService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Start date must be before end date"])
        }
        
        // Convert dates to Timestamp
        let startTimestamp = Timestamp(date: startDate)
        let endTimestamp = Timestamp(date: endDate)
        
        // Query hangouts within the date range
        let query = db.collection("hangouts")
            .whereField("scheduledDate", isGreaterThanOrEqualTo: startTimestamp)
            .whereField("scheduledDate", isLessThanOrEqualTo: endTimestamp)
            .limit(to: limit)
        
        let snapshot = try await query.getDocuments()
        var hangouts: [Hangout] = []
        
        for document in snapshot.documents {
            do {
                var hangout = try Firestore.Decoder().decode(Hangout.self, from: document.data())
                hangout.id = document.documentID
                hangouts.append(hangout)
            } catch {
                print("Error decoding hangout in date range: \(error.localizedDescription)")
            }
        }
        
        return hangouts
    }
    
    public func searchPersonas(query: String, userId: String?, limit: Int) async throws -> [Persona] {
        guard !query.isEmpty else {
            return []
        }
        
        // Create a normalized query for case-insensitive search
        let normalizedQuery = query.lowercased()
        
        // Start building the query
        var personaQuery: Query = db.collection("personas")
        
        // Filter by user ID if provided
        if let userId = userId {
            personaQuery = personaQuery.whereField("userId", isEqualTo: userId)
        }
        
        // Apply the search filter - first by name
        personaQuery = personaQuery
            .whereField("name_lowercase", isGreaterThanOrEqualTo: normalizedQuery)
            .whereField("name_lowercase", isLessThan: normalizedQuery + "\u{f8ff}")
            .limit(to: limit)
        
        // Execute the query
        let snapshot = try await personaQuery.getDocuments()
        var personas: [Persona] = []
        
        for document in snapshot.documents {
            do {
                var persona = try Firestore.Decoder().decode(Persona.self, from: document.data())
                persona.id = document.documentID
                personas.append(persona)
            } catch {
                print("Error decoding persona: \(error.localizedDescription)")
            }
        }
        
        // If we need more results, also search by interests or bio
        if personas.count < limit {
            // Unfortunately, Firestore doesn't support direct text search within arrays or for substring matching
            // For a more robust solution, we would need to use a search service like Algolia
            // For this implementation, we'll do a simpler query on tags that might contain the term
            
            let tagsLimit = limit - personas.count
            
            var tagsQuery: Query = db.collection("personas")
            
            if let userId = userId {
                tagsQuery = tagsQuery.whereField("userId", isEqualTo: userId)
            }
            
            tagsQuery = tagsQuery.limit(to: tagsLimit)
            
            let tagsSnapshot = try await tagsQuery.getDocuments()
            
            // Filter client-side for tags containing the query
            let existingIds = Set(personas.compactMap { $0.id })
            
            for document in tagsSnapshot.documents {
                if !existingIds.contains(document.documentID) {
                    let tags = document.data()["tags"] as? [String] ?? []
                    // Check if any tag contains the query
                    if tags.contains(where: { $0.lowercased().contains(normalizedQuery) }) {
                        do {
                            var persona = try Firestore.Decoder().decode(Persona.self, from: document.data())
                            persona.id = document.documentID
                            personas.append(persona)
                            
                            if personas.count >= limit {
                                break
                            }
                        } catch {
                            print("Error decoding persona from tags search: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        
        // Save the search query to recent searches
        try await saveRecentSearch(query: query, category: .personas)
        
        return personas
    }
    
    public func searchRelationships(query: String, status: RelationshipStatus?, limit: Int) async throws -> [Relationship] {
        // For relationships, we'll do a more basic search since they typically don't have searchable text fields
        // We'll search by user displayName in the relationship
        
        // Get current user ID
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseSearchService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User must be authenticated to search relationships"])
        }
        
        // First, get relationships for the current user
        var relationshipQuery = db.collection("relationships")
            .whereField("users", arrayContains: currentUserId)
        
        // Add status filter if provided
        if let status = status {
            relationshipQuery = relationshipQuery.whereField("status", isEqualTo: status.rawValue)
        }
        
        // Get all relationships for the user
        let snapshot = try await relationshipQuery.getDocuments()
        var relationships: [Relationship] = []
        
        for document in snapshot.documents {
            do {
                var relationship = try Firestore.Decoder().decode(Relationship.self, from: document.data())
                relationship.id = document.documentID
                relationships.append(relationship)
            } catch {
                print("Error decoding relationship: \(error.localizedDescription)")
            }
        }
        
        // If a query string is provided, filter relationships by partner name
        if !query.isEmpty {
            let normalizedQuery = query.lowercased()
            
            // Get all user IDs in these relationships except the current user
            var partnerIds: [String] = []
            for relationship in relationships {
                let users = relationship.users ?? []
                for userId in users {
                    if userId != currentUserId {
                        partnerIds.append(userId)
                    }
                }
            }
            
            // Get user data for all partners
            var partnerData: [String: AppUser] = [:]
            for partnerId in partnerIds {
                do {
                    let userDoc = try await db.collection("users").document(partnerId).getDocument()
                    if userDoc.exists {
                        var user = try Firestore.Decoder().decode(AppUser.self, from: userDoc.data() ?? [:])
                        user.id = userDoc.documentID
                        partnerData[partnerId] = user
                    }
                } catch {
                    print("Error fetching partner data: \(error.localizedDescription)")
                }
            }
            
            // Filter relationships based on partner name
            relationships = relationships.filter { relationship in
                let users = relationship.users ?? []
                for userId in users {
                    if userId != currentUserId, let partner = partnerData[userId] {
                        if let displayName = partner.displayName?.lowercased(), displayName.contains(normalizedQuery) {
                            return true
                        }
                        if let email = partner.email?.lowercased(), email.contains(normalizedQuery) {
                            return true
                        }
                    }
                }
                return false
            }
        }
        
        // Apply limit after filtering
        if relationships.count > limit {
            relationships = Array(relationships.prefix(limit))
        }
        
        // Save the search query to recent searches
        if !query.isEmpty {
            try await saveRecentSearch(query: query, category: .relationships)
        }
        
        return relationships
    }
    
    public func globalSearch(query: String, categories: [SearchCategory], limit: Int) async throws -> [SearchCategory: [SearchResult]] {
        guard !query.isEmpty else {
            return [:]
        }
        
        var results: [SearchCategory: [SearchResult]] = [:]
        
        // Determine which categories to search
        let categoriesToSearch = categories.contains(.all) 
            ? [SearchCategory.users, .hangouts, .personas, .relationships] 
            : categories
        
        // Execute each search in parallel using async/await
        await withTaskGroup(of: (SearchCategory, [SearchResult]).self) { group in
            // Add task for each category
            for category in categoriesToSearch {
                group.addTask {
                    switch category {
                    case .users:
                        let users = try? await self.searchUsers(query: query, limit: limit, includeCurrentUser: true)
                        let searchResults = users?.map { user in
                            SearchResult(
                                id: user.id ?? UUID().uuidString,
                                title: user.displayName ?? user.email ?? "Unknown User",
                                subtitle: user.email,
                                type: .users,
                                data: user,
                                iconName: "person.circle",
                                timestamp: nil
                            )
                        } ?? []
                        return (.users, searchResults)
                        
                    case .hangouts:
                        let hangouts = try? await self.searchHangouts(query: query, status: nil, limit: limit)
                        let searchResults = hangouts?.map { hangout in
                            SearchResult(
                                id: hangout.id ?? UUID().uuidString,
                                title: hangout.title ?? "Untitled Hangout",
                                subtitle: hangout.description,
                                type: .hangouts,
                                data: hangout,
                                iconName: "calendar",
                                timestamp: hangout.scheduledDate
                            )
                        } ?? []
                        return (.hangouts, searchResults)
                        
                    case .personas:
                        let personas = try? await self.searchPersonas(query: query, userId: nil, limit: limit)
                        let searchResults = personas?.map { persona in
                            SearchResult(
                                id: persona.id ?? UUID().uuidString,
                                title: persona.name ?? "Unnamed Persona",
                                subtitle: persona.description,
                                type: .personas,
                                data: persona,
                                iconName: "person.fill",
                                timestamp: nil
                            )
                        } ?? []
                        return (.personas, searchResults)
                        
                    case .relationships:
                        let relationships = try? await self.searchRelationships(query: query, status: nil, limit: limit)
                        let searchResults = relationships?.map { relationship in
                            SearchResult(
                                id: relationship.id ?? UUID().uuidString,
                                title: relationship.name ?? "Unnamed Relationship",
                                subtitle: "Status: \(relationship.status ?? "Unknown")",
                                type: .relationships,
                                data: relationship,
                                iconName: "person.2.fill",
                                timestamp: relationship.createdAt
                            )
                        } ?? []
                        return (.relationships, searchResults)
                        
                    case .all:
                        // This should be handled by categoriesToSearch logic
                        return (.all, [])
                    }
                }
            }
            
            // Collect results
            for await (category, categoryResults) in group {
                results[category] = categoryResults
            }
        }
        
        // Only save global searches if query is meaningful
        if query.count >= 3 {
            try await saveRecentSearch(query: query, category: .all)
        }
        
        return results
    }
    
    public func getSearchSuggestions(partialQuery: String, categories: [SearchCategory], limit: Int) async throws -> [SearchSuggestion] {
        guard !partialQuery.isEmpty else {
            // If no query, return popular/recent searches
            return try await getPopularSearchSuggestions(limit: limit, categories: categories)
        }
        
        var suggestions: [SearchSuggestion] = []
        
        // Get suggestions from recent searches
        let recentSearches = try await getRecentSearches(limit: limit)
        
        for recentSearch in recentSearches {
            if recentSearch.query.lowercased().contains(partialQuery.lowercased()) {
                // Check if the category is relevant
                if categories.contains(.all) || categories.contains(recentSearch.category) {
                    suggestions.append(SearchSuggestion(
                        text: recentSearch.query,
                        category: recentSearch.category,
                        matchType: .contains
                    ))
                }
            }
        }
        
        // If we need more suggestions, get from the database
        if suggestions.count < limit {
            // For a real implementation, we might integrate with a search service like Algolia
            // For now, we'll use simple prefix matching in Firestore
            
            // Try to get user name suggestions
            if categories.contains(.all) || categories.contains(.users) {
                let userQuery = db.collection("users")
                    .whereField("displayName_lowercase", isGreaterThanOrEqualTo: partialQuery.lowercased())
                    .whereField("displayName_lowercase", isLessThan: partialQuery.lowercased() + "\u{f8ff}")
                    .limit(to: 5)
                
                let userSnapshot = try await userQuery.getDocuments()
                
                for document in userSnapshot.documents {
                    if let displayName = document.data()["displayName"] as? String {
                        suggestions.append(SearchSuggestion(
                            text: displayName,
                            category: .users,
                            matchType: .prefix
                        ))
                    }
                }
            }
            
            // Get hangout title suggestions
            if (categories.contains(.all) || categories.contains(.hangouts)) && suggestions.count < limit {
                let hangoutQuery = db.collection("hangouts")
                    .whereField("title_lowercase", isGreaterThanOrEqualTo: partialQuery.lowercased())
                    .whereField("title_lowercase", isLessThan: partialQuery.lowercased() + "\u{f8ff}")
                    .limit(to: 5)
                
                let hangoutSnapshot = try await hangoutQuery.getDocuments()
                
                for document in hangoutSnapshot.documents {
                    if let title = document.data()["title"] as? String {
                        suggestions.append(SearchSuggestion(
                            text: title,
                            category: .hangouts,
                            matchType: .prefix
                        ))
                    }
                }
            }
        }
        
        // Remove duplicates
        var uniqueSuggestions: [SearchSuggestion] = []
        var seenTexts = Set<String>()
        
        for suggestion in suggestions {
            if !seenTexts.contains(suggestion.text.lowercased()) {
                uniqueSuggestions.append(suggestion)
                seenTexts.insert(suggestion.text.lowercased())
                
                if uniqueSuggestions.count >= limit {
                    break
                }
            }
        }
        
        return uniqueSuggestions
    }
    
    public func getRecentSearches(limit: Int) async throws -> [RecentSearch] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return []
        }
        
        let recentSearchesData = userDefaults.data(forKey: "\(recentSearchesKey)_\(currentUserId)")
        
        if let data = recentSearchesData {
            do {
                let searches = try JSONDecoder().decode([RecentSearch].self, from: data)
                
                // Return most recent searches first, limited to the specified count
                return Array(searches.sorted(by: { $0.timestamp > $1.timestamp }).prefix(limit))
            } catch {
                print("Error decoding recent searches: \(error.localizedDescription)")
                return []
            }
        }
        
        return []
    }
    
    public func saveRecentSearch(query: String, category: SearchCategory) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return
        }
        
        // Skip very short queries
        guard query.count >= 2 else {
            return
        }
        
        // Get existing searches
        var existingSearches = try await getRecentSearches(limit: maxRecentSearches)
        
        // Create new search
        let newSearch = RecentSearch(
            query: query,
            timestamp: Date(),
            category: category
        )
        
        // Remove any existing search with the same query
        existingSearches.removeAll { $0.query.lowercased() == query.lowercased() }
        
        // Add new search at the beginning
        existingSearches.insert(newSearch, at: 0)
        
        // Limit to max recent searches
        if existingSearches.count > maxRecentSearches {
            existingSearches = Array(existingSearches.prefix(maxRecentSearches))
        }
        
        // Save to UserDefaults
        do {
            let data = try JSONEncoder().encode(existingSearches)
            userDefaults.set(data, forKey: "\(recentSearchesKey)_\(currentUserId)")
        } catch {
            print("Error saving recent searches: \(error.localizedDescription)")
        }
    }
    
    public func clearRecentSearches() async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return
        }
        
        userDefaults.removeObject(forKey: "\(recentSearchesKey)_\(currentUserId)")
    }
    
    // MARK: - Private Helper Methods
    
    /// Execute a user search query with filtering
    private func executeUserSearch(_ query: Query, currentUserId: String?, includeCurrentUser: Bool) async throws -> [AppUser] {
        let snapshot = try await query.getDocuments()
        var users: [AppUser] = []
        
        for document in snapshot.documents {
            // Skip current user if needed
            if !includeCurrentUser, document.documentID == currentUserId {
                continue
            }
            
            do {
                var user = try Firestore.Decoder().decode(AppUser.self, from: document.data())
                user.id = document.documentID
                users.append(user)
            } catch {
                print("Error decoding user document: \(error.localizedDescription)")
            }
        }
        
        return users
    }
    
    /// Get popular or trending search suggestions
    private func getPopularSearchSuggestions(limit: Int, categories: [SearchCategory]) async throws -> [SearchSuggestion] {
        // In a real implementation, this would be based on analytics data
        // For now, we'll return some hardcoded suggestions based on category
        
        var suggestions: [SearchSuggestion] = []
        
        if categories.contains(.all) || categories.contains(.users) {
            suggestions.append(SearchSuggestion(text: "Find friends", category: .users, matchType: .popular))
            suggestions.append(SearchSuggestion(text: "New users", category: .users, matchType: .popular))
        }
        
        if categories.contains(.all) || categories.contains(.hangouts) {
            suggestions.append(SearchSuggestion(text: "Weekend plans", category: .hangouts, matchType: .popular))
            suggestions.append(SearchSuggestion(text: "Coffee meetup", category: .hangouts, matchType: .popular))
        }
        
        if categories.contains(.all) || categories.contains(.personas) {
            suggestions.append(SearchSuggestion(text: "Work persona", category: .personas, matchType: .popular))
            suggestions.append(SearchSuggestion(text: "Social persona", category: .personas, matchType: .popular))
        }
        
        // Add some recent searches if available
        let recentSearches = try await getRecentSearches(limit: 5)
        for recentSearch in recentSearches {
            if categories.contains(.all) || categories.contains(recentSearch.category) {
                suggestions.append(SearchSuggestion(
                    text: recentSearch.query,
                    category: recentSearch.category,
                    matchType: .related
                ))
            }
        }
        
        // Limit the results
        return Array(suggestions.prefix(limit))
    }
} 