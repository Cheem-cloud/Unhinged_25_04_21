import SwiftUI
import CoreText

/// View for testing font availability and rendering
struct FontTestView: View {
    @State private var interVariableAvailable = false
    @State private var interItalicVariableAvailable = false
    @State private var fontDebugText = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Font Diagnosis")
                    .font(.largeTitle)
                    .padding()
                
                // Font availability indicators
                Group {
                    HStack {
                        Circle()
                            .fill(interVariableAvailable ? Color.green : Color.red)
                            .frame(width: 16, height: 16)
                        Text("InterVariable")
                            .font(.interSystem(size: 17))
                    }
                    
                    HStack {
                        Circle()
                            .fill(interItalicVariableAvailable ? Color.green : Color.red)
                            .frame(width: 16, height: 16)
                        Text("InterVariable-Italic")
                            .font(.interSystem(size: 17))
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                Group {
                    Text("System Fallback: Large Title")
                        .font(.largeTitle)
                    
                    Text("System Fallback: Title")
                        .font(.title)
                    
                    Text("System Fallback: Headline")
                        .font(.headline)
                    
                    Text("System Fallback: Body")
                        .font(.body)
                }
                .padding(.horizontal)
                
                Divider()
                
                Group {
                    Text("AppTheme: Title1")
                        .font(AppTheme.Typography.title1)
                    
                    Text("AppTheme: Body")
                        .font(AppTheme.Typography.body)
                    
                    Text("AppTheme: Caption")
                        .font(AppTheme.Typography.caption)
                }
                .padding(.horizontal)
                
                Divider()
                
                Group {
                    Text("CustomTheme: Title")
                        .font(CustomTheme.Typography.title)
                    
                    Text("CustomTheme: Body")
                        .font(CustomTheme.Typography.body)
                    
                    Text("CustomTheme: Caption")
                        .font(CustomTheme.Typography.caption)
                }
                .padding(.horizontal)
                
                Divider()
                
                Group {
                    Text("Direct Font Test: InterVariable (Regular)")
                        .font(.custom("InterVariable", size: 18, relativeTo: .body)
                              .weight(.regular))
                    
                    Text("Direct Font Test: InterVariable (Medium)")
                        .font(.custom("InterVariable", size: 18, relativeTo: .body)
                              .weight(.medium))
                    
                    Text("Direct Font Test: InterVariable (SemiBold)")
                        .font(.custom("InterVariable", size: 18, relativeTo: .body)
                              .weight(.semibold))
                    
                    Text("Direct Font Test: InterVariable (Bold)")
                        .font(.custom("InterVariable", size: 18, relativeTo: .body)
                              .weight(.bold))
                    
                    Text("Direct Font Test: InterVariableItalic (Regular)")
                        .font(.custom("InterVariableItalic", size: 18, relativeTo: .body)
                              .weight(.regular))
                }
                .padding(.horizontal)
                
                Divider()
                
                VStack(spacing: 10) {
                    Button("Print Font Info to Console") {
                        printFontInfo()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Try to Register Fonts") {
                        registerCustomFonts()
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Test System Fonts") {
                        testSystemFonts()
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Font debug output
                if !fontDebugText.isEmpty {
                    ScrollView {
                        Text(fontDebugText)
                            .font(.custom("Menlo", size: 14, relativeTo: .caption))
                            .padding()
                    }
                    .frame(height: 200)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(8)
                    .padding()
                }
            }
            .padding()
            .onAppear {
                checkFontAvailability()
            }
        }
    }
    
    private func checkFontAvailability() {
        interVariableAvailable = UIFont(name: "InterVariable", size: 17) != nil
        interItalicVariableAvailable = UIFont(name: "InterVariableItalic", size: 17) != nil
    }
    
    func printFontInfo() {
        var output = "📋 FONT DIAGNOSIS REPORT\n"
        output += "Listing available font families:\n"
        
        for family in UIFont.familyNames.sorted() {
            output += "- \(family)\n"
            for name in UIFont.fontNames(forFamilyName: family).sorted() {
                output += "  • \(name)\n"
            }
        }
        
        // Check variable fonts
        let interVariable = UIFont(name: "InterVariable", size: 17)
        let interItalicVariable = UIFont(name: "InterVariableItalic", size: 17)
        
        output += "\n📋 INTER FONT AVAILABILITY:\n"
        output += "InterVariable available: \(interVariable != nil)\n"
        output += "InterVariableItalic available: \(interItalicVariable != nil)\n"
        
        // Check for a font that should definitely be available (system font)
        let helvetica = UIFont(name: "HelveticaNeue", size: 17)
        output += "Control test - HelveticaNeue available: \(helvetica != nil)\n"
        
        // Update state and print to console
        fontDebugText = output
        print(output)
        checkFontAvailability()
    }
    
    func registerCustomFonts() {
        var output = "🔤 Manual Variable Font Registration\n"
        
        // Map between file names and font family names
        let fontMapping = [
            "InterVariable.ttf": "InterVariable",
            "InterVariable-Italic.ttf": "InterVariableItalic"
        ]
        
        // List all TTF files in bundle
        output += "\nTTF files in bundle:\n"
        let paths = Bundle.main.paths(forResourcesOfType: "ttf", inDirectory: nil)
        for path in paths {
            output += "• \(path)\n"
        }
        
        // Try to register each variable font
        for (fontFile, fontName) in fontMapping {
            // Find the font in the bundle
            if let fontURL = Bundle.main.url(forResource: fontFile.replacingOccurrences(of: ".ttf", with: ""), withExtension: "ttf") {
                output += "\nFound \(fontFile) at: \(fontURL.path)\n"
                output += "Will register as: \(fontName)\n"
                
                // Try to load the font data
                guard let fontData = try? Data(contentsOf: fontURL) else {
                    output += "❌ Failed to load font data\n"
                    continue
                }
                
                // Try to create a CGFont
                guard let provider = CGDataProvider(data: fontData as CFData),
                      let font = CGFont(provider) else {
                    output += "❌ Failed to create font from data\n"
                    continue
                }
                
                // Try to register the font
                var error: Unmanaged<CFError>?
                if !CTFontManagerRegisterGraphicsFont(font, &error) {
                    if let unwrappedError = error?.takeRetainedValue() {
                        output += "❌ Error registering font: \(unwrappedError)\n"
                    } else {
                        output += "❌ Unknown error registering font\n"
                    }
                } else {
                    output += "✅ Successfully registered variable font: \(fontName)\n"
                }
            } else {
                output += "\n❌ Variable font file not found: \(fontFile)\n"
            }
        }
        
        // Update state and print to console
        fontDebugText = output
        print(output)
        checkFontAvailability()
    }
    
    func testSystemFonts() {
        var output = "System Font Test\n\n"
        
        // Test if we can create various system fonts
        let systemRegular = UIFont.systemFont(ofSize: 17, weight: .regular)
        let systemBold = UIFont.systemFont(ofSize: 17, weight: .bold)
        let systemMedium = UIFont.systemFont(ofSize: 17, weight: .medium)
        let systemSemibold = UIFont.systemFont(ofSize: 17, weight: .semibold)
        
        output += "System Regular created: \(systemRegular != nil)\n"
        output += "System Bold created: \(systemBold != nil)\n"
        output += "System Medium created: \(systemMedium != nil)\n"
        output += "System Semibold created: \(systemSemibold != nil)\n"
        
        // Test if we can create some known system fonts by name
        let helveticaNeue = UIFont(name: "HelveticaNeue", size: 17)
        let sfPro = UIFont(name: "SFProText-Regular", size: 17)
        let arial = UIFont(name: "ArialMT", size: 17)
        
        output += "\nSystem font availability by name:\n"
        output += "HelveticaNeue: \(helveticaNeue != nil)\n"
        output += "SFProText-Regular: \(sfPro != nil)\n"
        output += "ArialMT: \(arial != nil)\n"
        
        // Update state and print to console
        fontDebugText = output
        print(output)
    }
}

#Preview {
    FontTestView()
} 