import SwiftUI
import FirebaseAuth

struct PartnerPersonasView: View {
    @StateObject private var viewModel: PartnerPersonasViewModel
    @State private var selection = Set<String>()
    
    init(relationshipID: String) {
        _viewModel = StateObject(wrappedValue: PartnerPersonasViewModel(relationshipID: relationshipID))
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
            } else {
                List(viewModel.personas, id: \.id, selection: $selection) { persona in
                    personaRow(persona)
                }
                .listStyle(.inset)
                .environment(\.defaultMinListRowHeight, 100)
                .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Partner Personas")
        .toolbar {
            #if !os(macOS)
            EditButton()
            #endif
        }
    }
    
    private func personaRow(_ persona: PartnerPersona) -> some View {
        HStack(spacing: 15) {
            // Profile Image or Emoji
            ZStack {
                Circle()
                    .fill(Color(hex: persona.color))
                    .frame(width: 60, height: 60)
                
                Text(persona.emoji)
                    .font(.system(size: 30))
            }
            
            // Persona Details
            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text(persona.name)
                    .font(.headline)
                    .fontWeight(.bold)
                
                // Description
                Text(persona.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Preferences (if available)
                if !persona.preferences.isEmpty {
                    tagsView(preferences: persona.preferences)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    // Tags view for preferences
    private func tagsView(preferences: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(preferences, id: \.self) { preference in
                    Text(preference)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
        .frame(height: 28)
    }
}

// MARK: - Color Extension for hex support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct PartnerPersonasView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PartnerPersonasView(relationshipID: "sample-relationship-id")
        }
    }
} 