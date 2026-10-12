//
//  DragAction.swift
//  Adwaita
//
//  Created by desbeers on 21.08.26.
//

import CAdw

/// An action that can be performed when data is dropped.
nonisolated
public enum DragAction {

    /// Copy the dropped data.
    case copy
    /// Move the dropped data.
    case move
    /// Create a link to the dropped data.
    case link
    /// Ask the user what to do with the dropped data.
    case ask
    /// The DragAction value as GdkDragAction.
    var gdkValue: GdkDragAction {
        switch self {
        case .copy:
            .GDK_ACTION_COPY
        case .move:
            .GDK_ACTION_MOVE
        case .link:
            .GDK_ACTION_LINK
        case .ask:
            .GDK_ACTION_ASK
        }
    }
}
