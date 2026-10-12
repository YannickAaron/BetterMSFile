//
//  FileDialog.swift
//  Adwaita
//
//  Created by david-swift on 12.08.24.
//

import CAdw
import Foundation

/// A structure representing a file dialog window.
struct FileDialog: AdwaitaWidget {

    /// The dialog type.
    var type: DialogType
    /// Whether the dialog should open.
    var open: Binding<Signal>
    /// The dialog's child.
    var child: AnyView
    /// The initial folder.
    var initialFolder: URL?
    /// The title of the dialog.
    var title: String?
    /// The label shown on the accept button.
    var acceptLabel: String?
    /// The closure to run when the import or export is successful.
    var result: (URL) -> Void
    /// The closure to run when the import or export is not successful.
    var cancel: () -> Void

    /// Initialize the file dialog wrapper.
    /// - Parameters:
    ///     - type: The dialog type.
    ///     - open: The signal.
    ///     - child: The wrapped view.
    ///     - result: Run when the import or export succeeds.
    ///     - cancel: Run when the import or export is not successful.
    ///     - initialFolder: The initial folder.
    ///     - title: The title of the dialog.
    ///     - acceptLabel: The label shown on the accept button.
    init(
        type: DialogType,
        `open`: Binding<Signal>,
        child: AnyView,
        result: @escaping (URL) -> Void,
        cancel: @escaping () -> Void,
        initialFolder: URL? = nil,
        title: String? = nil,
        acceptLabel: String? = nil
    ) {
        self.type = type
        self.open = open
        self.child = child
        self.result = result
        self.cancel = cancel
        self.initialFolder = initialFolder
        self.title = title
        self.acceptLabel = acceptLabel
    }

    /// The different types of dialogs and their properties.
    enum DialogType {

        /// An importer dialog.
        case importer(folder: Bool, filters: [FileDialogFilter]?)
        /// An exporter dialog.
        case exporter(initialName: String?)

        /// Whether the dialog is an importer.
        var isImporter: Bool {
            switch self {
            case .importer:
                true
            default:
                false
            }
        }

        /// The optional file filters
        var filters: [FileDialogFilter]? {
            switch self {
            case let .importer(folder: _, filters: filters):
                filters
            default:
                nil
            }
        }

        /// Whether to import folders.
        var folder: Bool {
            switch self {
            case let .importer(folder: folder, filters: _):
                folder
            default:
                false
            }
        }

        /// The initial name.
        var initialName: String? {
            switch self {
            case let .exporter(initialName: initialName):
                initialName
            default:
                nil
            }
        }

    }

    /// The view storage.
    /// - Parameters:
    ///     - modifiers: Modify views before being updated.
    ///     - type: The view render data type.
    /// - Returns: The view storage.
    func container<Data>(data: WidgetData, type: Data.Type) -> ViewStorage where Data: ViewRenderData {
        let child = child.storage(data: data, type: type)
        return .init(child.opaquePointer, content: [.mainContent: [child]])
    }

    /// Update the stored content.
    /// - Parameters:
    ///     - storage: The storage to update.
    ///     - modifiers: Modify views before being updated
    ///     - updateProperties: Whether to update the view's properties.
    ///     - type: The view render data type.
    func update<Data>(
        _ storage: ViewStorage,
        data: WidgetData,
        updateProperties: Bool,
        type: Data.Type
    ) where Data: ViewRenderData {
        storage.fields[.dialogResult] = result
        storage.fields[.dialogCancel] = cancel
        guard let mainStorage = storage.content[.mainContent]?.first else {
            return
        }
        child.updateStorage(mainStorage, data: data, updateProperties: updateProperties, type: type)
        data.stateManager.withBlockedUpdates {
            if open.wrappedValue.update, storage.fields[.callbacks] == nil {
                showDialog(storage, data: data)
            }
        }
    }

