//
//  StateManager.swift
//  Meta
//
//  Created by david-swift on 21.06.24.
//

import Foundation

/// This type manages view updates.
public class StateManager {

    /// Whether to block updates in general.
    var blockUpdates = false
    /// The functions handling view updates.
    var updateHandlers: [(Bool, String?) -> Void] = []

    /// Update all of the views.
    /// - Parameters:
    ///     - force: Whether to force all views to update.
    ///     - id: An optional identifier for identifying the update.
    public func updateViews(force: Bool = false, id: String? = nil) {
        if !blockUpdates {
            for handler in updateHandlers {
                handler(force, id)
            }
        }
    }

    /// Change properties without updating the view.
    /// - Parameter action: The action that changes properties.
    public func withBlockedUpdates(action: () -> Void) {
        blockUpdates = true
        action()
        blockUpdates = false
    }

    /// Add a handler that is called when the user interface should update.
    /// - Parameter handler: The handler. The parameter defines whether the whole UI should be force updated.
    public func addUpdateHandler(handler: @escaping (Bool) -> Void) {
        addUpdateHandler { force, _ in handler(force) }
    }

    /// Add a handler that is called when the user interface should update.
    /// - Parameter handler: The handler. The first parameter defines whether the whole UI should be force updated.
    ///   With the second parameter, an id can be passed to characterize the update from within the backend
    ///   (e.g. origin/purpose).
    public func addUpdateHandler(handler: @escaping (Bool, String?) -> Void) {
        updateHandlers.append(handler)
    }

}
