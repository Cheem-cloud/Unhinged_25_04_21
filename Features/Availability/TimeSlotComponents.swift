import SwiftUI

/// Cell for displaying a time slot
struct TimeSlotCell: View {
    var timeSlot: TimeSlot
    var isSelected: Bool
    var onSelect: () -> Void
    
    @State private var isPressed = false
    @State private var animateSelection = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onSelect()
                animateSelection = true
                
                // Reset animation flag after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    animateSelection = false
                }
            }
        }) {
            HStack(spacing: 12) {
                // Time indicator bar
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.7))
                    .frame(width: 4)
                    .cornerRadius(2)
                
                VStack(alignment: .leading, spacing: 6) {
                    // Time range
                    Text(timeSlot.formattedTimeRange)
                        .font(.headline)
                        .foregroundColor(isSelected ? .primary : .primary)
                    
                    // Duration indicator
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatDuration(start: timeSlot.startTime, end: timeSlot.endTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    // Availability indicator
                    HStack(spacing: 4) {
                        Text("Available")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    // Selection marker
                    if isSelected {
                        HStack(spacing: 4) {
                            Text("Selected")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                                .scaleEffect(animateSelection ? 1.3 : 1.0)
                                .animation(
                                    Animation.spring(response: 0.3, dampingFraction: 0.7)
                                        .repeatCount(1), 
                                    value: animateSelection
                                )
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.12) : Color(.secondarySystemBackground))
                    .shadow(
                        color: isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1),
                        radius: isSelected ? 4 : 2,
                        x: 0,
                        y: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Helper to format duration
    private func formatDuration(start: Date, end: Date) -> String {
        let minutes = Int(end.timeIntervalSince(start) / 60)
        if minutes < 60 {
            return "\(minutes) minutes"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hour\(hours > 1 ? "s" : "")"
            } else {
                return "\(hours) hour\(hours > 1 ? "s" : "") \(remainingMinutes) min"
            }
        }
    }
}

// MARK: - More flexible variant

/// A more flexible time slot cell with customizable content
struct TimeSlotCellCustom<Content: View>: View {
    var timeSlot: TimeSlot
    var isSelected: Bool
    var onSelect: () -> Void
    var content: (TimeSlot, Bool) -> Content
    
    @State private var isPressed = false
    
    init(
        timeSlot: TimeSlot,
        isSelected: Bool,
        onSelect: @escaping () -> Void,
        @ViewBuilder content: @escaping (TimeSlot, Bool) -> Content
    ) {
        self.timeSlot = timeSlot
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.content = content
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onSelect()
            }
        }) {
            content(timeSlot, isSelected)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.blue.opacity(0.12) : Color(.secondarySystemBackground))
                        .shadow(
                            color: isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1),
                            radius: isSelected ? 4 : 2,
                            x: 0,
                            y: isSelected ? 2 : 1
                        )
                )
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
                .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
                    isPressed = pressing
                }, perform: {})
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct TimeSlotCell_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            TimeSlotCell(
                timeSlot: TimeSlot(
                    id: "preview1",
                    day: "Monday",
                    date: Date(),
                    startTime: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!,
                    endTime: Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date())!
                ),
                isSelected: false,
                onSelect: {}
            )
            
            TimeSlotCell(
                timeSlot: TimeSlot(
                    id: "preview2",
                    day: "Monday",
                    date: Date(),
                    startTime: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!,
                    endTime: Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!
                ),
                isSelected: true,
                onSelect: {}
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 