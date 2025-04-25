import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

/// Firebase implementation of the ReferralService protocol
public class FirebaseReferralService: ReferralService {
    /// Firestore database reference
    private let db = Firestore.firestore()
    
    /// Reference to the referral codes collection
    private var referralCodesCollection: CollectionReference {
        return db.collection("referralCodes")
    }
    
    /// Reference to the referral usages collection
    private var referralUsagesCollection: CollectionReference {
        return db.collection("referralUsages")
    }
    
    /// Reference to the referral rewards collection
    private var referralRewardsCollection: CollectionReference {
        return db.collection("referralRewards")
    }
    
    /// Length of the generated referral codes
    private let codeLength = 8
    
    /// Initializes a new Firebase referral service
    public init() {}
    
    /// Creates a new referral code for a user
    /// - Parameters:
    ///   - userId: The ID of the user creating the referral code
    ///   - type: The type of referral (specific reward/campaign)
    ///   - expirationDate: Optional expiration date for the referral code
    /// - Returns: The generated referral code
    public func createReferralCode(for userId: String, type: ReferralType, expirationDate: Date?) async throws -> ReferralCode {
        // Generate a unique referral code
        let code = try await generateUniqueReferralCode()
        
        let referralCode = ReferralCode(
            code: code,
            referrerId: userId,
            type: type,
            createdAt: Date(),
            expirationDate: expirationDate,
            isActive: true,
            usageCount: 0,
            maxUsage: 0 // 0 means unlimited
        )
        
        do {
            let docRef = referralCodesCollection.document()
            try docRef.setData(from: referralCode)
            
            var savedReferralCode = referralCode
            savedReferralCode.id = docRef.documentID
            
            return savedReferralCode
        } catch {
            throw ReferralError.creationFailed(error.localizedDescription)
        }
    }
    
    /// Validates a referral code
    /// - Parameter code: The referral code to validate
    /// - Returns: The referral details if valid
    public func validateReferralCode(_ code: String) async throws -> ReferralCode? {
        do {
            let snapshot = try await referralCodesCollection
                .whereField("code", isEqualTo: code)
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            
            guard let document = snapshot.documents.first else {
                return nil // Code not found
            }
            
            var referralCode = try document.data(as: ReferralCode.self)
            referralCode.id = document.documentID
            
            // Check if expired
            if let expirationDate = referralCode.expirationDate, expirationDate < Date() {
                return nil // Code expired
            }
            
            // Check if maximum usage exceeded
            if referralCode.maxUsage > 0 && referralCode.usageCount >= referralCode.maxUsage {
                return nil // Maximum usage exceeded
            }
            
            return referralCode
        } catch {
            throw ReferralError.validationFailed(error.localizedDescription)
        }
    }
    
    /// Records when a referral is used by a new user
    /// - Parameters:
    ///   - code: The referral code that was used
    ///   - newUserId: The ID of the user who used the referral code
    /// - Returns: The referral reward details
    public func useReferralCode(_ code: String, by newUserId: String) async throws -> ReferralReward {
        // Validate the code first
        guard let referralCode = try await validateReferralCode(code) else {
            throw ReferralError.invalidCode
        }
        
        // Check if the user has already used a referral code
        let existingUsages = try await referralUsagesCollection
            .whereField("refereeId", isEqualTo: newUserId)
            .getDocuments()
        
        if !existingUsages.documents.isEmpty {
            throw ReferralError.alreadyUsedReferral
        }
        
        // Get the reward for this referral type
        let reward = try await getReferralReward(for: referralCode.type)
        
        // Create usage record
        let usage = ReferralUsage(
            referralCode: code,
            referrerId: referralCode.referrerId,
            refereeId: newUserId,
            referralType: referralCode.type,
            usedAt: Date(),
            rewardStatus: .pending
        )
        
        // Update referral code usage count
        try await referralCodesCollection.document(referralCode.id!).updateData([
            "usageCount": FieldValue.increment(Int64(1))
        ])
        
        // Save the usage record
        try referralUsagesCollection.document().setData(from: usage)
        
        return reward
    }
    