    /// Show the dialog.
    /// - Parameters:
    ///     - storage: The view storage.
    ///     - data: The view data.
    func showDialog(_ storage: ViewStorage, data: WidgetData) {
        var unref: [OpaquePointer?] = []
        let pointer = gtk_file_dialog_new()
        unref.append(pointer)
        if let initialName = self.type.initialName {
            gtk_file_dialog_set_initial_name(pointer, initialName)
        }
        if let filters = self.type.filters {
            setFilters(pointer, filters: filters, unref: &unref)
        }
        if let initialFolder {
            let file = g_file_new_for_path(initialFolder.path)
            gtk_file_dialog_set_initial_folder(pointer, file)
            unref.append(file)
        }
        if let title {
            gtk_file_dialog_set_title(pointer, title)
        }
        if let acceptLabel {
            gtk_file_dialog_set_accept_label(pointer, acceptLabel)
        }
        let callbacks = AdwaitaFileDialog()
        let unrefClosure = {
            for ref in unref {
                g_object_unref(ref?.cast())
            }
            storage.fields[.callbacks] = nil
        }
        callbacks.onResult = { (storage.fields[.dialogResult] as? (URL) -> Void)?($0); unrefClosure() }
        callbacks.onCancel = { (storage.fields[.dialogCancel] as? () -> Void)?(); unrefClosure() }
        callbacks.reset = { storage.fields[.callbacks] = nil }
        storage.fields[.callbacks] = callbacks
        let windowPointer = (data.sceneStorage.pointer as? AdwaitaWindow)?.pointer
        let window: UnsafeMutablePointer<GtkWindow>? = windowPointer?.cast()
        let data = UnsafeMutableRawPointer(bitPattern: unsafeBitCast(callbacks, to: UInt.self))
        if self.type.isImporter && self.type.folder {
            gtui_filedialog_open_folder(pointer, data, window)
        } else if self.type.isImporter {
            gtui_filedialog_open(pointer, data, window)
        } else {
            gtui_filedialog_save(pointer, data, window)
        }
    }

    /// Assign the filters to the dialog.
    /// - Parameters:
    ///     - dialog: The file dialog.
    ///     - filters: The filters.
    ///     - unref: A list storing the objects to g_object_unref.
    func setFilters(_ dialog: OpaquePointer?, filters: [FileDialogFilter], unref: inout [OpaquePointer?]) {
        let filterStore: OpaquePointer? = g_list_store_new(gtk_file_filter_get_type())
        for filter in filters {
            let fileFilter = gtk_file_filter_new()
            switch filter {
            case let .extensions(extensions, name):
                for fileExtension in extensions {
                    gtk_file_filter_add_suffix(fileFilter, fileExtension)
                }
                if let name {
                    gtk_file_filter_set_name(fileFilter, name)
                }
            case let .mimeType(mimeType, name):
                gtk_file_filter_add_mime_type(fileFilter, mimeType)
                if let name {
                    gtk_file_filter_set_name(fileFilter, name)
                }
            }
            g_list_store_append(filterStore, fileFilter?.cast())
            unref.append(fileFilter)
        }
        gtk_file_dialog_set_filters(dialog, filterStore)
        unref.append(filterStore)
    }

}

/// Filter options for the file dialog 
public enum FileDialogFilter {
    /// Filter by file extensions
    case extensions([String], name: String? = nil)
    /// Filter by mime type
    case mimeType(String, name: String? = nil)
    /// The optional name of the filter
    var name: String? {
        switch self {
        case let .extensions(_, name):
            name
        case let .mimeType(_, name):
            name
        }
    }
}

/// An Adwaita file dialog window callback.
class AdwaitaFileDialog {

    /// A closure triggered on selecting a file in the dialog.
    var onResult: (URL) -> Void = { _ in }
    /// A closure triggered when the dialog is canceled.
    var onCancel: () -> Void = { }
    /// Reset the file dialog.
    var reset: () -> Void = { }

    /// Initialize the window callback.
    init() { }

    /// Run this when a file gets opened.
    /// - Parameter path: The file path.
    func onOpen(_ path: String) {
        let url = URL(fileURLWithPath: path)
        onResult(url)
        reset()
    }

    /// Run this when a file gets saved.
    /// - Parameter path: The file path.
    func onSave(_ path: String) {
        let url = URL(fileURLWithPath: path)
        onResult(url)
        reset()
    }

    /// Run this when the user cancels the action.
    func onClose() {
        onCancel()
        reset()
    }

}

/// Run when a file should be opened.
/// - Parameters:
///   - ptr: The pointer.
///   - file: The path to the file.
///   - userData: The file dialog data.
@_cdecl("filedialog_on_open_cb")
func filedialog_on_open_cb(
    ptr: UnsafeMutableRawPointer,
    file: UnsafePointer<CChar>?,
    userData: UnsafeMutableRawPointer
) {
    let dialog = Unmanaged<AdwaitaFileDialog>.fromOpaque(userData).takeUnretainedValue()
    if let file {
        dialog.onOpen(.init(cString: file))
    } else {
        dialog.onClose()
    }
}

/// Run when a file should be saved.
/// - Parameters:
///   - ptr: The pointer.
///   - file: The path to the file.
///   - userData: The file dialog data.
@_cdecl("filedialog_on_save_cb")
func filedialog_on_save_cb(
    ptr: UnsafeMutableRawPointer,
    file: UnsafePointer<CChar>?,
    userData: UnsafeMutableRawPointer
) {
    let dialog = Unmanaged<AdwaitaFileDialog>.fromOpaque(userData).takeUnretainedValue()
    if let file {
        dialog.onSave(.init(cString: file))
    } else {
        dialog.onClose()
    }
}
