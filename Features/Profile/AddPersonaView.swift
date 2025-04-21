import SwiftUI

struct AddPersonaView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PersonasViewModel()
    
    @State private var name = ""
    @State private var description = ""
    @State private var makeDefault = false
    @State private var isLoading = false
    @State private var error: Error?
    
    let onComplete: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Persona Details") {
                    TextField("Name", text: $name)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(4)
                }
                
                Section {
                    Toggle("Make Default Persona", isOn: $makeDefault)
                }
                
                Section {
                    Button("Create Persona") {
                        createPersona()
                    }
                    .disabled(name.isEmpty || isLoading)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("New Persona")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .alert("Error Creating Persona", isPresented: .init(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    private func createPersona() {
        isLoading = true
        
        Task {
            do {
                try await viewModel.createPersona(
                    name: name,
                    description: description,
                    avatarURL: nil,
                    makeDefault: makeDefault
                )
                
                DispatchQueue.main.async {
                    isLoading = false
                    onComplete()
                    dismiss()
                }
            } catch {
                print("Error creating persona: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isLoading = false
                    self.error = error
                }
            }
        }
    }
}

#Preview {
    AddPersonaView(onComplete: {})
} 