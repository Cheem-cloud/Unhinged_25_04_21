import SwiftUI

struct PersonaCard: View {
    let persona: Persona
    let onTap: () -> Void
    let onRequestHangout: () -> Void
    let onPoke: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image section - make larger
            ZStack(alignment: .topTrailing) {
                if let imageURL = persona.imageURL {
                    AsyncImage(url: URL(string: imageURL)) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 280) // Larger image height
                                .clipped()
                        } else if phase.error != nil {
                            Image(systemName: "photo")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                                .frame(height: 280) // Match height
                                .frame(maxWidth: .infinity)
                                .background(Color.lightGray)
                        } else {
                            ProgressView()
                                .frame(height: 280) // Match height
                                .frame(maxWidth: .infinity)
                                .background(Color.lightGray.opacity(0.3))
                        }
                    }
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 70)) // Larger icon
                        .foregroundColor(.gray)
                        .frame(height: 280) // Match height
                        .frame(maxWidth: .infinity)
                        .background(Color.lightGray)
                }
                
                if persona.isPremium {
                    Image(systemName: "star.fill")
                        .font(.system(size: 22)) // Larger premium indicator
                        .foregroundColor(.mutedGold)
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.8)))
                        .padding(12)
                }
            }
            
            // Basic info - larger text and more padding
            VStack(alignment: .leading, spacing: 8) { // Increased spacing
                HStack {
                    Text(persona.name)
                        .font(.title2) // Larger name
                        .fontWeight(.bold)
                        .foregroundColor(.deepRed)
                    
                    Spacer()
                    
                    if let age = persona.age {
                        Text("\(age)")
                            .font(.title3) // Larger age
                            .foregroundColor(.charcoal.opacity(0.7))
                    }
                }
                
                if let breed = persona.breed {
                    Text(breed)
                        .font(.subheadline) // Larger breed
                        .foregroundColor(.charcoal)
                }
                
                if let bio = persona.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.callout) // Larger bio
                        .foregroundColor(.charcoal.opacity(0.8))
                        .lineLimit(3) // Show more text
                        .padding(.top, 4)
                }
                
                // Buttons row - Request Hangout and Poke
                HStack(spacing: 10) {
                    // Request Hangout button
                    Button(action: {
                        onRequestHangout()
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                                .font(.subheadline)
                            Text("Request Hangout")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.deepRed)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    // Poke button
                    Button(action: {
                        print("💖 POKE: Poke button tapped for persona: \(persona.name)")
                        onPoke()
                    }) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .font(.subheadline)
                            Text("Poke")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.pink)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding(.top, 10)
            }
            .padding(16)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
        .frame(maxWidth: .infinity)
    }
} 