//
//  String.swift
//  Adwaita
//
//  Created by david-swift on 14.01.24.
//

nonisolated extension String: @retroactive CodingKey {

    /// The string.
    public var stringValue: String {
        self
    }

    /// A string cannot be represented as an integer.
    public var intValue: Int? {
        nil
    }

    /// Initialize from an int value.
    /// - Parameter intValue: The int value.
    public init?(intValue: Int) {
        nil
    }

    /// Initialize from a string value.
    /// - Parameter stringValue: The string value.
    public init?(stringValue: String) {
        self = stringValue
    }

    /// Generate a doc comment out of the string.
    /// - Parameters:
    ///     - configuration: The generation configuration.
    ///     - indent: Indentation added at the beginning of every line.
    /// - Returns: The comment.
    func docComment(configuration: GenerationConfiguration, indent: String = "") -> String {
        applyDocRegex(configuration: configuration)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .enumerated()
            .map { $0.offset == 0 ? $0.element.prefix(1).capitalized + $0.element.dropFirst() : $0.element }
            .map { "\(indent)/// \($0)" }
            .joined(separator: "\n")
    }

    /// Convert delimited to camel casing.
    /// - Parameters:
    ///     - delimiter: The demiliter.
    ///     - unshorten: Whether to unshorten.
    ///     - configuration: The generation configuration.
    /// - Returns: The string using camel casing.
    func convertDelimitedCasingToCamel(
        delimiter: Character,
        configuration: GenerationConfiguration,
        unshorten: Bool = false
    ) -> String {
        var parts = split(separator: delimiter).map(Self.init)
        for (index, part) in parts.enumerated() {
            if let replacement = configuration.unshorteningMap[part] {
                parts[index] = replacement
            }
        }
        let first = parts.removeFirst()
        return first + parts.map(\.capitalized).joined()
    }

    /// Convert a C type to its Swift equivalent using the generation configuration.
    /// - Parameter configuration: The generation configuration.
    /// - Returns: The Swift type.
    func convertCType(configuration: GenerationConfiguration) -> String {
        if let replacement = configuration.cTypeReplacements[self] {
            return replacement
        }
        var type = self
        if type.last == "*" {
            let pointeeType = String(type.dropLast()).convertCType(configuration: configuration)
            type = "UnsafeMutablePointer<\(pointeeType)>!"
        }
        return type
    }

    /// Apply the documentation regex.
    /// - Parameter configuration: The generation configuration.
    /// - Returns: The documentation with the regex applied.
    func applyDocRegex(configuration: GenerationConfiguration) -> String {
        var modified = self
        do {
            modified = try modified.applyExtraContentRegex()
            modified = try modified.applySimpleRegex()
            modified = try modified.applyPropertyRegex(configuration: configuration)
            modified = try modified.applyBooleanRegex()
            modified = try modified.applyHTMLRegex()
            modified = try modified.applyNoteRegex()
            return modified
        } catch {
            print("FAIL!")
            return modified
        }
    }

    /// Apply the regex to remove additional documentation content.
    /// - Returns: The documentation with the regex applied.
    func applyExtraContentRegex() throws -> String {
        let extraContent = try Regex("##?(.|\\n)*")
        return replacing(extraContent, with: "")
    }

    /// Translate simple definitions into Markdown inline code.
    /// - Returns: The documentation with the regex applied.
    func applySimpleRegex() throws -> String {
        let regex = try Regex("\\[(class|func|method|ctor|signal|const|iface)@(.*?)\\]")
        return replacing(regex) { match in
            "`\(match.output[2].substring ?? "")`"
        }
    }

    /// Translate property definitions into Swift references.
    /// - Parameter configuration: The generation configuration.
    /// - Returns: The documentation with the regex applied.
    func applyPropertyRegex(configuration: GenerationConfiguration) throws -> String {
        let property = try Regex("\\[property@(.*?)\\:(.*?)\\]")
        return replacing(property) { match in
            let method = String(match.output[2].substring ?? "")
                .convertDelimitedCasingToCamel(delimiter: "-", configuration: configuration, unshorten: true)
            return "``\(method)(_:)``"
        }
    }

    /// Translate booleans into inline Markdown code with Swift booleans.
    /// - Returns: The documentation with the regex applied.
    func applyBooleanRegex() throws -> String {
        var modified = self
        let `false` = try Regex("(`|%)FALSE`?")
        modified = modified.replacing(`false`, with: "`false`")
        let `true` = try Regex("(`|%)TRUE`?")
        modified = modified.replacing(`true`, with: "`true`")
        return modified
    }

    /// Remove broken HTML tags.
    /// - Returns: The documentation with the regex applied.
    func applyHTMLRegex() throws -> String {
        let picture = try Regex("<picture>.*?</picture>")
        return replacing(picture, with: "")
    }

    /// Interpret note/warning blocks.
    /// - Returns: The documentation with the regex applied.
    func applyNoteRegex() throws -> String {
        var modified = self
        let note = try Regex("::: note\\n((.|\\n)*?)(\\n\\n)?")
        modified = modified.replacing(note) { match in
            "> [!NOTE]\n> \(match.output[1].substring ?? "")"
        }
        let warning = try Regex("::: warning\\n((.|\\n)*?)(\\n\\n)?")
        modified = modified.replacing(warning) { match in
            "> [!WARNING]\n> \(match.output[1].substring ?? "")"
        }
        return modified
    }

}
