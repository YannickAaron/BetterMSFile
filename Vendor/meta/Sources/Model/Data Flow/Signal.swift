//
//  Signal.swift
//  Meta
//
//  Created by david-swift on 26.05.24.
//

import Foundation

/// A type that signalizes an action.
public struct Signal {

    /// An action is signalized by toggling a boolean to `true` and back to `false`.
    var boolean = false
    /// A signal has a unique identifier.
    public let id: UUID = .init()

    /// Whether the action has caused an update.
    public var update: Bool {
        mutating get {
            if boolean {
                boolean = false
                return true
            }
            return false
        }
    }

    /// Initialize a signal.
    public init() { }

    /// Activate a signal.
    public mutating func signal() {
        boolean = true
    }

}
