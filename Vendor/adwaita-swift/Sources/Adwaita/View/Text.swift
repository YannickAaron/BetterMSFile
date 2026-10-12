//
//  Text.swift
//  Adwaita
//
//  Created by david-swift on 23.08.23.
//

import CAdw

/// A text widget.
public typealias Text = Label

extension Text {

    /// Initialize a text widget.
    /// - Parameter text: The content.
    public init(_ text: String) {
        self.init(label: text)
    }

    /// Set whether the text should ellipsize at the end.
    /// - Parameter ellipsize: Whether it should ellipsize.
    /// - Returns: The text widget.
    public func ellipsize(_ ellipsize: Bool = true) -> Self {
        var newSelf = self
        newSelf.updateFunctions.append { storage, _, _ in
            gtk_label_set_ellipsize(storage.opaquePointer, ellipsize ? PANGO_ELLIPSIZE_END : PANGO_ELLIPSIZE_NONE)
        }
        return newSelf
    }

    /// Sets the alignment of lines in the text relative to each other.
    /// - Parameter justify: The justification of the text.
    /// - Returns: The text widget.
    public func justify(_ justify: Justification = .left) -> Self {
        var newSelf = self
        newSelf.updateFunctions.append { storage, _, _ in
           gtk_label_set_justify(storage.opaquePointer, justify.gtkValue)
        }
        return newSelf
    }

}
