//
//  UnsafePointer.swift
//  Adwaita
//
//  Created by david-swift on 14.08.26.
//

nonisolated
extension UnsafePointer {

    /// Convert into an opaque pointer.
    /// - Returns: The opaque pointer.
    public func opaque() -> OpaquePointer {
        .init(self)
    }

    /// Convert into an unsafe mutable pointer of another type.
    /// - Returns: The unsafe mutable pointer.
    public func cast<T>() -> UnsafePointer<T> {
        UnsafeRawPointer(self).assumingMemoryBound(to: T.self)
    }

}
