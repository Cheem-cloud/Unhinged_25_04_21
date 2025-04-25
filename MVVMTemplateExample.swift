import SwiftUI
import Combine

// Create a minimal version of the components we need from MVVMTemplate for the example
// This allows us to run the example without build issues

// Custom error handler (simplified)
class UIErrorHandler {
    static let shared = UIErrorHandler()
    private init() {}
    
    func handle(_ error: Error) {
        print("Error handled: \(error.localizedDescription)")
    }
}

// Base protocol for view models
protocol BaseViewModel: ObservableObject {
    var isLoading: Bool { get set }
    var error: Error? { get set }
    var hasError: Bool { get }
    func clearError()
    func handleError(_ error: Error, file: String, function: String, line: Int)
}

extension BaseViewModel {
    var hasError: Bool {
        return error != nil
    }
    
    func clearError() {
        error = nil
    }
    
    func handleError(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        self.error = error
        
        // Log the error
        let fileName = (file as NSString).lastPathComponent
        print("❌ ERROR: \(error.localizedDescription) in \(fileName):\(line) - \(function)")
        
        // Use the centralized error handler
        UIErrorHandler.shared.handle(error)
    }
}

// Base view model class
class MVVMViewModel: BaseViewModel {
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    var cancellables = Set<AnyCancellable>()
    
    func reset() {
        isLoading = false
        error = nil
    }
    
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

// View extensions
extension View {
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
    
    // Add a standardized error alert that uses the central error handler
    func centralizedErrorAlert() -> some View {
        self.errorAlert(error: .constant(nil))
    }
    
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
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    }
                }
            }
        )
        .disabled(isLoading)
    }
}

// EXAMPLE IMPLEMENTATION

// Sample model
struct TodoItem: Identifiable {
    let id = UUID()
    var title: String
    var isCompleted: Bool = false
}

// ViewModel using our MVVM template
class TodoViewModel: MVVMViewModel {
    @Published var todoItems: [TodoItem] = []
    @Published var newTaskTitle: String = ""
    
    func addTodo() {
        guard !newTaskTitle.isEmpty else {
            handleError(NSError(domain: "TodoViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Task title cannot be empty"]))
            return
        }
        
        let newItem = TodoItem(title: newTaskTitle)
        todoItems.append(newItem)
        newTaskTitle = ""
    }
    
    func toggleComplete(item: TodoItem) {
        if let index = todoItems.firstIndex(where: { $0.id == item.id }) {
            todoItems[index].isCompleted.toggle()
        }
    }
    
    func loadSampleData() async {
        // Use the performAsyncOperation method for async operations
        _ = await performAsyncOperation {
            // Simulate network request
            try await Task.sleep(nanoseconds: 1_500_000_000)
            
            return [
                TodoItem(title: "Buy groceries"),
                TodoItem(title: "Fix the bug"),
                TodoItem(title: "Write documentation")
            ]
        }
        
        // Update the todoItems with the result
        todoItems = [
            TodoItem(title: "Buy groceries"),
            TodoItem(title: "Fix the bug"),
            TodoItem(title: "Write documentation")
        ]
    }
    
    func triggerError() {
        handleError(NSError(domain: "TodoViewModel", 
               code: 100, 
               userInfo: [NSLocalizedDescriptionKey: "This is a test error"]))
    }
}

// Sample view using the ViewModel
struct TodoListView: View {
    @StateObject var viewModel = TodoViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("New task", text: $viewModel.newTaskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: viewModel.addTodo) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                    }
                }
                .padding()
                
                List {
                    ForEach(viewModel.todoItems) { item in
                        HStack {
                            Text(item.title)
                                .strikethrough(item.isCompleted)
                                .foregroundColor(item.isCompleted ? .gray : .primary)
                            
                            Spacer()
                            
                            if item.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.toggleComplete(item: item)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Todo List")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Load Sample Data") {
                        Task {
                            await viewModel.loadSampleData()
                        }
                    }
                    
                    Button("Trigger Error") {
                        viewModel.triggerError()
                    }
                }
            }
            .errorAlert(error: $viewModel.error)
            .loadingOverlay(viewModel.isLoading)
            .onAppear {
                // Load data automatically when view appears
                Task {
                    await viewModel.loadSampleData()
                }
            }
        }
    }
}

// Preview
struct TodoListView_Previews: PreviewProvider {
    static var previews: some View {
        TodoListView()
    }
} 