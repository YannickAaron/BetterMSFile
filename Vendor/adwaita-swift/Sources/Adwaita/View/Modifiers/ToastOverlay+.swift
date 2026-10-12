//
//  ToastOverlay+.swift
//  Adwaita
//
//  Created by david-swift on 21.01.24.
//

import CAdw
import Foundation

/// A wrapper around a view presenting toasts.
extension ToastOverlay {

    /// Initialize a toast overlay.
    /// - Parameters:
    ///     - title: The toast's title.
    ///     - signal: The signal for adding a toast.
    public init(_ title: String, signal: Binding<Signal>) {
        updateFunctions.append { storage, data, _ in
            data.stateManager.withBlockedUpdates {
                if signal.wrappedValue.update {
                    let toast = ViewStorage(adw_toast_new(title))
                    storage.fields[UUID().uuidString] = toast
                    if let button = storage.fields[.toastButton] as? String,
                    let handler = storage.fields[.toastHandler] as? () -> Void {
                        adw_toast_set_button_label(toast.opaquePointer, button)
                        toast.connectSignal(name: "button-clicked", type: .noArgs, handler: handler)
                    }
                    adw_toast_overlay_add_toast(storage.opaquePointer, toast.opaquePointer)
                }
            }
        }
    }

    /// Add an action button to the toast.
    /// - Parameters:
    ///     - button: The button's label.
    ///     - handler: The handler.
    /// - Returns: The toast overlay.
    public func action(button: String, handler: @escaping () -> Void) -> Self {
        var newSelf = self
        let action: (ViewStorage, WidgetData, Bool) -> Void = { storage, _, _ in
            storage.fields[.toastButton] = button
            storage.fields[.toastHandler] = handler
        }
        newSelf.updateFunctions.insert(action, at: 0)
        return newSelf
    }

}
