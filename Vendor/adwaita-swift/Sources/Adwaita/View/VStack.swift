//
//  VStack.swift
//  Adwaita
//
//  Created by david-swift on 23.08.23.
//

import CAdw

extension Box {

    /// Initialize a ``Box`` that is aware of the context's spacing/orientation.
    /// - Parameter content: The content.
    public init(@ViewBuilder content: @escaping () -> Body) {
        self.init()
        self = self.append(content)
    }

    /// Initialize a `Box`.
    /// - Parameters:
    ///     - orientation: The orientation of the box.
    ///     - content: The view content.
    init(orientation: Orientation, spacing: Int, @ViewBuilder content: @escaping () -> Body) {
        self.init(content: content)
        self = self
            .spacing(spacing)
            .orientation(orientation)
    }

}

/// A GtkBox that sets the orientation context explicitly.
public struct VStack: AdwaitaWidget {

    /// The orientation (can only be set internally for HStack).
    var orientation: Orientation
    /// The spacing.
    var spacing: Int
    /// The content.
    var content: Body

    /// Initialize a `VStack`.
    /// - Parameters:
    ///     - spacing: The spacing between elements.
    ///     - content: The view content.
    public init(spacing: Int = 0, @ViewBuilder content: () -> Body) {
        self.init(orientation: .vertical, spacing: spacing, content: content)
    }

    /// Initialize a `VStack`.
    /// - Parameters:
    ///     - orientation: The orientation of the box.
    ///     - content: The view content.
    init(orientation: Orientation, spacing: Int, @ViewBuilder content: () -> Body) {
        self.orientation = orientation
        self.spacing = spacing
        self.content = content()
    }

    /// The view storage.
    /// - Parameters:
    ///     - modifiers: Modify views before being updated.
    ///     - type: The view render data type.
    /// - Returns: The view storage.
    public func container<Data>(data: WidgetData, type: Data.Type) -> ViewStorage where Data: ViewRenderData {
        getBox()
            .container(
                data: data.orientation(orientation).spacing(spacing),
                type: type
            )
    }

    /// Update the stored content.
    /// - Parameters:
    ///     - storage: The storage to update.
    ///     - modifiers: Modify views before being updated
    ///     - updateProperties: Whether to update the view's properties.
    ///     - type: The view render data type.
    public func update<Data>(
        _ storage: ViewStorage,
        data: WidgetData,
        updateProperties: Bool,
        type: Data.Type
    ) where Data: ViewRenderData {
        getBox()
            .update(
                storage,
                data: data.orientation(orientation).spacing(spacing),
                updateProperties: updateProperties,
                type: type
            )
    }

    /// Get the GtkBox.
    func getBox() -> Box {
        Box(orientation: orientation, spacing: spacing) { content }
    }

}

/// A wrapper around ``Box`` which applies ``Box`` only if there is more than one view.
public struct BoxWrapper: AdwaitaWidget, Wrapper {

    /// The content.
    var content: Body

    /// The box.
    var contentView: Box {
        .init { content }
    }

    /// Initialize the wrapper.
    /// - Parameter content: The view content.
    public init(@ViewBuilder content: () -> Body) {
        self.content = content()
    }

    /// The view storage.
    /// - Parameters:
    ///     - modifiers: Modify views before being updated.
    ///     - type: The view render data type.
    /// - Returns: The view storage.
    public func container<Data>(
        data: WidgetData,
        type: Data.Type
    ) -> ViewStorage where Data: ViewRenderData {
        if content.count == 1, let element = content.first {
            return element.storage(data: data, type: type)
        } else {
            return contentView.storage(data: data, type: type)
        }
    }

    /// Update the stored content.
    /// - Parameters:
    ///     - storage: The storage to update.
    ///     - modifiers: Modify views before being updated
    ///     - updateProperties: Whether to update the view's properties.
    ///     - type: The view render data type.
    public func update<Data>(
        _ storage: ViewStorage,
        data: WidgetData,
        updateProperties: Bool,
        type: Data.Type
    ) where Data: ViewRenderData {
        if content.count == 1, let element = content.first {
            element.updateStorage(storage, data: data, updateProperties: updateProperties, type: type)
        } else {
            contentView
                .updateStorage(storage, data: data, updateProperties: updateProperties, type: type)
        }
    }

}
