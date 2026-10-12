//
//  ToggleGroup+.swift
//  Adwaita
//
//  Created by david-swift on 03.11.25.
//

import CAdw
import LevenshteinTransformations

extension ToggleGroup {

    /// The identifier for the values.
    static var values: String { "values" }
    /// The identifier for the toggles.
    static var toggle: String { "Toggle::" }

    /// Initialize a toggle group.
    /// - Parameters:
    ///     - selection: The selected value.
    ///     - values: The available values.
    public init<Element>(
        selection: Binding<Element.ID>,
        values: [Element]
    ) where Element: ToggleGroupItem {
        self.init(
            selection: selection,
            values: values,
            id: \.id,
            label: \.id.description,
            icon: \.icon,
            showLabel: \.showLabel
        )
    }

    /// Initialize a toggle group.
    /// - Parameters:
    ///     - selection: The selected value.
    ///     - values: The available values.
    ///     - id: The path to the identifier.
    ///     - label: The path to the label.
    ///     - icon: The path to the icon.
    ///     - showLabel: The path to the boolean that defines whether to show an element's label.
    public init<Element, Identifier>(
        selection: Binding<Identifier>,
        values: [Element],
        id: KeyPath<Element, Identifier>,
        label: KeyPath<Element, String>,
        icon: KeyPath<Element, Icon?>? = nil,
        showLabel: KeyPath<Element, Bool>? = nil
    ) where Identifier: Equatable {
        self.init()
        appearFunctions.append { storage, _ in
            storage.notify(name: "active-name", id: "init") {
                if let name = adw_toggle_group_get_active_name(storage.opaquePointer),
                let values = storage.fields[Self.values] as? [Element],
                let identifier = values
                    .map({ $0[keyPath: label] }).first(where: { $0.description == String(cString: name) }),
                let value = values.first(where: { $0[keyPath: label] == identifier }) {
                    selection.wrappedValue = value[keyPath: id]
                }
            }
        }
        updateFunctions.append { storage, _, updateProperties in
            Self.updateContent(
                storage: storage,
                selection: selection.wrappedValue,
                values: values,
                id: id,
                label: label,
                icon: icon,
                showLabel: showLabel,
                updateProperties: updateProperties
            )
        }
    }

    // swiftlint:disable function_parameter_count
    /// Update the combo row's content.
    static func updateContent<Element, Identifier>(
        storage: ViewStorage,
        selection: Identifier,
        values: [Element],
        id: KeyPath<Element, Identifier>,
        label: KeyPath<Element, String>,
        icon: KeyPath<Element, Icon?>?,
        showLabel: KeyPath<Element, Bool>?,
        updateProperties: Bool
    ) where Identifier: Equatable {
        guard updateProperties else {
            return
        }
        let old = storage.fields[Self.values] as? [Element] ?? []
        old.transform(
            to: values,
            id: id,
            functions: .init { index in
                if let id = old[safe: index]?[keyPath: label],
                let toggle = storage.fields[Self.toggle + id] as? OpaquePointer {
                    adw_toggle_group_remove(storage.opaquePointer, toggle)
                }
            } insert: { _, element in
                let toggle = adw_toggle_new()
                adw_toggle_set_name(toggle, element[keyPath: label])
                let showLabel: Bool? = if let showLabel {
                    element[keyPath: showLabel]
                } else {
                    nil
                }
                setShowLabel(showLabel, toggle: toggle, label: element[keyPath: label])
                if let icon, let icon = element[keyPath: icon] {
                    adw_toggle_set_icon_name(toggle, icon.string)
                }
                storage.fields[Self.toggle + element[keyPath: label]] = toggle
                adw_toggle_group_add(storage.opaquePointer, toggle)
            }
        )
        storage.fields[Self.values] = values
        if let selection = values.first(where: { $0[keyPath: id] == selection }) {
            adw_toggle_group_set_active_name(storage.opaquePointer, selection[keyPath: label])
        }
        let previousShowLabel = storage.fields["previous-show-label"] as? Bool
        if let showLabel = storage.fields["show-label"] as? Bool, showLabel != previousShowLabel {
            for value in values {
                guard let toggle = storage.fields[Self.toggle + value[keyPath: label]] as? OpaquePointer else {
                    continue
                }
                setShowLabel(showLabel, toggle: toggle, label: value[keyPath: label])
            }
            storage.fields["previous-show-label"] = showLabel
        }
    }
    // swiftlint:enable function_parameter_count

    /// Set whether to show the label on a toggle.
    /// - Parameters:
    ///     - showLabel: Whether to show the label.
    ///     - toggle: The toggle's pointer.
    ///     - label: The toggle's label.
    static func setShowLabel(_ showLabel: Bool?, toggle: OpaquePointer?, label: String) {
        if let showLabel, !showLabel {
            adw_toggle_set_tooltip(toggle, label)
            adw_toggle_set_label(toggle, nil)
        } else {
            adw_toggle_set_label(toggle, label)
            adw_toggle_set_tooltip(toggle, nil)
        }
    }

    /// Overwrite the show label value added via the type.
    /// - Parameter showLabel: Whether to show the labels.
    /// - Returns: The toggle group.
    public func showLabel(_ showLabel: Bool) -> Self {
        modify { group in
            group.updateFunctions.insert({ storage, _, updateProperties in
                if updateProperties {
                    storage.fields["show-label"] = showLabel
                }
            }, at: 0)
        }
    }

}

/// An item of a toggle group.
public protocol ToggleGroupItem: Identifiable where Self.ID: CustomStringConvertible {

    /// The item's icon.
    var icon: Icon? { get }
    /// Whether to show the label in the UI (the identifier's string conversion).
    ///
    /// Otherwise, it will be used as the tooltip.
    var showLabel: Bool { get }

}
