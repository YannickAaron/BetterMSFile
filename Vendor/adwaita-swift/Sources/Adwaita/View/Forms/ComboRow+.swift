//
//  ComboRow+.swift
//  Adwaita
//
//  Created by david-swift on 20.01.24.
//

import CAdw
import LevenshteinTransformations

/// A row for selecting an element out of a list of elements.
extension ComboRow {

    /// The identifier for the values.
    static var values: String { "values" }
    /// The identifier for the string list.
    static var stringList: String { "string-list" }

    /// Initialize a combo row.
    /// - Parameters:
    ///     - title: The row's title.
    ///     - selection: The selected value.
    ///     - values: The available values.
    public init<Element>(
        _ title: String,
        selection: Binding<Element.ID>,
        values: [Element]
    ) where Element: Identifiable, Element: CustomStringConvertible {
        self.init(title, selection: selection, values: values, id: \.id, description: \.description)
    }

    /// Initialize a combo row.
    /// - Parameters:
    ///     - title: The row's title.
    ///     - selection: The selected value.
    ///     - values: The available values.
    public init<Element, Identifier>(
        _ title: String,
        selection: Binding<Identifier>,
        values: [Element],
        id: KeyPath<Element, Identifier>,
        description: KeyPath<Element, String>
    ) where Identifier: Equatable {
        self = self.title(title)
        self = self.selected(.init {
            .init(values.firstIndex { $0[keyPath: id] == selection.wrappedValue } ?? 0)
        } set: { index in
            if let id = values[safe: .init(index)]?[keyPath: id] {
                selection.wrappedValue = id
            }
        })
        appearFunctions.append { storage, _ in
            let list = gtk_string_list_new(nil)
            storage.fields[Self.stringList] = list
            adw_combo_row_set_model(storage.opaquePointer?.cast(), list)
            g_object_unref(list?.cast())
            DropDown.updateContent(storage: storage, values: values, id: id, description: description)
        }
        updateFunctions.append { storage, _, _ in
            DropDown.updateContent(storage: storage, values: values, id: id, description: description)
        }
    }

}
