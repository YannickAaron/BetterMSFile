//
//  FlowBox+.swift
//  Adwaita
//
//  Created by david-swift on 12.02.24.
//

import CAdw

extension FlowBox {

    /// The ID for the field storing the selection value.
    static var selectionField: String { "selection" }
    /// The ID for the field storing the elements.
    static var elementsField: String { "element" }

    /// Initialize `FlowBox`.
    /// - Parameters:
    ///   - elements: The elements.
    ///   - id: The element identifier keypath.
    ///   - selection: The identifier of the selected element. Selection disabled if `nil`.
    ///   - content: The view for an element.
    public init(
        _ elements: [Element],
        id: KeyPath<Element, Identifier>,
        selection: Binding<Identifier>? = nil,
        @ViewBuilder content: @escaping (Element) -> Body
    ) {
        self.init(elements, id: id, content: content)
        let getID: (ViewStorage, [Element]) -> Identifier? = { storage, elements in
            if let child = g_list_nth_data(gtk_flow_box_get_selected_children(storage.opaquePointer), 0) {
                let element = gtk_flow_box_child_get_child(child.cast())
                return elements[safe: storage.content[.mainContent]?
                    .firstIndex { $0.opaquePointer?.cast() == element }]?[keyPath: id]
            }
            return nil
        }
        if let selection {
            updateFunctions.append { storage, _, _ in
                storage.connectSignal(name: "selected_children_changed", id: Self.selectionField, type: .noArgs) {
                    if let elements = storage.fields[Self.elementsField] as? [Element],
                    let id = getID(storage, elements) {
                        selection.wrappedValue = id
                    }
                }
                if selection.wrappedValue != getID(storage, elements),
                let index = elements.firstIndex(where: { $0[keyPath: id] == selection.wrappedValue })?.cInt {
                    gtk_flow_box_select_child(
                        storage.opaquePointer,
                        gtk_flow_box_get_child_at_index(storage.opaquePointer, index)
                    )
                }
            }
        } else {
            appearFunctions.append { storage, _ in
                gtk_flow_box_set_selection_mode(storage.opaquePointer, .GTK_SELECTION_NONE)
            }
        }
    }

}

extension FlowBox where Element: Identifiable, Identifier == Element.ID {

    /// Initialize `FlowBox`.
    /// - Parameters:
    ///   - elements: The elements.
    ///   - selection: The identifier of the selected element. Selection disabled if `nil`.
    ///   - content: The view for an element.
    public init(
        _ elements: [Element],
        selection: Binding<Element.ID>? = nil,
        @ViewBuilder content: @escaping (Element) -> Body
    ) {
        self.init(elements, id: \.id, selection: selection, content: content)
    }

}
