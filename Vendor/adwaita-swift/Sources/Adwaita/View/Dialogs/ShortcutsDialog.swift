//
//  ShortcutsDialog.swift
//  Adwaita
//
//  Created by david-swift on 04.11.25.
//

import CAdw

/// The shortcuts dialog widget.
public struct ShortcutsDialog: AdwaitaWidget {

    /// Whether the dialog is visible.
    @Binding var visible: Bool
    /// An identifier used if multiple dialogs are on one view.
    var id: String
    /// The shortcuts dialog sections.
    var sections: [ShortcutsSection] = []
    /// The content.
    var child: AnyView

    /// The ID for the dialog's storage.
    let dialogID = "dialog"
    /// The ID for the content's storage.
    let contentID = "content"

    /// Initialize a dialog wrapper.
    /// - Parameters:
    ///     - visible: Whether the dialog is visible.
    ///     - child: The wrapped view.
    ///     - id: A unique identifier for dialogs on the view.
    init(
        visible: Binding<Bool>,
        child: AnyView,
        id: String
    ) {
        self._visible = visible
        self.child = child
        self.id = id
    }

    /// A shortcuts section.
    public struct ShortcutsSection {

        /// The section's title.
        var title: String?
        /// The section's content.
        var content: [ShortcutsItem] = []

        /// Initialize the shortcuts section.
        /// - Parameter title: The section's title.
        init(_ title: String?) {
            self.title = title
        }

        /// Get the GTK shortcuts section as well as the section's view storages.
        /// - Parameter data: The widget data.
        /// - Returns: The shortcuts section pointer and the section's view storages.
        func gtkShortcutsSection(data: WidgetData) -> (OpaquePointer?, [ViewStorage]) {
            let section = adw_shortcuts_section_new(title)
            let items = content.map { $0.gtkShortcutsItem(data: data) }
            for item in items {
                adw_shortcuts_section_add(section, item.opaquePointer)
            }
            return (section, items)
        }

        /// Add a shortcuts item.
        /// - Parameters:
        ///     - title: The item's title.
        ///     - accelerator: The shortcut acccelerator.
        public func shortcutsItem(
            _ title: String,
            accelerator: String
        ) -> Self {
            var newSelf = self
            newSelf.content.append(
                .init(
                    title: title,
                    accelerator: accelerator
                )
            )
            return newSelf
        }

    }

    /// The shortcuts item.
    struct ShortcutsItem {

        /// The item's title.
        var title: String
        /// The item's description.
        var accelerator: String

        /// Get the GTK preferences group's storage.
        /// - Parameter data: The widget data.
        /// - Returns: The view storage.
        func gtkShortcutsItem(data: WidgetData) -> ViewStorage {
            .init(adw_shortcuts_item_new(title, accelerator))
        }

    }

    /// The view storage.
    /// - Parameters:
    ///     - modifiers: Modify views before being updated.
    ///     - type: The view render data type.
    /// - Returns: The view storage.
    public func container<Data>(data: WidgetData, type: Data.Type) -> ViewStorage where Data: ViewRenderData {
        let child = child.storage(data: data, type: type)
        return .init(child.opaquePointer, content: [.mainContent: [child]])
    }

    /// Update the stored content.
    /// - Parameters:
    ///     - storage: The storage to update.
    ///     - modifiers: Modify views before being updated
    ///     - updateProperties: Whether to update the view's properties.
    ///     - type: The view render data type.
    public func update<Data>(
        _ storage: ViewStorage,
        data: WidgetData,
        updateProperties: Bool,
        type: Data.Type
    ) where Data: ViewRenderData {
        if let storage = storage.content[.mainContent]?.first {
            child.updateStorage(storage, data: data, updateProperties: updateProperties, type: type)
        }
        guard updateProperties else {
            return
        }
        if visible {
            if storage.content[dialogID + id]?.first == nil {
                createDialog(storage: storage, data: data, type: type)
                adw_dialog_present(
                    storage.content[dialogID + id]?.first?.opaquePointer?.cast(),
                    storage.opaquePointer?.cast()
                )
            }
        } else {
            if storage.content[dialogID + id]?.first != nil {
                let dialog = storage.content[dialogID + id]?.first?.opaquePointer
                adw_dialog_close(dialog?.cast())
                g_object_unref(dialog?.cast())
                for index in sections.indices {
                    let container = storage.content[.shortcutsDialogIndex(index: index)]?.map { $0.opaquePointer }
                    container?.forEach { g_object_unref($0?.cast()) }
                    g_object_unref((storage.fields[.shortcutsDialogIndex(index: index)] as? OpaquePointer)?.cast())
                }
            }
        }
    }

    /// Create a new instance of the dialog.
    /// - Parameters:
    ///     - storage: The wrapped view's storage.
    ///     - modifiers: The view modifiers.
    ///     - type: The view render data type.
    func createDialog<Data>(
        storage: ViewStorage,
        data: WidgetData,
        type: Data.Type
    ) where Data: ViewRenderData {
        let pointer = adw_shortcuts_dialog_new()
        let dialog = ViewStorage(pointer?.opaque())
        storage.content[dialogID + id] = [dialog]
        dialog.connectSignal(name: "closed", type: .noArgs) {
            storage.content[dialogID + id] = []
            storage.content[contentID + id] = []
            if visible {
                visible = false
            }
        }
        for (index, section) in sections.map({ $0.gtkShortcutsSection(data: data) }).enumerated() {
            storage.content[.shortcutsDialogIndex(index: index)] = section.1
            storage.fields[.shortcutsDialogIndex(index: index)] = section.0
            adw_shortcuts_dialog_add(pointer?.opaque(), section.0)
        }
    }

    /// Add a shortcuts section.
    /// - Parameters:
    ///     - title: The section's title or `nil`.
    ///     - content: Modify the shortcuts items.
    public func shortcutsSection(
        _ title: String? = nil,
        content: (ShortcutsSection) -> ShortcutsSection
    ) -> Self {
        modify { $0.sections.append(content(.init(title))) }
    }
}
