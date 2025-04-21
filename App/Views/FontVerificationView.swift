import SwiftUI

/// View for comparing different text rendering approaches
struct FontVerificationView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Font Comparison")
                    .font(.largeTitle)
                    .padding(.bottom, 10)
                
                Group {
                    sectionHeader("1. System Text with Regular Font")
                    Text("This is standard SwiftUI Text with .font(.body)")
                        .font(.body)
                    
                    Text("This has .font(.headline)")
                        .font(.headline)
                        
                    Text("This has .font(.title3)")
                        .font(.title3)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.yellow.opacity(0.1))
                
                Group {
                    sectionHeader("2. Direct Font.custom() Usage")
                    Text("This uses .font(.custom(InterVariable, size: 17))")
                        .font(.custom("InterVariable", size: 17))
                        
                    Text("This adds .weight(.semibold)")
                        .font(.custom("InterVariable", size: 17))
                        .fontWeight(.semibold)
                        
                    Text("This uses .font(.custom(InterVariable, size: 20))")
                        .font(.custom("InterVariable", size: 20))
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.blue.opacity(0.1))
                
                Group {
                    sectionHeader("3. AppTheme Typography Usage")
                    Text("This uses .font(AppTheme.Typography.body)")
                        .font(AppTheme.Typography.body)
                        
                    Text("This uses .font(AppTheme.Typography.headline)")
                        .font(AppTheme.Typography.headline)
                        
                    Text("This uses .font(AppTheme.Typography.title3)")
                        .font(AppTheme.Typography.title3)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.green.opacity(0.1))
                
                Group {
                    sectionHeader("4. CustomText Component")
                    CustomText("Regular weight, size 17 (default)")
                    
                    CustomText("Medium weight, size 17", weight: .medium)
                    
                    CustomText("Bold weight, size 20", size: 20, weight: .bold, color: .blue)
                    
                    CustomText("Light weight, size 16", size: 16, weight: .light)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.purple.opacity(0.1))
                
                Group {
                    sectionHeader("5. Font.interSystem() Usage")
                    Text("This uses .font(.interSystem(size: 17))")
                        .font(.interSystem(size: 17))
                        
                    Text("This uses .font(.interSystem(size: 17, weight: .semibold))")
                        .font(.interSystem(size: 17, weight: .semibold))
                        
                    Text("This uses .font(.interSystem(size: 20, weight: .bold))")
                        .font(.interSystem(size: 20, weight: .bold))
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.orange.opacity(0.1))
                
                Group {
                    sectionHeader("6. New Text Extensions")
                    Text("This uses .interBody()")
                        .interBody()
                    
                    Text("This uses .interHeadline()")
                        .interHeadline()
                    
                    Text("This uses .interFont(size: 19, weight: .semibold)")
                        .interFont(size: 19, weight: .semibold)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.red.opacity(0.1))
                
                Group {
                    sectionHeader("7. InterText Factory")
                    InterText.body("Created with InterText.body()")
                    
                    InterText.heading("Created with InterText.heading()")
                    
                    InterText.custom("Created with InterText.custom(size:19, weight:.bold)", size: 19, weight: .bold)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.teal.opacity(0.1))
                
                Text("Recommendation:")
                    .font(.headline)
                    .padding(.top)
                    .padding(.horizontal)
                
                Text("For guaranteed use of InterVariable font, use approaches #2-7.")
                    .padding(.horizontal)
                
                Text("The most maintainable approaches are:")
                    .padding(.top)
                    .padding(.horizontal)
                
                VStack(alignment: .leading) {
                    Text("• CustomText (approach #4)")
                    Text("• Text extensions like .interHeadline() (approach #6)")
                    Text("• InterText factory (approach #7)")
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding()
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
            .padding(.vertical, 4)
    }
}

#Preview {
    FontVerificationView()
} 