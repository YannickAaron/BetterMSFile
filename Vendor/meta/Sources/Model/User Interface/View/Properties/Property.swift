//
//  Property.swift
//  Meta
//
//  Created by david-swift on 12.09.24.
//

/// Assign an updating closure to a widget's property.
///
/// This will be used if you do not provide a custom ``Widget/update(_:data:updateProperties:type:)`` method
/// or call the ``Widget/updateProperties(_:updateProperties:)`` method in your custom update method.
@propertyWrapper
public struct Property<Value, Pointer>: PropertyProtocol {

    /// The function applying the property to the UI.
    public var setProperty: (Pointer, Value, ViewStorage) -> Void
    /// The wrapped value.
    public var wrappedValue: Value
    /// The update strategy.
    public var updateStrategy: UpdateStrategy

    /// Initialize a property.
    /// - Parameters:
    ///     - wrappedValue: The wrapped value.
    ///     - setProperty: The function applying the property to the UI.
    ///     - pointer: The type of the pointer.
    ///     - updateStrategy: The update strategy, this should be ``UpdateStrategy/automatic`` in most cases.
    public init(
        wrappedValue: Value,
        set setProperty: @escaping (Pointer, Value, ViewStorage) -> Void,
        pointer: Pointer.Type,
        updateStrategy: UpdateStrategy = .automatic
    ) {
        self.setProperty = setProperty
        self.wrappedValue = wrappedValue
        self.updateStrategy = updateStrategy
    }

    /// Initialize a property.
    /// - Parameters:
    ///     - wrappedValue: The wrapped value.
    ///     - setProperty: The function applying the property to the UI.
    ///     - pointer: The type of the pointer.
    ///     - updateStrategy: The update strategy, this should be ``UpdateStrategy/automatic`` in most cases.
    public init(
        wrappedValue: Value,
        set setProperty: @escaping (Pointer, Value) -> Void,
        pointer: Pointer.Type,
        updateStrategy: UpdateStrategy = .automatic
    ) {
        self.init(
            wrappedValue: wrappedValue,
            set: { pointer, value, _ in setProperty(pointer, value) },
            pointer: pointer,
            updateStrategy: updateStrategy
        )
    }

}

extension Property where Value: OptionalProtocol {

    /// Initialize a property.
    /// - Parameters:
    ///     - setProperty: The function applying the property to the UI.
    ///     - pointer: The type of the pointer.
    ///     - updateStrategy: The update strategy, this should be ``UpdateStrategy/automatic`` in most cases.
    public init(
        set setProperty: @escaping (Pointer, Value.Wrapped, ViewStorage) -> Void,
        pointer: Pointer.Type,
        updateStrategy: UpdateStrategy = .automatic
    ) {
        self.setProperty = { pointer, value, storage in
            if let value = value.optionalValue {
                setProperty(pointer, value, storage)
            }
        }
        wrappedValue = nil
        self.updateStrategy = updateStrategy
    }

    /// Initialize a property.
    /// - Parameters:
    ///     - wrappedValue: The wrapped value.
    ///     - setProperty: The function applying the property to the UI.
    ///     - pointer: The type of the pointer.
    ///     - updateStrategy: The update strategy, this should be ``UpdateStrategy/automatic`` in most cases.
    public init(
        set setProperty: @escaping (Pointer, Value.Wrapped) -> Void,
        pointer: Pointer.Type,
        updateStrategy: UpdateStrategy = .automatic
    ) {
        self.init(
            set: { pointer, value, _ in setProperty(pointer, value) },
            pointer: pointer,
            updateStrategy: updateStrategy
        )
    }

}

/// The property protocol.
protocol PropertyProtocol {

    /// The type of the wrapped value.
    associatedtype Value
    /// The type of the view's pointer.
    associatedtype Pointer

    /// The wrapped value.
    var wrappedValue: Value { get }
    /// Set the property.
    var setProperty: (Pointer, Value, ViewStorage) -> Void { get }
    /// The update strategy.
    var updateStrategy: UpdateStrategy { get }

}

/// The update strategy for properties.
public enum UpdateStrategy {

