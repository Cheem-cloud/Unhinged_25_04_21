//
//  ActivityPreferencesView.swift
//  Unhinged
//
//  Created by Claude AI on 06/23/2024.
//

import SwiftUI

struct ActivityPreferencesView: View {
    @ObservedObject var viewModel: PersonasViewModel
    var persona: Persona
    @Environment(\.dismiss) private var dismiss
    
    @State private var activityPreferences: [ActivityPreference] = []
    @State private var newActivityName = ""
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        NavigationStack {
            List {
                // Existing activity preferences
                if activityPreferences.isEmpty {
                    emptyStateView
                } else {
                    preferencesSection
                }
                
                // Add new activity preference
                addNewActivitySection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Activity Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePreferences()
                    }
                    .disabled(isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .background(Color.black.opacity(0.1))
                }
            }
            .alert("Error", isPresented: .init(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
            .onAppear {
                // Load existing preferences
                activityPreferences = persona.activityPreferences
            }
        }
    }
    
    private var emptyStateView: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "star.slash")
                    .font(.system(size: 42))
                    .foregroundColor(.gray)
                
                Text("No Activity Preferences")
                    .font(.headline)
                
                Text("Activity preferences help your partner understand what you enjoy doing together")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("Add some activities below")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
    
    private var preferencesSection: some View {
        Section("Current Preferences") {
            ForEach(Array(activityPreferences.enumerated()), id: \.element.activityType) { index, preference in
                HStack {
                    VStack(alignment: .leading) {
                        Text(preference.activityType)
                            .font(.headline)
                        
                        if let notes = preference.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Preference level indicator
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { level in
                            Image(systemName: level <= preference.preferenceLevel ? "star.fill" : "star")
                                .foregroundColor(level <= preference.preferenceLevel ? .yellow : .gray)
                                .onTapGesture {
                                    var updatedPreference = preference
                                    updatedPreference.preferenceLevel = level
                                    activityPreferences[index] = updatedPreference
                                }
                        }
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        activityPreferences.remove(at: index)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    Button {
                        var updatedPreference = preference
                        updatedPreference.notes = preference.notes == nil ? "Add notes here" : nil
                        activityPreferences[index] = updatedPreference
                    } label: {
                        Label(preference.notes == nil ? "Add Notes" : "Remove Notes", systemImage: preference.notes == nil ? "square.and.pencil" : "xmark.square")
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        activityPreferences.remove(at: index)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    private var addNewActivitySection: some View {
        Section("Add New Activity") {
            VStack(spacing: 16) {
                // Predefined activity suggestions
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.activityTypes, id: \.self) { activity in
                            Button {
                                addActivityPreference(activity)
                            } label: {
                                Text(activity)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue.opacity(0.1))
                                    )
                                    .foregroundColor(.blue)
                            }
                            .disabled(activityPreferences.contains { $0.activityType == activity })
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Custom activity input
                HStack {
                    TextField("New Activity", text: $newActivityName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button {
                        addActivityPreference(newActivityName)
                        newActivityName = ""
                    } label: {
                        Text("Add")
                            .fontWeight(.semibold)
                    }
                    .disabled(newActivityName.isEmpty || activityPreferences.contains { $0.activityType == newActivityName })
                }
            }
        }
    }
    
    private func addActivityPreference(_ activityType: String) {
        guard !activityType.isEmpty, 
              !activityPreferences.contains(where: { $0.activityType == activityType }) else {
            return
        }
        
        let newPreference = ActivityPreference(
            activityType: activityType,
            preferenceLevel: 3 // Default middle value
        )
        
        withAnimation {
            activityPreferences.append(newPreference)
        }
    }
    
    private func savePreferences() {
        guard let personaId = persona.id else { return }
        
        isLoading = true
        
        Task {
            do {
                try await viewModel.updateActivityPreferences(for: personaId, preferences: activityPreferences)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    ActivityPreferencesView(
        viewModel: PersonasViewModel(),
        persona: Persona(
            id: "123",
            name: "Adventure Seeker",
            bio: "Love trying new things",
            activityPreferences: [
                ActivityPreference(activityType: "Hiking", preferenceLevel: 5),
                ActivityPreference(activityType: "Movies", preferenceLevel: 3),
                ActivityPreference(activityType: "Restaurants", preferenceLevel: 4, notes: "Especially Thai food")
            ]
        )
    )
} 