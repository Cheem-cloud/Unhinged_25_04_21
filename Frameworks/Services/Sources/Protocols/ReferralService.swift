import Foundation

/// Protocol defining operations for managing user referrals within the application
public protocol ReferralService {
    /// Creates a new referral code for a user
    /// - Parameters:
    ///   - userId: The ID of the user creating the referral code
    ///   - type: The type of referral (specific reward/campaign)
    ///   - expirationDate: Optional expiration date for the referral code
    /// - Returns: The generated referral code
    func createReferralCode(for userId: String, type: ReferralType, expirationDate: Date?) async throws -> ReferralCode
    
    /// Validates a referral code
    /// - Parameter code: The referral code to validate
    /// - Returns: The referral details if valid
    func validateReferralCode(_ code: String) async throws -> ReferralCode?
    
    /// Records when a referral is used by a new user
    /// - Parameters:
    ///   - code: The referral code that was used
    ///   - newUserId: The ID of the user who used the referral code
    /// - Returns: The referral reward details
    func useReferralCode(_ code: String, by newUserId: String) async throws -> ReferralReward
    
    /// Gets all referral codes created by a user
    /// - Parameter userId: The user ID to get referrals for
    /// - Returns: Array of referral codes created by the user
    func getReferralCodes(for userId: String) async throws -> [ReferralCode]
    
    /// Gets referral statistics for a user
    /// - Parameter userId: The user ID to get statistics for
    /// - Returns: Referral statistics for the user
    func getReferralStats(for userId: String) async throws -> ReferralStats
    
    /// Updates a referral code (e.g., to disable it)
    /// - Parameters:
    ///   - code: The referral code to update
    ///   - isActive: Whether the code should be active
    ///   - expirationDate: Optional new expiration date
    func updateReferralCode(_ code: String, isActive: Bool, expirationDate: Date?) async throws
    
    /// Gets all referrals used by a specific user
    /// - Parameter userId: The user ID to check
    /// - Returns: Array of referrals used by the user
    func getReferralsUsedBy(userId: String) async throws -> [ReferralUsage]
    
    /// Checks if a user is eligible to receive a referral reward
    /// - Parameter userId: The user ID to check
    /// - Returns: Whether the user is eligible for rewards
    func isEligibleForReferralReward(userId: String) async throws -> Bool
    
    /// Gets the referral reward for a specific referral type
    /// - Parameter type: The referral type
    /// - Returns: The reward details for the referral type
    func getReferralReward(for type: ReferralType) async throws -> ReferralReward
}

/// Represents a referral code in the system
public struct ReferralCode: Codable, Identifiable {
    /// Unique identifier for the referral code
    public var id: String?
    
    /// The actual code that users will enter
    public var code: String
    
    /// User ID of the referrer who created the code
    public var referrerId: String
    
    /// Type of referral
    public var type: ReferralType
    
    /// When the code was created
    public var createdAt: Date
    
    /// When the code expires (if applicable)
    public var expirationDate: Date?
    
    /// Whether the code is currently active
    public var isActive: Bool
    
    /// Number of times the code has been used
    public var usageCount: Int
    
    /// Maximum number of times the code can be used (0 = unlimited)
    public var maxUsage: Int
    
    /// Campaign identifier if this is part of a specific campaign
    public var campaignId: String?
    
    public init(
        id: String? = nil,
        code: String,
        referrerId: String,
        type: ReferralType,
        createdAt: Date = Date(),
        expirationDate: Date? = nil,
        isActive: Bool = true,
        usageCount: Int = 0,
        maxUsage: Int = 0,
        campaignId: String? = nil
    ) {
        self.id = id
        self.code = code
        self.referrerId = referrerId
        self.type = type
        self.createdAt = createdAt
        self.expirationDate = expirationDate
        self.isActive = isActive
        self.usageCount = usageCount
        self.maxUsage = maxUsage
        self.campaignId = campaignId
    }
}

