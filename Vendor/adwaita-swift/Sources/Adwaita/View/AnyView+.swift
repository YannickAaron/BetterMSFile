//
//  AnyView+.swift
//  Adwaita
//
//  Created by david-swift on 16.10.24.
//

import CAdw
import Foundation

extension AnyView {

    /// Add an about dialog to the parent window.
    /// - Parameters:
    ///     - visible: Whether the dialog is presented.
    ///     - app: The app's name.
    ///     - developer: The developer's name.
    ///     - version: The version string.
    ///     - icon: The app icon.
    ///     - details: Details of the app.
    ///     - links: Links.
    public func aboutDialog(
        visible: Binding<Bool>,
        app: String? = nil,
        developer: String? = nil,
        version: String? = nil,
        icon: Icon? = nil,
        details: [AboutDialogDetail]? = nil,
        links: [AboutDialogLink]? = nil
    ) -> AnyView {
        AboutDialog(
            visible: visible,
            child: self,
            appName: app,
            developer: developer,
            version: version,
            icon: icon,
            details: details,
            links: links
        )
    }

    /// Add an alert dialog to the parent window.
    /// - Parameters:
    ///     - visible: Whether the dialog is presented.
    ///     - heading: The heading.
    ///     - body: The body text.
    ///     - id: An optional identifier.
    ///     - extraChild: A view with custom content.
    public func alertDialog(
        visible: Binding<Bool>,
        heading: String,
        body: String = "",
        id: String? = nil
    ) -> AlertDialog {
        .init(
            visible: visible,
            child: self,
            id: id ?? "no-id",
            heading: heading,
            body: body
        )
    }

    /// Add an alert dialog to the parent window.
    /// - Parameters:
    ///     - visible: Whether the dialog is presented.
    ///     - heading: The heading.
    ///     - body: The body text.
    ///     - id: An optional identifier.
    ///     - extraChild: A view with custom content.
    public func alertDialog(
        visible: Binding<Bool>,
        heading: String,
        body: String = "",
        id: String? = nil,
        @ViewBuilder extraChild: () -> Body
    ) -> AlertDialog {
        .init(
            visible: visible,
            child: self,
            id: id ?? "no-id",
            heading: heading,
            body: body,
            extraChild: extraChild()
        )
    }

    /// Add a dialog to the parent window.
    /// - Parameters:
    ///     - visible: Whether the dialog is presented.
    ///     - title: The dialog's title.
    ///     - width: The dialog's width.
    ///     - height: The dialog's height.
    ///     - content: The dialog's content.
    public func dialog(
        visible: Binding<Bool>,
        title: String? = nil,
        id: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        @ViewBuilder content: () -> Body
    ) -> AnyView {
        Dialog(
            visible: visible,
            child: self,
            id: id ?? "",
            content: content(),
            title: title,
            width: width,
            height: height
        )
    }

    /// Add a preferences dialog to the parent window.
    /// - Parameters:
    ///     - visible: Whether the dialog is presented.
    ///     - id: The dialog's id.
    /// - Returns: The view.
    public func preferencesDialog(
        visible: Binding<Bool>,
        id: String? = nil
    ) -> PreferencesDialog {
        .init(
            visible: visible,
            child: self,
            id: id ?? ""
        )
    }

    /// Add a shortcuts dialog to the parent window.
    /// - Parameters:
    ///     - visible: Whether the dialog is presented.
    ///     - id: The dialog's id.
    /// - Returns: The view.
    public func shortcutsDialog(
        visible: Binding<Bool>,
        id: String? = nil
    ) -> ShortcutsDialog {
        .init(
            visible: visible,
            child: self,
            id: id ?? ""
        )
    }

    /// Create an importer file dialog.
    /// - Parameters:
    ///     - open: The signal to open the dialog.
    ///     - initialFolder: The URL to the folder open when being opened.
    ///     - filters: Optional file filters.
    ///     - title: The title of the dialog.
    ///     - acceptLabel: The label shown on the accept button.
    ///     - onOpen: Run this when a file for importing has been chosen.
    ///     - onClose: Run this when the user cancelled the action.
    public func fileImporter(
        open: Binding<Signal>,
        initialFolder: URL? = nil,
        filters: [FileDialogFilter]? = nil,
        title: String? = nil,
        acceptLabel: String? = nil,
        onOpen: @escaping (URL) -> Void,
        onClose: @escaping () -> Void = { }
    ) -> AnyView {
        FileDialog(
            type: .importer(folder: false, filters: filters),
            open: open,
            child: self,
            result: onOpen,
            cancel: onClose,
            initialFolder: initialFolder,
            title: title,
            acceptLabel: acceptLabel
        )
    }

