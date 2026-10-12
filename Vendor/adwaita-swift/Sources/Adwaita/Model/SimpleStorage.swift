//
//  SimpleStorage.swift
//  Adwaita
//
//  Created by david-swift on 26.07.2026.
//

/// Simply a very simple storage.
public class SimpleStorage: Storage {

    /// The pointer.
    public var opaquePointer: OpaquePointer?
    /// Additional fields.
    public var fields: [String: Any] = [:]

    /// Initialize a simple storage.
    /// - Parameter pointer: The pointer to store.
    public init(_ pointer: OpaquePointer?) {
        self.opaquePointer = pointer
    }

}
