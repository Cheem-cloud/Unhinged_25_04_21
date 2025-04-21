import SwiftUI

/// Loading view shown during availability search
public struct MutualAvailabilityLoadingView: View {
    let progress: Float?
    
    public init(progress: Float?) {
        self.progress = progress
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Finding Available Times")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Checking calendars and availability")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if let progress = progress {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal, 40)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview

internal struct MutualAvailabilityLoadingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Indeterminate loading
            MutualAvailabilityLoadingView(progress: nil)
                .previewDisplayName("Indeterminate")
            
            // Progress at 50%
            MutualAvailabilityLoadingView(progress: 0.5)
                .previewDisplayName("50% Progress")
        }
    }
} 