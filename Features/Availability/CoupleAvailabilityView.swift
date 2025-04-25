import SwiftUI
import Firebase
import FirebaseAuth
import UIKit
import Foundation // Ensure Foundation is imported before using extensions

/// View for editing couple availability preferences
struct CoupleAvailabilityView: View {
    @StateObject private var viewModel = CoupleAvailabilityViewModel()
    @State private var selectedDate: Date = Date()
    @State private var isCalendarExpanded = false
    @State private var isLoading = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerView
                        
                        // Calendar selection
                        calendarView
                        
                        // Available time slots
                        availabilityView
                    }
                    .padding(.horizontal)
                }
                
                // Loading overlay
                if isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            .navigationBarTitle("Couple Availability", displayMode: .inline)
            .navigationBarItems(
                trailing: Button(action: {
                    viewModel.refreshAvailability()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.primary)
                }
            )
        .onAppear {
                isLoading = true
                viewModel.loadAvailability {
                    isLoading = false
                }
            }
            .onChange(of: selectedDate) { newDate in
                viewModel.selectedDate = newDate
            }
        }
    }
    
    // MARK: - Sub Views
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Find Free Time Together")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Below are times when both you and your partner are available based on your calendars and availability settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let partner = viewModel.partner {
                HStack(spacing: 12) {
                    Text("Showing availability with:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    
                    HStack {
                        if let photoURL = partner.photoURL, !photoURL.isEmpty {
                            AsyncImage(url: URL(string: photoURL)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.accentColor)
                        }
                        
                        Text(partner.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
    
    private var calendarView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Select Date")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isCalendarExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text(isCalendarExpanded ? "Collapse" : "Expand")
                            .font(.subheadline)
                        
                        Image(systemName: isCalendarExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                }
            }
            
            if isCalendarExpanded {
                // Full month calendar view
                VStack {
                    DatePicker(
                        "Select a date",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .labelsHidden()
                }
                .padding(.vertical, 8)
                .background(Color.secondaryBackground)
                .cornerRadius(12)
            } else {
                // Week view
                HStack {
                    // Previous week button
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Week day buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(-3...3, id: \.self) { offset in
                                let date = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) ?? selectedDate
                                dayButton(date: date)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Next week button
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(16)
    }
    
    private func dayButton(date: Date) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let hasAvailability = viewModel.hasAvailabilityFor(date: date)
        
        return Button(action: {
            selectedDate = date
        }) {
            VStack(spacing: 8) {
                // Weekday
                Text(date.weekdayShortName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                // Day
                Text("\(calendar.component(.day, from: date))")
                    .font(.headline)
                
                // Indicator
                if hasAvailability {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 44, height: 70)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var availabilityView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Available Times")
                    .font(.headline)
                
                Spacer()
                
                Text(dateFormatter.string(from: selectedDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let slots = viewModel.availableSlots[selectedDate], !slots.isEmpty {
                timeSlotsList(slots: slots)
            } else {
                noAvailabilityView
            }
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(16)
    }
    
    private func timeSlotsList(slots: [AvailabilityTimeSlot]) -> some View {
        VStack(spacing: 12) {
            ForEach(slots.indices, id: \.self) { index in
                let slot = slots[index]
                
                timeSlotRow(slot: slot)
                
                if index < slots.count - 1 {
                    Divider()
                }
            }
        }
    }
    
    private func timeSlotRow(slot: AvailabilityTimeSlot) -> some View {
        HStack {
            // Time range
            VStack(alignment: .leading) {
                HStack {
                    Text(timeFormatter.string(from: slot.startTime))
                    
                    Text("-")
                    
                    Text(timeFormatter.string(from: slot.endTime))
                }
                    .font(.headline)
                
                // Duration
                Text(formatDuration(from: slot.startTime, to: slot.endTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Rating
            HStack {
                Circle()
                    .fill(Color(hex: slot.availabilityRating.color))
                    .frame(width: 10, height: 10)
                
                Text(slot.availabilityRating.description)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: slot.availabilityRating.color))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: slot.availabilityRating.color).opacity(0.1))
            .cornerRadius(12)
            
            // Actions
            Button(action: {
                // Schedule meeting action
                viewModel.scheduleMeeting(at: slot)
            }) {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var noAvailabilityView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            
            Text("No mutual availability")
                .font(.headline)
            
            Text("You and your partner don't have any matching free time on this day based on your calendars and availability settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                // Navigate to calendar settings
                // In a real app, this would navigate to the calendar integration view
            }) {
                Text("Adjust Calendar Settings")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(from startDate: Date, to endDate: Date) -> String {
        let duration = endDate.timeIntervalSince(startDate)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) minutes"
        }
    }
}

// MARK: - Preview
struct CoupleAvailabilityView_Previews: PreviewProvider {
    static var previews: some View {
        CoupleAvailabilityView()
    }
}

// MARK: - Extensions
// Note: The Date.weekdayShortName extension and Color.init(hex:) extensions were removed
// to eliminate duplications. These are now imported from Utilities/DateExtensions.swift
// and should be referenced from there. 
