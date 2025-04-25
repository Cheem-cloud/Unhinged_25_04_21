import Foundation
import Combine
import SwiftUI
// Removed // Removed: import Unhinged.Utilities

/// Base protocol for all view models to ensure consistency
protocol BaseViewModel: ObservableObject {
    /// Loading state
    var isLoading: Bool { get set }
    
    /// Error state
    var error: Error? { get set }
    
    /// Whether there's an error
    var hasError: Bool { get }
    
    /// Clear error state
    func clearError()
}

/// Default implementation for BaseViewModel
extension BaseViewModel {
    var hasError: Bool {
        return error != nil
    }
    
    func clearError() {
        error = nil
    }
}

/// Default error handling for view models
extension BaseViewModel {
    /// Handle errors in a consistent way
    /// - Parameter error: The error to handle
    func handleError(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        self.error = error
        
        // Log the error
        let fileName = (file as NSString).lastPathComponent
        print("❌ ERROR: \(error.localizedDescription) in \(fileName):\(line) - \(function)")
        
        // Use the centralized error handler
        UIErrorHandler.shared.handle(error)
    }
}

/// Base class for all view models to inherit from
class MVVMViewModel: BaseViewModel {
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    /// Cancellables for managing subscriptions
    var cancellables = Set<AnyCancellable>()
    
    /// Reset the view model state
    func reset() {
        isLoading = false
        error = nil
    }
    
    /// Perform an async operation with loading and error handling
    /// - Parameter operation: The async operation to perform
    func performAsyncOperation<T>(_ operation: @escaping () async throws -> T) async -> T? {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let result = try await operation()
            
            await MainActor.run {
                isLoading = false
            }
            
            return result
        } catch {
            await MainActor.run {
                handleError(error)
                isLoading = false
            }
            return nil
        }
    }
}

/// Protocol for view models that need to handle paginated data
protocol PaginatedViewModel: BaseViewModel {
    /// The current page
    var currentPage: Int { get set }
    
    /// Whether there are more pages to load
    var hasMorePages: Bool { get set }
    
    /// Whether data is being loaded for the next page
    var isLoadingNextPage: Bool { get set }
    
    /// Load the next page of data
    func loadNextPage() async
    
    /// Reset pagination state
    func resetPagination()
}

/// Base class for view models that need to handle paginated data
class PaginatedMVVMViewModel: MVVMViewModel, PaginatedViewModel {
    @Published var currentPage: Int = 1
    @Published var hasMorePages: Bool = true
    @Published var isLoadingNextPage: Bool = false
    
    /// Load the next page of data, to be implemented by subclasses
    func loadNextPage() async {
        // This should be implemented by subclasses
        fatalError("Subclasses must implement loadNextPage()")
    }
    
    /// Reset pagination state
    func resetPagination() {
        currentPage = 1
        hasMorePages = true
    }
    
    /// Perform a paginated operation with loading and error handling
    /// - Parameters:
    ///   - isFirstPage: Whether this is the first page being loaded
    ///   - operation: The async operation to perform
    func performPaginatedOperation<T>(_ isFirstPage: Bool = false, operation: @escaping (Int) async throws -> (items: [T], hasMore: Bool)) async -> [T]? {
        if isFirstPage {
            await MainActor.run {
                isLoading = true
                error = nil
                resetPagination()
            }
        } else {
            guard hasMorePages && !isLoadingNextPage else { return [] }
            
            await MainActor.run {
                isLoadingNextPage = true
                error = nil
            }
        }
        
        do {
            let result = try await operation(currentPage)
            
            await MainActor.run {
                currentPage += 1
                hasMorePages = result.hasMore
                isLoading = false
                isLoadingNextPage = false
            }
            
            return result.items
        } catch {
            await MainActor.run {
                handleError(error)
                isLoading = false
                isLoadingNextPage = false
            }
            return nil
        }
    }
}

/// Protocol for view models that need to handle search functionality
protocol SearchableViewModel: BaseViewModel {
    /// The search query
    var searchQuery: String { get set }
    
    /// Whether a search is currently active
    var isSearching: Bool { get set }
    
