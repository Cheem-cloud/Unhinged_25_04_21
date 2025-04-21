import SwiftUI

struct HangoutsView: View {
    @StateObject private var viewModel = HangoutsViewModel()
    @State private var showDetails = false
    @State private var selectedHangout: Hangout?
    @State private var isShowingError = false

    var body: some View {
        ZStack {
            // Background using theme colors
            CustomTheme.Colors.background
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: CustomTheme.Colors.text))
                        .padding()
                } else if viewModel.hangouts.isEmpty {
                    EmptyHangoutsView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                            // Pending hangouts
                            if !viewModel.pendingHangouts.isEmpty {
                                Section {
                                    sectionContent(hangouts: viewModel.pendingHangouts)
                                } header: {
                                    sectionHeader(title: "Pending Requests", systemImage: "clock.fill")
                                }
                            }
                            
                            // Upcoming hangouts
                            if !viewModel.upcomingHangouts.isEmpty {
                                Section {
                                    sectionContent(hangouts: viewModel.upcomingHangouts)
                                } header: {
                                    sectionHeader(title: "Upcoming Dates", systemImage: "calendar.badge.clock")
                                }
                            }
                            
                            // Declined hangouts
                            if !viewModel.declinedHangouts.isEmpty {
                                Section {
                                    sectionContent(hangouts: viewModel.declinedHangouts)
                                } header: {
                                    sectionHeader(title: "Declined", systemImage: "xmark.circle.fill")
                                }
                            }
                            
                            // Past hangouts
                            if !viewModel.pastHangouts.isEmpty {
                                Section {
                                    sectionContent(hangouts: viewModel.pastHangouts)
                                } header: {
                                    sectionHeader(title: "Past Dates", systemImage: "clock.arrow.circlepath")
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .refreshable {
                        viewModel.loadHangouts()
                    }
                }
            }
        }
        .navigationTitle("Hangouts")
        .sheet(isPresented: $showDetails, onDismiss: {
            selectedHangout = nil
        }) {
            if let hangout = selectedHangout {
                HangoutDetailSheet(hangout: hangout, onClose: {
                    showDetails = false
                })
            }
        }
        .onAppear {
            viewModel.loadHangouts()
        }
        // Use the errorAlert modifier for centralized error handling
        .errorAlert(isPresented: $isShowingError) { error in
            // Handle error dismissal if needed
            viewModel.loadHangouts()
        }
        // Connect our viewModel's error state to the centralized system
        .onChange(of: viewModel.error) { error in
            if let error = error {
                viewModel.handleErrorWithCentralizedSystem(error)
                isShowingError = true
            }
        }
        .withInterFont() // Apply Inter font to all text
    }
    
    private func sectionHeader(title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(.white)
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.deepRed.opacity(0.8))
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
    }
    
    private func sectionContent(hangouts: [Hangout]) -> some View {
        VStack(spacing: 12) {
            ForEach(hangouts) { hangout in
                HangoutCard(hangout: hangout, onTap: {
                    selectedHangout = hangout
                    showDetails = true
                })
                .transition(.scale.combined(with: .opacity))
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
}

struct EmptyHangoutsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar")
                .font(.system(size: 70))
                .foregroundColor(.white)
                .padding(.bottom, 10)
            
            Text("No Hangouts Yet")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Your hangouts with other dog owners will appear here")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct HangoutsView_Previews: PreviewProvider {
    static var previews: some View {
        HangoutsView()
    }
}

// HangoutDetailSheet remains mostly the same with minor style updates
struct HangoutDetailSheet: View {
    let hangout: Hangout
    let onClose: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.deepRed
                    .edgesIgnoringSafeArea(.all)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text(hangout.title)
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text(hangout.description)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text(formatDate(hangout.startDate))
                                .foregroundColor(.white.opacity(0.9))
                        } icon: {
                            Image(systemName: "calendar")
                                .foregroundColor(.white)
                        }
                        
                        if let location = hangout.location, !location.isEmpty {
                            Label {
                                Text(location)
                                    .foregroundColor(.white.opacity(0.9))
                            } icon: {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    // Debug button
                    Button(action: {
                        printHangoutDetails(hangout: hangout)
                    }) {
                        HStack {
                            Image(systemName: "ladybug.fill")
                                .foregroundColor(.deepRed)
                            Text("Debug Info")
                                .foregroundColor(.deepRed)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(8)
                    }
                    .padding(.top, 16)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Hangout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        onClose()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func printHangoutDetails(hangout: Hangout) {
        print("🧐 HANGOUT DETAILS:")
        print("🆔 ID: \(hangout.id ?? "nil")")
        print("📝 Title: \(hangout.title)")
        print("📋 Description: \(hangout.description)")
        print("🗓️ Start: \(hangout.startDate)")
        print("🗓️ End: \(hangout.endDate)")
        print("📍 Location: \(hangout.location ?? "nil")")
        print("👤 Creator ID: \(hangout.creatorID)")
        print("👤 Creator Persona ID: \(hangout.creatorPersonaID)")
        print("👥 Invitee ID: \(hangout.inviteeID)")
        print("👥 Invitee Persona ID: \(hangout.inviteePersonaID)")
        print("📊 Status: \(hangout.status.rawValue)")
        print("⏰ Created At: \(hangout.createdAt)")
        print("⏰ Updated At: \(hangout.updatedAt)")
    }
} 