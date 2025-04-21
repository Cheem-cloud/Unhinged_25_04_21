import SwiftUI

/// Enhanced loading view with customizable animation
public struct LoadingView: View {
    var message: String
    var steps: [String]
    
    @State private var currentStep = 0
    
    // For dot animation
    @State private var showingDot1 = false
    @State private var showingDot2 = false
    @State private var showingDot3 = false
    
    public init(
        message: String,
        steps: [String] = [
            "Loading...",
            "Almost there...",
            "Just a moment..."
        ]
    ) {
        self.message = message
        self.steps = steps
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Main loading icon
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                // Progress circle with rotation animation
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(Angle(degrees: 360 * Double(currentStep) / Double(steps.count)))
                    .rotationEffect(Angle(degrees: -90))
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: currentStep
                    )
                
                // Calendar icon in center
                Image(systemName: "calendar")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
            }
            .padding()
            
            // Progress stage
            VStack(spacing: 8) {
                // Main message
                Text(message)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Current step detail
                Text(steps[currentStep % steps.count])
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .animation(.easeInOut(duration: 0.5), value: currentStep)
                
                // Animated dots
                HStack(spacing: 4) {
                    Circle()
                        .fill(showingDot1 ? Color.blue : Color.blue.opacity(0.3))
                        .frame(width: 8, height: 8)
                    
                    Circle()
                        .fill(showingDot2 ? Color.blue : Color.blue.opacity(0.3))
                        .frame(width: 8, height: 8)
                    
                    Circle()
                        .fill(showingDot3 ? Color.blue : Color.blue.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            // Start animations
            animateDots()
            animateSteps()
        }
    }
    
    // Animate the progress dots
    private func animateDots() {
        // Animation for first dot
        withAnimation(Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(0)) {
            showingDot1 = true
        }
        
        // Animation for second dot
        withAnimation(Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(0.2)) {
            showingDot2 = true
        }
        
        // Animation for third dot
        withAnimation(Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(0.4)) {
            showingDot3 = true
        }
    }
    
    // Animate through the steps
    private func animateSteps() {
        // Create a timer to cycle through steps
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation {
                currentStep = (currentStep + 1) % steps.count
            }
        }
    }
}

// MARK: - Calendar-specific loading view

/// Specialized loading view for calendar operations
public struct CalendarLoadingView: View {
    var message: String
    
    private let steps = [
        "Checking calendars...",
        "Finding available times...",
        "Comparing schedules...",
        "Almost there..."
    ]
    
    public init(message: String = "Finding Available Times") {
        self.message = message
    }
    
    public var body: some View {
        LoadingView(message: message, steps: steps)
    }
}

// MARK: - Simple loading view variant

/// A simpler loading view for quick operations
public struct SimpleLoadingView: View {
    var message: String
    
    public init(message: String = "Loading...") {
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoadingView(message: "Finding Available Times")
                .previewDisplayName("Standard Loading")
            
            CalendarLoadingView()
                .previewDisplayName("Calendar Loading")
            
            SimpleLoadingView()
                .previewDisplayName("Simple Loading")
        }
    }
} 