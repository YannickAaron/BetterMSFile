//
//  Plugin.swift
//  Adwaita
//
//  Created by david-swift on 03.09.26.
//

import PackagePlugin

/// The build tool plugin for generating the CAdw API notes.
@main
struct Plugin: BuildToolPlugin {

    /// Create the commands for generating the notes.
    /// - Parameters:
    ///     - context: The plugin context.
    ///     - target: The target.
    /// - Returns: The commands.
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let inputFiles = target.sourceModule?.sourceFiles.filter(
            { file in
                file.url.lastPathComponent == "adwshim.h" ||
                file.url.lastPathComponent == "apinotes.txt" ||
                file.url.lastPathComponent == "module.txt"
            }
        )
        .sorted(by: { $0.url.lastPathComponent < $1.url.lastPathComponent }) else {
            return []
        }
        let lastComponents = ["adwshim.h", "CAdw.apinotes", "module.modulemap"]
        let outputFiles = lastComponents.map { context.pluginWorkDirectoryURL.appending(path: $0) }
        let arguments = outputFiles.map { $0.path } + inputFiles.map { $0.url.path }
        return [
            .buildCommand(
                displayName: "Generating API Notes",
                executable: try context.tool(named: "WidgetGeneration").url,
                arguments: arguments,
                inputFiles: inputFiles.map { $0.url },
                outputFiles: outputFiles
            )
        ]
    }

}
