import Foundation
import SwiftUI

// Using centralized TimeSlot model from TimeModels.swift
class TimeSelectionViewModel: ObservableObject {
    @Published var availableTimeSlots: [TimeSlot] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    // Load available times from Calendar service
    func loadAvailableTimes(for partnerUserId: String, duration: Int) {
        isLoading = true
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.generateSampleTimeSlots(duration: duration)
            self.isLoading = false
        }
    }
    
    // Generate sample time slots for preview/testing
    private func generateSampleTimeSlots(duration: Int) {
        // Create calendar instance
        let calendar = Calendar.current
        
        // Clear existing time slots
        availableTimeSlots.removeAll()
        
        // Get start of tomorrow
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) else {
            return
        }
        
        var startComponent = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        startComponent.hour = 9 // Start at 9 AM
        
        // Generate time slots for next 5 days
        for day in 0..<5 {
            startComponent.day = calendar.component(.day, from: tomorrow) + day
            
            // Generate 3 slots per day
            for slot in 0..<3 {
                guard let startTime = calendar.date(from: startComponent) else {
                    continue
                }
                
                // Random hour offset between 0-6 for variety
                let hourOffset = slot * 2 + Int.random(in: 0...1)
                guard let adjustedStart = calendar.date(byAdding: .hour, value: hourOffset, to: startTime),
                      let endTime = calendar.date(byAdding: .minute, value: duration, to: adjustedStart) else {
                    continue
                }
                
                // Only add slots before 7 PM
                let endHour = calendar.component(.hour, from: endTime)
                if endHour <= 19 {
                    let timeSlot = TimeSlot(startTime: adjustedStart, endTime: endTime)
                    availableTimeSlots.append(timeSlot)
                }
            }
        }
    }
} 