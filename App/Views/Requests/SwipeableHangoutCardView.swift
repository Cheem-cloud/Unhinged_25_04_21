import SwiftUI

struct SwipeableHangoutCardView: View {
    let hangout: Hangout
    let viewModel: HangoutsViewModel
    var offset: CGSize
    var rotation: Double
    
    // Calculate dynamic opacity for decision indicators
    private var approveIndicatorOpacity: Double {
        return offset.width > 0 ? min(Double(offset.width) / 100, 1.0) : 0
    }
    
    private var declineIndicatorOpacity: Double {
        return offset.width < 0 ? min(Double(-offset.width) / 100, 1.0) : 0
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Creator Persona Image
                if let persona = viewModel.personaDetails[hangout.creatorPersonaID],
                   let imageURL = persona.imageURL,
                   !imageURL.isEmpty {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 300)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 300)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            )
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 300)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }
                
                // Details
                VStack(alignment: .leading, spacing: 15) {
                    // Title
                    Text(hangout.title)
                        .font(.custom("InterVariable", size: 22, fallback: .title2))
                        .fontWeight(.bold)
                        .foregroundColor(CustomTheme.Colors.text)
                    
                    // Description
                    Text(hangout.description)
                        .font(.custom("InterVariable", size: 16, fallback: .body))
                        .foregroundColor(CustomTheme.Colors.text.opacity(0.8))
                        .lineLimit(3)
                    
                    Divider()
                    
                    // Date and Time
                    HStack {
                        // Calendar icon
                        Image(systemName: "calendar")
                            .foregroundColor(CustomTheme.Colors.accent)
                        
                        // Date
                        Text(formatDate(hangout.startDate))
                            .font(.custom("InterVariable", size: 16, fallback: .headline))
                            .foregroundColor(CustomTheme.Colors.text)
                        
                        Spacer()
                        
                        // Clock icon
                        Image(systemName: "clock")
                            .foregroundColor(CustomTheme.Colors.accent)
                        
                        // Time
                        Text(formatTime(start: hangout.startDate, end: hangout.endDate))
                            .font(.custom("InterVariable", size: 16, fallback: .headline))
                            .foregroundColor(CustomTheme.Colors.text)
                    }
                    
                    // Location if available
                    if let location = hangout.location, !location.isEmpty {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(CustomTheme.Colors.accent)
                            
                            Text(location)
                                .font(.custom("InterVariable", size: 15, fallback: .subheadline))
                                .foregroundColor(CustomTheme.Colors.text)
                        }
                    }
                    
                    // Creator
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(CustomTheme.Colors.accent)
                        
                        Text("From: \(getCreatorName())")
                            .font(.custom("InterVariable", size: 15, fallback: .subheadline))
                            .foregroundColor(CustomTheme.Colors.text)
                    }
                }
                .padding(20)
            }
            
            // Card overlay decision indicators
            // Approve indicator (right side)
            VStack {
                Text("🔥")
                    .font(.system(size: 70))
                    .padding(20)
                    .background(
                        Circle()
                            .fill(CustomTheme.Colors.accent.opacity(0.8))
                    )
                    .opacity(approveIndicatorOpacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(20)
            
            // Decline indicator (left side)
            VStack {
                Text("👎")
                    .font(.system(size: 70))
                    .padding(20)
                    .background(
                        Circle()
                            .fill(CustomTheme.Colors.buttonDark.opacity(0.7))
                    )
                    .opacity(declineIndicatorOpacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)
        }
        .frame(width: 320, height: 550)
        .background(CustomTheme.Colors.backgroundLight)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .offset(offset)
        .rotationEffect(.degrees(rotation))
        .animation(.spring(), value: offset)
    }
    
    private func getCreatorName() -> String {
        if let persona = viewModel.personaDetails[hangout.creatorPersonaID] {
            return persona.name
        }
        return "Unknown"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTime(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    func printHangoutDetails(hangout: Hangout) {
        print("🧐 HANGOUT DETAILS:")
        print("🆔 ID: \(hangout.id ?? "nil")")
        print("📝 Title: \(hangout.title)")
        print("📋 Description: \(hangout.description)")
        print("🗓️ Start: \(hangout.startDate)")
        print("🗓️ End: \(hangout.endDate)")
        print("📍 Location: \(hangout.location ?? "nil")")
        print("👤 Creator ID: \(hangout.creatorID)")
        print("👤 Creator Persona ID: \(hangout.creatorPersonaID)")
        print("👥 Invitee ID: \(hangout.inviteeID)")
        print("👥 Invitee Persona ID: \(hangout.inviteePersonaID)")
        print("📊 Status: \(hangout.status.rawValue)")
        print("⏰ Created At: \(hangout.createdAt)")
        print("⏰ Updated At: \(hangout.updatedAt)")
    }
} 