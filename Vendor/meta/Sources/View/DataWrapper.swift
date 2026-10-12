//
//  StateWrapper.swift
//  Meta
//
//  Created by david-swift on 09.06.24.
//

/// Assign values to the environment.
///
/// Access the environment in views (``View``) via `@Environment`.
struct DataWrapper: ConvenienceWidget {

    /// The content.
    var content: Body
    /// The identifier for the new environment value.
    var label: String
    /// The environment value.
    var data: Any

    /// Get a view storage.
    /// - Parameters:
    ///     - data: Modify views before being updated.
    ///     - type: The view render data type.
    /// - Returns: The view storage.
    func container<Data>(
        data: WidgetData,
        type: Data.Type
    ) -> ViewStorage where Data: ViewRenderData {
        content.storage(data: data.modify { $0.fields[label] = self.data }, type: type)
    }

    /// Update a view storage.
    /// - Parameters:
    ///     - storage: The view storage.
    ///     - data: Modify views before being updated.
    ///     - updateProperties: Whether to update properties.
    ///     - type: The view render data type.
    /// - Returns: The view storage.
    func update<Data>(
        _ storage: ViewStorage,
        data: WidgetData,
        updateProperties: Bool,
        type: Data.Type
    ) where Data: ViewRenderData {
        content
            .updateStorage(
                storage,
                data: data.modify { $0.fields[label] = self.data },
                updateProperties: updateProperties,
                type: type
            )
    }

}

extension AnyView {

    /// Assign a value to an environment label.
    /// - Parameters:
    ///     - label: The environment label.
    ///     - data: The value.
    /// - Returns: The view.
    public func environment(_ label: String, data: Any) -> AnyView {
        DataWrapper(content: [self], label: label, data: data)
    }

}
