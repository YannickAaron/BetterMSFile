//
//  Clamp+.swift
//  Adwaita
//
//  Created by david-swift on 20.01.24.
//

import CAdw

extension Clamp {

    /// Initialize either a horizontal or vertical clamp.
    /// - Parameter orientation: The orientation of the clamp.
    public init(orientation: Orientation) {
        self.init()
        appearFunctions.append { storage, _ in
            gtk_orientable_set_orientation(storage.opaquePointer, orientation.gtkValue)
        }
    }

}