    /// Gets all referral codes created by a user
    /// - Parameter userId: The user ID to get referrals for
    /// - Returns: Array of referral codes created by the user
    public func getReferralCodes(for userId: String) async throws -> [ReferralCode] {
        do {
            let snapshot = try await referralCodesCollection
                .whereField("referrerId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                var referralCode = try document.data(as: ReferralCode.self)
                referralCode.id = document.documentID
                return referralCode
            }
        } catch {
            throw ReferralError.retrievalFailed(error.localizedDescription)
        }
    }
    
    /// Gets referral statistics for a user
    /// - Parameter userId: The user ID to get statistics for
    /// - Returns: Referral statistics for the user
    public func getReferralStats(for userId: String) async throws -> ReferralStats {
        do {
            // Get all referral codes created by the user
            let referralCodes = try await getReferralCodes(for: userId)
            
            // Get all successful referrals
            let referralCodes_code = referralCodes.map { $0.code }
            
            let usagesSnapshot = try await referralUsagesCollection
                .whereField("referrerId", isEqualTo: userId)
                .getDocuments()
            
            let usages = try usagesSnapshot.documents.compactMap { document in
                try document.data(as: ReferralUsage.self)
            }
            
            // Calculate stats by type
            var statsByType: [ReferralType: Int] = [:]
            for type in ReferralType.allCases {
                statsByType[type] = usages.filter { $0.referralType == type }.count
            }
            
            // Calculate monthly stats
            var monthlyStats: [String: Int] = [:]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM"
            
            for usage in usages {
                let monthKey = dateFormatter.string(from: usage.usedAt)
                monthlyStats[monthKey, default: 0] += 1
            }
            
            // Calculate total reward value
            var totalRewardValue: Double = 0
            for usage in usages {
                if usage.rewardStatus == .completed {
                    let reward = try await getReferralReward(for: usage.referralType)
                    totalRewardValue += reward.value
                }
            }
            
            // Count pending rewards
            let pendingRewards = usages.filter { $0.rewardStatus == .pending }.count
            
            return ReferralStats(
                totalCodesCreated: referralCodes.count,
                successfulReferrals: usages.filter { $0.rewardStatus == .completed }.count,
                totalRewardValue: totalRewardValue,
                pendingRewards: pendingRewards,
                statsByType: statsByType,
                monthlyStats: monthlyStats
            )
        } catch {
            throw ReferralError.statisticsRetrievalFailed(error.localizedDescription)
        }
    }
    
    /// Updates a referral code (e.g., to disable it)
    /// - Parameters:
    ///   - code: The referral code to update
    ///   - isActive: Whether the code should be active
    ///   - expirationDate: Optional new expiration date
    public func updateReferralCode(_ code: String, isActive: Bool, expirationDate: Date?) async throws {
        do {
            let snapshot = try await referralCodesCollection
                .whereField("code", isEqualTo: code)
                .getDocuments()
            
            guard let document = snapshot.documents.first else {
                throw ReferralError.codeNotFound
            }
            
            var updateData: [String: Any] = [
                "isActive": isActive
            ]
            
            if let expirationDate = expirationDate {
                updateData["expirationDate"] = expirationDate
            }
            
            try await referralCodesCollection.document(document.documentID).updateData(updateData)
        } catch {
            throw ReferralError.updateFailed(error.localizedDescription)
        }
    }
    
