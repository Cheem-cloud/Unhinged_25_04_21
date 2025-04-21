import SwiftUI
import Foundation
import FirebaseAuth

struct CalendarIntegrationView: View {
    @EnvironmentObject var viewModel: CalendarIntegrationViewModel
    @State private var currentStep = CalendarStep.overview
    @State private var selectedProvider: CalendarProvider?
    @State private var isAnimating = false
    @State private var transitionDirection: TransitionDirection = .forward
    
    // Track previous steps for back navigation
    @State private var navigationStack: [CalendarStep] = []
    
    // Availability settings
    @State private var workHoursStart = Date.today(hour: 9)
    @State private var workHoursEnd = Date.today(hour: 17)
    @State private var selectedDays: Set<Unhinged.Weekday> = Set(Unhinged.Weekday.allCases)
    
    // Navigation properties
    @State private var isShowingCoupleAvailability = false
    
    private let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                CustomTheme.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with back button
                    headerView
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    // Main content
                    ZStack {
                        switch currentStep {
                        case .overview:
                            calendarOverviewView
                                .transition(transitionFor(direction: transitionDirection))
                        case .providerSelection:
                            providerSelectionView
                                .transition(transitionFor(direction: transitionDirection))
                        case .providerAuth(let provider):
                            calendarAuthView(for: provider)
                                .transition(transitionFor(direction: transitionDirection))
                        case .availability:
                            availabilitySettingsView
                                .transition(transitionFor(direction: transitionDirection))
                        case .privacySettings:
                            privacySettingsView
                                .transition(transitionFor(direction: transitionDirection))
                        case .syncSettings:
                            syncSettingsView
                                .transition(transitionFor(direction: transitionDirection))
                        }
                    }
                    .animation(.spring(), value: currentStep)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Add the navigation link
                NavigationLink(
                    destination: CoupleAvailabilityView(),
                    isActive: $isShowingCoupleAvailability,
                    label: { EmptyView() }
                )
                .hidden()
            }
            .navigationBarTitle("Calendar Integration", displayMode: .inline)
            .onAppear {
                viewModel.fetchConnectedCalendars()
                Task {
                    await viewModel.refreshAllCalendarEvents()
                }
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            // Only show back button if we have steps to go back to
            if !navigationStack.isEmpty {
                    Button {
                    navigateBack()
                    } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.custom("InterVariable", size: 16))
                    .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                }
            }
            
            Spacer()
            
            Text(titleForCurrentStep)
                .font(.custom("InterVariable", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(CustomTheme.Colors.text)
            
            Spacer()
            
            // Home button to go back to overview
            if currentStep != .overview {
                Button {
                    navigateTo(.overview)
                } label: {
                    Image(systemName: "house")
                        .font(.custom("InterVariable", size: 16))
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                }
            } else {
                // Invisible placeholder for layout balance
                Color.clear.frame(width: 20, height: 20)
            }
        }
    }
    
    // MARK: - Calendar Overview Screen
    
    private var calendarOverviewView: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Hero image and title
                VStack(spacing: 15) {
                    Image(systemName: "calendar")
                        .font(.system(size: 70))
                        .foregroundColor(CustomTheme.Colors.accent)
                        .padding(.top, 20)
                    
                    Text("Calendar Management")
                        .font(.custom("InterVariable", size: 26))
                        .fontWeight(.bold)
                        .foregroundColor(CustomTheme.Colors.text)
                    
                    Text("Connect and manage your calendars to simplify scheduling")
                        .font(.custom("InterVariable", size: 16))
                        .multilineTextAlignment(.center)
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                        .padding(.horizontal)
                }
                
                // Connected calendars section
                VStack(alignment: .leading, spacing: 10) {
                    Text("CONNECTED CALENDARS")
                        .font(.custom("InterVariable", size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                    
                    if viewModel.isLoading {
                            HStack {
                                    Spacer()
                                    ProgressView()
                                .padding()
                            Spacer()
                        }
                    } else if viewModel.connectedProviders.isEmpty {
                        emptyCalendarView
                    } else {
                        connectedCalendarsView
                    }
                }
                
                // Actions section
                VStack(alignment: .leading, spacing: 10) {
                    Text("ACTIONS")
                        .font(.custom("InterVariable", size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                    
                    actionButton(
                        icon: "plus.circle.fill", 
                        title: "Connect a Calendar",
                        subtitle: "Add Google, Apple, or Outlook calendar",
                        iconColor: .blue
                    ) {
                        navigateTo(.providerSelection)
                    }
                    
                    actionButton(
                        icon: "clock.fill", 
                        title: "Availability Settings",
                        subtitle: "Set your preferred available hours",
                        iconColor: .orange
                    ) {
                        navigateTo(.availability)
                    }
                    
                    actionButton(
                        icon: "eye.fill", 
                        title: "Privacy Settings",
                        subtitle: "Control what calendar details are shared",
                        iconColor: .purple
                    ) {
                        navigateTo(.privacySettings)
                    }
                    
                    actionButton(
                        icon: "arrow.triangle.2.circlepath", 
                        title: "Sync Settings",
                        subtitle: "Manage how your calendars sync",
                        iconColor: .green
                    ) {
                        navigateTo(.syncSettings)
                    }
                }
            }
            .padding(.bottom, 30)
        }
    }
    
    private var emptyCalendarView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(CustomTheme.Colors.text.opacity(0.5))
                .padding(.top, 20)
            
            Text("No Calendars Connected")
                .font(.custom("InterVariable", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(CustomTheme.Colors.text)
            
            Text("Connect your calendars to see your schedule and help find the best time for hangouts")
                .font(.custom("InterVariable", size: 15))
                .multilineTextAlignment(.center)
                .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                .padding(.horizontal)
            
                    Button {
                navigateTo(.providerSelection)
                    } label: {
                Text("Connect Calendar")
                    .font(.custom("InterVariable", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 24)
                    .background(CustomTheme.Colors.accent)
                    .cornerRadius(30)
            }
            .padding(.top, 10)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var connectedCalendarsView: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.connectedProviders, id: \.self) { provider in
                HStack(spacing: 15) {
                    Image(systemName: provider.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(providerColor(for: provider))
                        .frame(width: 40, height: 40)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    providerColor(for: provider).opacity(0.2),
                                    providerColor(for: provider).opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.displayName)
                            .font(.custom("InterVariable", size: 17))
                            .foregroundColor(CustomTheme.Colors.text)
                        
                        Text("Connected")
                            .font(.custom("InterVariable", size: 14))
                            .foregroundColor(Color(red: 0.3, green: 0.7, blue: 0.3))
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button(action: {
                            viewModel.refreshCalendar(provider: provider)
                        }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        
                        Button(action: {
                            viewModel.disconnectCalendar(provider: provider)
                        }) {
                            Label("Disconnect", systemImage: "minus.circle")
                                .foregroundColor(.red)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20))
                            .foregroundColor(CustomTheme.Colors.text.opacity(0.6))
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 15)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(providerColor(for: provider).opacity(0.15), lineWidth: 1)
                )
            }
            
            // Recent calendar events summary
            if !viewModel.calendarEvents.isEmpty {
                HStack {
                    Text("UPCOMING EVENTS")
                        .font(.custom("InterVariable", size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                    
                    Spacer()
                    
                    Button {
                        Task {
                            await viewModel.refreshAllCalendarEvents()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Refresh")
                            Image(systemName: "arrow.clockwise")
                        }
                        .font(.custom("InterVariable", size: 14))
                        .foregroundColor(CustomTheme.Colors.accent)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 5)
                
                ForEach(viewModel.calendarEvents.prefix(3), id: \.id) { event in
                    calendarEventRow(event: event)
                }
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Provider Selection Screen
    
    private var providerSelectionView: some View {
        VStack(spacing: 30) {
            // Hero icon and title
            VStack(spacing: 15) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 70))
                    .foregroundColor(CustomTheme.Colors.accent)
                    .padding(.top, 20)
                
                Text("Choose a Calendar")
                    .font(.custom("InterVariable", size: 26))
                    .fontWeight(.bold)
                    .foregroundColor(CustomTheme.Colors.text)
                
                Text("Select which calendar you'd like to connect")
                    .font(.custom("InterVariable", size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                    .padding(.horizontal)
            }
            
            // Calendar provider options
            VStack(spacing: 16) {
                ForEach(CalendarProvider.allCases, id: \.self) { provider in
                    if !viewModel.connectedProviders.contains(provider) {
                    Button {
                            selectedProvider = provider
                            navigateTo(.providerAuth(provider))
                    } label: {
                            HStack(spacing: 15) {
                            Image(systemName: provider.iconName)
                                    .font(.system(size: 24))
                                    .foregroundColor(providerColor(for: provider))
                                    .frame(width: 50, height: 50)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                providerColor(for: provider).opacity(0.2),
                                                providerColor(for: provider).opacity(0.05)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 4) {
                                Text(provider.displayName)
                                        .font(.custom("InterVariable", size: 18))
                                        .fontWeight(.medium)
                                        .foregroundColor(CustomTheme.Colors.text)
                                    
                                Text("Connect your \(provider.displayName) calendar")
                                        .font(.custom("InterVariable", size: 14))
                                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(CustomTheme.Colors.text.opacity(0.5))
                            }
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(providerColor(for: provider).opacity(0.15), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .padding(.top, 20)
    }
    
    // MARK: - Calendar Authorization Screen
    
    private func calendarAuthView(for provider: CalendarProvider) -> some View {
        CalendarAuthStepView(provider: provider, onComplete: {
            viewModel.fetchConnectedCalendars()
            navigateTo(.overview)
        })
    }
    
    // Separate view for calendar authorization
    struct CalendarAuthStepView: View {
        let provider: CalendarProvider
        let onComplete: () -> Void
        
        @StateObject private var authViewModel = CalendarAuthViewModel()
        
        var body: some View {
            VStack(spacing: 30) {
                // Hero icon and title
                VStack(spacing: 15) {
                    Image(systemName: provider.iconName)
                        .font(.system(size: 70))
                        .foregroundColor(providerColor)
                        .padding(.top, 20)
                    
                    Text("Connect \(provider.displayName)")
                        .font(.custom("InterVariable", size: 26))
                        .fontWeight(.bold)
                        .foregroundColor(CustomTheme.Colors.text)
                    
                    Text("You'll be redirected to authorize Unhinged to access your calendar")
                        .font(.custom("InterVariable", size: 16))
                        .multilineTextAlignment(.center)
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                        .padding(.horizontal)
                }
                
                if authViewModel.isConnecting {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Connecting to \(provider.displayName)...")
                            .font(.custom("InterVariable", size: 16))
                            .foregroundColor(CustomTheme.Colors.text)
                    }
                    .padding()
                    .frame(height: 100)
                } else if let error = authViewModel.error {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text("Connection Error")
                            .font(.custom("InterVariable", size: 18))
                            .fontWeight(.semibold)
                            .foregroundColor(CustomTheme.Colors.text)
                        
                        Text(error.localizedDescription)
                            .font(.custom("InterVariable", size: 15))
                            .multilineTextAlignment(.center)
                            .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                            .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                } else {
                    VStack(spacing: 20) {
                        // Connect button
                        Button {
                            connectToCalendar(provider: provider)
                        } label: {
                            Text("Connect \(provider.displayName)")
                                .font(.custom("InterVariable", size: 16))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(providerColor)
                                .cornerRadius(30)
                                .shadow(color: providerColor.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        
                        Text("You'll need to grant permission to read your calendar events")
                            .font(.custom("InterVariable", size: 14))
                            .multilineTextAlignment(.center)
                            .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding(.top, 20)
        }
        
        func connectToCalendar(provider: CalendarProvider) {
            Task {
                switch provider {
                case .google:
                    await authViewModel.connectGoogleCalendar()
                case .apple:
                    await authViewModel.connectAppleCalendar()
                case .outlook:
                    await authViewModel.connectOutlookCalendar()
                }
                
                // After connection, wait a moment and refresh providers
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                onComplete()
            }
        }
        
        private var providerColor: Color {
            switch provider {
            case .google: return .red
            case .outlook: return .blue
            case .apple: return .green
            }
        }
    }
    
    // MARK: - Availability Settings Screen
    
    private var availabilitySettingsView: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Hero icon and title
                VStack(spacing: 15) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 70))
                        .foregroundColor(CustomTheme.Colors.accent)
                        .padding(.top, 20)
                    
                    Text("Availability Settings")
                        .font(.custom("InterVariable", size: 26))
                        .fontWeight(.bold)
                        .foregroundColor(CustomTheme.Colors.text)
                    
                    Text("Set your typical working hours and availability")
                        .font(.custom("InterVariable", size: 16))
                        .multilineTextAlignment(.center)
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                        .padding(.horizontal)
                }
                
                // Working Hours
                VStack(alignment: .leading, spacing: 16) {
                    Text("YOUR WORKING HOURS")
                        .font(.custom("InterVariable", size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                    
                    HStack(spacing: 15) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Start time")
                                .font(.custom("InterVariable", size: 15))
                                .foregroundColor(CustomTheme.Colors.text)
                            
                            DatePicker("", selection: $viewModel.workHoursStart, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        
                        Text("to")
                            .font(.custom("InterVariable", size: 15))
                            .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                            .padding(.top, 10)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("End time")
                                .font(.custom("InterVariable", size: 15))
                                .foregroundColor(CustomTheme.Colors.text)
                            
                            DatePicker("", selection: $viewModel.workHoursEnd, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                
                // Available Days
                VStack(alignment: .leading, spacing: 16) {
                    Text("AVAILABLE DAYS")
                        .font(.custom("InterVariable", size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                    
                    // Day selection buttons
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 15) {
                        ForEach(Unhinged.Weekday.allCases, id: \.self) { day in
                            Button {
                                toggleDaySelection(day)
                            } label: {
                                Text(day.shortName)
                                    .font(.custom("InterVariable", size: 16))
                                    .fontWeight(.medium)
                                    .frame(height: 45)
                                    .frame(maxWidth: .infinity)
                                    .background(viewModel.selectedDays.contains(day) ? CustomTheme.Colors.accent : Color.white.opacity(0.05))
                                    .foregroundColor(viewModel.selectedDays.contains(day) ? .white : CustomTheme.Colors.text.opacity(0.7))
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                
                // Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("SUMMARY")
                        .font(.custom("InterVariable", size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                    
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(CustomTheme.Colors.accent)
                        
                        Text("You are available from \(hourFormatter.string(from: viewModel.workHoursStart)) to \(hourFormatter.string(from: viewModel.workHoursEnd))")
                            .font(.custom("InterVariable", size: 15))
                            .foregroundColor(CustomTheme.Colors.text)
                    }
                    
                    HStack(alignment: .top) {
                        Image(systemName: "calendar")
                            .foregroundColor(CustomTheme.Colors.accent)
                        
                        Text("You are available on \(availableDaysText)")
                            .font(.custom("InterVariable", size: 15))
                            .foregroundColor(CustomTheme.Colors.text)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                // Save Button
                Button {
                    viewModel.updateAvailabilitySettings(
                        workHoursStart: viewModel.workHoursStart,
                        workHoursEnd: viewModel.workHoursEnd,
                        selectedDays: viewModel.selectedDays
                    )
                    navigateTo(.overview)
                } label: {
                    Text("Save Settings")
                        .font(.custom("InterVariable", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(CustomTheme.Colors.accent)
                        .cornerRadius(30)
                }
                .padding(.vertical, 20)
            }
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Privacy Settings Screen
    
    private var privacySettingsView: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Hero icon and title
                VStack(spacing: 15) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 70))
                        .foregroundColor(CustomTheme.Colors.accent)
                        .padding(.top, 20)
                    
                    Text("Privacy Settings")
                        .font(.custom("InterVariable", size: 26))
                        .fontWeight(.bold)
                        .foregroundColor(CustomTheme.Colors.text)
                    
                    Text("Control what calendar information is shared")
                        .font(.custom("InterVariable", size: 16))
                        .multilineTextAlignment(.center)
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                        .padding(.horizontal)
                }
                
                // Privacy toggles
                VStack(alignment: .leading, spacing: 20) {
                    Text("EVENT VISIBILITY")
                        .font(.custom("InterVariable", size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                    
                    Toggle(isOn: $viewModel.showBusyEvents) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Show busy/free status")
                                .font(.custom("InterVariable", size: 16))
                                .foregroundColor(CustomTheme.Colors.text)
                            
                            Text("Let your partner know when you're busy without sharing details")
                                .font(.custom("InterVariable", size: 14))
                                .foregroundColor(CustomTheme.Colors.text.opacity(0.6))
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    
                    Toggle(isOn: $viewModel.showEventDetails) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Share event titles")
                                .font(.custom("InterVariable", size: 16))
                                .foregroundColor(CustomTheme.Colors.text)
                            
                            Text("Show your partner what events you have scheduled")
                                .font(.custom("InterVariable", size: 14))
                                .foregroundColor(CustomTheme.Colors.text.opacity(0.6))
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                
                // Save Button
                Button {
                    viewModel.updatePrivacySettings(
                        showBusyEvents: viewModel.showBusyEvents,
                        showEventDetails: viewModel.showEventDetails
                    )
                    navigateTo(.overview)
                } label: {
                    Text("Save Privacy Settings")
                        .font(.custom("InterVariable", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(CustomTheme.Colors.accent)
                        .cornerRadius(30)
                }
                .padding(.vertical, 20)
            }
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Sync Settings Screen
    
    private var syncSettingsView: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Hero icon and title
                VStack(spacing: 15) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 70))
                        .foregroundColor(CustomTheme.Colors.accent)
                        .padding(.top, 20)
                    
                    Text("Sync Settings")
                        .font(.custom("InterVariable", size: 26))
                        .fontWeight(.bold)
                        .foregroundColor(CustomTheme.Colors.text)
                    
                    Text("Control how and when your calendars sync")
                        .font(.custom("InterVariable", size: 16))
                        .multilineTextAlignment(.center)
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                        .padding(.horizontal)
                }
                
                // Sync frequency options
                VStack(alignment: .leading, spacing: 16) {
                    Text("SYNC FREQUENCY")
                        .font(.custom("InterVariable", size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                    
                    ForEach(SyncFrequency.allCases) { frequency in
                        Button {
                            viewModel.syncFrequency = frequency
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(frequency.rawValue)
                                        .font(.custom("InterVariable", size: 16))
                                        .foregroundColor(CustomTheme.Colors.text)
                                    
                                    Text(frequency.description)
                                        .font(.custom("InterVariable", size: 14))
                                        .foregroundColor(CustomTheme.Colors.text.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                if viewModel.syncFrequency == frequency {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(CustomTheme.Colors.accent)
                                }
                            }
                            .padding()
                            .background(viewModel.syncFrequency == frequency ? Color.white.opacity(0.08) : Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                }
                
                // Manual sync button
                Button {
                    handleSync()
                } label: {
                    HStack {
                        if viewModel.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 20, height: 20)
                        } else if viewModel.syncSuccessful {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        
                        Text(viewModel.isSyncing ? "Syncing..." : (viewModel.syncSuccessful ? "Sync Complete" : "Sync Now"))
                    }
                    .font(.custom("InterVariable", size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.isSyncing ? CustomTheme.Colors.accent.opacity(0.7) : CustomTheme.Colors.accent)
                    .cornerRadius(12)
                }
                .padding(.top, 10)
                .disabled(viewModel.isSyncing)
                
                // Save Button
                Button {
                    viewModel.updateSyncSettings(frequency: viewModel.syncFrequency)
                    navigateTo(.overview)
                } label: {
                    Text("Save Sync Settings")
                        .font(.custom("InterVariable", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(CustomTheme.Colors.accent)
                        .cornerRadius(30)
                }
                .padding(.vertical, 20)
                
                Spacer()
                
                Button(action: {
                    // Save final settings
                    viewModel.savePreferences()
                    
                    // Navigate to couple availability view
                    isShowingCoupleAvailability = true
                }) {
                    HStack {
                        Text("View Couple Availability")
                        
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.top, 24)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Components
    
    private func settingToggle(title: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 15) {
            Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(isOn.wrappedValue ? .green : CustomTheme.Colors.text.opacity(0.5))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("InterVariable", size: 16))
                    .foregroundColor(CustomTheme.Colors.text)
                
                Text(description)
                    .font(.custom("InterVariable", size: 14))
                    .foregroundColor(CustomTheme.Colors.text.opacity(0.6))
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.vertical, 15)
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture {
            isOn.wrappedValue.toggle()
        }
    }
    
    private func calendarEventRow(event: CalendarEvent) -> some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(spacing: 2) {
                Text(formatEventTime(date: event.startTime))
                    .font(.custom("InterVariable", size: 14))
                    .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
                
                Text(formatEventDate(date: event.startTime))
                    .font(.custom("InterVariable", size: 12))
                    .foregroundColor(CustomTheme.Colors.text.opacity(0.6))
            }
            .frame(width: 70)
            
            // Colored indicator line
            Rectangle()
                .fill(Color(hexString: event.colorHex) ?? .gray)
                .frame(width: 4)
                .cornerRadius(2)
            
            // Event details
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.custom("InterVariable", size: 15))
                    .fontWeight(.medium)
                    .foregroundColor(CustomTheme.Colors.text)
                
                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                        Text(location)
                            .font(.custom("InterVariable", size: 13))
                    }
                    .foregroundColor(CustomTheme.Colors.text.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Duration
            let endTime = event.endTime
            let duration = Calendar.current.dateComponents([.hour, .minute], from: event.startTime, to: endTime)
            if let hours = duration.hour, let minutes = duration.minute {
                Text(hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m")
                    .font(.custom("InterVariable", size: 12))
                    .foregroundColor(CustomTheme.Colors.text.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.06)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func actionButton(icon: String, title: String, subtitle: String, iconColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.custom("InterVariable", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(CustomTheme.Colors.text)
                    
                    Text(subtitle)
                        .font(.custom("InterVariable", size: 14))
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(CustomTheme.Colors.text.opacity(0.5))
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.03)]), 
                    startPoint: .topLeading, 
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateTo(_ step: CalendarStep) {
        // Add current step to navigation stack if not already the last item
        if !navigationStack.isEmpty && navigationStack.last != currentStep {
            navigationStack.append(currentStep)
        } else if navigationStack.isEmpty {
            navigationStack.append(currentStep)
        }
        
        // Set animation direction based on "depth" of navigation
        transitionDirection = stepDepth(step) > stepDepth(currentStep) ? .forward : .backward
        
        // Animate to the new step
        withAnimation(.spring()) {
            currentStep = step
        }
    }
    
    private func navigateBack() {
        if !navigationStack.isEmpty {
            // Pop the last step from the navigation stack
            let previousStep = navigationStack.removeLast()
            
            // Always set direction to backward when going back
            transitionDirection = .backward
            
            // Animate to the previous step
            withAnimation(.spring()) {
                currentStep = previousStep
            }
        }
    }
    
    private func stepDepth(_ step: CalendarStep) -> Int {
        switch step {
        case .overview:
            return 0
        case .providerSelection, .availability, .privacySettings, .syncSettings:
            return 1
        case .providerAuth:
            return 2
        }
    }
    
    private func toggleDaySelection(_ day: Unhinged.Weekday) {
        if selectedDays.contains(day) {
            // Don't allow deselecting all days
            if selectedDays.count > 1 {
                selectedDays.remove(day)
                    }
                } else {
            selectedDays.insert(day)
        }
    }
    
    private func formatEventTime(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func formatEventDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private var titleForCurrentStep: String {
        switch currentStep {
        case .overview:
            return "Calendar Management"
        case .providerSelection:
            return "Select Calendar"
        case .providerAuth(let provider):
            return "Connect \(provider.displayName)"
        case .availability:
            return "Availability Settings"
        case .privacySettings:
            return "Privacy Settings"
        case .syncSettings:
            return "Sync Settings"
        }
    }
    
    private func providerColor(for provider: CalendarProvider) -> Color {
        switch provider {
        case .google:
            return .red
        case .outlook:
            return .blue
        case .apple:
            return .green
        }
    }
    
    private func transitionFor(direction: TransitionDirection) -> AnyTransition {
        switch direction {
        case .forward:
            return .asymmetric(
                insertion: .modifier(
                    active: SlideTransitionModifier(offset: CGSize(width: UIScreen.main.bounds.width * 0.3, height: 0), opacity: 0),
                    identity: SlideTransitionModifier(offset: .zero, opacity: 1)
                ),
                removal: .modifier(
                    active: SlideTransitionModifier(offset: CGSize(width: -UIScreen.main.bounds.width * 0.3, height: 0), opacity: 0),
                    identity: SlideTransitionModifier(offset: .zero, opacity: 1)
                )
            )
        case .backward:
            return .asymmetric(
                insertion: .modifier(
                    active: SlideTransitionModifier(offset: CGSize(width: -UIScreen.main.bounds.width * 0.3, height: 0), opacity: 0),
                    identity: SlideTransitionModifier(offset: .zero, opacity: 1)
                ),
                removal: .modifier(
                    active: SlideTransitionModifier(offset: CGSize(width: UIScreen.main.bounds.width * 0.3, height: 0), opacity: 0),
                    identity: SlideTransitionModifier(offset: .zero, opacity: 1)
                )
            )
        }
    }
    
    // Custom transition modifier
    struct SlideTransitionModifier: ViewModifier {
        let offset: CGSize
        let opacity: Double
        
        func body(content: Content) -> some View {
            content
                .offset(offset)
                .opacity(opacity)
        }
    }
    
    // Format the days into readable text
    private var availableDaysText: String {
        let sortedDays = selectedDays.sorted { $0.calendarValue < $1.calendarValue }
        
        if sortedDays.count == Unhinged.Weekday.allCases.count {
            return "all days"
        } else if sortedDays.count >= 5 {
            return "most days"
        } else {
            return sortedDays.map { $0.shortName }.joined(separator: ", ")
        }
    }
    
    // Helper method to perform sync with feedback
    private func performSync() async {
        // Reset success flag if previously set
        if viewModel.syncSuccessful {
            viewModel.syncSuccessful = false
        }
        
        // Refresh calendar events - this should be a real sync in production
        await viewModel.refreshAllCalendarEvents()
        
        // After refresh is complete, show success for a moment
        viewModel.syncSuccessful = true
        
        // Auto-reset success flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            viewModel.syncSuccessful = false
        }
    }
    
    // Button handler that calls the async method
    private func handleSync() {
        Task {
            await performSync()
        }
    }
}

// MARK: - Supporting Types

// For our mock data
extension Date {
    static func today(hour: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        return calendar.date(from: components) ?? Date()
    }
}

// MARK: - Preview Provider

struct CalendarIntegrationView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarIntegrationView()
            .environmentObject(CalendarIntegrationViewModel())
    }
} 
