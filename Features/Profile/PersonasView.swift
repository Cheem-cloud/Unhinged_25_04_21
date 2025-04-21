import SwiftUI

struct PersonasView: View {
    @StateObject private var viewModel = PersonasViewModel()
    @State private var showingAddPersona = false
    
    var body: some View {
        List {
            ForEach(viewModel.personas) { persona in
                ProfilePersonaCard(persona: persona)
                    .padding(.vertical, 4)
            }
            .onDelete(perform: viewModel.deletePersona)
        }
        .navigationTitle("My Personas")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    showingAddPersona = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPersona) {
            AddPersonaView(onComplete: { viewModel.loadPersonas() })
        }
        .onAppear {
            viewModel.loadPersonas()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

struct ProfilePersonaCard: View {
    let persona: Persona
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                if let imageURL = persona.imageURL, !imageURL.isEmpty {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .background(
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                        .frame(width: 60, height: 60)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                        .background(
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(persona.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(persona.bio ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if persona.isPremium {
                        Text("Premium")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.mutedGold)
                            .clipShape(Capsule())
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        PersonasView()
    }
} 