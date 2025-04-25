import Foundation
import Combine
import Core
import FirebaseFirestore
import FirebaseFirestoreSwift

/// Firebase implementation of the HangoutService protocol
public class HangoutServiceImpl: HangoutService {
    private let db = Firestore.firestore()
    private let hangoutsCollection = "hangouts"
    
    public init() {}
    
    public func getHangouts(forUserID userID: String) -> AnyPublisher<[Hangout], Error> {
        let query = db.collection(hangoutsCollection)
            .whereFilter(Filter.orFilter([
                Filter.whereField("creatorID", isEqualTo: userID),
                Filter.whereField("inviteeID", isEqualTo: userID)
            ]))
        
        return query.getDocumentsPublisher()
            .map { snapshot in
                snapshot.documents.compactMap { document in
                    try? document.data(as: Hangout.self)
                }
            }
            .eraseToAnyPublisher()
    }
    
    public func getPendingHangouts(forUserID userID: String) -> AnyPublisher<[Hangout], Error> {
        let query = db.collection(hangoutsCollection)
            .whereField("inviteeID", isEqualTo: userID)
            .whereField("status", isEqualTo: HangoutStatus.pending.rawValue)
        
        return query.getDocumentsPublisher()
            .map { snapshot in
                snapshot.documents.compactMap { document in
                    try? document.data(as: Hangout.self)
                }
            }
            .eraseToAnyPublisher()
    }
    
    public func getAcceptedHangouts(forUserID userID: String) -> AnyPublisher<[Hangout], Error> {
        let query = db.collection(hangoutsCollection)
            .whereFilter(Filter.orFilter([
                Filter.whereField("creatorID", isEqualTo: userID),
                Filter.whereField("inviteeID", isEqualTo: userID)
            ]))
            .whereField("status", isEqualTo: HangoutStatus.accepted.rawValue)
        
        return query.getDocumentsPublisher()
            .map { snapshot in
                snapshot.documents.compactMap { document in
                    try? document.data(as: Hangout.self)
                }
            }
            .eraseToAnyPublisher()
    }
    
    public func getAll() -> AnyPublisher<[Hangout], Error> {
        return db.collection(hangoutsCollection).getDocumentsPublisher()
            .map { snapshot in
                snapshot.documents.compactMap { document in
                    try? document.data(as: Hangout.self)
                }
            }
            .eraseToAnyPublisher()
    }
    
    public func get(by id: String) -> AnyPublisher<Hangout, Error> {
        return db.collection(hangoutsCollection).document(id).getDocumentPublisher()
            .tryMap { snapshot in
                guard let hangout = try? snapshot.data(as: Hangout.self) else {
                    throw ServiceError.documentDoesNotExist
                }
                return hangout
            }
            .eraseToAnyPublisher()
    }
    
    public func create(_ item: Hangout) -> AnyPublisher<Hangout, Error> {
        return createHangout(item)
    }
    
    public func createHangout(_ hangout: Hangout) -> AnyPublisher<Hangout, Error> {
        var newHangout = hangout
        
        if newHangout.id.isEmpty {
            newHangout.id = UUID().uuidString
        }
        
        return Future<Hangout, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(ServiceError.unknown))
                return
            }
            
            do {
                _ = try self.db.collection(self.hangoutsCollection).document(newHangout.id).setData(from: newHangout)
                promise(.success(newHangout))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    public func update(_ item: Hangout) -> AnyPublisher<Hangout, Error> {
        return updateHangout(item)
    }
    
    public func updateHangout(_ hangout: Hangout) -> AnyPublisher<Hangout, Error> {
        return Future<Hangout, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(ServiceError.unknown))
                return
            }
            
            do {
                _ = try self.db.collection(self.hangoutsCollection).document(hangout.id).setData(from: hangout)
                promise(.success(hangout))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    public func delete(_ id: String) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(ServiceError.unknown))
                return
            }
            
            self.db.collection(self.hangoutsCollection).document(id).delete { error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    public func acceptHangout(hangoutID: String) -> AnyPublisher<Hangout, Error> {
        return updateHangoutStatus(hangoutID: hangoutID, status: .accepted)
    }
    
    public func declineHangout(hangoutID: String) -> AnyPublisher<Hangout, Error> {
        return updateHangoutStatus(hangoutID: hangoutID, status: .declined)
    }
    
    public func cancelHangout(hangoutID: String) -> AnyPublisher<Hangout, Error> {
        return updateHangoutStatus(hangoutID: hangoutID, status: .canceled)
    }
    
    public func completeHangout(hangoutID: String) -> AnyPublisher<Hangout, Error> {
        return updateHangoutStatus(hangoutID: hangoutID, status: .completed)
    }
    
    private func updateHangoutStatus(hangoutID: String, status: HangoutStatus) -> AnyPublisher<Hangout, Error> {
        return get(by: hangoutID)
            .flatMap { [weak self] hangout in
                guard let self = self else {
                    return Fail(error: ServiceError.unknown).eraseToAnyPublisher()
                }
                
                var updatedHangout = hangout
                updatedHangout.status = status
                updatedHangout.updatedAt = Date()
                
                return self.updateHangout(updatedHangout)
            }
            .eraseToAnyPublisher()
    }
} 