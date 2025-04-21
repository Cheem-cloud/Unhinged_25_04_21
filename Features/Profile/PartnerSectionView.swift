import SwiftUI

/// View component for displaying partner information in the profile
struct PartnerSectionView: View {
    @ObservedObject var relationshipViewModel: RelationshipViewModel
    @Binding var showingRelationshipView: Bool
    @Binding var showingInvitePartnerView: Bool
    @Binding var showingCoupleProfileView: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("Partner")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    relationshipViewModel.loadRelationship()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal)
            
            // Partner card content
            partnerCardContent
                .padding(.top, 10)
        }
    }
    
    // Partner card content based on relationship status
    private var partnerCardContent: some View {
        Group {
            if relationshipViewModel.isLoading {
                partnerLoadingCard
            } else if let relationship = relationshipViewModel.relationship, relationship.status == .active {
                activePartnerCard
            } else {
                noPartnerCard
            }
        }
    }
    
    // Loading card while fetching relationship data
    private var partnerLoadingCard: some View {
        VStack {
            HStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                    .scaleEffect(1.2)
                    .padding()
                Spacer()
            }
            Text("Loading partner information...")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.bottom, 15)
        }
        .background(Color.white)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // Card when user has an active partner
    private var activePartnerCard: some View {
        VStack(spacing: 10) {
            // Partner info button
            Button(action: {
                showingRelationshipView = true
            }) {
                HStack(spacing: 15) {
                    // Partner avatar
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 60, height: 60)
                        
                        if let photoURL = relationshipViewModel.partner?.photoURL, !photoURL.isEmpty {
                            AsyncImage(url: URL(string: photoURL)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.blue)
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Partner info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(relationshipViewModel.partner?.displayName ?? "Your Partner")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Together for \(relationshipViewModel.getRelationshipDuration())")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // Couple Profile button
            Button(action: {
                showingCoupleProfileView = true
            }) {
                HStack {
                    Image(systemName: "person.2.circle.fill")
                    Text("Couple Profile Hub")
                        .fontWeight(.semibold)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    // Card when user doesn't have a partner
    private var noPartnerCard: some View {
        Button(action: {
            showingInvitePartnerView = true
        }) {
            HStack {
                Spacer()
                
                VStack(spacing: 10) {
                    Image(systemName: "person.2.badge.plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.blue)
                    
                    Text("Connect with your partner")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Invite your partner to join you on Unhinged")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 5)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
} 