    /// Debounce time for search queries in seconds
    var searchDebounceTime: Double { get }
    
    /// Minimum query length for searching
    var minimumQueryLength: Int { get }
    
    /// Perform a search with the current query
    func performSearch() async
    
    /// Reset search state
    func resetSearch()
}

/// Base class for view models that need to handle search functionality
class SearchableMVVMViewModel: MVVMViewModel, SearchableViewModel {
    @Published var searchQuery: String = ""
    @Published var isSearching: Bool = false
    
    /// Default debounce time of 0.5 seconds
    var searchDebounceTime: Double { 0.5 }
    
    /// Default minimum query length of 2 characters
    var minimumQueryLength: Int { 2 }
    
    /// Search cancellable for debouncing
    private var searchCancellable: AnyCancellable?
    
    override init() {
        super.init()
        setupSearchDebounce()
    }
    
    /// Set up search debounce to avoid excessive search operations
    private func setupSearchDebounce() {
        searchCancellable = $searchQuery
            .removeDuplicates()
            .debounce(for: .seconds(searchDebounceTime), scheduler: RunLoop.main)
            .sink { [weak self] query in
                guard let self = self else { return }
                
                // Only search if query is long enough
                guard query.count >= self.minimumQueryLength || query.isEmpty else { return }
                
                Task {
                    await self.performSearch()
                }
            }
        
        searchCancellable?.store(in: &cancellables)
    }
    
    /// Perform a search with the current query, to be implemented by subclasses
    func performSearch() async {
        // This should be implemented by subclasses
        fatalError("Subclasses must implement performSearch()")
    }
    
    /// Reset search state
    func resetSearch() {
        searchQuery = ""
        isSearching = false
    }
    
    /// Perform a search operation with loading and error handling
    /// - Parameter operation: The async operation to perform
    func performSearchOperation<T>(_ operation: @escaping (String) async throws -> [T]) async -> [T]? {
        // No need to search if query is too short (unless empty, which means reset to all items)
        if searchQuery.count < minimumQueryLength && !searchQuery.isEmpty {
            return nil
        }
        
        await MainActor.run {
            isSearching = true
            error = nil
        }
        
        do {
            let results = try await operation(searchQuery)
            
            await MainActor.run {
                isSearching = false
            }
            
            return results
        } catch {
            await MainActor.run {
                handleError(error)
                isSearching = false
            }
            return nil
        }
    }
}

/// Base class for view models that need both pagination and search
class SearchablePaginatedMVVMViewModel: PaginatedMVVMViewModel, SearchableViewModel {
    @Published var searchQuery: String = ""
    @Published var isSearching: Bool = false
    
    /// Default debounce time of 0.5 seconds
    var searchDebounceTime: Double { 0.5 }
    
    /// Default minimum query length of 2 characters
    var minimumQueryLength: Int { 2 }
    
    /// Search cancellable for debouncing
    private var searchCancellable: AnyCancellable?
    
    override init() {
        super.init()
        setupSearchDebounce()
    }
    
    /// Set up search debounce to avoid excessive search operations
    private func setupSearchDebounce() {
        searchCancellable = $searchQuery
            .removeDuplicates()
            .debounce(for: .seconds(searchDebounceTime), scheduler: RunLoop.main)
            .sink { [weak self] query in
                guard let self = self else { return }
                
                // Only search if query is long enough, or empty (which resets the search)
                guard query.count >= self.minimumQueryLength || query.isEmpty else { return }
                
                Task {
                    // Reset pagination when search query changes
                    self.resetPagination()
                    await self.performSearch()
                }
            }
        
        searchCancellable?.store(in: &cancellables)
    }
    
    /// Perform a search with the current query, to be implemented by subclasses
    func performSearch() async {
        // This should be implemented by subclasses
        fatalError("Subclasses must implement performSearch()")
    }
    
    /// Reset search state
    func resetSearch() {
        searchQuery = ""
        isSearching = false
        resetPagination()
    }
    