    /// If equatable, update only when the value changed.
    /// If not equatable, this is equivalent to ``UpdateStrategy/always``.
    case automatic
    /// Update always when an update is triggered.
    case always
    /// Update always when a state value in a parent view changed,
    /// regardless of the property's value.
    case alwaysWhenStateUpdate

}

extension Widget {

    /// The view storage.
    /// - Parameters:
    ///     - data: Modify views before being updated.
    ///     - type: The view render data type.
    /// - Returns: The view storage.
    public func container<Data>(
        data: WidgetData,
        type: Data.Type
    ) -> ViewStorage where Data: ViewRenderData {
        let storage = ViewStorage(initializeWidget())
        initProperties(storage, data: data, type: type)
        return storage
    }

    /// Update the stored content.
    /// - Parameters:
    ///     - storage: The storage to update.
    ///     - data: Modify views before being updated
    ///     - updateProperties: Whether to update the view's properties.
    ///     - type: The view render data type.
    ///
    /// This is the default implementation which requires the usage of ``Property``.
    public func update<Data>(
        _ storage: ViewStorage,
        data: WidgetData,
        updateProperties: Bool,
        type: Data.Type
    ) where Data: ViewRenderData {
        self.updateProperties(storage, data: data, updateProperties: updateProperties, type: type)
        if updateProperties {
            storage.previousState = self
        }
    }

    /// Initialize the properties wrapped with ``Property``.
    /// - Parameters:
    ///     - storage: The view storage.
    ///     - data: Modify views before being updated.
    ///     - type: The view render data type.
    public func initProperties<Data>(
        _ storage: ViewStorage,
        data: WidgetData,
        type: Data.Type
    ) where Data: ViewRenderData {
        let mirror = Mirror(reflecting: self)
        for property in mirror.children {
            if let value = property.value as? any ViewPropertyProtocol {
                initViewProperty(value, data: data, parent: storage, label: property.label ?? .mainContent, type: type)
            }
            if let value = property.value as? any BindingPropertyProtocol {
                initBindingProperty(value, parent: storage)
            }
        }
    }

    /// Initialize the properties wrapped with ``ViewProperty``.
    /// - Parameters:
    ///     - value: The property.
    ///     - data: The widget data.
    ///     - parent: The parent's view storage.
    ///     - label: The view content label.
    ///     - type: The view context type of the parent view.
    func initViewProperty<Property, ParentContext>(
        _ value: Property,
        data: WidgetData,
        parent: ViewStorage,
        label: String,
        type: ParentContext.Type
    ) where Property: ViewPropertyProtocol, ParentContext: ViewRenderData {
        var data = data
        if type != Property.ViewContext.self {
            data = data.noModifiers
        }
        let subview = value.wrappedValue.storage(data: data, type: Property.ViewContext.self)
        if let view = subview.pointer as? Property.ViewPointer, let pointer = parent.pointer as? Property.Pointer {
            value.setView(pointer, view)
        }
        parent.content[label] = [subview]
    }

    /// Initialize a binding property.
    /// - Parameters:
    ///     - value: The property.
    ///     - parent: The view storage.
    func initBindingProperty<Property>(_ value: Property, parent: ViewStorage) where Property: BindingPropertyProtocol {
        if let view = parent.pointer as? Property.Pointer {
            value.observe(
                view,
                .init {
                    value.wrappedValue.wrappedValue
                } set: { newValue in
                    if let compareValue = newValue as? any Equatable,
                    !equal(value.wrappedValue.wrappedValue, compareValue) {
                        value.wrappedValue.wrappedValue = newValue
                    }
                },
                parent
            )
        }
    }

}

/// A protocol for values which can be optional.
public protocol OptionalProtocol: ExpressibleByNilLiteral {

    /// The type of the wrapped value.
    associatedtype Wrapped

    /// Initialize from a non-optional value.
    init(_ nonOptional: Wrapped)

    /// The value.
    var optionalValue: Wrapped? { get }

}

extension Optional: OptionalProtocol {

    /// Initialize from a non-optional value.
    /// - Parameter nonOptional: The value.
    public init(_ nonOptional: Wrapped) {
        self = nonOptional
    }

    /// The optional value.
    public var optionalValue: Wrapped? {
        self
    }

}
