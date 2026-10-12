//
//  Environment.swift
//  Meta
//
//  Created by david-swift on 23.10.24.
//

/// A property wrapper for properties in a view that should be stored throughout view updates.
@propertyWrapper
public struct Environment<Value>: EnvironmentProtocol {

    /// Access the environment value.
    public var wrappedValue: Value? {
        content.value as? Value
    }
    /// The value's identifier.
    var id: String
    /// The content.
    let content = EnvironmentContent()

    // swiftlint:disable function_default_parameter_at_end
    /// Initialize a property representing an environment value in the view.
    /// - Parameters:
    ///     - wrappedValue: The wrapped value.
    ///     - id: The environment value's identifier.
    public init(wrappedValue: Value? = nil, _ id: String) {
        self.id = id
    }
    // swiftlint:enable function_default_parameter_at_end

}

/// An environment property's content.
class EnvironmentContent {

    /// The value.
    var value: Any?

}

/// The environment property protocol.
protocol EnvironmentProtocol {

    /// The content.
    var content: EnvironmentContent { get }
    /// The identifier.
    var id: String { get }

}
