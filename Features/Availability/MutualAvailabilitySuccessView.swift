import SwiftUI
// Removed // Removed: import Unhinged.Utilities
// Removed: // Removed: import Unhinged.Components

/// Success view shown after hangout creation
public struct MutualAvailabilitySuccessView: View {
    // Data
    let selectedTimeSlot: TimeSlot?
    
    // Actions
    let onViewDetails: () -> Void
    let onFindAnother: () -> Void
    
    // Styling
    let spacing: CGFloat
    let iconSize: CGFloat
    let accentColor: Color
    let secondaryColor: Color
    
    public init(
        selectedTimeSlot: TimeSlot?,
        onViewDetails: @escaping () -> Void,
        onFindAnother: @escaping () -> Void,
        spacing: CGFloat = AppTheme.Layout.paddingLarge,
        iconSize: CGFloat = 80,
        accentColor: Color = AppTheme.Colors.success,
        secondaryColor: Color = AppTheme.Colors.successGradient
    ) {
        self.selectedTimeSlot = selectedTimeSlot
        self.onViewDetails = onViewDetails
        self.onFindAnother = onFindAnother
        self.spacing = spacing
        self.iconSize = iconSize
        self.accentColor = accentColor
        self.secondaryColor = secondaryColor
    }
    
    public var body: some View {
        VStack(spacing: spacing) {
            // Success icon and title - replaced Components.SuccessHeader
            VStack(spacing: spacing / 2) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: iconSize, height: iconSize)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(accentColor)
                        .frame(width: iconSize * 0.6, height: iconSize * 0.6)
                }
                
                Text("Hangout Created!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(.top, spacing)
            
            // Time slot details
            if let timeSlot = selectedTimeSlot {
                // Replaced Components.Card
                VStack {
                    VStack(spacing: spacing / 2) {
                        HStack {
                            // Replaced Components.CircleIcon
                            ZStack {
                                Circle()
                                    .fill(accentColor.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "calendar")
                                    .foregroundColor(accentColor)
                            }
                            
                            Text(timeSlot.formattedDate)
                                .font(AppTheme.Typography.body)
                                .fontWeight(.medium)
                                .padding(.leading, 8)
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        HStack {
                            // Replaced Components.CircleIcon
                            ZStack {
                                Circle()
                                    .fill(accentColor.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "clock")
                                    .foregroundColor(accentColor)
                            }
                            
                            Text(timeSlot.formattedTimeRange)
                                .font(AppTheme.Typography.body)
                                .fontWeight(.medium)
                                .padding(.leading, 8)
                            
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            
            // Actions
            VStack(spacing: spacing / 2) {
                // Replaced Components.PrimaryButton
                Button(action: onViewDetails) {
                    HStack {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 16, weight: .medium))
                        Text("View Hangout Details")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // Replaced Components.PrimaryButton
                Button(action: onFindAnother) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 16, weight: .medium))
                        Text("Find Another Time")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(secondaryColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

internal struct MutualAvailabilitySuccessView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default styling
            MutualAvailabilitySuccessView(
                selectedTimeSlot: TimeSlot(
                    id: "preview",
                    day: "Monday",
                    date: Date(),
                    startTime: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!,
                    endTime: Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
                ),
                onViewDetails: {},
                onFindAnother: {}
            )
            .previewDisplayName("Default Style")
            
            // Custom styling
            MutualAvailabilitySuccessView(
                selectedTimeSlot: TimeSlot(
                    id: "preview",
                    day: "Monday",
                    date: Date(),
                    startTime: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!,
                    endTime: Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
                ),
                onViewDetails: {},
                onFindAnother: {},
                spacing: 16,
                iconSize: 60,
                accentColor: .blue,
                secondaryColor: .indigo
            )
            .previewDisplayName("Custom Style")
        }
    }
} 