    /// Gets all referrals used by a specific user
    /// - Parameter userId: The user ID to check
    /// - Returns: Array of referrals used by the user
    public func getReferralsUsedBy(userId: String) async throws -> [ReferralUsage] {
        do {
            let snapshot = try await referralUsagesCollection
                .whereField("refereeId", isEqualTo: userId)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                var usage = try document.data(as: ReferralUsage.self)
                usage.id = document.documentID
                return usage
            }
        } catch {
            throw ReferralError.retrievalFailed(error.localizedDescription)
        }
    }
    
    /// Checks if a user is eligible to receive a referral reward
    /// - Parameter userId: The user ID to check
    /// - Returns: Whether the user is eligible for rewards
    public func isEligibleForReferralReward(userId: String) async throws -> Bool {
        do {
            // Check if the user has already used a referral code
            let existingUsages = try await referralUsagesCollection
                .whereField("refereeId", isEqualTo: userId)
                .getDocuments()
            
            // If they've already used a referral, they're not eligible for another
            if !existingUsages.documents.isEmpty {
                return false
            }
            
            // Here you could add additional eligibility criteria
            // For example, account age, completed profile, etc.
            
            return true
        } catch {
            throw ReferralError.eligibilityCheckFailed(error.localizedDescription)
        }
    }
    
    /// Gets the referral reward for a specific referral type
    /// - Parameter type: The referral type
    /// - Returns: The reward details for the referral type
    public func getReferralReward(for type: ReferralType) async throws -> ReferralReward {
        do {
            let snapshot = try await referralRewardsCollection
                .whereField("referralType", isEqualTo: type.rawValue)
                .getDocuments()
            
            guard let document = snapshot.documents.first else {
                // Return a default reward if no specific reward is configured
                return ReferralReward(
                    referralType: type,
                    description: "Default reward for \(type.rawValue) referrals",
                    value: 10.0,
                    rewardType: .points
                )
            }
            
            var reward = try document.data(as: ReferralReward.self)
            reward.id = document.documentID
            return reward
        } catch {
            throw ReferralError.rewardRetrievalFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Generates a unique referral code
    /// - Returns: A unique referral code that doesn't exist in the system
    private func generateUniqueReferralCode() async throws -> String {
        let maxAttempts = 5
        
        for _ in 0..<maxAttempts {
            let code = generateRandomCode(length: codeLength)
            
            // Check if this code already exists
            let snapshot = try await referralCodesCollection
                .whereField("code", isEqualTo: code)
                .getDocuments()
            
            if snapshot.documents.isEmpty {
                return code
            }
        }
        
        throw ReferralError.codeGenerationFailed("Failed to generate a unique code after \(maxAttempts) attempts")
    }
    
    /// Generates a random alphanumeric code
    /// - Parameter length: Length of the code to generate
    /// - Returns: Random alphanumeric code
    private func generateRandomCode(length: Int) -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Removed ambiguous characters like O/0, I/1
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}

/// Errors specific to referral operations
public enum ReferralError: Error {
    case creationFailed(String)
    case validationFailed(String)
    case invalidCode
    case codeNotFound
    case alreadyUsedReferral
    case retrievalFailed(String)
    case updateFailed(String)
    case codeGenerationFailed(String)
    case statisticsRetrievalFailed(String)
    case eligibilityCheckFailed(String)
    case rewardRetrievalFailed(String)
}

extension ReferralError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .creationFailed(let message):
            return "Failed to create referral code: \(message)"
        case .validationFailed(let message):
            return "Failed to validate referral code: \(message)"
        case .invalidCode:
            return "The referral code is invalid or expired"
        case .codeNotFound:
            return "Referral code not found"
        case .alreadyUsedReferral:
            return "You have already used a referral code"
        case .retrievalFailed(let message):
            return "Failed to retrieve referral data: \(message)"
        case .updateFailed(let message):
            return "Failed to update referral code: \(message)"
        case .codeGenerationFailed(let message):
            return "Failed to generate referral code: \(message)"
        case .statisticsRetrievalFailed(let message):
            return "Failed to retrieve referral statistics: \(message)"
        case .eligibilityCheckFailed(let message):
            return "Failed to check referral eligibility: \(message)"
        case .rewardRetrievalFailed(let message):
            return "Failed to retrieve referral reward: \(message)"
        }
    }
} 