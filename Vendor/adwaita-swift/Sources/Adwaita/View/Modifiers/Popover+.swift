//
//  Popover+.swift
//  Adwaita
//
//  Created by david-swift on 10.02.24.
//

import CAdw

extension Popover {

    /// Initialize a popover.
    /// - Parameter visible: Whether the popover is visible.
    public init(visible: Binding<Bool>) {
        self.init()
        updateFunctions.append { storage, _, _ in
            Self.updateFunction(storage: storage, visible: visible)
        }
    }

    /// The function that is being run on every updated that connects the visible binding.
    /// - Parameters:
    ///     - storage: The popover's view storage.
    ///     - visible: Whether it is visible.
    static func updateFunction(storage: ViewStorage, visible: Binding<Bool>) {
        storage.connectSignal(name: "closed", id: "visible", type: .noArgs) {
            if visible.wrappedValue {
                visible.wrappedValue = false
            }
        }
        if visible.wrappedValue {
            gtk_popover_popup(storage.opaquePointer?.cast())
        } else {
            gtk_popover_popdown(storage.opaquePointer?.cast())
        }
    }

}

extension PopoverMenu {

    /// Initialize a popover menu.
    /// - Parameter visible: Whether the popover is visible.
    public init(visible: Binding<Bool>) {
        self.init()
        updateFunctions.append { storage, _, _ in
            Popover.updateFunction(storage: storage, visible: visible)
        }
    }

}
