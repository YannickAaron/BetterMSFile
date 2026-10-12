//
//  Enumeration.swift
//  Adwaita
//
//  Created by david-swift on 04.09.26.
//

import Foundation

/// An enumeration.
struct Enumeration: Decodable {

    /// The enumeration's name.
    var name: String
    /// The type in C.
    var cType: String
    /// The doc string.
    var doc: String?
    /// The enumeration's members (cases).
    var member: [Member]

    /// Only the non-deprecated members.
    var nonDeprecated: [Member] {
        member.filter { $0.docDeprecated == nil }
    }

    /// An enumeration case.
    struct Member: Decodable {

        /// Enum cases with these names are wrapped into "`".
        static let exceptions = [
            "default", "import", "true", "false", "switch"
        ]

        /// The enumeration case's name.
        var name: String
        /// The identifier in C.
        var cIdentifier: String
        /// The doc string.
        var doc: String?
        /// The doc for deprecated members.
        var docDeprecated: String?

        /// Get the Swift member name.
        /// - Parameter configuration: The generation configuration.
        /// - Returns: The name.
        func convertMemberName(configuration: GenerationConfiguration) -> String {
            let camel = name
                .convertDelimitedCasingToCamel(delimiter: "_", configuration: configuration, unshorten: true)
            if name.first?.isNumber == true
            || Self.exceptions.contains(name) {
                return "`\(camel)`"
            } else {
                return camel
            }
        }

    }

    /// Generate the Swift type definition for an enumeration.
    /// - Parameter genConfig: The configuration.
    /// - Returns: The definition.
    func generate(genConfig: GenerationConfiguration) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yy"
        return """
        //
        //  \(name).swift
        //  Adwaita
        //
        //  Created by auto-generation on \(dateFormatter.string(from: .init())).
        //

        import CAdw

        \(doc?.docComment(configuration: genConfig) ?? "/// An enumeration.")
        nonisolated
        public enum \(name): CaseIterable {

        \(generateCases(genConfig: genConfig))
            /// The representation as its corresponding GLib type.
            var gtkValue: \(cType) {
                switch self {

        \(generateSwitchCases(genConfig: genConfig))
                }
            }
        }
        """
    }

    /// Generate the cases for the type definition.
    func generateCases(genConfig: GenerationConfiguration) -> String {
        var content = ""
        for member in nonDeprecated {
            content += """

            \(member.doc?.docComment(configuration: genConfig, indent: "    ") ?? "/// An enumeration case.")
                case \(member.convertMemberName(configuration: genConfig))

            """
        }
        return content
    }

    /// Generate the cases for the `switch` expression in `gtkValue`.
    func generateSwitchCases(genConfig: GenerationConfiguration) -> String {
        var content = ""
        for member in nonDeprecated {
            content += """
                    case .\(member.convertMemberName(configuration: genConfig)): .\(member.cIdentifier)

            """
        }
        return content
    }

    /// Generate the content for the API notes file.
    func generateAPINote() -> String {
        """
        - Name: \(cType)
          EnumExtensibility: closed

        """
    }

}
