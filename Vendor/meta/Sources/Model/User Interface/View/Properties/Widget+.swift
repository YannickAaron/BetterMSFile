//
//  Property+.swift
//  Meta
//
//  Created by david-swift on 14.10.24.
//

extension Widget {

    /// Update the properties wrapped with ``Property``.
    /// - Parameters:
    ///     - storage: The storage to update.
    ///     - data: The widget data.
    ///     - updateProperties: Whether to update the view's properties.
    ///     - type: The view render data type.
    public func updateProperties<Data>(
        _ storage: ViewStorage,
        data: WidgetData,
        updateProperties: Bool,
        type: Data.Type
    ) where Data: ViewRenderData {
        let mirror = Mirror(reflecting: self)
        updateNotEquatable(mirror: mirror, storage: storage, data: data, updateProperties: updateProperties, type: type)
        guard updateProperties else {
            return
        }
        updateAlwaysWhenStateUpdate(mirror: mirror, storage: storage)
        updateEquatable(mirror: mirror, storage: storage)
    }

    /// Update the properties which are not equatable and should always be updated (e.g. closures).
    /// - Parameters:
    ///     - mirror: A mirror of the widget.
    ///     - storage: The view storage.
    ///     - data: The widget data.
    ///     - updateProperties: Whether to update the properties.
    ///     - type: The view render data type.
    func updateNotEquatable<Data>(
        mirror: Mirror,
        storage: ViewStorage,
        data: WidgetData,
        updateProperties: Bool,
        type: Data.Type
    ) where Data: ViewRenderData {
        for property in mirror.children {
            if let value = property.value as? any PropertyProtocol {
                if value.updateStrategy == .always ||
                value.wrappedValue as? any Equatable == nil && value.updateStrategy != .alwaysWhenStateUpdate {
                    setProperty(property: value, storage: storage)
                }
            }
            if let value = property.value as? any ViewPropertyProtocol,
               let storage = storage.content[property.label ?? .mainContent]?.first {
                updateViewProperty(
                    value: value,
                    storage: storage,
                    data: data,
                    updateProperties: updateProperties,
                    type: type
                )
            }
            if let value = property.value as? any BindingPropertyProtocol {
                setBindingProperty(property: value, storage: storage)
            }
        }
    }

    /// Update a view property.
    /// - Parameters:
    ///     - value: The property.
    ///     - storage: The view storage.
    ///     - data: The widget data.
    ///     - updateProperties: Whether to update the properties.
    ///     - type: The parent context type.
    func updateViewProperty<Property, ParentContext>(
        value: Property,
        storage: ViewStorage,
        data: WidgetData,
        updateProperties: Bool,
        type: ParentContext.Type
    ) where Property: ViewPropertyProtocol, ParentContext: ViewRenderData {
        var data = data
        if type != Property.ViewContext.self {
            data = data.noModifiers
        }
        value.wrappedValue
            .updateStorage(storage, data: data, updateProperties: updateProperties, type: Property.ViewContext.self)
    }

    /// Update the properties which should always be updated when a state property changed
    /// (e.g. "regular" properties which are not equatable).
    /// - Parameters:
    ///     - mirror: A mirror of the widget.
    ///     - storage: The view storage.
    ///
    /// Initialize the ``Property`` property wrapper with the ``UpdateStrategy/alwaysWhenStateUpdate``.
    func updateAlwaysWhenStateUpdate(mirror: Mirror, storage: ViewStorage) {
        for property in mirror.children {
            if let value = property.value as? any PropertyProtocol {
                if value.updateStrategy == .alwaysWhenStateUpdate {
                    setProperty(property: value, storage: storage)
                }
            }
        }
    }

    /// Update equatable properties (most properties).
    /// - Parameters:
    ///     - mirror: A mirror of the widget.
    ///     - storage: The view storage.
    func updateEquatable(mirror: Mirror, storage: ViewStorage) {
        let previousState: Mirror.Children? = if let previousState = storage.previousState {
            Mirror(reflecting: previousState).children
        } else {
            nil
        }
        for property in mirror.children {
            if let value = property.value as? any PropertyProtocol,
               value.updateStrategy == .automatic,
               let wrappedValue = value.wrappedValue as? any Equatable {
                var update = true
                if let previous = previousState?.first(where: { previousProperty in
                    previousProperty.label == property.label
                })?.value as? any PropertyProtocol,
                equal(previous, wrappedValue) {
                    update = false
                }
                if update {
                    setProperty(property: value, storage: storage)
                }
            }
        }
    }

    /// Check whether a property is equal to a value.
    /// - Parameters:
    ///     - property: The property.
    ///     - value: The value.
    /// - Returns: Whether the property and value are equal.
    func equal<Property, Value>(
        _ property: Property,
        _ value: Value
    ) -> Bool where Property: PropertyProtocol, Value: Equatable {
        equal(property.wrappedValue, value)
    }

    /// Check whether a value is equal to another value.
    /// - Parameters:
    ///     - value1: The first value.
    ///     - value2: The second value.
    /// - Returns: Whether the values are equal.
    func equal<Value1, Value2>(
        _ value1: Value1,
        _ value2: Value2
    ) -> Bool where Value2: Equatable {
        if let value1 = value1 as? Value2 {
            return value1 == value2
        }
        return false
    }

    /// Apply a property to the framework.
    /// - Parameters:
    ///     - property: The property.
    ///     - storage: The view storage.
    func setProperty<Property>(property: Property, storage: ViewStorage) where Property: PropertyProtocol {
        if let optional = property.wrappedValue as? any OptionalProtocol, optional.optionalValue == nil {
            return
        }
        if let pointer = storage.pointer as? Property.Pointer {
            property.setProperty(pointer, property.wrappedValue, storage)
        }
    }

}
