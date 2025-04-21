import SwiftUI

struct PersonaDetailView: View {
    let persona: Persona
    @State private var showHangoutCreation = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Profile image
                ZStack(alignment: .bottomTrailing) {
                    if let imageURL = persona.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 300)
                                    .clipped()
                            } else if phase.error != nil {
                                Image(systemName: "photo")
                                    .font(.system(size: 80))
                                    .foregroundColor(.gray)
                                    .frame(height: 300)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.lightGray)
                            } else {
                                ProgressView()
                                    .frame(height: 300)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                            .frame(height: 300)
                            .frame(maxWidth: .infinity)
                            .background(Color.lightGray)
                    }
                    
                    if persona.isPremium {
                        Image(systemName: "star.fill")
                            .foregroundColor(.mutedGold)
                            .padding(10)
                            .background(Circle().fill(Color.white.opacity(0.9)))
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                            .padding(16)
                    }
                }
                
                // Profile info
                VStack(alignment: .leading, spacing: 20) {
                    // Name and age
                    HStack {
                        Text(persona.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.deepRed)
                        
                        Spacer()
                        
                        if let age = persona.age {
                            Text("\(age)")
                                .font(.title2)
                                .foregroundColor(.charcoal)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.lightGray.opacity(0.5))
                                )
                        }
                    }
                    
                    // Breed
                    if let breed = persona.breed {
                        Text(breed)
                            .font(.headline)
                            .foregroundColor(.charcoal)
                    }
                    
                    // Bio
                    if let bio = persona.bio, !bio.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio")
                                .font(.headline)
                                .foregroundColor(.deepRed)
                            
                            Text(bio)
                                .font(.body)
                                .foregroundColor(.charcoal)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .background(Color.lightGray.opacity(0.2))
                        .cornerRadius(10)
                    }
                    
                    // Interests
                    if let interests = persona.interests, !interests.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Interests")
                                .font(.headline)
                                .foregroundColor(.deepRed)
                            
                            // Modern FlowLayout with LazyVGrid
                            let columns = [
                                GridItem(.adaptive(minimum: 100, maximum: 200), spacing: 8)
                            ]
                            
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                                ForEach(interests, id: \.self) { interest in
                                    Text(interest)
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Color.tealGreen))
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding()
                        .background(Color.lightGray.opacity(0.2))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .onAppear {
            print("DEBUG: PersonaDetailView appeared with persona: \(persona.name)")
            print("DEBUG: Persona details - ID: \(persona.id ?? "nil"), Bio: \(persona.bio ?? "nil")")
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    print("DEBUG: Starting HangoutCreationView with persona: \(persona.name), ID: \(persona.id ?? "nil")")
                    dismiss() // Dismiss the current sheet first
                    showHangoutCreation = true
                }) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3)
                        .foregroundColor(.deepRed)
                }
            }
        }
        .fullScreenCover(isPresented: $showHangoutCreation) {
            HangoutCreationView(
                partnerPersona: persona,
                onComplete: {
                    print("DEBUG: HangoutCreationView completed for persona: \(persona.name)")
                    showHangoutCreation = false
                }
            )
        }
    }
}

#Preview {
    PersonaDetailView(persona: Persona(
        id: "1", 
        name: "Sample", 
        bio: "I love long walks and playing fetch!", 
        age: 28,
        breed: "Golden Retriever",
        interests: ["Walking", "Swimming", "Fetch", "Treats", "Napping", "Playing"],
        isPremium: true
    ))
} 