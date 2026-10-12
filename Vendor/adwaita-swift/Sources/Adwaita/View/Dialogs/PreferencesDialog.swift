//
//  PreferencesDialog.swift
//  Adwaita
//
//  Created by david-swift on 04.11.24.
//

import CAdw

/// The preferences dialog widget.
public struct PreferencesDialog: AdwaitaWidget {

    /// Whether the dialog is visible.
    @Binding var visible: Bool
    /// An identifier used if multiple dialogs are on one view.
    var id: String
    /// The settings dialog pages.
    var pages: [PreferencesPage] = []
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
    ///     - id: An unique identifier for dialogs on the view.
    init(
        visible: Binding<Bool>,
        child: AnyView,
        id: String
    ) {
        self._visible = visible
        self.child = child
        self.id = id
    }

    /// A preferences page.
    public struct PreferencesPage {

        /// The page's title.
        var title: String
        /// The page's icon.
        var icon: Icon
        /// The page content.
        var content: [PreferencesGroup] = []

        /// Initialize the preferences page.
        /// - Parameters:
        ///     - title: The page title.
        ///     - icon: The page's icon.
        init(_ title: String, icon: Icon) {
            self.title = title
            self.icon = icon
        }

        /// Get the GTK preferences page as well as the group's view storages.
        /// - Parameter data: The widget data.
        /// - Returns: The preferences page pointer and the groups view storages.
        func gtkPreferencesPage(data: WidgetData) -> (OpaquePointer?, [ViewStorage]) {
            let page = Adwaita.PreferencesPage()
                .title(title)
                .iconName(icon.string)
            let pageStorage = page.storage(data: data.noModifiers, type: AdwaitaMainView.self)
            page.update(pageStorage, data: data, updateProperties: true, type: AdwaitaMainView.self)
            let groups = content.map { item in
                let storage = item.gtkPreferencesGroup(data: data)
                item.update(group: storage, data: data, updateProperties: true)
                adw_preferences_page_add(pageStorage.opaquePointer?.cast(), storage.opaquePointer?.cast())
                return storage
            }
            return (pageStorage.opaquePointer, groups)
        }

        /// Update the page.
        /// - Parameters:
        ///     - groups: The groups' view storages.
        ///     - data: The widget data.
        ///     - updateProperties: Whether to update the properties.
        func update(groups: [ViewStorage], data: WidgetData, updateProperties: Bool) {
            for (index, storage) in groups.enumerated() {
                content[safe: index]?.update(group: storage, data: data, updateProperties: updateProperties)
            }
        }

        /// Add a preferences group.
        /// - Parameters:
        ///     - title: The group's title.
        ///     - description: The group's description.
        ///     - child: The view child.
        public func group(
            _ title: String,
            description: String = "",
            @ViewBuilder child: () -> Body
        ) -> Self {
            var newSelf = self
            newSelf.content.append(
                .init(
                    title: title,
                    description: description,
                    child: child()
                )
            )
            return newSelf
        }

    }

    /// The preferences group.
    struct PreferencesGroup {

        /// The group's title.
        var title: String
        /// The group's description.
        var description: String
        /// The group's child view.
        var child: Body

        /// Get the GTk preferences group.
        /// - Parameter data: The widget data.
        /// - Returns: The preferences group.
        func group(data: WidgetData) -> Adwaita.PreferencesGroup {
            .init()
                .title(title)
                .description(description)
                .child { child }
        }

        /// Get the GTK preferences group's storage.
        /// - Parameter data: The widget data.
        /// - Returns: The view storage.
        func gtkPreferencesGroup(data: WidgetData) -> ViewStorage {
            group(data: data).container(data: data.noModifiers, type: AdwaitaMainView.self)
        }

        /// Update the preferences group.
        /// - Parameters:
        ///     - group: The view storage.
        ///     - data: The widget data.
        ///     - updateProperties: Whether to update the properties.
        func update(group: ViewStorage, data: WidgetData, updateProperties: Bool) {
            self.group(data: data)
                .update(group, data: data, updateProperties: updateProperties, type: AdwaitaMainView.self)
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
        defer {
            if visible {
                for (index, page) in pages.enumerated() {
                    if let preferences = storage.content[.preferencesDialogIndex(index: index)] {
                        page.update(groups: preferences, data: data, updateProperties: updateProperties)
                    }
                }
            }
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
                for index in pages.indices {
                    let container = storage.content[.preferencesDialogIndex(index: index)]?.map { $0.opaquePointer }
                    container?.forEach { g_object_unref($0?.cast()) }
                    g_object_unref((storage.fields[.preferencesDialogIndex(index: index)] as? OpaquePointer)?.cast())
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
        let pointer = adw_preferences_dialog_new()
        adw_preferences_dialog_set_search_enabled(pointer?.cast(), 1)
        let dialog = ViewStorage(pointer?.opaque())
        storage.content[dialogID + id] = [dialog]
        dialog.connectSignal(name: "closed", type: .noArgs) {
            storage.content[dialogID + id] = []
            storage.content[contentID + id] = []
            if visible {
                visible = false
            }
        }
        for (index, page) in pages.map({ $0.gtkPreferencesPage(data: data) }).enumerated() {
            storage.content[.preferencesDialogIndex(index: index)] = page.1
            storage.fields[.preferencesDialogIndex(index: index)] = page.0
            adw_preferences_dialog_add(pointer?.cast(), page.0?.cast())
        }
    }

    /// Add a preferences page.
    /// - Parameters:
    ///     - title: The page title.
    ///     - icon: The page icon.
    ///     - content: Modify the preferences pages.
    public func preferencesPage(
        _ title: String,
        icon: Icon,
        content: (PreferencesPage) -> PreferencesPage
    ) -> Self {
        modify { $0.pages.append(content(.init(title, icon: icon))) }
    }

}
