//
//  Generation.swift
//  Adwaita
//
//  Created by david-swift on 14.01.24.
//

import Foundation

/// The generation executable.
@main
struct Generation {

    /// The generation configuration.
    var configuration: GenerationConfiguration = .init()

    /// The static main function.
    static func main() throws {
        let generation = Self()
        try generation.run()
    }

    /// The main function.
    func run() throws {
        guard let gtkDefinitions = getGtkDefinitions(path: configuration.gtkGirFilePath) else {
            print("failed to get Gtk definitions")
            return
        }

        guard let adwDefinitions = getAdwDefinitions(path: configuration.adwGirFilePath) else {
            print("failed to get Adw definitions")
            return
        }
        if CommandLine.arguments.count > 3 {
            try apiNotes(gtk: gtkDefinitions, adw: adwDefinitions)
            return
        }
        var content = ""
        for `class` in gtkDefinitions.namespace.classes {
            if let config = configuration.gtkWidgets.first(where: { $0.class == `class`.name }) {
                content += getContent(
                    class: `class`,
                    config: config,
                    namespace: gtkDefinitions.namespace,
                    configs: configuration.gtkWidgets
                ) + "\n\n"
            }
        }
        for `class` in adwDefinitions.namespace.classes {
            if let config = configuration.adwWidgets.first(where: { $0.class == `class`.name }) {
                content += getContent(
                    class: `class`,
                    config: config,
                    namespace: adwDefinitions.namespace,
                    configs: configuration.adwWidgets
                ) + "\n\n"
            }
        }
        try write(content, to: CommandLine.arguments[1])
        try generateEnums(gtk: gtkDefinitions, adw: adwDefinitions)
    }

    /// Generate enumerations.
    func generateEnums(gtk: GIR, adw: GIR) throws {
        var content = ""
        for enumeration in gtk.namespace.enumerations + adw.namespace.enumerations {
            print("Generating enum \(enumeration.name)")
            content += enumeration.generate(genConfig: configuration) + "\n\n"
        }
        try write(content, to: CommandLine.arguments[2])
    }

    /// Generate the API notes.
    func apiNotes(gtk: GIR, adw: GIR) throws {
        print("Generating API Notes")
        var content = try String(contentsOf: .init(fileURLWithPath: CommandLine.arguments[5]), encoding: .utf8) + "\n"
        for enumeration in gtk.namespace.enumerations + adw.namespace.enumerations {
            content += enumeration.generateAPINote()
        }
        try write(content, to: CommandLine.arguments[2])
        // modulemap and shim.h (doesn't work otherwise)
        let map = try String(contentsOf: .init(fileURLWithPath: CommandLine.arguments[6]), encoding: .utf8)
        try write(map, to: CommandLine.arguments[3])
        let shim = try String(contentsOf: .init(fileURLWithPath: CommandLine.arguments[4]), encoding: .utf8)
        try write(shim, to: CommandLine.arguments[1])
    }

    /// Write a file.
    func write(_ content: String, to path: String) throws {
        let data = content.data(using: .utf8)
        try data?.write(to: URL(fileURLWithPath: path))
    }

    /// Get the definitions of a GIR file at a specified path.
    /// - Parameter path: The path.
    /// - Returns: The GIR data.
    func getGtkDefinitions(path: String) -> GIR? {
        var path = path
        let girDir = getGtkGirDir()
        path = path.replacingOccurrences(of: GenerationConfiguration.gtkIncludeDir, with: girDir)
        let data = (try? Data(contentsOf: .init(fileURLWithPath: path))) ?? .init()
        return try? GIR.decodeGIR(data)
    }

    /// Get the definitions of a GIR file at a specified path.
    /// - Parameter path: The path.
    /// - Returns: The GIR data.
    func getAdwDefinitions(path: String) -> GIR? {
        var path = path
        let girDir = getAdwGirDir()
        path = path.replacingOccurrences(of: GenerationConfiguration.adwIncludeDir, with: girDir)
        let data = (try? Data(contentsOf: .init(fileURLWithPath: path))) ?? .init()
        return try? GIR.decodeGIR(data)
    }

    /// Get the directory of the gir files.
    /// - Returns: The path.
    func getGtkGirDir() -> String {
        let process = Process()
        process.executableURL = .init(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "pkg-config --variable=includedir gtk4"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return .init(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Get the directory of the gir files.
    /// - Returns: The path.
    func getAdwGirDir() -> String {
        let process = Process()
        process.executableURL = .init(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "pkg-config --variable=includedir libadwaita-1"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return .init(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Create a file containing a class.
    /// - Parameters:
    ///     - class: The class.
    ///     - config: The widget configuration.
    ///     - namespace: The namespace.
    ///     - configs: All the available configs.
    func getContent(
        `class`: Class,
        config: WidgetConfiguration,
        namespace: Namespace,
        configs: [WidgetConfiguration]
    ) -> String {
        print("Generating widget \(config.name ?? `class`.name)")
        return `class`
            .generate(config: config, genConfig: configuration, namespace: namespace, configs: configs)
    }

}
