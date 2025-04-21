import Foundation
import Combine
import SwiftUI

/// Sample implementation of a view model that uses standardized callbacks
class SampleCallbackViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Loading state
    @Published var isLoading: Bool = false
    
    /// Error state
    @Published var error: Error?
    
    /// Data state
    @Published var data: [String] = []
    
    // MARK: - Callback Properties
    
    /// Called when data loading completes successfully
    var onLoadSuccess: CallbackManager.Callback<[String]>?
    
    /// Called when an error occurs
    var onLoadError: CallbackManager.Callback<Error>?
    
    /// Called when loading state changes
    var onLoadingStateChanged: CallbackManager.Callback<Bool>?
    
    // MARK: - Dependencies
    
    /// Sample service
    private let service = SampleService()
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Set up state observation
        $isLoading
            .sink { [weak self] isLoading in
                self?.onLoadingStateChanged?(isLoading)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Load data with callbacks
    func loadData() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let result = try await service.fetchData()
                
                await MainActor.run {
                    self.data = result
                    self.isLoading = false
                    self.onLoadSuccess?(result)
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                    self.onLoadError?(error)
                }
            }
        }
    }
    
    /// Load data with completion handler
    func loadData(completion: @escaping CallbackManager.Completion<[String]>) {
        isLoading = true
        error = nil
        
        Task {
            do {
                let result = try await service.fetchData()
                
                await MainActor.run {
                    self.data = result
                    self.isLoading = false
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Load data with a composite callback that combines multiple callbacks
    func loadDataWithCompositeCallback() {
        isLoading = true
        error = nil
        
        let onStart = CallbackManager.SimpleCallback {
            print("Loading started")
        }
        
        let onFinish = CallbackManager.SimpleCallback {
            print("Loading finished")
        }
        
        // Chain callbacks together
        let chainedCallback = CallbackManager.chain(onStart, onFinish)
        
        // Execute the chained callback
        chainedCallback()
        
        Task {
            do {
                let result = try await service.fetchData()
                
                await MainActor.run {
                    self.data = result
                    self.isLoading = false
                    self.onLoadSuccess?(result)
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                    self.onLoadError?(error)
                }
            }
        }
    }
    
    /// Load data using the weak callback pattern to prevent retain cycles
    func loadDataWithWeakCallback(owner: AnyObject, callback: @escaping (AnyObject, [String]) -> Void) {
        isLoading = true
        error = nil
        
        // Create a weak callback to prevent retain cycles
        let weakCallback = CallbackManager.WeakParamCallback(owner: owner, callback: callback)
        
        Task {
            do {
                let result = try await service.fetchData()
                
                await MainActor.run {
                    self.data = result
                    self.isLoading = false
                    _ = weakCallback.execute(with: result)
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Load data using publisher conversion
    func loadDataAsPublisher() -> AnyPublisher<[String], Error> {
        return CallbackManager.createPublisher { [weak self] in
            guard let self = self else { throw NSError(domain: "com.cheemhang", code: -1, userInfo: nil) }
            return try await self.service.fetchData()
        }
    }
    
    /// Load data with debounced callback
    func setupDebouncedDataLoading() {
        // Create a debounced callback that will only execute after 500ms of inactivity
        let debouncedLoad = CallbackManager.debounce(interval: 0.5) { [weak self] in
            self?.loadData()
        }
        
        // Use the debounced callback
        debouncedLoad()
    }
}

/// Sample service class
class SampleService {
    /// Simulates fetching data asynchronously
    func fetchData() async throws -> [String] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Randomly succeed or fail
        let shouldSucceed = Bool.random()
        
        if shouldSucceed {
            return ["Item 1", "Item 2", "Item 3"]
        } else {
            throw NSError(domain: "com.cheemhang", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch data"])
        }
    }
}

/// Sample SwiftUI view that demonstrates the use of the ViewModel
struct SampleCallbackView: View {
    @StateObject private var viewModel = SampleCallbackViewModel()
    @State private var successMessage: String?
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else if let error = viewModel.error {
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .padding()
            } else if !viewModel.data.isEmpty {
                List(viewModel.data, id: \.self) { item in
                    Text(item)
                }
            } else if let successMessage = successMessage {
                Text(successMessage)
                    .foregroundColor(.green)
                    .padding()
            } else {
                Text("No data loaded")
                    .padding()
            }
            
            Button("Load Data") {
                viewModel.loadData()
            }
            .padding()
            
            Button("Load with Completion") {
                viewModel.loadData { result in
                    switch result {
                    case .success(let data):
                        successMessage = "Loaded \(data.count) items"
                    case .failure(let error):
                        print("Error: \(error.localizedDescription)")
                    }
                }
            }
            .padding()
            
            Button("Load with Publisher") {
                viewModel.loadDataAsPublisher()
                    .receive(on: RunLoop.main)
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                print("Error: \(error.localizedDescription)")
                            }
                        },
                        receiveValue: { data in
                            successMessage = "Loaded \(data.count) items via publisher"
                        }
                    )
                    .store(in: &viewModel.cancellables)
            }
            .padding()
            
            Button("Debounced Load") {
                viewModel.setupDebouncedDataLoading()
            }
            .padding()
        }
        .onAppear {
            // Set up callbacks when the view appears
            viewModel.onLoadSuccess = { data in
                successMessage = "Successfully loaded \(data.count) items"
            }
            
            viewModel.onLoadError = { error in
                print("Error callback: \(error.localizedDescription)")
            }
            
            viewModel.onLoadingStateChanged = { isLoading in
                print("Loading state changed: \(isLoading)")
            }
        }
    }
} 