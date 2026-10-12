//
//  Box+.swift
//  Adwaita
//
//  Created by david-swift on 16.10.24.
//

extension Box {

    /// Link the children.
    /// - Parameters:
    ///     - active: Whether the style is currently applied.
    ///     - content: The content view.
    /// - Returns: A view.
    static func linked(_ active: Bool, content: AnyView) -> AnyView {
        content.style("linked", active: active)
    }

    /// Link the children.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func linked(_ active: Bool = true) -> AnyView {
        Self.linked(active, content: self)
    }

}

extension VStack {

    /// Link the children.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func linked(_ active: Bool = true) -> AnyView {
        Box.linked(active, content: self)
    }

}
