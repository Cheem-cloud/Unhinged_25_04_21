import SwiftUI

/// A view that allows users to select a date range with a start and end date
public struct DateRangePickerView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    var minDate: Date
    var maxDate: Date
    
    @State private var selectedTab = 0
    
    /// Initialize a date range picker
    /// - Parameters:
    ///   - startDate: Binding to the start date
    ///   - endDate: Binding to the end date
    ///   - minDate: Optional minimum allowed date (defaults to current date)
    ///   - maxDate: Optional maximum allowed date (defaults to 3 months from now)
    public init(
        startDate: Binding<Date>,
        endDate: Binding<Date>,
        minDate: Date = Date(),
        maxDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    ) {
        self._startDate = startDate
        self._endDate = endDate
        self.minDate = minDate
        self.maxDate = maxDate
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Tab selection for start/end date
            Picker("", selection: $selectedTab) {
                Text("Start Date").tag(0)
                Text("End Date").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Date summary card
            dateRangeSummaryCard
            
            // Calendar view for selection
            if selectedTab == 0 {
                // Start date picker
                DatePicker(
                    "Start Date",
                    selection: $startDate,
                    in: minDate...maxDate,
                    displayedComponents: .date
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .labelsHidden()
                .onChange(of: startDate) { newStartDate in
                    // Ensure end date is not before start date
                    if endDate < newStartDate {
                        endDate = newStartDate
                    }
                }
            } else {
                // End date picker
                DatePicker(
                    "End Date",
                    selection: $endDate,
                    in: startDate...maxDate,
                    displayedComponents: .date
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .labelsHidden()
            }
            
            // Quick selection buttons
            dateRangePresets
        }
        .padding()
    }
    
    // MARK: - Date Range Summary Card
    
    private var dateRangeSummaryCard: some View {
        HStack(spacing: 0) {
            // Start date card
            VStack(alignment: .center, spacing: 4) {
                Text("FROM")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatDate(startDate))
                    .font(.headline)
                    .foregroundColor(selectedTab == 0 ? .blue : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedTab == 0 ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
            .onTapGesture {
                selectedTab = 0
            }
            
            Spacer()
                .frame(width: 20)
            
            // End date card
            VStack(alignment: .center, spacing: 4) {
                Text("TO")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatDate(endDate))
                    .font(.headline)
                    .foregroundColor(selectedTab == 1 ? .blue : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedTab == 1 ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
            .onTapGesture {
                selectedTab = 1
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Date Range Presets
    
    private var dateRangePresets: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Select")
                .font(.headline)
                .padding(.leading)
            
            HStack {
                // Next 3 days
                quickSelectButton(title: "Next 3 Days") {
                    setDateRange(days: 3)
                }
                
                // Next Week
                quickSelectButton(title: "Next Week") {
                    setDateRange(days: 7)
                }
                
                // Next Month
                quickSelectButton(title: "Next Month") {
                    setDateRange(days: 30)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func quickSelectButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Methods
    
    private func setDateRange(days: Int) {
        startDate = Date()
        endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) ?? startDate
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct DateRangePickerView_Previews: PreviewProvider {
    static var previews: some View {
        DateRangePickerView(
            startDate: .constant(Date()),
            endDate: .constant(Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date())
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
} 