import SwiftUI

/// Namespace for common UI components
public enum Components {
    /// Empty state view for when there's no content
    public struct EmptyState: View {
        private let icon: String
        private let title: String
        private let message: String
        private let actionTitle: String?
        private let action: (() -> Void)?
        
        /// Initialize a new empty state view
        /// - Parameters:
        ///   - icon: SF Symbol name for the icon
        ///   - title: Title text
        ///   - message: Description message
        ///   - actionTitle: Optional button text
        ///   - action: Optional button action
        public init(
            icon: String,
            title: String,
            message: String,
            actionTitle: String? = nil,
            action: (() -> Void)? = nil
        ) {
            self.icon = icon
            self.title = title
            self.message = message
            self.actionTitle = actionTitle
            self.action = action
        }
        
        public var body: some View {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: icon)
                    .font(.system(size: 70))
                    .foregroundColor(.gray)
                
                VStack(spacing: 16) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if let actionTitle = actionTitle, let action = action {
                    Button(action: action) {
                        Text(actionTitle)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(30)
                    }
                    .padding(.top, 8)
                }
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    /// Loading indicator with optional text
    public struct LoadingIndicator: View {
        private let message: String?
        private let progress: Double?
        
        /// Initialize a new loading indicator
        /// - Parameters:
        ///   - message: Optional loading message
        ///   - progress: Optional progress value (0-1)
        public init(message: String? = nil, progress: Double? = nil) {
            self.message = message
            self.progress = progress
        }
        
        public var body: some View {
            VStack(spacing: 20) {
                if let progress = progress {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .padding()
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .padding()
                }
                
                if let message = message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
            .background(CustomTheme.Colors.background.opacity(0.8))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 10)
        }
    }
    
    /// Button with icon and text
    public struct IconButton: View {
        private let icon: String
        private let text: String
        private let color: Color
        private let action: () -> Void
        
        /// Initialize a new icon button
        /// - Parameters:
        ///   - icon: SF Symbol name
        ///   - text: Button text
        ///   - color: Button color
        ///   - action: Button action
        public init(
            icon: String,
            text: String,
            color: Color = .blue,
            action: @escaping () -> Void
        ) {
            self.icon = icon
            self.text = text
            self.color = color
            self.action = action
        }
        
        public var body: some View {
            Button(action: action) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Text(text)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(color.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
} 