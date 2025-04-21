import SwiftUI
import FirebaseAuth

struct PartnerPersonasView: View {
    @StateObject private var viewModel = PartnerPersonasViewModel()
    @State private var currentIndex = 0
    @State private var hangoutPersona: Persona?
    @State private var showCreateHangout = false
    @State private var dragOffset: CGFloat = 0
    @State private var isAnimating = false
    @State private var showPokeAlert = false
    @State private var pokedPersonaName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Use the style guide background color
                CustomTheme.Colors.background
                    .edgesIgnoringSafeArea(.all)
                
                if viewModel.personas.isEmpty {
                    EmptyStateView()
                } else {
                    VStack(spacing: 0) {
                        // Card container - add some top padding
                        Spacer()
                            .frame(height: 20)
                        
                        GeometryReader { geometry in
                            if !viewModel.personas.isEmpty {
                                // Card stack with animation
                                ZStack {
                                    // Show up to 3 cards in the stack for better visual effect
                                    ForEach(visibleCardIndices(), id: \.self) { index in
                                        let persona = viewModel.personas[index]
                                        
                                        PersonaCard(
                                            persona: persona,
                                            onTap: {}, // No-op since we don't want card tap
                                            onRequestHangout: {
                                                print("DEBUG: Request hangout for \(persona.name)")
                                                hangoutPersona = persona
                                                showCreateHangout = true
                                            },
                                            onPoke: {
                                                sendPokeNotification(to: persona)
                                            }
                                        )
                                        .frame(
                                            width: min(geometry.size.width * 0.95, 400),
                                            height: min(geometry.size.height * 0.8, 700)
                                        )
                                        .scaleEffect(cardScale(for: index))
                                        .offset(x: cardOffset(for: index))
                                        .zIndex(zIndex(for: index))
                                        .opacity(cardOpacity(for: index))
                                    }
                                }
                                .offset(x: dragOffset)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if !isAnimating {
                                                dragOffset = value.translation.width
                                            }
                                        }
                                        .onEnded { value in
                                            if isAnimating { return }
                                            
                                            // Determine if the drag was significant enough
                                            let threshold: CGFloat = 50
                                            
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                                isAnimating = true
                                                
                                                if dragOffset > threshold && currentIndex > 0 {
                                                    // Swiped right - show previous
                                                    currentIndex -= 1
                                                } else if dragOffset < -threshold && currentIndex < viewModel.personas.count - 1 {
                                                    // Swiped left - show next
                                                    currentIndex += 1
                                                }
                                                
                                                // Reset drag offset
                                                dragOffset = 0
                                            }
                                            
                                            // Reset animation flag after animation completes
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                isAnimating = false
                                            }
                                        }
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        
                        Spacer()
                        
                        // Pagination dots and counter - increased bottom padding
                        VStack {
                            // Pagination dots
                            HStack(spacing: 10) {
                                ForEach(0..<viewModel.personas.count, id: \.self) { index in
                                    Circle()
                                        .fill(index == currentIndex ? CustomTheme.Colors.text : CustomTheme.Colors.text.opacity(0.4))
                                        .frame(width: 10, height: 10)
                                }
                            }
                            .padding(.top, 10)
                            
                            // Card counter
                            Text("\(currentIndex + 1) of \(viewModel.personas.count)")
                                .font(.custom("InterVariable", size: 12, fallback: .caption))
                                .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
                                .padding(.top, 5)
                        }
                        .padding(.bottom, 100) // Much more bottom padding to avoid tab bar
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: CustomTheme.Colors.text))
                }
            }
            .navigationTitle("Find a Date")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.loadPartnerPersonas()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(CustomTheme.Colors.text)
                    }
                }
            }
            .onAppear {
                viewModel.loadPartnerPersonas()
            }
            .alert("Poke Sent! ❤️", isPresented: $showPokeAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You poked \(pokedPersonaName)! They'll receive a notification.")
            }
        }
        .fullScreenCover(item: $hangoutPersona) { persona in
            HangoutCreationView(
                partnerPersona: persona,
                onComplete: {
                    print("DEBUG: HangoutCreationView completed for persona: \(persona.name)")
                    hangoutPersona = nil
                    showCreateHangout = false
                }
            )
        }
    }
    
    // Function to send a poke notification
    private func sendPokeNotification(to persona: Persona) {
        print("🔍 DEBUG: Poke button pressed for persona: \(persona.name)")
        
        guard let partnerId = viewModel.partnerId,
              let userId = Auth.auth().currentUser?.uid,
              let currentUser = Auth.auth().currentUser else {
            print("❌ ERROR: Failed to send poke - Missing user data")
            print("  partnerId: \(String(describing: viewModel.partnerId))")
            print("  userId: \(String(describing: Auth.auth().currentUser?.uid))")
            return
        }
        
        print("✅ DEBUG: Preparing to send poke notification")
        print("  From user: \(userId) (\(currentUser.displayName ?? "Unknown"))")
        print("  To user: \(partnerId)")
        print("  For persona: \(persona.name) (ID: \(persona.id ?? "unknown"))")
        
        let senderName = currentUser.displayName ?? "Someone"
        
        // Send the notification
        NotificationService.shared.sendPokeNotification(
            to: partnerId,
            from: senderName
        )
        
        // Show confirmation
        pokedPersonaName = persona.name
        showPokeAlert = true
        
        print("✅ DEBUG: Poke notification sent to service")
    }
    
    // Helper to determine which cards are visible
    private func visibleCardIndices() -> [Int] {
        let personasCount = viewModel.personas.count
        
        if personasCount == 0 {
            return []
        } else if personasCount == 1 {
            return [0]
        } else {
            // For multiple cards, show current, next, and previous if available
            var indices = [currentIndex]
            
            // Add next card if available
            if currentIndex < personasCount - 1 {
                indices.append(currentIndex + 1)
            }
            
            // Add previous card if available
            if currentIndex > 0 {
                indices.append(currentIndex - 1)
            }
            
            return indices.sorted() // Sort to maintain consistent order
        }
    }
    
    // Scale for each card in the stack
    private func cardScale(for index: Int) -> CGFloat {
        if index == currentIndex {
            return 1.0
        } else if index == currentIndex + 1 {
            // Next card is slightly smaller
            return 0.9
        } else if index == currentIndex - 1 {
            // Previous card is slightly smaller too
            return 0.9
        } else {
            return 0.8
        }
    }
    
    // Horizontal offset for cards
    private func cardOffset(for index: Int) -> CGFloat {
        if index == currentIndex {
            return 0
        } else if index == currentIndex + 1 {
            // Next card is peeking from right side
            return 300
        } else if index == currentIndex - 1 {
            // Previous card is peeking from left side
            return -300
        } else {
            return 0
        }
    }
    
    // Z-index for stacking cards
    private func zIndex(for index: Int) -> Double {
        if index == currentIndex {
            return 3
        } else if index == currentIndex + 1 || index == currentIndex - 1 {
            return 2
        } else {
            return 1
        }
    }
    
    // Opacity for cards
    private func cardOpacity(for index: Int) -> Double {
        if index == currentIndex {
            return 1.0
        } else if index == currentIndex + 1 || index == currentIndex - 1 {
            return 0.7
        } else {
            return 0.5
        }
    }
}

// Empty state view
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.fill.questionmark")
                .font(.interSystem(size: 70))
                .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
            
            Text("No potential dates found")
                .font(.custom("InterVariable", size: 24, fallback: .title2))
                .fontWeight(.medium)
                .foregroundColor(CustomTheme.Colors.text)
            
            Text("Create your own persona to start matching")
                .font(.custom("InterVariable", size: 18, fallback: .body))
                .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                // Navigate to profile creation
            }) {
                Text("CREATE YOUR PROFILE")
                    .font(.custom("InterVariable", size: 16, fallback: .headline))
                    .fontWeight(.semibold)
                    .foregroundColor(CustomTheme.Colors.accent)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(CustomTheme.Colors.accent, lineWidth: 1)
                    )
            }
            .padding(.top, 10)
        }
        .padding()
    }
} 