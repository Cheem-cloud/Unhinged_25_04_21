import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

/// View model for friend couple picker
class FriendCouplePickerViewModel: ObservableObject {
    /// Available friend couples
    @Published var friendCouples: [Relationship] = []
    
    /// Recently selected couples
    @Published var recentCouples: [Relationship] = []
    
    /// Search text
    @Published var searchText = ""
    
    /// Whether we're currently loading data
    @Published var isLoading = false
    
    /// Any error that occurred during operations
    @Published var error: Error?
    
    /// The current user's relationship ID
    private var relationshipID: String?
    
    /// Relationship service for user data
    private let relationshipService = RelationshipService.shared
    
    /// Initialize with a relationship ID
    /// - Parameter relationshipID: The relationship ID
    init(relationshipID: String? = nil) {
        self.relationshipID = relationshipID
        
        if let relationshipID = relationshipID {
            loadFriendCouples(relationshipID: relationshipID)
        } else {
            // Try to load current user's relationship
            loadCurrentUserRelationship()
        }
    }
    
    /// Load the current user's relationship
    func loadCurrentUserRelationship() {
        guard let userID = Auth.auth().currentUser?.uid else {
            self.error = NSError(
                domain: "com.cheemhang.availability",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]
            )
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let relationship = try await relationshipService.getRelationshipForUser(userID: userID)
                
                await MainActor.run {
                    self.relationshipID = relationship.id ?? ""
                    if let id = relationship.id {
                        loadFriendCouples(relationshipID: id)
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Load friend couples for a relationship
    /// - Parameter relationshipID: The relationship ID
    func loadFriendCouples(relationshipID: String) {
        isLoading = true
        
        Task {
            do {
                // For now, we'll just load all relationships as a demo
                // In a real app, you would have a "friends" collection or relation
                let allRelationships = try await relationshipService.getAllRelationships()
                
                // Filter out the current relationship
                let friends = allRelationships.filter { $0.id != relationshipID }
                
                // In a real app, you'd also load recent couples from user preferences
                let recents = friends.prefix(2).map { $0 }
                
                await MainActor.run {
                    self.friendCouples = friends
                    self.recentCouples = Array(recents)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Get filtered friend couples based on search text
    /// - Returns: Filtered friend couples
    func getFilteredFriendCouples() -> [Relationship] {
        if searchText.isEmpty {
            return friendCouples
        } else {
            return friendCouples.filter { relationship in
                // In a real app, you would search by couple name, user names, etc.
                // For demo purposes, we'll just search by ID
                guard let id = relationship.id else { return false }
                return id.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    /// Add a couple to recent couples
    /// - Parameter relationship: The relationship to add
    func addToRecentCouples(_ relationship: Relationship) {
        // Remove if already exists
        recentCouples.removeAll { $0.id == relationship.id }
        
        // Add to the beginning
        recentCouples.insert(relationship, at: 0)
        
        // Cap at 5 recent couples
        if recentCouples.count > 5 {
            recentCouples = Array(recentCouples.prefix(5))
        }
        
        // In a real app, you would save this to user preferences
    }
}

/// View for picking a friend couple
struct FriendCouplePickerView: View {
    @StateObject var viewModel = FriendCouplePickerViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var onSelectCouple: (Relationship) -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading friend couples...")
                } else if viewModel.getFilteredFriendCouples().isEmpty && viewModel.recentCouples.isEmpty {
                    emptyStateView
                } else {
                    listContentView
                }
            }
            .navigationTitle("Select Friends")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .searchable(text: $viewModel.searchText, prompt: "Search friends")
        }
    }
    
    /// Empty state view when no friend couples are available
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)
            
            Text("No Friend Couples")
                .font(.headline)
            
            Text("You don't have any friend couples yet. Add friends to find mutual availability.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    /// List content view for displaying friend couples
    private var listContentView: some View {
        List {
            // Recent couples section
            if !viewModel.recentCouples.isEmpty {
                Section(header: Text("Recent")) {
                    ForEach(viewModel.recentCouples) { relationship in
                        CoupleCell(relationship: relationship) {
                            viewModel.addToRecentCouples(relationship)
                            onSelectCouple(relationship)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            
            // All friend couples section
            Section(header: Text("All Friends")) {
                ForEach(viewModel.getFilteredFriendCouples()) { relationship in
                    CoupleCell(relationship: relationship) {
                        viewModel.addToRecentCouples(relationship)
                        onSelectCouple(relationship)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

/// Cell for displaying a couple
struct CoupleCell: View {
    var relationship: Relationship
    var onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                // In a real app, you would display a couple avatar or profile images
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // In a real app, you would display the couple's name
                    if let id = relationship.id {
                        Text("Couple \(id.prefix(4))")
                            .font(.headline)
                    } else {
                        Text("Unknown Couple")
                            .font(.headline)
                    }
                    
                    // In a real app, you would display additional info
                    Text("Friends since \(formatDate(relationship.createdDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    /// Format a date as a string
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct FriendCouplePickerView_Previews: PreviewProvider {
    static var previews: some View {
        FriendCouplePickerView { _ in
            // Do nothing in preview
        }
    }
} 