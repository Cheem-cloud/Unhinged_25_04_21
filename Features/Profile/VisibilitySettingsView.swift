//
//  VisibilitySettingsView.swift
//  Unhinged
//
//  Created by Claude AI on 06/23/2024.
//

import SwiftUI

struct VisibilitySettingsView: View {
    @ObservedObject var viewModel: PersonasViewModel
    var persona: Persona
    @Environment(\.dismiss) private var dismiss
    
    @State private var visibilitySettings: VisibilitySettings
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showingInfoSheet = false
    
    init(viewModel: PersonasViewModel, persona: Persona) {
        self.viewModel = viewModel
        self.persona = persona
        _visibilitySettings = State(initialValue: persona.visibilitySettings)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.title)
                        
                        VStack(alignment: .leading) {
                            Text(persona.name)
                                .font(.headline)
                            
                            Text("Visibility Settings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Toggle("Visible to Partner", isOn: $visibilitySettings.visibleToPartner)
                        .tint(.blue)
                    
                    Toggle("Visible to Friends", isOn: $visibilitySettings.visibleToFriends)
                        .tint(.green)
                    
                    Toggle("Visible in Public Profile", isOn: $visibilitySettings.visibleInPublicProfile)
                        .tint(.orange)
                } footer: {
                    Text("Control who can see this persona and its associated details")
                }
                
                Section("Privacy Information") {
                    Button {
                        showingInfoSheet = true
                    } label: {
                        HStack {
                            Text("How visibility works")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Visibility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
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
            .sheet(isPresented: $showingInfoSheet) {
                visibilityInfoView
            }
        }
    }
    
    private var visibilityInfoView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("How Visibility Settings Work")
                            .font(.title)
                            .bold()
                        
                        Text("Visibility settings control who can see this persona and its associated information across the Unhinged app.")
                            .font(.body)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 16) {
                            infoRow(
                                title: "Visible to Partner",
                                description: "When enabled, your partner can see this persona in their Partner Personas view.",
                                icon: "person.2.fill",
                                color: .blue
                            )
                            
                            infoRow(
                                title: "Visible to Friends",
                                description: "When enabled, friends can see this persona when they interact with you.",
                                icon: "person.3.fill",
                                color: .green
                            )
                            
                            infoRow(
                                title: "Visible in Public Profile",
                                description: "When enabled, this persona may appear in public-facing areas of the app.",
                                icon: "globe",
                                color: .orange
                            )
                        }
                        
                        Divider()
                        
                        Text("Default Visibility")
                            .font(.headline)
                        
                        Text("By default, new personas are visible to your partner but not in your public profile. Adjust these settings based on how you want to present yourself.")
                            .font(.body)
                        
                        Divider()
                        
                        Text("Privacy Note")
                            .font(.headline)
                        
                        Text("Even when a persona is not visible, some basic information about you is still accessible to those you interact with through the app.")
                            .font(.body)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingInfoSheet = false
                    }
                }
            }
        }
    }
    
    private func infoRow(title: String, description: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func saveSettings() {
        guard let personaId = persona.id else { return }
        
        isLoading = true
        
        Task {
            do {
                try await viewModel.updateVisibilitySettings(for: personaId, visibilitySettings: visibilitySettings)
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
    VisibilitySettingsView(
        viewModel: PersonasViewModel(),
        persona: Persona(
            id: "123",
            name: "Social Butterfly",
            bio: "Outgoing and friendly",
            visibilitySettings: VisibilitySettings(
                visibleToPartner: true,
                visibleToFriends: true,
                visibleInPublicProfile: false
            )
        )
    )
} 