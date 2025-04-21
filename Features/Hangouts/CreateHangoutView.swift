import SwiftUI
import FirebaseAuth
import Firebase
import FirebaseFirestore
import MapKit

// Import explicit HangoutData struct
typealias HangoutData = CreateHangoutViewModel.HangoutData

struct CreateHangoutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var date = Date()
    @State private var duration: Duration = .medium
    @State private var location = ""
    @State private var friendId = ""
    @State private var personaId = ""
    @State private var friendPersonaId = ""
    @State private var showingFriendPicker = false
    @State private var showingPersonaPicker = false
    @State private var showingFriendPersonaPicker = false
    @State private var selectedFriend: (userId: String, name: String)?
    @State private var selectedPersona: Persona?
    @State private var selectedFriendPersona: Persona?
    @State private var isLoading = false
    @State private var error: Error?
    
    var onComplete: () -> Void
    var selectedTime: TimeSlot?
    var friendRelationshipID: String?
    var onCreateHangout: ((String, String, String?, HangoutType) -> Void)?
    var onCancel: (() -> Void)?
    
    // Added initializer that accepts an optional selectedPersona
    init(onComplete: @escaping () -> Void, selectedPersona: Persona? = nil) {
        self.onComplete = onComplete
        self._selectedPersona = State(initialValue: selectedPersona)
        if let persona = selectedPersona, let id = persona.id {
            self._personaId = State(initialValue: id)
        }
    }
    
    // New initializer for HangoutCoordinatorView
    init(onComplete: @escaping () -> Void, selectedTime: TimeSlot, friendRelationshipID: String, onCreateHangout: @escaping (String, String, String?, HangoutType) -> Void, onCancel: @escaping () -> Void) {
        self.onComplete = onComplete
        self.selectedTime = selectedTime
        self.friendRelationshipID = friendRelationshipID
        self.onCreateHangout = onCreateHangout
        self.onCancel = onCancel
        
        // Initialize date from selectedTime if provided
        if let startTime = selectedTime.startTime as? Date {
            self._date = State(initialValue: startTime)
        }
        
        // Initialize friendId if relationship ID is provided
        if !friendRelationshipID.isEmpty {
            self._friendId = State(initialValue: friendRelationshipID)
        }
    }
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Hangout Details")) {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $description)
                    DatePicker("Date", selection: $date, in: Date()...)
                    
                    Picker("Duration", selection: $duration) {
                        ForEach(Duration.allCases) { duration in
                            Text(duration.displayName).tag(duration)
                        }
                    }
                    
                    TextField("Location (optional)", text: $location)
                }
                
                Section(header: Text("Who's Invited")) {
                    Button {
                        showingFriendPicker = true
                    } label: {
                        HStack {
                            Text(selectedFriend?.name ?? "Select Friend")
                                .foregroundColor(selectedFriend == nil ? .blue : .primary)
                            Spacer()
                            if selectedFriend != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Button {
                        showingPersonaPicker = true
                    } label: {
                        HStack {
                            Text(selectedPersona?.name ?? "Select Your Persona")
                                .foregroundColor(selectedPersona == nil ? .blue : .primary)
                            Spacer()
                            if selectedPersona != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    if selectedFriend != nil {
                        Button {
                            showingFriendPersonaPicker = true
                        } label: {
                            HStack {
                                Text(selectedFriendPersona?.name ?? "Select Friend's Persona")
                                    .foregroundColor(selectedFriendPersona == nil ? .blue : .primary)
                                Spacer()
                                if selectedFriendPersona != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button {
                        if let onCreateHangout = onCreateHangout {
                            // Use coordinator's create hangout function
                            onCreateHangout(title, description, location, .other)
                            dismiss()
                        } else {
                            // Use default implementation
                            createHangout()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Hangout")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isFormIncomplete || isLoading)
                }
            }
            .navigationTitle("Create Hangout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if let onCancel = onCancel {
                            onCancel()
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFriendPicker) {
                FriendPickerView(onSelect: { userId, name in
                    selectedFriend = (userId: userId, name: name)
                    friendId = userId
                    // Reset friend's persona since friend changed
                    selectedFriendPersona = nil
                    friendPersonaId = ""
                })
            }
            .sheet(isPresented: $showingPersonaPicker) {
                PersonaPickerView(onSelect: { persona in
                    selectedPersona = persona
                    personaId = persona.id ?? ""
                })
            }
            .sheet(isPresented: $showingFriendPersonaPicker) {
                if let friendId = selectedFriend?.userId {
                    FriendPersonaPickerView(friendId: friendId, onSelect: { persona in
                        selectedFriendPersona = persona
                        friendPersonaId = persona.id ?? ""
                    })
                }
            }
            .alert("Error", isPresented: .init(
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
    
    private var isFormIncomplete: Bool {
        title.isEmpty || friendId.isEmpty || personaId.isEmpty || friendPersonaId.isEmpty
    }
    
    private func createHangout() {
        isLoading = true
        
        Task {
            do {
                guard let userId = Auth.auth().currentUser?.uid else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
                }
                
                let hangoutRef = db.collection("hangouts").document()
                
                let hangoutData: [String: Any] = [
                    "title": title,
                    "description": description,
                    "startDate": Timestamp(date: date),
                    "endDate": Timestamp(date: date.addingTimeInterval(Double(duration.rawValue))),
                    "location": location,
                    "creatorID": userId,
                    "creatorPersonaID": personaId,
                    "inviteeID": friendId,
                    "inviteePersonaID": friendPersonaId,
                    "status": "pending",
                    "createdAt": Timestamp(date: Date())
                ]
                
                try await hangoutRef.setData(hangoutData)
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    isLoading = false
                }
            }
        }
    }
}

// Helper Views
struct FriendPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [(userId: String, name: String)] = []
    @State private var isLoading = true
    
    var onSelect: (String, String) -> Void
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading friends...")
                } else if friends.isEmpty {
                    ContentUnavailableView {
                        Label("No Friends Found", systemImage: "person.slash")
                    } description: {
                        Text("You don't have any connections yet.")
                    }
                } else {
                    List {
                        ForEach(friends, id: \.userId) { friend in
                            Button {
                                onSelect(friend.userId, friend.name)
                                dismiss()
                            } label: {
                                Text(friend.name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Friend")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadFriends()
            }
        }
    }
    
    private func loadFriends() {
        // Simulate loading friends
        // In a real app, you would load from Firestore
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            friends = [
                (userId: "friend1", name: "John Smith"),
                (userId: "friend2", name: "Jane Doe"),
                (userId: "friend3", name: "Bob Johnson")
            ]
            isLoading = false
        }
    }
}

struct PersonaPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var personas: [Persona] = []
    @State private var isLoading = true
    
    var onSelect: (Persona) -> Void
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading personas...")
                } else if personas.isEmpty {
                    ContentUnavailableView {
                        Label("No Personas Found", systemImage: "person.slash")
                    } description: {
                        Text("You haven't created any personas yet.")
                    }
                } else {
                    List {
                        ForEach(personas) { persona in
                            Button {
                                onSelect(persona)
                                dismiss()
                            } label: {
                                Text(persona.name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Your Persona")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadPersonas()
            }
        }
    }
    
    private func loadPersonas() {
        Task {
            do {
                guard let userId = Auth.auth().currentUser?.uid else { return }
                
                let db = Firestore.firestore()
                let snapshot = try await db.collection("users").document(userId).collection("personas").getDocuments()
                
                let loadedPersonas = snapshot.documents.compactMap { doc -> Persona? in
                    guard let data = try? doc.data(as: Persona.self) else { return nil }
                    return data
                }
                
                await MainActor.run {
                    personas = loadedPersonas
                    isLoading = false
                }
            } catch {
                print("Error loading personas: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

struct FriendPersonaPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var personas: [Persona] = []
    @State private var isLoading = true
    
    var friendId: String
    var onSelect: (Persona) -> Void
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading friend's personas...")
                } else if personas.isEmpty {
                    ContentUnavailableView {
                        Label("No Personas Found", systemImage: "person.slash")
                    } description: {
                        Text("Your friend hasn't created any personas yet.")
                    }
                } else {
                    List {
                        ForEach(personas) { persona in
                            Button {
                                onSelect(persona)
                                dismiss()
                            } label: {
                                Text(persona.name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Friend's Persona")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadFriendPersonas()
            }
        }
    }
    
    private func loadFriendPersonas() {
        Task {
            do {
                let db = Firestore.firestore()
                let snapshot = try await db.collection("users").document(friendId).collection("personas").getDocuments()
                
                let loadedPersonas = snapshot.documents.compactMap { doc -> Persona? in
                    guard let data = try? doc.data(as: Persona.self) else { return nil }
                    return data
                }
                
                await MainActor.run {
                    personas = loadedPersonas
                    isLoading = false
                }
            } catch {
                print("Error loading friend personas: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

struct NewHangoutRequest {
    let title: String
    let description: String
    let date: Date
    let duration: TimeInterval
    let location: String?
    let inviteeID: String
    let hostPersonaID: String
    let inviteePersonaID: String
    
    init(title: String, description: String, date: Date, duration: TimeInterval, location: String?, inviteeID: String, hostPersonaID: String, inviteePersonaID: String) {
        self.title = title
        self.description = description
        self.date = date
        self.duration = duration
        self.location = location
        self.inviteeID = inviteeID
        self.hostPersonaID = hostPersonaID
        self.inviteePersonaID = inviteePersonaID
    }
}

#Preview {
    CreateHangoutView(onComplete: {}, selectedPersona: nil)
}

// Additional helper view functions and definitions go here

// Hide this Duration definition for now to avoid ambiguity
/*
enum Duration: CaseIterable {
    case thirtyMinutes
    case oneHour
    case twoHours
    case fourHours
    
    var displayName: String {
        switch self {
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        case .fourHours: return "4 hours"
        }
    }
    
    var rawValue: TimeInterval {
        switch self {
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .fourHours: return 4 * 60 * 60
        }
    }
}
*/ 