import SwiftUI

/// A view for selecting a duration in minutes
public struct DurationPickerView: View {
    @Binding var duration: Int
    
    // Common duration options in minutes
    private let durationOptions = [15, 30, 45, 60, 90, 120, 180, 240]
    
    // Custom duration
    @State private var isCustomDuration = false
    @State private var customHours = 0
    @State private var customMinutes = 0
    
    /// Initialize a duration picker
    /// - Parameter duration: Binding to the duration in minutes
    public init(duration: Binding<Int>) {
        self._duration = duration
        
        // Set initial custom duration values based on the current duration
        let initialDuration = duration.wrappedValue
        let hours = initialDuration / 60
        let minutes = initialDuration % 60
        
        _customHours = State(initialValue: hours)
        _customMinutes = State(initialValue: minutes)
        
        // Check if the initial duration is a custom value
        _isCustomDuration = State(initialValue: !durationOptions.contains(initialDuration))
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Standard duration options
            VStack(alignment: .leading, spacing: 8) {
                Text("Common Durations")
                    .font(.headline)
                    .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(durationOptions, id: \.self) { option in
                            DurationOptionCard(
                                minutes: option,
                                isSelected: !isCustomDuration && duration == option,
                                onSelect: {
                                    duration = option
                                    isCustomDuration = false
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Custom duration option
            VStack(alignment: .leading, spacing: 16) {
                Text("Custom Duration")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    // Custom duration card
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        // Hours picker
                        VStack(alignment: .leading) {
                            Text("Hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Hours", selection: $customHours) {
                                ForEach(0..<24) { hour in
                                    Text("\(hour)").tag(hour)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(width: 70, height: 100)
                            .clipped()
                        }
                        
                        Text(":")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        // Minutes picker (in 5-minute increments)
                        VStack(alignment: .leading) {
                            Text("Minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Minutes", selection: $customMinutes) {
                                ForEach(0..<12) { index in
                                    let minutes = index * 5
                                    Text(String(format: "%02d", minutes)).tag(minutes)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(width: 70, height: 100)
                            .clipped()
                        }
                        
                        Spacer()
                        
                        // Apply button
                        Button(action: {
                            let totalMinutes = (customHours * 60) + customMinutes
                            if totalMinutes > 0 {
                                duration = totalMinutes
                                isCustomDuration = true
                            }
                        }) {
                            Text("Apply")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isCustomDuration ? Color.blue : Color.clear, lineWidth: 2)
                            )
                    )
                    .padding(.horizontal)
                }
            }
            
            // Current selection display
            VStack(spacing: 8) {
                Text("Selected Duration")
                    .font(.headline)
                
                Text(formatDuration(minutes: duration))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
            )
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private func formatDuration(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minutes"
        } else if minutes == 60 {
            return "1 hour"
        } else if minutes % 60 == 0 {
            return "\(minutes / 60) hours"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours) hour\(hours > 1 ? "s" : "") \(remainingMinutes) min"
        }
    }
}

// MARK: - Duration Option Card

struct DurationOptionCard: View {
    let minutes: Int
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                // Duration icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "clock")
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                
                // Duration text
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDuration(minutes: minutes))
                        .font(.headline)
                        .foregroundColor(isSelected ? .primary : .secondary)
                }
                .padding(.leading, 8)
                
                Spacer()
                
                // Selected indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 22))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDuration(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minutes"
        } else if minutes == 60 {
            return "1 hour"
        } else if minutes % 60 == 0 {
            return "\(minutes / 60) hours"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours) hour\(hours > 1 ? "s" : "") \(remainingMinutes) min"
        }
    }
}

// MARK: - Preview

struct DurationPickerView_Previews: PreviewProvider {
    static var previews: some View {
        DurationPickerView(duration: .constant(60))
            .previewLayout(.sizeThatFits)
            .padding()
    }
} 