    /// Create an importer file dialog for folders.
    /// - Parameters:
    ///     - open: The signal to open the dialog.
    ///     - initialFolder: The URL to the folder open when being opened.
    ///     - title: The title of the dialog.
    ///     - acceptLabel: The label shown on the accept button.
    ///     - onOpen: Run this when a file for importing has been chosen.
    ///     - onClose: Run this when the user cancelled the action.
    public func folderImporter(
        open: Binding<Signal>,
        initialFolder: URL? = nil,
        title: String? = nil,
        acceptLabel: String? = nil,
        onOpen: @escaping (URL) -> Void,
        onClose: @escaping () -> Void = { }
    ) -> AnyView {
        FileDialog(
            type: .importer(folder: true, filters: nil),
            open: open,
            child: self,
            result: onOpen,
            cancel: onClose,
            initialFolder: initialFolder,
            title: title,
            acceptLabel: acceptLabel
        )
    }

    /// Create an exporter file dialog.
    /// - Parameters:
    ///     - exporter: The signal to open the dialog.
    ///     - initialFolder: The URL to the folder open when being opened.
    ///     - initialName: The default file name.
    ///     - title: The title of the dialog.
    ///     - acceptLabel: The label shown on the accept button.
    ///     - onSave: Run this when a path for exporting has been chosen.
    ///     - onClose: Run this when the user cancelled the action.
    public func fileExporter(
        open: Binding<Signal>,
        initialFolder: URL? = nil,
        initialName: String? = nil,
        title: String? = nil,
        acceptLabel: String? = nil,
        onSave: @escaping (URL) -> Void,
        onClose: @escaping () -> Void = { }
    ) -> AnyView {
        FileDialog(
            type: .exporter(initialName: initialName),
            open: open,
            child: self,
            result: onSave,
            cancel: onClose,
            initialFolder: initialFolder,
            title: title,
            acceptLabel: acceptLabel
        )
    }

    /// Add a popover on top of the view.
    /// - Parameters:
    ///     - visible: Whether the popover is displayed.
    ///     - content: The popover's content.
    /// - Returns: The view.
    public func popover(visible: Binding<Bool>, @ViewBuilder content: @escaping () -> Body) -> Overlay {
        overlay {
            Popover(visible: visible)
                .child(content)
        }
    }

    /// Add a menu popover on top of the view.
    /// - Parameters:
    ///     - visible: Whether the popover is displayed.
    ///     - content: The popover's menu content.
    /// - Returns: The view.
    public func menuPopover(visible: Binding<Bool>, @ViewBuilder content: @escaping () -> Body) -> Overlay {
        overlay {
            PopoverMenu(visible: visible)
                .menuModel(content)
        }
    }

    /// Set the view's maximum width.
    /// - Parameter maxWidth: The maximum width.
    /// - Returns: A view.
    public func frame(maxWidth: Int? = nil) -> Clamp {
        .init()
            .child { self }
            .maximumSize(maxWidth ?? -1)
    }

    /// Set the view's maximum height.
    /// - Parameter maxHeight: The maximum height.
    /// - Returns: A view.
    public func frame(maxHeight: Int? = nil) -> Clamp {
        .init(orientation: .vertical)
            .child { self }
            .maximumSize(maxHeight ?? -1)
    }

    /// Present a toast when the signal gets activated.
    /// - Parameters:
    ///     - title: The title of the toast.
    ///     - signal: The signal which activates the presentation of a toast.
    /// - Returns: A view.
    public func toast(_ title: String, signal: Binding<Signal>) -> ToastOverlay {
        .init(title, signal: signal)
            .child { self }
    }

    /// Present a toast with a button when the signal gets activated.
    /// - Parameters:
    ///     - title: The title of the toast.
    ///     - signal: The signal which activates the presentation of a toast.
    ///     - button: The button's label.
    ///     - handler: The handler for the button.
    /// - Returns: A view.
    public func toast(
        _ title: String,
        signal: Binding<Signal>,
        button: String,
        handler: @escaping () -> Void
    ) -> ToastOverlay {
        .init(title, signal: signal)
            .child { self }
            .action(button: button, handler: handler)
    }

    /// Add a breakpoint.
    /// - Parameters:
    ///     - maxWidth: The maximum width.
    ///     - matches: Whether the content view matches the breakpoint.
    public func breakpoint(maxWidth: Int, matches: Binding<Bool>) -> AnyView {
        BreakpointBin(condition: .maxWidth(maxWidth), matches: matches) { self }
    }

