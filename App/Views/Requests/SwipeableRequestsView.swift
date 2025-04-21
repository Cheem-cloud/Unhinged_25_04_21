import SwiftUI

struct SwipeableRequestsView: View {
    @StateObject private var viewModel = HangoutsViewModel()
    @State private var currentCardIndex = 0
    @State private var offset: CGSize = .zero
    @State private var cardRotation: Double = 0
    @State private var showEmptyState = false
    
    // States for emoji animations
    @State private var showApproveEmoji = false
    @State private var showDeclineEmoji = false
    @State private var emojiOffset: CGFloat = 0
    @State private var emojiOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background - change to match the app's color scheme
            CustomTheme.Colors.background
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                // Cards
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: CustomTheme.Colors.text))
                } else if viewModel.pendingHangouts.isEmpty || showEmptyState {
                    EmptyRequestsView()
                        .transition(.opacity)
                        .onAppear {
                            // Reset state when showing empty view
                            currentCardIndex = 0
                            showEmptyState = false
                        }
                } else {
                    ZStack {
                        ForEach(Array(viewModel.pendingHangouts.enumerated()), id: \.element.id) { index, hangout in
                            if index >= currentCardIndex && index < currentCardIndex + 3 {
                                SwipeableHangoutCardView(
                                    hangout: hangout,
                                    viewModel: viewModel,
                                    offset: index == currentCardIndex ? offset : .zero,
                                    rotation: index == currentCardIndex ? cardRotation : 0
                                )
                                .zIndex(Double(viewModel.pendingHangouts.count - index))
                                .offset(y: CGFloat(index - currentCardIndex) * 10)
                                .scaleEffect(index == currentCardIndex ? 1 : 1 - CGFloat(index - currentCardIndex) * 0.05)
                                .gesture(
                                    DragGesture()
                                        .onChanged { gesture in
                                            if index == currentCardIndex {
                                                offset = gesture.translation
                                                withAnimation {
                                                    cardRotation = Double(offset.width / 20)
                                                }
                                            }
                                        }
                                        .onEnded { gesture in
                                            if index == currentCardIndex {
                                                let swipeThreshold: CGFloat = 120
                                                
                                                if offset.width > swipeThreshold {
                                                    // Accept
                                                    withAnimation(.spring()) {
                                                        offset.width = 500
                                                        cardRotation = 15
                                                    }
                                                    acceptHangout(hangout)
                                                    animateEmoji(isApproved: true)
                                                } else if offset.width < -swipeThreshold {
                                                    // Decline
                                                    withAnimation(.spring()) {
                                                        offset.width = -500
                                                        cardRotation = -15
                                                    }
                                                    declineHangout(hangout)
                                                    animateEmoji(isApproved: false)
                                                } else {
                                                    // Reset
                                                    withAnimation(.spring()) {
                                                        offset = .zero
                                                        cardRotation = 0
                                                    }
                                                }
                                            }
                                        }
                                )
                            }
                        }
                    }
                    .padding(.bottom, 60)
                }
                
                Spacer()
            }
            
            // Floating emojis overlay
            ZStack {
                // Color overlay covering the entire screen
                Group {
                    if showApproveEmoji {
                        CustomTheme.Colors.accent.opacity(0.3)
                    } else if showDeclineEmoji {
                        CustomTheme.Colors.buttonDark.opacity(0.3)
                    }
                }
                .edgesIgnoringSafeArea(.all)
                .animation(.easeInOut, value: showApproveEmoji || showDeclineEmoji)
                
                // Centered emoji
                if showApproveEmoji {
                    Text("🔥")
                        .font(.system(size: 150))
                        .opacity(emojiOpacity)
                } else if showDeclineEmoji {
                    Text("👎")
                        .font(.system(size: 150))
                        .opacity(emojiOpacity)
                }
            }
            .edgesIgnoringSafeArea(.all)
            .allowsHitTesting(false) // Allow taps to pass through
        }
        .navigationTitle("Requests")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadHangouts()
        }
        .withInterFont() // Apply Inter font to all text
    }
    
    private func animateEmoji(isApproved: Bool) {
        // Reset states
        showApproveEmoji = false
        showDeclineEmoji = false
        emojiOffset = 0
        emojiOpacity = 1
        
        // Set the appropriate emoji
        if isApproved {
            showApproveEmoji = true
        } else {
            showDeclineEmoji = true
        }
        
        // Animate the emoji fading out
        withAnimation(.easeOut(duration: 1.5)) {
            emojiOpacity = 0
        }
        
        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showApproveEmoji = false
            showDeclineEmoji = false
        }
    }
    
    private func acceptHangout(_ hangout: Hangout) {
        Task {
            await viewModel.updateHangoutStatus(hangout: hangout, newStatus: .accepted)
            
            // Small delay to allow animation to complete
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            withAnimation {
                offset = .zero
                cardRotation = 0
                moveToNextCard()
            }
        }
    }
    
    private func declineHangout(_ hangout: Hangout) {
        Task {
            await viewModel.updateHangoutStatus(hangout: hangout, newStatus: .declined)
            
            // Small delay to allow animation to complete
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            withAnimation {
                offset = .zero
                cardRotation = 0
                moveToNextCard()
            }
        }
    }
    
    private func moveToNextCard() {
        // Increment the card index
        currentCardIndex += 1
        
        // Check if we've gone through all cards
        if currentCardIndex >= viewModel.pendingHangouts.count {
            // Reset the animation properties
            offset = .zero
            cardRotation = 0
            
            // Refresh the view to show the empty state
            withAnimation {
                showEmptyState = true
            }
            
            // Also reload hangouts to make sure we have the latest data
            // This helps in case the user has received new requests meanwhile
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.viewModel.loadHangouts()
            }
        }
    }
} 