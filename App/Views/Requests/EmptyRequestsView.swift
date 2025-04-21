import SwiftUI

struct EmptyRequestsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.interSystem(size: 70))
                .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
            
            Text("No pending requests")
                .font(.custom("InterVariable", size: 24, fallback: .title2))
                .fontWeight(.medium)
                .foregroundColor(CustomTheme.Colors.text)
            
            Text("When someone wants to hang out\nwith your pet, you'll see it here")
                .font(.custom("InterVariable", size: 18, fallback: .body))
                .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
} 