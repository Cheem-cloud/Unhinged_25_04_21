import SwiftUI
import Foundation
import Combine

// Sample model for the searchable paginated example
struct Product: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let price: Double
    let category: String
    
    static let categories = ["Electronics", "Clothing", "Home", "Sports", "Books"]
    
    static func sample(index: Int) -> Product {
        let category = categories[index % categories.count]
        return Product(
            name: "\(category) Item \(index)",
            description: "This is a sample product description for item number \(index). It belongs to the \(category) category.",
            price: Double(index * 10) + 9.99,
            category: category
        )
    }
}

// ViewModel using our searchable and paginated MVVM template
class ProductListViewModel: SearchablePaginatedMVVMViewModel {
    @Published var products: [Product] = []
    @Published var filteredProducts: [Product] = []
    
    private let productsPerPage = 8
    private let maxProducts = 100
    private var allProducts: [Product] = []
    
    override init() {
        super.init()
        // Generate all products once for demo purposes
        allProducts = (1...maxProducts).map { Product.sample(index: $0) }
    }
    
    // Load the initial data
    func loadInitialData() async {
        guard let newProducts = await performPaginatedOperation(true) { page in
            await fetchProducts(page: page, query: searchQuery)
        } else { return }
        
        await MainActor.run {
            self.products = newProducts
            self.filteredProducts = newProducts
        }
    }
    
    // Override loadNextPage from PaginatedViewModel
    override func loadNextPage() async {
        guard let newProducts = await performPaginatedOperation(false) { page in
            await fetchProducts(page: page, query: searchQuery)
        } else { return }
        
        await MainActor.run {
            self.products.append(contentsOf: newProducts)
            self.filteredProducts = self.products
        }
    }
    
    // Override performSearch from SearchableViewModel
    override func performSearch() async {
        guard let searchResults = await performSearchOperation { query in
            await searchProducts(query: query)
        } else { return }
        
        await MainActor.run {
            if searchQuery.isEmpty {
                // If search is empty, load initial data again
                Task {
                    await loadInitialData()
                }
            } else {
                // Otherwise, update filtered products
                self.filteredProducts = searchResults
            }
        }
    }
    
    // Simulated network request to fetch products with pagination
    private func fetchProducts(page: Int, query: String) async -> (items: [Product], hasMore: Bool) {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        // Filter by search query if not empty
        var filteredList = allProducts
        if !query.isEmpty {
            filteredList = allProducts.filter { product in
                product.name.lowercased().contains(query.lowercased()) ||
                product.description.lowercased().contains(query.lowercased()) ||
                product.category.lowercased().contains(query.lowercased())
            }
        }
        
        // Calculate start and end indices for this page
        let startIndex = (page - 1) * productsPerPage
        
        // Ensure we don't go out of bounds
        guard startIndex < filteredList.count else {
            return (items: [], hasMore: false)
        }
        
        let endIndex = min(startIndex + productsPerPage, filteredList.count)
        
        // Determine if there are more pages
        let hasMore = endIndex < filteredList.count
        
        // Get the products for this page
        let pageProducts = Array(filteredList[startIndex..<endIndex])
        
        return (items: pageProducts, hasMore: hasMore)
    }
    
    // Simulated search operation
    private func searchProducts(query: String) async -> [Product] {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // If query is empty, return all products from current page
        if query.isEmpty {
            return products
        }
        
        // Otherwise, filter all products by query
        return allProducts.filter { product in
            product.name.lowercased().contains(query.lowercased()) ||
            product.description.lowercased().contains(query.lowercased()) ||
            product.category.lowercased().contains(query.lowercased())
        }
    }
}

// Sample view using the searchable and paginated ViewModel
struct ProductListView: View {
    @StateObject var viewModel = ProductListViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                // Custom search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search products", text: $viewModel.searchQuery)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            viewModel.resetSearch()
                            Task {
                                await viewModel.loadInitialData()
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                
                // Product list with loading indicators
                ZStack {
                    List {
                        ForEach(viewModel.filteredProducts) { product in
                            ProductRowView(product: product)
                                // When the last item becomes visible, load more
                                .onAppear {
                                    if product.id == viewModel.filteredProducts.last?.id && !viewModel.isSearching {
                                        Task {
                                            await viewModel.loadNextPage()
                                        }
                                    }
                                }
                        }
                        
                        if viewModel.isLoadingNextPage && viewModel.hasMorePages {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    
                    // Show empty state when no products match search
                    if viewModel.filteredProducts.isEmpty && !viewModel.isLoading {
                        VStack(spacing: 20) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            if !viewModel.searchQuery.isEmpty {
                                Text("No products match '\(viewModel.searchQuery)'")
                                    .font(.title2)
                            } else {
                                Text("No Products Found")
                                    .font(.title2)
                            }
                            
                            Button("Clear Search") {
                                viewModel.resetSearch()
                                Task {
                                    await viewModel.loadInitialData()
                                }
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .navigationTitle("Products")
            .refreshable {
                await viewModel.loadInitialData()
            }
            .onAppear {
                Task {
                    await viewModel.loadInitialData()
                }
            }
            .loadingOverlay(viewModel.isLoading)
            .centralizedErrorAlert()
        }
    }
}

// Product row view
struct ProductRowView: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(product.name)
                .font(.headline)
            
            Text(product.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text(product.category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor(for: product.category).opacity(0.2))
                    .foregroundColor(categoryColor(for: product.category))
                    .cornerRadius(4)
                
                Spacer()
                
                Text("$\(String(format: "%.2f", product.price))")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
    
    // Get a consistent color for each category
    private func categoryColor(for category: String) -> Color {
        switch category {
        case "Electronics":
            return .blue
        case "Clothing":
            return .purple
        case "Home":
            return .green
        case "Sports":
            return .red
        case "Books":
            return .orange
        default:
            return .gray
        }
    }
}

// Preview provider
struct ProductListView_Previews: PreviewProvider {
    static var previews: some View {
        ProductListView()
    }
} 