//
//  HStack.swift
//  Adwaita
//
//  Created by david-swift on 26.09.23.
//

/// A horizontal GtkBox equivalent.
public struct HStack: SimpleView {

    /// The content.
    var content: () -> Body
    /// The spacing between elements.
    var spacing: Int

    /// The view's body.
    public var view: Body {
        VStack(orientation: .horizontal, spacing: spacing, content: content)
    }

    /// Initialize a `HStack`.
    /// - Parameters:
    ///     - spacing: The spacing between elements.
    ///     - content: The view content.
    public init(spacing: Int = 0, @ViewBuilder content: @escaping () -> Body) {
        self.content = content
        self.spacing = spacing
    }

    /// Link the children.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func linked(_ active: Bool = true) -> AnyView {
        Box.linked(active, content: self)
    }

}