    /// Perform a search operation with loading and error handling
    /// - Parameter operation: The async operation to perform with search query and page
    func performSearchOperation<T>(_ isFirstPage: Bool = true, operation: @escaping (String, Int) async throws -> (items: [T], hasMore: Bool)) async -> [T]? {
        // No need to search if query is too short (unless empty, which means reset to all items)
        if searchQuery.count < minimumQueryLength && !searchQuery.isEmpty {
            return nil
        }
        
        if isFirstPage {
            await MainActor.run {
                isLoading = true
                isSearching = true
                error = nil
                resetPagination()
            }
        } else {
            guard hasMorePages && !isLoadingNextPage else { return [] }
            
            await MainActor.run {
                isLoadingNextPage = true
                isSearching = true
                error = nil
            }
        }
        
        do {
            let result = try await operation(searchQuery, currentPage)
            
            await MainActor.run {
                currentPage += 1
                hasMorePages = result.hasMore
                isLoading = false
                isLoadingNextPage = false
                isSearching = false
            }
            
            return result.items
        } catch {
            await MainActor.run {
                handleError(error)
                isLoading = false
                isLoadingNextPage = false
                isSearching = false
            }
            return nil
        }
    }
}

// MARK: - View Extensions

/// Extension on View to provide consistent error alert handling
extension View {
    /// Add an error alert to a view
    /// - Parameters:
    ///   - error: Binding to the error
    ///   - buttonTitle: Title for the dismiss button
    ///   - onDismiss: Action to perform when the alert is dismissed
    /// - Returns: View with error alert
    func errorAlert<T: Error>(
        error: Binding<T?>,
        buttonTitle: String = "OK",
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        let localizedError = error.wrappedValue?.localizedDescription ?? "Unknown error"
        return alert(isPresented: .init(
            get: { error.wrappedValue != nil },
            set: { if !$0 { error.wrappedValue = nil }}
        )) {
            Alert(
                title: Text("Error"),
                message: Text(localizedError),
                dismissButton: .default(Text(buttonTitle)) {
                    error.wrappedValue = nil
                    onDismiss?()
                }
            )
        }
    }
    
    /// Add a standardized error alert that uses the central error handler
    func centralizedErrorAlert(isPresented: Binding<Bool> = .constant(false)) -> some View {
        self.handleAppErrors(errorHandler: UIErrorHandler.shared)
    }
    
    /// Add a loading overlay to a view
    /// - Parameters:
    ///   - isLoading: Binding to the loading state
    ///   - message: Message to display while loading
    /// - Returns: View with loading overlay
    func loadingOverlay(_ isLoading: Bool, message: String = "Loading...") -> some View {
        self.overlay(
            Group {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.2)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text(message)
                                .foregroundColor(CustomTheme.Colors.textSecondary)
                                .font(.caption)
                        }
                        .padding()
                        .background(CustomTheme.Colors.background)
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    }
                }
            }
        )
        .disabled(isLoading)
    }
    
    /// Add a pagination loading indicator to a list
    /// - Parameters:
    ///   - isLoading: Whether the next page is loading
    ///   - action: Action to perform when the indicator is visible
    /// - Returns: View with pagination loading indicator
    func paginationLoadingIndicator(isLoading: Bool, loadNextPage: @escaping () async -> Void) -> some View {
        self.overlay(
            VStack {
                Spacer()
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                    .background(CustomTheme.Colors.background)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .padding(.bottom, 8)
                }
            }
            .onAppear {
                Task {
                    await loadNextPage()
                }
            }
        )
    }
    
    /// Add a search bar to a view
    /// - Parameters:
    ///   - text: Binding to the search text
    ///   - placeholder: Placeholder text to display
    ///   - onSearch: Action to perform when search is activated
    ///   - onCancel: Action to perform when search is cancelled
    /// - Returns: View with search bar
    func searchBar(
        text: Binding<String>,
        placeholder: String = "Search",
        onSearch: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        self.overlay(
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField(placeholder, text: text)
                        .disableAutocorrection(true)
                        .onSubmit(onSearch)
                    
                    if !text.wrappedValue.isEmpty {
                        Button(action: {
                            text.wrappedValue = ""
                            onCancel()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
            }
            .frame(height: 60)
        )
        .padding(.top, 60) // Add padding to account for the search bar
    }
} 