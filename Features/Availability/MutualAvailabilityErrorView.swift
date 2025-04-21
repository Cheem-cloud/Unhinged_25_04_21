import SwiftUI
// Removed // Removed: import Unhinged.Utilities
// Removed: // Removed: import Unhinged.Components

/// Error view when an error occurs during availability search
public struct MutualAvailabilityErrorView: View {
    let error: Error
    let onDateRangeEdit: () -> Void
    let onDurationEdit: () -> Void
    let onFriendPickerShow: () -> Void
    let onRetry: () -> Void
    let onDismissError: () -> Void
    
    public init(
        error: Error,
        onDateRangeEdit: @escaping () -> Void,
        onDurationEdit: @escaping () -> Void,
        onFriendPickerShow: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onDismissError: @escaping () -> Void
    ) {
        self.error = error
        self.onDateRangeEdit = onDateRangeEdit
        self.onDurationEdit = onDurationEdit
        self.onFriendPickerShow = onFriendPickerShow
        self.onRetry = onRetry
        self.onDismissError = onDismissError
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Layout.paddingLarge) {
                // Error icon and title
                Components.ErrorHeader(
                    title: "Something Went Wrong",
                    message: error.localizedDescription
                )
                
                // Action buttons
                VStack(spacing: AppTheme.Layout.paddingMedium) {
                    Components.PrimaryButton(
                        title: "Try Again",
                        icon: "arrow.clockwise",
                        action: onRetry
                    )
                    
                    // Specific error types get specialized recovery options
                    if let availabilityError = error as? MutualAvailabilityViewModel.MutualAvailabilityError {
                        switch availabilityError {
                        case .noMutualAvailabilityFound, .searchRangeTooNarrow:
                            Components.PrimaryButton(
                                title: "Suggest Alternative Times",
                                icon: "calendar.badge.plus",
                                action: onRetry,
                                color: AppTheme.Colors.successGradient
                            )
                            
                            Components.SecondaryButton(
                                title: "Adjust Date Range",
                                icon: "calendar",
                                action: onDateRangeEdit,
                                color: AppTheme.Colors.primary
                            )
                            
                            Components.SecondaryButton(
                                title: "Adjust Duration",
                                icon: "clock",
                                action: onDurationEdit,
                                color: AppTheme.Colors.primary
                            )
                        
                        case .calendarPermissionRequired:
                            Components.PrimaryButton(
                                title: "Use Manual Availability Instead",
                                icon: "hand.raised",
                                action: onRetry,
                                color: AppTheme.Colors.successGradient
                            )
                            
                            Components.SecondaryButton(
                                title: "Open Settings",
                                icon: "gear",
                                action: {
                                    PlatformUtilities.openSettings()
                                }
                            )
                            
                        case .networkError:
                            Components.PrimaryButton(
                                title: "Retry Connection",
                                icon: "network",
                                action: onRetry,
                                color: AppTheme.Colors.successGradient
                            )
                            
                        case .noFriendCoupleSelected:
                            Components.PrimaryButton(
                                title: "Select Friend Couple",
                                icon: "person.2",
                                action: onFriendPickerShow,
                                color: AppTheme.Colors.successGradient
                            )
                            
                        default:
                            EmptyView()
                        }
                    }
                    
                    Components.SecondaryButton(
                        title: "Dismiss",
                        action: onDismissError,
                        color: AppTheme.Colors.textSecondary
                    )
                    .padding(.top, 4)
                }
                .padding(.horizontal, AppTheme.Layout.paddingLarge)
                .padding(.top, AppTheme.Layout.paddingMedium)
            }
            .padding(.bottom, AppTheme.Layout.paddingLarge)
        }
        .background(AppTheme.Colors.background)
    }
}

// MARK: - Preview

internal struct MutualAvailabilityErrorView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample error
        let networkError = NSError(domain: "Network", code: 500, userInfo: [
            NSLocalizedDescriptionKey: "Could not connect to server"
        ])
        
        // Mock the MutualAvailabilityViewModel.MutualAvailabilityError enum
        let availabilityError = NSError(domain: "Availability", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "No mutual availability found"
        ])
        
        Group {
            // Network error preview
            MutualAvailabilityErrorView(
                error: networkError,
                onDateRangeEdit: {},
                onDurationEdit: {},
                onFriendPickerShow: {},
                onRetry: {},
                onDismissError: {}
            )
            .previewDisplayName("Network Error")
            
            // Availability error preview
            MutualAvailabilityErrorView(
                error: availabilityError,
                onDateRangeEdit: {},
                onDurationEdit: {},
                onFriendPickerShow: {},
                onRetry: {},
                onDismissError: {}
            )
            .previewDisplayName("Availability Error")
        }
    }
} 