import SwiftUI
// Removed // Removed: import Unhinged.Utilities
// Removed: // Removed: import Unhinged.Components

/// Create hangout view
public struct MutualAvailabilityCreateHangoutView: View {
    // Data
    let selectedTime: TimeSlot
    let friendRelationshipID: String
    
    // State
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var location: String = ""
    @State private var hangoutType: HangoutType = .inPerson
    
    // Actions
    let onCreateHangout: (String, String, String, HangoutType) -> Void
    let onCancel: () -> Void
    
    // Styling
    let theme: ThemeConfig
    
    public init(
        selectedTime: TimeSlot,
        friendRelationshipID: String,
        onCreateHangout: @escaping (String, String, String, HangoutType) -> Void,
        onCancel: @escaping () -> Void,
        theme: ThemeConfig = .standard
    ) {
        self.selectedTime = selectedTime
        self.friendRelationshipID = friendRelationshipID
        self.onCreateHangout = onCreateHangout
        self.onCancel = onCancel
        self.theme = theme
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: theme.spacing.large) {
                    VStack {
                        VStack(spacing: theme.spacing.medium) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(theme.colors.primary.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "calendar")
                                        .foregroundColor(theme.colors.primary)
                                }
                                
                                Text(selectedTime.formattedDate)
                                    .font(theme.typography.body)
                                    .fontWeight(.medium)
                                    .padding(.leading, theme.spacing.small)
                                
                                Spacer()
                            }
                            
                            Divider()
                            
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(theme.colors.primary.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "clock")
                                        .foregroundColor(theme.colors.primary)
                                }
                                
                                Text(selectedTime.formattedTimeRange)
                                    .font(theme.typography.body)
                                    .fontWeight(.medium)
                                    .padding(.leading, theme.spacing.small)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(theme.cornerRadius.medium)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                    
                    VStack(spacing: theme.spacing.medium) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hangout Title")
                                .font(theme.typography.caption)
                                .foregroundColor(theme.colors.secondary)
                            
                            HStack {
                                Image(systemName: "textformat.alt")
                                    .foregroundColor(theme.colors.primary)
                                
                                TextField("Enter title", text: $title)
                                    .font(theme.typography.body)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(theme.cornerRadius.small)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(theme.typography.caption)
                                .foregroundColor(theme.colors.secondary)
                            
                            HStack(alignment: .top) {
                                Image(systemName: "text.alignleft")
                                    .foregroundColor(theme.colors.primary)
                                    .padding(.top, 8)
                                
                                TextEditor(text: $description)
                                    .font(theme.typography.body)
                                    .frame(minHeight: 100)
                                    .padding(8)
                                    .background(Color.clear)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(theme.cornerRadius.small)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location")
                                .font(theme.typography.caption)
                                .foregroundColor(theme.colors.secondary)
                            
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(theme.colors.primary)
                                
                                TextField("Where will you meet?", text: $location)
                                    .font(theme.typography.body)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(theme.cornerRadius.small)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hangout Type")
                                .font(theme.typography.caption)
                                .foregroundColor(theme.colors.secondary)
                            
                            Picker("Hangout Type", selection: $hangoutType) {
                                ForEach(HangoutType.allCases, id: \.self) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(theme.cornerRadius.small)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: theme.spacing.extraLarge)
                    
                    Button(action: {
                        onCreateHangout(title, description, location, hangoutType)
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Create Hangout")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(title.isEmpty ? theme.colors.accent.opacity(0.5) : theme.colors.accent)
                        .foregroundColor(.white)
                        .cornerRadius(theme.cornerRadius.medium)
                    }
                    .disabled(title.isEmpty)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Create Hangout")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(action: onCancel) {
                    Text("Cancel")
                        .foregroundColor(theme.colors.primary)
                }
            )
        }
    }
}

// MARK: - Preview

internal struct MutualAvailabilityCreateHangoutView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default theme
            MutualAvailabilityCreateHangoutView(
                selectedTime: TimeSlot(
                    id: "preview",
                    day: "Monday",
                    date: Date(),
                    startTime: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!,
                    endTime: Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date())!
                ),
                friendRelationshipID: "preview-relationship",
                onCreateHangout: { _, _, _, _ in },
                onCancel: { }
            )
            .previewDisplayName("Default Theme")
            
            // Compact theme
            MutualAvailabilityCreateHangoutView(
                selectedTime: TimeSlot(
                    id: "preview",
                    day: "Monday",
                    date: Date(),
                    startTime: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!,
                    endTime: Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date())!
                ),
                friendRelationshipID: "preview-relationship",
                onCreateHangout: { _, _, _, _ in },
                onCancel: { },
                theme: .compact
            )
            .previewDisplayName("Compact Theme")
            
            // Accessible theme
            MutualAvailabilityCreateHangoutView(
                selectedTime: TimeSlot(
                    id: "preview",
                    day: "Monday",
                    date: Date(),
                    startTime: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!,
                    endTime: Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date())!
                ),
                friendRelationshipID: "preview-relationship",
                onCreateHangout: { _, _, _, _ in },
                onCancel: { },
                theme: .accessible
            )
            .previewDisplayName("Accessible Theme")
        }
    }
} 