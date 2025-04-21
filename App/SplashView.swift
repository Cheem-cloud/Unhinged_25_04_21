import SwiftUI

struct SplashView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var size = 0.8
    @State private var opacity = 0.5
    
    var body: some View {
        VStack {
            VStack {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                
                Text("Unhinged")
                    .font(.custom("InterVariable", size: 32, fallback: .largeTitle))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                Text("Hinge, but for your partner")
                    .font(.custom("InterVariable", size: 16, fallback: .body))
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
            }
            .scaleEffect(size)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2)) {
                    self.size = 1.0
                    self.opacity = 1.0
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CustomTheme.Colors.button)
        .edgesIgnoringSafeArea(.all)
        .withInterFont()
    }
} 