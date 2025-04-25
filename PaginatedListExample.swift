import SwiftUI
import Foundation
import Combine

// Sample model for pagination example
struct Article: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let description: String
    let author: String
    let publishedDate: Date
    
    static func sample(index: Int) -> Article {
        return Article(
            title: "Article \(index)",
            description: "This is a sample article description for article number \(index). It contains some text to demonstrate how articles would look in a paginated list.",
            author: "Author \(index % 5 + 1)",
            publishedDate: Date().addingTimeInterval(-Double(index * 86400))
        )
    }
}

// ViewModel using our paginated MVVM template
class ArticleListViewModel: PaginatedMVVMViewModel {
    @Published var articles: [Article] = []
    private let articlesPerPage = 10
    private let maxArticles = 50
    
    override init() {
        super.init()
    }
    
    // Load the initial data
    func loadInitialData() async {
        guard let newArticles = await performPaginatedOperation(true) { page in
            await fetchArticles(page: page)
        } else { return }
        
        await MainActor.run {
            self.articles = newArticles
        }
    }
    
    // Override loadNextPage from PaginatedViewModel
    override func loadNextPage() async {
        guard let newArticles = await performPaginatedOperation(false) { page in
            await fetchArticles(page: page)
        } else { return }
        
        await MainActor.run {
            self.articles.append(contentsOf: newArticles)
        }
    }
    
    // Simulated network request to fetch articles
    private func fetchArticles(page: Int) async -> (items: [Article], hasMore: Bool) {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Calculate start and end indices for this page
        let startIndex = (page - 1) * articlesPerPage
        let endIndex = min(startIndex + articlesPerPage, maxArticles)
        
        // If we've reached the maximum number of articles, there are no more pages
        let hasMore = endIndex < maxArticles
        
        // Generate sample articles for this page
        let pageArticles = (startIndex..<endIndex).map { Article.sample(index: $0 + 1) }
        
        return (items: pageArticles, hasMore: hasMore)
    }
}

// Sample view using the paginated ViewModel
struct ArticleListView: View {
    @StateObject var viewModel = ArticleListViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(viewModel.articles) { article in
                        ArticleRowView(article: article)
                            // When the last item becomes visible, load more
                            .onAppear {
                                if article.id == viewModel.articles.last?.id {
                                    Task {
                                        await viewModel.loadNextPage()
                                    }
                                }
                            }
                    }
                    
                    // Show loader at the bottom when loading more
                    if viewModel.isLoadingNextPage && viewModel.hasMorePages {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    }
                }
                
                // Show empty state
                if viewModel.articles.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 20) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Articles Yet")
                            .font(.title2)
                        
                        Text("Pull to refresh or tap the button below")
                            .foregroundColor(.secondary)
                        
                        Button("Load Articles") {
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
            .refreshable {
                await viewModel.loadInitialData()
            }
            .navigationTitle("Articles")
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

// Article row view
struct ArticleRowView: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title)
                .font(.headline)
            
            Text(article.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text(article.author)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text(article.publishedDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
}

// Preview provider
struct ArticleListView_Previews: PreviewProvider {
    static var previews: some View {
        ArticleListView()
    }
} 