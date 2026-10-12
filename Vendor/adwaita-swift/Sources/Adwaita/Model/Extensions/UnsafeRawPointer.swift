//
//  UnsafeRawPointer.swift
//  Adwaita
//
//  Created by david-swift on 14.08.26.
//

nonisolated
extension UnsafeRawPointer {

    /// Convert into an unsafe mutable pointer of a certain type.
    /// - Returns: The unsafe mutable pointer.
    public func cast<T>() -> UnsafePointer<T> {
        assumingMemoryBound(to: T.self)
    }

}