/// Types of referrals available in the system
public enum ReferralType: String, Codable, CaseIterable {
    case standard = "standard"
    case premium = "premium"
    case specialEvent = "special_event"
    case partner = "partner"
    case promotion = "promotion"
    case beta = "beta"
}

/// Represents a referral reward that can be earned
public struct ReferralReward: Codable {
    /// Unique identifier for the reward
    public var id: String?
    
    /// Type of referral this reward is for
    public var referralType: ReferralType
    
    /// Description of the reward
    public var description: String
    
    /// Value of the reward (e.g., number of points, credit amount)
    public var value: Double
    
    /// Type of reward (what the user gets)
    public var rewardType: RewardType
    
    /// Whether both referrer and referee get a reward
    public var bothReceiveReward: Bool
    
    /// Any conditions that must be met to receive the reward
    public var conditions: [String]?
    
    /// When the reward was last updated
    public var updatedAt: Date
    
    public init(
        id: String? = nil,
        referralType: ReferralType,
        description: String,
        value: Double,
        rewardType: RewardType,
        bothReceiveReward: Bool = true,
        conditions: [String]? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.referralType = referralType
        self.description = description
        self.value = value
        self.rewardType = rewardType
        self.bothReceiveReward = bothReceiveReward
        self.conditions = conditions
        self.updatedAt = updatedAt
    }
}

/// Types of rewards that can be given
public enum RewardType: String, Codable {
    case points = "points"
    case credit = "credit"
    case subscription = "subscription"
    case feature = "feature"
    case item = "item"
}

/// Record of a referral code being used
public struct ReferralUsage: Codable, Identifiable {
    /// Unique identifier for the usage record
    public var id: String?
    
    /// The referral code that was used
    public var referralCode: String
    
    /// ID of the user who created the referral code
    public var referrerId: String
    
    /// ID of the user who used the referral code
    public var refereeId: String
    
    /// Type of referral
    public var referralType: ReferralType
    
    /// When the referral was used
    public var usedAt: Date
    
    /// Status of the reward (e.g., pending, completed)
    public var rewardStatus: RewardStatus
    
    /// When the reward was processed (if applicable)
    public var rewardProcessedAt: Date?
    
    /// Additional notes about the referral usage
    public var notes: String?
    
    public init(
        id: String? = nil,
        referralCode: String,
        referrerId: String,
        refereeId: String,
        referralType: ReferralType,
        usedAt: Date = Date(),
        rewardStatus: RewardStatus = .pending,
        rewardProcessedAt: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.referralCode = referralCode
        self.referrerId = referrerId
        self.refereeId = refereeId
        self.referralType = referralType
        self.usedAt = usedAt
        self.rewardStatus = rewardStatus
        self.rewardProcessedAt = rewardProcessedAt
        self.notes = notes
    }
}

/// Status of a referral reward
public enum RewardStatus: String, Codable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

/// Statistics about a user's referral activity
public struct ReferralStats: Codable {
    /// Total number of referral codes created
    public var totalCodesCreated: Int
    
    /// Total number of successful referrals
    public var successfulReferrals: Int
    
    /// Total reward value earned from referrals
    public var totalRewardValue: Double
    
    /// Number of pending rewards
    public var pendingRewards: Int
    
    /// Statistics by referral type
    public var statsByType: [ReferralType: Int]
    
    /// Monthly referral counts
    public var monthlyStats: [String: Int]
    
    public init(
        totalCodesCreated: Int,
        successfulReferrals: Int,
        totalRewardValue: Double,
        pendingRewards: Int,
        statsByType: [ReferralType: Int],
        monthlyStats: [String: Int]
    ) {
        self.totalCodesCreated = totalCodesCreated
        self.successfulReferrals = successfulReferrals
        self.totalRewardValue = totalRewardValue
        self.pendingRewards = pendingRewards
        self.statsByType = statsByType
        self.monthlyStats = monthlyStats
    }
} 