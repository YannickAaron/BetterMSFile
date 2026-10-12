//
//  UnsafeMutableRawPointer.swift
//  Adwaita
//
//  Created by david-swift on 15.01.24.
//

nonisolated
extension UnsafeMutableRawPointer {

    /// Convert into an unsafe mutable pointer of a certain type.
    /// - Returns: The unsafe mutable pointer.
    public func cast<T>() -> UnsafeMutablePointer<T> {
        assumingMemoryBound(to: T.self)
    }

}
