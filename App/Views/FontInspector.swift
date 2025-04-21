import SwiftUI
import UIKit

/// A view that inspects and displays font information for view hierarchies
struct FontInspector: View {
    let pageName: String
    @State private var fontReport: String = "Analyzing..."
    @State private var isVisible = false
    
    var body: some View {
        VStack {
            if isVisible {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Font Inspector: \(pageName)")
                            .font(.custom("Menlo", size: 14, relativeTo: .caption))
                            .bold()
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            refreshFontAnalysis()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.trailing, 8)
                        
                        Button(action: {
                            isVisible = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    ScrollView {
                        Text(fontReport)
                            .font(.custom("Menlo", size: 12, relativeTo: .caption))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                .shadow(radius: 5)
                .padding()
            } else {
                Button(action: {
                    isVisible = true
                    refreshFontAnalysis()
                }) {
                    HStack {
                        Image(systemName: "text.magnifyingglass")
                        Text("Show Font Inspector")
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .onAppear {
            // Give the view time to layout before inspecting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                analyzeFonts()
            }
        }
    }
    
    private func analyzeFonts() {
        // Get all UIKit text elements from the view hierarchy
        guard let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
            fontReport = "Could not access key window"
            return
        }
        
        // Start building the report
        var report = "📱 FONT USAGE REPORT\n"
        report += "Page: \(pageName)\n\n"
        
        // Get all views
        let allViews = getAllSubviews(of: keyWindow)
        
        // Count labels by font
        var fontCounts: [String: Int] = [:]
        var interVariableCount = 0
        var systemFontCount = 0
        var otherFontCount = 0
        
        // Find UILabels
        let labels = allViews.compactMap { $0 as? UILabel }
        
        if labels.isEmpty {
            report += "No UILabels found in current view hierarchy.\n"
        } else {
            report += "Found \(labels.count) text elements:\n\n"
            
            for label in labels {
                if let font = label.font {
                    let fontName = font.fontName
                    let fontSize = font.pointSize
                    let text = label.text ?? "(empty)"
                    let truncatedText = text.count > 20 ? text.prefix(20) + "..." : text
                    
                    // Identify the font type
                    if fontName.contains("InterVariable") {
                        interVariableCount += 1
                    } else if fontName.contains(".SFUI") || fontName.contains("System") {
                        systemFontCount += 1
                    } else {
                        otherFontCount += 1
                    }
                    
                    // Update count for this font
                    fontCounts[fontName, default: 0] += 1
                    
                    // Add to report
                    report += "\"\(truncatedText)\"\n"
                    report += "  Font: \(fontName) (\(fontSize)pt)\n\n"
                }
            }
            
            // Summary
            report += "--- SUMMARY ---\n"
            report += "InterVariable fonts: \(interVariableCount)\n"
            report += "System fonts: \(systemFontCount)\n"
            report += "Other fonts: \(otherFontCount)\n\n"
            
            // Font breakdown
            report += "--- FONT BREAKDOWN ---\n"
            for (font, count) in fontCounts.sorted(by: { $0.value > $1.value }) {
                report += "\(font): \(count) instances\n"
            }
        }
        
        fontReport = report
    }
    
    private func getAllSubviews(of view: UIView) -> [UIView] {
        var allSubviews = view.subviews
        for subview in view.subviews {
            allSubviews.append(contentsOf: getAllSubviews(of: subview))
        }
        return allSubviews
    }
    
    private func refreshFontAnalysis() {
        fontReport = "Refreshing font analysis..."
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            analyzeFonts()
        }
    }
}

/// A ZStack overlay that adds the font inspector to any view
struct WithFontInspector: ViewModifier {
    let pageName: String
    
    func body(content: Content) -> some View {
        ZStack {
            content
            FontInspector(pageName: pageName)
        }
    }
}

/// Extension to make it easy to add the font inspector to any view
extension View {
    func withFontInspector(pageName: String) -> some View {
        self.modifier(WithFontInspector(pageName: pageName))
    }
} 