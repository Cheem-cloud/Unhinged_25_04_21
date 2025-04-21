import SwiftUI

/// Main profile feature component
public struct ProfileFeature: View {
    @ObservedObject var viewModel: ProfileViewModel
    let onEditProfile: () -> Void
    let onSettings: () -> Void
    let onLogout: () -> Void
    
    public init(
        viewModel: ProfileViewModel,
        onEditProfile: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onLogout: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onEditProfile = onEditProfile
        self.onSettings = onSettings
        self.onLogout = onLogout
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ProfileHeader(
                        user: viewModel.user,
                        onEditProfile: onEditProfile
                    )
                    
                    StatsSection(stats: viewModel.userStats)
                    
                    if !viewModel.upcomingHangouts.isEmpty {
                        UpcomingHangoutsSection(
                            hangouts: viewModel.upcomingHangouts,
                            onViewAll: viewModel.navigateToHangouts
                        )
                    }
                    
                    SettingsSection(
                        onSettingsTap: onSettings,
                        onLogoutTap: onLogout
                    )
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                viewModel.refreshProfile()
            }
        }
    }
}

/// Profile header with user info and edit button
struct ProfileHeader: View {
    let user: User
    let onEditProfile: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            ProfileImage(imageURL: user.profileImageURL)
            
            Text(user.name)
                .font(.title2)
                .fontWeight(.bold)
            
            if !user.bio.isEmpty {
                Text(user.bio)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: onEditProfile) {
                Text("Edit Profile")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.blue)
                    .cornerRadius(20)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

/// Profile image component with placeholder
struct ProfileImage: View {
    let imageURL: URL?
    
    var body: some View {
        if let imageURL = imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.gray)
        }
    }
}

/// Stats section showing user activity data
struct StatsSection: View {
    let stats: UserStats
    
    var body: some View {
        HStack(spacing: 0) {
            StatItem(value: stats.hangoutsCount, label: "Hangouts")
            Divider().frame(height: 40)
            StatItem(value: stats.friendsCount, label: "Friends")
            Divider().frame(height: 40)
            StatItem(value: stats.ratingsCount, label: "Ratings")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

/// Individual stat item
struct StatItem: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Upcoming hangouts preview section
struct UpcomingHangoutsSection: View {
    let hangouts: [Hangout]
    let onViewAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Hangouts")
                    .font(.headline)
                
                Spacer()
                
                Button(action: onViewAll) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            ForEach(hangouts.prefix(3)) { hangout in
                HangoutRow(hangout: hangout)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

/// Individual hangout row for the upcoming hangouts section
struct HangoutRow: View {
    let hangout: Hangout
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(hangout.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(hangout.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            StatusBadge(status: hangout.status)
        }
        .padding(.vertical, 8)
    }
}

/// Status badge for hangouts
struct StatusBadge: View {
    let status: HangoutStatus
    
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .confirmed:
            return .green
        case .pending:
            return .orange
        case .cancelled:
            return .red
        }
    }
}

/// Settings section
struct SettingsSection: View {
    let onSettingsTap: () -> Void
    let onLogoutTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(icon: "gear", title: "Settings", action: onSettingsTap)
            
            Divider()
                .padding(.leading, 56)
            
            SettingsRow(icon: "arrow.right.square", title: "Logout", action: onLogoutTap)
                .foregroundColor(.red)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

/// Individual settings row
struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .padding(.leading, 16)
                
                Text(title)
                    .font(.subheadline)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.trailing, 16)
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
} 