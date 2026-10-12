//
//  Class.swift
//  Adwaita
//
//  Created by david-swift on 14.01.24.
//

import Foundation

/// A class.
struct Class: ClassLike, Decodable {

    /// The name of the class.
    var name: String
    /// The prefix for C symbols.
    var cSymbolPrefix: String
    /// The type in C.
    var cType: String?
    /// The parent class.
    var parent: String?

    /// The doc string.
    var doc: String
    /// The available initializers.
    var constructors: [Constructor]
    /// The available properties.
    var properties: [Property]
    /// The available signals (callbacks).
    var signals: [Signal]
    /// Protocol conformances.
    var conformances: [Conformance]

    /// The coding keys for the class
    enum CodingKeys: String, CodingKey {

        /// Coding key
        case name, cSymbolPrefix, cType, parent, doc
        /// Coding key
        case constructors = "constructor"
        /// Coding key
        case properties = "property"
        /// Coding key
        case signals = "glibSignal"
        /// Coding key
        case conformances = "implements"

    }

    // swiftlint:disable function_body_length line_length
    /// Generate the code for the class.
    /// - Parameters:
    ///     - config: The widget configuration.
    ///     - genConfig: The generation configuration.
    ///     - namespace: The namespace.
    ///     - configs: The available widget configurations.
    /// - Returns: The code.
    func generate(
        config: WidgetConfiguration,
        genConfig: GenerationConfiguration,
        namespace: Namespace,
        configs: [WidgetConfiguration]
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yy"
        let widgetName = config.name ?? config.class
        let definition: String
        var extensions = ""
        if config.dynamicWidget == nil {
            definition = "\(widgetName): AdwaitaWidget"
        } else {
            definition = "\(widgetName)<Element, Identifier>: AdwaitaWidget where Identifier: Equatable"
            extensions += """

            extension \(widgetName) where Element: Identifiable, Identifier == Element.ID {

                /// Initialize `\(widgetName)`.
                public init(_ elements: [Element], @ViewBuilder content: @escaping (Element) -> Body) {
                    self.elements = elements
                    self.content = content
                    self.id = \\.id
                }

            }

            """
        }
        return """
        //
        //  \(widgetName).swift
        //  Adwaita
        //
        //  Created by auto-generation on \(dateFormatter.string(from: .init())).
        //

        import CAdw
        import LevenshteinTransformations

        \(doc.docComment(configuration: genConfig))
        public struct \(definition) {

            #if exposeGeneratedAppearUpdateFunctions
            /// Additional update functions for type extensions.
            public var updateFunctions: [(ViewStorage, WidgetData, Bool) -> Void] = []
            /// Additional appear functions for type extensions.
            public var appearFunctions: [(ViewStorage, WidgetData) -> Void] = []
            #else
            /// Additional update functions for type extensions.
            var updateFunctions: [(ViewStorage, WidgetData, Bool) -> Void] = []
            /// Additional appear functions for type extensions.
            var appearFunctions: [(ViewStorage, WidgetData) -> Void] = []
            #endif
        \(generateProperties(config: config, genConfig: genConfig, namespace: namespace, configs: configs))

            /// Initialize `\(widgetName)`.
            \(generateAdwaitaInitializer(config: config, genConfig: genConfig, namespace: namespace, configs: configs))

            /// The view storage.
            /// - Parameters:
            ///     - modifiers: Modify views before being updated.
            ///     - type: The view render data type.
            /// - Returns: The view storage.
            public func container<Data>(data: WidgetData, type: Data.Type) -> ViewStorage where Data: ViewRenderData {
                let storage = ViewStorage(\(generateInitializer(name: widgetName, config: config, namespace: namespace, configs: configs))?.opaque())
                for function in appearFunctions {
                    function(storage, data)
                }
        \(generateWidgetAssignments(config: config, genConfig: genConfig, namespace: namespace, configs: configs))
                return storage
            }

            /// Update the stored content.
            /// - Parameters:
            ///     - storage: The storage to update.
            ///     - modifiers: Modify views before being updated
            ///     - updateProperties: Whether to update the view's properties.
            ///     - type: The view render data type.
            public func update<Data>(_ storage: ViewStorage, data: WidgetData, updateProperties: Bool, type: Data.Type) where Data: ViewRenderData {\(generateSignalModifications(config: config, genConfig: genConfig, namespace: namespace))
                storage.modify { widget in
        \(generateBindingAssignments(config: config, genConfig: genConfig, namespace: namespace, configs: configs))
        \(generateModifications(config: config, genConfig: genConfig, namespace: namespace, configs: configs))
        \(generateDynamicWidgetUpdate(config: config, genConfig: genConfig))
        \(generateManualSetters(config: config))
                }
                for function in updateFunctions {
                    function(storage, data, updateProperties)
                }
                if updateProperties {
                    storage.previousState = self
                }
            }
        \(generateModifiers(config: config, genConfig: genConfig, namespace: namespace, configs: configs))
        }
        \(extensions)
        """
    }
    // swiftlint:enable function_body_length line_length

}
