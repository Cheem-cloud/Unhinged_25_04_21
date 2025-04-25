import SwiftUI
import Combine
import Foundation

// Sample model for testing
struct TodoItem: Identifiable {
    let id = UUID()
    var title: String
    var isCompleted: Bool = false
}

// ViewModel implementing the MVVMViewModel
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
        // Use the performAsyncOperation method from MVVMViewModel
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
        handleError(NSError(domain: "TodoViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "This is a test error"]))
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
                    
                    Button("Test Error") {
                        viewModel.triggerError()
                    }
                }
            }
            .centralizedErrorAlert()
            .loadingOverlay(viewModel.isLoading)
        }
    }
}

// Preview provider
struct TodoListView_Previews: PreviewProvider {
    static var previews: some View {
        TodoListView()
    }
}

// Main app entry point for testing
@main
struct MVVMTemplateTestApp: App {
    var body: some Scene {
        WindowGroup {
            TodoListView()
        }
    }
} 