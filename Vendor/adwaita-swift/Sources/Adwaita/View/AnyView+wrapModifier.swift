//
//  AnyView+wrapModifier.swift
//  Adwaita
//
//  Created by david-swift on 02.02.26.
//

import CAdw

extension AnyView {

    /// Add padding around a view.
    /// - Parameters:
    ///   - padding: The size of the padding.
    ///   - edges: The edges which are affected by the padding.
    /// - Returns: A view.
    public func padding(_ padding: Int = 10, _ edges: Set<Edge> = .all) -> AnyView {
        wrapModifier(properties: [padding, edges]) { storage in
            if edges.contains(.leading) { gtk_widget_set_margin_start(storage.opaquePointer?.cast(), padding.cInt) }
            if edges.contains(.trailing) { gtk_widget_set_margin_end(storage.opaquePointer?.cast(), padding.cInt) }
            if edges.contains(.top) { gtk_widget_set_margin_top(storage.opaquePointer?.cast(), padding.cInt) }
            if edges.contains(.bottom) { gtk_widget_set_margin_bottom(storage.opaquePointer?.cast(), padding.cInt) }
        }
    }

    /// Add a padding of 10 around a view.
    /// - Parameters:
    ///   - edges: The edges which are affected by the padding.
    /// - Returns: A view.
    public func padding(_ edges: Set<Edge> = .all) -> AnyView {
        padding(10, edges)
    }

    /// Enable or disable the horizontal expansion.
    /// - Parameter enabled: Whether it is enabled or disabled.
    /// - Returns: A view.
    public func hexpand(_ enabled: Bool = true) -> AnyView {
        wrapModifier(properties: [enabled]) { storage in
            gtk_widget_set_hexpand(storage.opaquePointer?.cast(), enabled.cBool)
        }
    }

    /// Enable or disable the vertical expansion.
    /// - Parameter enabled: Whether it is enabled or disabled.
    /// - Returns: A view.
    public func vexpand(_ enabled: Bool = true) -> AnyView {
        wrapModifier(properties: [enabled]) { storage in
            gtk_widget_set_vexpand(storage.opaquePointer?.cast(), enabled.cBool)
        }
    }

    /// Set the horizontal alignment.
    /// - Parameter align: The alignment.
    /// - Returns: A view.
    public func halign(_ align: Alignment) -> AnyView {
        wrapModifier(properties: [align]) { storage in
            gtk_widget_set_halign(storage.opaquePointer?.cast(), align.gtkValue)
        }
    }

    /// Set the vertical alignment.
    /// - Parameter align: The alignment.
    /// - Returns: A view.
    public func valign(_ align: Alignment) -> AnyView {
        wrapModifier(properties: [align]) { storage in
            gtk_widget_set_valign(storage.opaquePointer?.cast(), align.gtkValue)
        }
    }

    /// Set the view's minimal width or height.
    /// - Parameters:
    ///   - minWidth: The minimal width.
    ///   - minHeight: The minimal height.
    /// - Returns: A view.
    public func frame(minWidth: Int? = nil, minHeight: Int? = nil) -> AnyView {
        wrapModifier(properties: [minWidth, minHeight]) { storage in
            gtk_widget_set_size_request(storage.opaquePointer?.cast(), minWidth?.cInt ?? 1, minHeight?.cInt ?? -1)
        }
    }

    /// Add a style class to the view.
    /// - Parameters:
    ///     - style: The style class.
    ///     - active: Whether the style is currently applied.
    /// - Returns: A view.
    public func style(_ style: String, active: Bool = true) -> AnyView {
        wrapModifier(properties: [style, active]) { storage in
            if active {
                gtk_widget_add_css_class(storage.opaquePointer?.cast(), style)
            } else {
                gtk_widget_remove_css_class(storage.opaquePointer?.cast(), style)
            }
        }
    }

    /// Make the view insensitive (useful e.g. in overlays).
    /// - Parameter insensitive: Whether the view is insensitive.
    /// - Returns: A view.
    public func insensitive(_ insensitive: Bool = true) -> AnyView {
        wrapModifier(properties: [insensitive]) { storage in
            gtk_widget_set_sensitive(storage.opaquePointer?.cast(), insensitive ? 0 : 1)
        }
    }

    /// Set the view's visibility.
    /// - Parameter visible: Whether the view is visible.
    /// - Returns: A view.
    public func visible(_ visible: Bool = true) -> AnyView {
        wrapModifier(properties: [visible]) { storage in
            gtk_widget_set_visible(storage.opaquePointer?.cast(), visible.cBool)
        }
    }

    /// Add a tooltip to the widget.
    /// - Parameter tooltip: The tooltip text.
    /// - Returns: A view.
    public func tooltip(_ tooltip: String) -> AnyView {
        wrapModifier(properties: [tooltip]) { storage in
            gtk_widget_set_tooltip_markup(storage.opaquePointer?.cast(), tooltip)
        }
    }

}
