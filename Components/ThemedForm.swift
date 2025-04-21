import SwiftUI

/// A form component that uses the current theme
public struct ThemedForm<Content: View>: View {
    private let content: Content
    private let title: String?
    private let submitText: String
    private let cancelText: String?
    private let onSubmit: () -> Void
    private let onCancel: (() -> Void)?
    private let isLoading: Bool
    
    /// Creates a themed form with consistent styling
    /// - Parameters:
    ///   - title: Form title (optional)
    ///   - submitText: Text for the submit button
    ///   - cancelText: Text for the optional cancel button
    ///   - isLoading: Whether the form is in a loading state
    ///   - onSubmit: Action to perform when the form is submitted
    ///   - onCancel: Action to perform when the form is cancelled (optional)
    ///   - content: The content of the form
    public init(
        title: String? = nil,
        submitText: String = "Submit",
        cancelText: String? = nil,
        isLoading: Bool = false,
        onSubmit: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.submitText = submitText
        self.cancelText = cancelText
        self.isLoading = isLoading
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.large) {
            // Title if provided
            if let title = title {
                ThemedText(title, style: .title)
            }
            
            // Form content
            VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.medium) {
                content
            }
            
            // Buttons
            VStack(spacing: ThemeManager.shared.spacing.small) {
                ThemedButton(submitText, isPrimary: true) {
                    onSubmit()
                }
                .disabled(isLoading)
                .opacity(isLoading ? 0.7 : 1.0)
                
                if let cancelText = cancelText, let onCancel = onCancel {
                    ThemedButton(cancelText, isPrimary: false) {
                        onCancel()
                    }
                    .disabled(isLoading)
                }
            }
            
            // Loading indicator
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.themedPrimary))
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.themedBackground.opacity(0.5))
        .cornerRadius(12)
    }
}

/// A form section component with consistent styling
public struct ThemedFormSection<Content: View>: View {
    private let content: Content
    private let title: String?
    
    public init(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.small) {
            if let title = title {
                ThemedText(title, style: .subtitle)
                    .padding(.bottom, 4)
            }
            
            content
        }
        .padding(.bottom, ThemeManager.shared.spacing.medium)
    }
}

/// A form field wrapper for consistent styling
public struct ThemedFormField<Content: View>: View {
    private let content: Content
    private let label: String
    private let errorMessage: String?
    
    public init(
        label: String,
        errorMessage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.errorMessage = errorMessage
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ThemedText(label, style: .caption)
                .foregroundColor(Color.themedSecondary)
            
            content
            
            if let errorMessage = errorMessage, !errorMessage.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.themedError)
                    
                    Text(errorMessage)
                        .font(Font.themedCaption)
                        .foregroundColor(Color.themedError)
                }
                .padding(.top, 2)
            }
        }
        .padding(.bottom, 8)
    }
}

/// A date picker with themed styling
public struct ThemedDatePicker: View {
    private let label: String
    @Binding private var date: Date
    private let range: ClosedRange<Date>?
    private let displayedComponents: DatePickerComponents
    
    public init(
        _ label: String,
        date: Binding<Date>,
        in range: ClosedRange<Date>? = nil,
        displayedComponents: DatePickerComponents = [.date]
    ) {
        self.label = label
        self._date = date
        self.range = range
        self.displayedComponents = displayedComponents
    }
    
    public var body: some View {
        ThemedFormField(label: label) {
            if let range = range {
                DatePicker("", selection: $date, in: range, displayedComponents: displayedComponents)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .accentColor(Color.themedAccent)
            } else {
                DatePicker("", selection: $date, displayedComponents: displayedComponents)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .accentColor(Color.themedAccent)
            }
        }
    }
}

/// Preview for themed form components
struct ThemedForm_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Basic form
                ThemedForm(
                    title: "Basic Form",
                    submitText: "Save",
                    cancelText: "Cancel",
                    onSubmit: {},
                    onCancel: {}
                ) {
                    ThemedFormField(label: "Name") {
                        ThemedTextField("Enter your name", text: .constant("John Doe"))
                    }
                    
                    ThemedFormField(label: "Email", errorMessage: "Please enter a valid email") {
                        ThemedTextField("Enter your email", text: .constant("invalid-email"))
                    }
                    
                    ThemedDatePicker("Date of Birth", date: .constant(Date()))
                }
                
                // Form with sections
                ThemedForm(
                    title: "Sectioned Form",
                    submitText: "Submit",
                    onSubmit: {}
                ) {
                    ThemedFormSection(title: "Personal Information") {
                        ThemedFormField(label: "First Name") {
                            ThemedTextField("Enter first name", text: .constant(""))
                        }
                        
                        ThemedFormField(label: "Last Name") {
                            ThemedTextField("Enter last name", text: .constant(""))
                        }
                    }
                    
                    ThemedFormSection(title: "Contact Information") {
                        ThemedFormField(label: "Phone") {
                            ThemedTextField("Enter phone number", text: .constant(""))
                        }
                        
                        ThemedFormField(label: "Email") {
                            ThemedTextField("Enter email address", text: .constant(""))
                        }
                    }
                }
                
                // Loading form
                ThemedForm(
                    title: "Loading State",
                    submitText: "Submit",
                    isLoading: true,
                    onSubmit: {}
                ) {
                    ThemedFormField(label: "Username") {
                        ThemedTextField("Enter username", text: .constant("user123"))
                    }
                    
                    ThemedFormField(label: "Password") {
                        SecureField("Enter password", text: .constant("password"))
                            .padding()
                            .background(Color.themedBackground.opacity(0.2))
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .background(Color.themedBackground.opacity(0.2))
        .edgesIgnoringSafeArea(.all)
        .withCurrentTheme()
    }
} 