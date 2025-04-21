import Foundation
import FirebaseFirestore

/// Encoder for Firestore documents
public class FirestoreEncoder {
    /// Encode an object to a dictionary
    /// - Parameter value: The value to encode
    /// - Returns: The encoded dictionary
    /// - Throws: Encoding errors
    public func encode<T: Encodable>(_ value: T) throws -> Any {
        // Use Firestore's internal encoder
        return try Firestore.Encoder().encode(value)
    }
}

/// Decoder for Firestore documents
public class FirestoreDecoder {
    /// Decode a dictionary to an object
    /// - Parameters:
    ///   - type: The type to decode to
    ///   - value: The dictionary to decode
    /// - Returns: The decoded object
    /// - Throws: Decoding errors
    public func decode<T: Decodable>(_ type: T.Type, from value: Any) throws -> T {
        // Use Firestore's internal decoder
        if let dict = value as? [String: Any] {
            return try Firestore.Decoder().decode(type, from: dict)
        } else {
            throw ServiceError.invalidOperation("Value is not a dictionary")
        }
    }
    
    /// Decode a dictionary to an object
    /// - Parameters:
    ///   - type: The type to decode to (inferred)
    ///   - value: The dictionary to decode
    /// - Returns: The decoded object
    /// - Throws: Decoding errors
    public func decode<T: Decodable>(_ type: T.Type = T.self, from value: Any) throws -> T {
        return try decode(type, from: value)
    }
} 