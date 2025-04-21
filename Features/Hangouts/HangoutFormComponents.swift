import SwiftUI

/// Main form component for creating or editing a hangout
public struct HangoutFormFeature: View {
    @ObservedObject var viewModel: HangoutFormViewModel
    let onSave: () -> Void
    let onCancel: () -> Void
    
    public init(
        viewModel: HangoutFormViewModel,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    public var body: some View {
        NavigationView {
            Form {
                // Basic Info Section
                Section(header: Text("HANGOUT INFO")) {
                    TextField("Title", text: $viewModel.title)
                    
                    DatePicker(
                        "Date",
                        selection: $viewModel.date,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    
                    TextField("Location", text: $viewModel.location)
                }
                
                // Notes Section
                Section(header: Text("NOTES")) {
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 100)
                }
                
                // Status Section
                Section(header: Text("STATUS")) {
                    Picker("Status", selection: $viewModel.status) {
                        ForEach(HangoutStatus.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized)
                                .tag(status)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Participants Section
                Section(header: ParticipantsHeader(onAddParticipant: viewModel.showAddParticipantSheet)) {
                    if viewModel.participants.isEmpty {
                        Text("No participants yet")
                            .foregroundColor(.secondary)
                    } else {
                        participantsList
                    }
                }
                
                // Save or Delete Button Section
                Section {
                    if viewModel.isEditing {
                        deleteButton
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Hangout" : "New Hangout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveHangout()
                        onSave()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
            .sheet(isPresented: $viewModel.showingAddParticipant) {
                ParticipantSelectionSheet(
                    selectedParticipants: $viewModel.participants,
                    onDismiss: { viewModel.showingAddParticipant = false }
                )
            }
            .alert(isPresented: $viewModel.showingDeleteConfirmation) {
                Alert(
                    title: Text("Delete Hangout"),
                    message: Text("Are you sure you want to delete this hangout? This cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        viewModel.deleteHangout()
                        onCancel()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private var participantsList: some View {
        ForEach(viewModel.participants) { participant in
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                
                Text(participant.name)
                
                Spacer()
                
                if participant.hasResponded {
                    Image(systemName: participant.isAttending ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(participant.isAttending ? .green : .red)
                } else {
                    Text("Awaiting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onDelete(perform: viewModel.removeParticipant)
    }
    
    private var deleteButton: some View {
        Button(role: .destructive) {
            viewModel.showDeleteConfirmation()
        } label: {
            HStack {
                Spacer()
                Text("Delete Hangout")
                Spacer()
            }
        }
    }
}

/// Header for the participants section with add button
struct ParticipantsHeader: View {
    let onAddParticipant: () -> Void
    
    var body: some View {
        HStack {
            Text("PARTICIPANTS")
            
            Spacer()
            
            Button(action: onAddParticipant) {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
}

/// Sheet for selecting participants
struct ParticipantSelectionSheet: View {
    @Binding var selectedParticipants: [Participant]
    let onDismiss: () -> Void
    @State private var searchText = ""
    
    // This would typically come from a user service or similar
    private let availableContacts = [
        Participant(id: UUID(), name: "John Doe"),
        Participant(id: UUID(), name: "Jane Smith"),
        Participant(id: UUID(), name: "Mike Johnson"),
        // More contacts...
    ]
    
    private var filteredContacts: [Participant] {
        if searchText.isEmpty {
            return availableContacts
        } else {
            return availableContacts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredContacts) { contact in
                    Button(action: {
                        toggleParticipant(contact)
                    }) {
                        HStack {
                            Text(contact.name)
                            
                            Spacer()
                            
                            if isSelected(contact) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .searchable(text: $searchText, prompt: "Search contacts")
            .navigationTitle("Add Participants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }
    
    private func isSelected(_ contact: Participant) -> Bool {
        selectedParticipants.contains { $0.id == contact.id }
    }
    
    private func toggleParticipant(_ contact: Participant) {
        if isSelected(contact) {
            selectedParticipants.removeAll { $0.id == contact.id }
        } else {
            selectedParticipants.append(contact)
        }
    }
} 