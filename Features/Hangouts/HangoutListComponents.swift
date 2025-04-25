import SwiftUI

/// Filter options for hangouts
enum HangoutFilter: String, CaseIterable {
    case all
    case pending
    case confirmed
    case cancelled
    case completed
    
    /// Display name for the filter
    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .pending:
            return "Pending"
        case .confirmed:
            return "Confirmed"
        case .cancelled:
            return "Cancelled"
        case .completed:
            return "Completed"
        }
    }
}

/// Component for displaying the list of hangouts
internal struct HangoutListFeature: View {
    @ObservedObject var viewModel: HangoutsViewModel
    let onSelectHangout: (Hangout) -> Void
    let onCreateHangout: () -> Void
    
    internal init(
        viewModel: HangoutsViewModel,
        onSelectHangout: @escaping (Hangout) -> Void,
        onCreateHangout: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onSelectHangout = onSelectHangout
        self.onCreateHangout = onCreateHangout
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HangoutListHeader(onCreateHangout: onCreateHangout)
            
            // Filter options
            FilterSection(selectedFilter: $viewModel.filter)
            
            // List of hangouts
            if viewModel.filteredHangouts.isEmpty {
                EmptyHangoutState()
            } else {
                hangoutsList
            }
        }
        .onAppear {
            viewModel.loadHangouts()
        }
    }
    
    private var hangoutsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.filteredHangouts) { hangout in
                    HangoutCard(hangout: hangout) {
                        onSelectHangout(hangout)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

/// Header for the hangout list with title and create button
struct HangoutListHeader: View {
    let onCreateHangout: () -> Void
    
    var body: some View {
        HStack {
            Text("Hangouts")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: onCreateHangout) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

/// Filter section for hangout statuses
struct FilterSection: View {
    @Binding var selectedFilter: HangoutFilter
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(HangoutFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

/// Individual filter chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

/// Empty state when no hangouts are available
struct EmptyHangoutState: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 70))
                .foregroundColor(.gray)
            
            Text("No Hangouts")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Create your first hangout to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Extension to provide display names for hangout filters
extension HangoutFilter {
    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .pending:
            return "Pending"
        case .confirmed:
            return "Confirmed"
        case .cancelled:
            return "Cancelled"
        case .completed:
            return "Completed"
        }
    }
} 