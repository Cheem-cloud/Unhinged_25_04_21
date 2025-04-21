import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@MainActor
class CreateHangoutViewModel: ObservableObject {
    // Define the data structure for hangout creation as a nested type
    struct HangoutData {
        let title: String
        let description: String
        let startDate: Date
        let endDate: Date
        let location: String?
        let inviteeID: String?
        let hostPersonaID: String
        let inviteePersonaID: String?
    }
    
    @Published var friends: [AppUser] = []
    @Published var personas: [Persona] = []
    @Published var friendPersonas: [Persona] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let firestoreService = FirestoreService()
    
    init() {
        Task {
            await loadFriends()
            await loadPersonas()
        }
    }
    
    func loadFriends() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let fetchedFriends = try await firestoreService.getFriends(for: userId)
            self.friends = fetchedFriends
        } catch {
            self.error = error
        }
    }
    
    func loadPersonas() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let fetchedPersonas = try await firestoreService.getPersonas(for: userId)
            self.personas = fetchedPersonas
        } catch {
            self.error = error
        }
    }
    
    func loadFriendPersonas(_ friendId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fetchedPersonas = try await firestoreService.getPersonas(for: friendId)
            self.friendPersonas = fetchedPersonas
        } catch {
            self.error = error
        }
    }
    
    func createHangout(hangoutData: HangoutData) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // TODO: Implement actual hangout creation
            // Convert HangoutData to Hangout model
            let hangout = Hangout(
                id: nil,
                title: hangoutData.title,
                description: hangoutData.description,
                startDate: hangoutData.startDate,
                endDate: hangoutData.endDate,
                location: hangoutData.location,
                creatorID: Auth.auth().currentUser?.uid ?? "",
                creatorPersonaID: hangoutData.hostPersonaID,
                inviteeID: hangoutData.inviteeID ?? "",
                inviteePersonaID: hangoutData.inviteePersonaID ?? "",
                status: .pending
            )
            
            _ = try await firestoreService.createHangout(hangout)
        } catch {
            self.error = error
        }
    }
} 