//
//  Plugin.swift
//  Adwaita
//
//  Created by david-swift on 02.09.26.
//

import PackagePlugin

/// The build tool plugin for generating the GTK/libadwaita widget wrappers.
@main
struct Plugin: BuildToolPlugin {

    /// Create the commands for generating the code.
    /// - Parameters:
    ///     - context: The plugin context.
    ///     - target: The target.
    /// - Returns: The commands.
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let outputFile = context.pluginWorkDirectoryURL.appending(path: "GeneratedWidgets.swift")
        let enumFile = context.pluginWorkDirectoryURL.appending(path: "GeneratedEnums.swift")
        return [
            .buildCommand(
                displayName: "Generating Widgets",
                executable: try context.tool(named: "WidgetGeneration").url,
                arguments: [outputFile.path, enumFile.path],
                inputFiles: [],
                outputFiles: [outputFile, enumFile]
            )
        ]
    }

}
