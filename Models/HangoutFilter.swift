import Foundation

/// Filter options for hangouts in list views
public enum HangoutFilter: String, CaseIterable, Identifiable {
    case all
    case pending
    case upcoming
    case past
    case myInvites
    case mySentInvites
    
    public var id: String {
        return self.rawValue
    }
    
    public var displayName: String {
        switch self {
        case .all:
            return "All"
        case .pending:
            return "Pending"
        case .upcoming:
            return "Upcoming"
        case .past:
            return "Past"
        case .myInvites:
            return "My Invites"
        case .mySentInvites:
            return "Sent Invites"
        }
    }
    
    /// Apply filter to a list of hangouts
    public func apply(to hangouts: [Hangout], currentUserID: String) -> [Hangout] {
        let now = Date()
        
        switch self {
        case .all:
            return hangouts
            
        case .pending:
            return hangouts.filter { hangout in
                return hangout.status == .pending
            }
            
        case .upcoming:
            return hangouts.filter { hangout in
                guard let startDate = hangout.startDate else { return false }
                return startDate > now && 
                       (hangout.status == .accepted || hangout.status == .pending)
            }
            
        case .past:
            return hangouts.filter { hangout in
                guard let endDate = hangout.endDate else { return false }
                return endDate < now || hangout.status == .completed
            }
            
        case .myInvites:
            return hangouts.filter { hangout in
                return hangout.inviteeID == currentUserID && hangout.status == .pending
            }
            
        case .mySentInvites:
            return hangouts.filter { hangout in
                return hangout.creatorID == currentUserID && hangout.status == .pending
            }
        }
    }
    
    /// Get a predefined set of filters for the hangout list
    public static var defaultFilters: [HangoutFilter] {
        return [.all, .pending, .upcoming, .past]
    }
    
    /// Get a specified icon for each filter
    public var icon: String {
        switch self {
        case .all:
            return "list.bullet"
        case .pending:
            return "clock"
        case .upcoming:
            return "calendar"
        case .past:
            return "calendar.badge.clock"
        case .myInvites:
            return "tray.and.arrow.down"
        case .mySentInvites:
            return "tray.and.arrow.up"
        }
    }
} 