    /// Add a breakpoint.
    /// - Parameters:
    ///     - minWidth: The minimum width.
    ///     - matches: Whether the content view matches the breakpoint.
    public func breakpoint(minWidth: Int, matches: Binding<Bool>) -> AnyView {
        BreakpointBin(condition: .minWidth(minWidth), matches: matches) { self }
    }

    /// Add a breakpoint.
    /// - Parameters:
    ///     - maxHeight: The maximum height.
    ///     - matches: Whether the content view matches the breakpoint.
    public func breakpoint(maxHeight: Int, matches: Binding<Bool>) -> AnyView {
        BreakpointBin(condition: .maxHeight(maxHeight), matches: matches) { self }
    }

    /// Add a breakpoint.
    /// - Parameters:
    ///     - minHeight: The minimum height.
    ///     - matches: Whether the content view matches the breakpoint.
    public func breakpoint(minHeight: Int, matches: Binding<Bool>) -> AnyView {
        BreakpointBin(condition: .minHeight(minHeight), matches: matches) { self }
    }

    /// Build the UI from scratch once the identifier changes.
    /// - Parameter id: The identifier.
    public func id(_ id: CustomStringConvertible) -> AnyView {
        ViewStack(id: id) { _ in self }
            .limitChildren()
    }

    /// Run a function when the widget gets clicked.
    /// - Parameter handler: The function.
    /// - Returns: A view.
    public func onClick(handler: @escaping () -> Void) -> AnyView {
        onClick { _, _ in handler() }
    }

    /// Run a function when the widget gets clicked.
    /// - Parameter handler: The function. The parameters are the x and y coordinates of the click.
    /// - Returns: A view.
    public func onClick(handler: @escaping (Double, Double) -> Void) -> AnyView {
        inspectOnAppear { storage in
            let controller = ViewStorage(gtk_gesture_click_new())
            gtk_widget_add_controller(storage.opaquePointer?.cast(), controller.opaquePointer)
            storage.fields[.clickController] = controller
            controller.connectSignal(name: "released", type: .pointerDoubleDouble) { args in
                if let handler = storage.fields[.clickHandler] as? (Double, Double) -> Void {
                    handler(args[1] as? Double ?? 0, args[2] as? Double ?? 0)
                }
            }
        }
        .inspect { storage, _, updateProperties in
            if updateProperties {
                storage.fields[.clickHandler] = handler
            }
        }
    }

    /// Overlay a bottom sheet with a bottom bar.
    /// - Parameters:
    ///     - title: The content.
    ///     - visible: Whether the banner is visible.
    public func bottomSheet(
        @ViewBuilder sheet: () -> Body,
        @ViewBuilder bottomBar: () -> Body
    ) -> BottomSheet {
        .init()
            .content { self }
            .sheet(sheet)
            .bottomBar(bottomBar)
    }

    /// Overlay a bottom sheet.
    /// - Parameters:
    ///     - title: The content.
    ///     - visible: Whether the banner is visible.
    public func bottomSheet(
        @ViewBuilder sheet: () -> Body
    ) -> BottomSheet {
        .init()
            .content { self }
            .sheet(sheet)
    }

    /// Make a Widget accept dropped files.
    /// - Parameters:
    ///   - filter: The optional filter.
    ///   - handler: The handler for the dropped files.
    /// - Returns: A view.
    public func fileDropTarget(filter: FileDialogFilter? = nil, handler: @escaping ([URL]?) -> Void) -> AnyView {
        inspectOnAppear { storage in
            let controller = ViewStorage(gtk_drop_target_new(gdk_file_list_get_type(), .GDK_ACTION_COPY))
            gtk_widget_add_controller(storage.opaquePointer?.cast(), controller.opaquePointer)
            storage.fields[.dropTargetController] = controller
            controller.connectSignal(name: "drop", type: .pointerDoubleDouble) { args in
                guard let pointer = args.first as? UnsafeRawPointer else {
                    return
                }
                if let handler = storage.fields[.dropTargetHandler] as? ([URL]?) -> Void {
                    handler(FileDropTarget.handleDroppedFiles(pointer, filter: filter))
                }
            }
            if let name = filter?.name {
                gtk_widget_set_tooltip_markup(storage.opaquePointer?.cast(), name)
            }
        }
        .inspect { storage, _, updateProperties in
            if updateProperties {
                storage.fields[.dropTargetHandler] = handler
            }
        }
    }

}
