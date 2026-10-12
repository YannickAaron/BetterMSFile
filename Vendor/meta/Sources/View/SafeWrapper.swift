//
//  SafeWrapper.swift
//  Meta
//
//  Created by david-swift on 02.02.26.
//

/// Wrap a widget but keep its pointer.
struct SafeWrapper: ConvenienceWidget {

    /// The custom code to edit the wrapper.
    /// The pointer is the one of the child widget.
    var modify: (ViewStorage, WidgetData, Bool) -> Void
    /// The wrapped view.
    var content: AnyView

    /// The view storage.
    /// - Parameters:
    ///     - data: Modify views before being updated.
    ///     - type: The view render data type.
    /// - Returns: The view storage.
    func container<Data>(
        data: WidgetData,
        type: Data.Type
    ) -> ViewStorage where Data: ViewRenderData {
        let contentStorage = content.storage(data: data, type: type)
        return .init(contentStorage.pointer, content: [.mainContent: [contentStorage]])
    }

    /// Update the stored content.
    /// - Parameters:
    ///     - storage: The storage to update.
    ///     - data: Modify views before being updated
    ///     - updateProperties: Whether to update the view's properties.
    ///     - type: The view render data type.
    func update<Data>(
        _ storage: ViewStorage,
        data: WidgetData,
        updateProperties: Bool,
        type: Data.Type
    ) where Data: ViewRenderData {
        if let contentStorage = storage.content[.mainContent]?.first {
            content.updateStorage(contentStorage, data: data, updateProperties: updateProperties, type: type)
        }
        modify(storage, data, updateProperties)
    }

}

/// Extend any view.
extension AnyView {

    /// Wrap a widget but keep its pointer.
    /// - Parameter modify: Modify the storage. The boolean indicates whether state in parent views changed.
    /// - Returns: A view.
    public func wrap(_ modify: @escaping (ViewStorage, WidgetData, Bool) -> Void) -> AnyView {
        SafeWrapper(modify: modify, content: self)
    }

    /// Wrap a widget but keep its pointer.
    /// - Parameter modify: Modify the storage. The boolean indicates whether state in parent views changed.
    /// - Returns: A view.
    public func wrap(_ modify: @escaping (ViewStorage, Bool) -> Void) -> AnyView {
        wrap { storage, _, updateProperties in modify(storage, updateProperties) }
    }

    /// A wrapper for generic simple modifiers.
    /// - Parameters:
    ///   - properties: The properties will be stored. Do not change the layout throughout updates.
    ///   - update: If properties change, run this function.
    /// - Returns: A view.
    public func wrapModifier(properties: [any Hashable], update: @escaping (ViewStorage) -> Void) -> AnyView {
        wrap { storage, _, updateProperties in
            guard updateProperties else {
                return
            }
            var shouldUpdate = false
            for (index, property) in properties.enumerated() {
                let update = {
                    shouldUpdate = true
                    storage.fields[index.description] = property
                }
                if let equatable = storage.fields[index.description] as? any Hashable {
                    if property.hashValue != equatable.hashValue { update() }
                } else { update() }
            }
            if shouldUpdate { update(storage) }
        }
    }

}
