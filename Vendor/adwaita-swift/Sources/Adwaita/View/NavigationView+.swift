//
//  NavigationView+.swift
//  Adwaita
//
//  Created by david-swift on 17.02.24.
//

import CAdw
import Foundation

extension NavigationView {

    /// The ID for the component field in a content storage.
    static var componentID: String { "component" }

    /// Initialize a navigation view.
    /// - Parameters:
    ///   - stack: The navigation stack for pushing and popping.
    ///   - initialTitle: The title of the initial view.
    ///   - content: The view for a path component.
    ///   - initialView: The view that is displayed when the path is empty.
    public init<Component>(
        _ stack: Binding<NavigationStack<Component>>,
        _ initialTitle: String,
        @ViewBuilder content: @escaping (Component) -> Body,
        @ViewBuilder initialView: @escaping () -> Body
    ) {
        self.init()
        appearFunctions.append { storage, data in
            let initialStorage = initialView().storage(data: data, type: AdwaitaMainView.self)
            storage.content[.mainContent] = [initialStorage]
            adw_navigation_view_push(
                storage.opaquePointer,
                adw_navigation_page_new(initialStorage.opaquePointer?.cast(), initialTitle)
            )
            storage.connectSignal(name: "popped", id: "components", type: .oneArg) { args in
                guard let arg = args.first as? UnsafeRawPointer else {
                    return
                }
                let pointer = adw_navigation_page_get_child(OpaquePointer(arg).cast())?.opaque()
                if let id = storage.fields[pointer?.debugDescription ?? ""] as? UUID {
                    storage.fields[pointer?.debugDescription ?? ""] = nil
                    stack.wrappedValue.pop(id: id)
                }
            }
        }
        updateFunctions.append { [self] storage, data, updateProperties in
            updateStack(
                storage: storage,
                data: data,
                stack: stack,
                views: (content, initialView()),
                updateProperties: updateProperties
            )
        }
    }

    /// A stack controls a navigation view.
    public struct NavigationStack<Component> where Component: CustomStringConvertible {

        /// The action history.
        var history: [Element] = []

        /// Initialize a navigation stack.
        public init() { }

        // swiftlint:disable nesting
        /// An element added to the navigation view.
        struct Element: Identifiable {

            /// The identifier.
            var id: UUID = .init()
            /// The component.
            var component: Component

        }
        // swiftlint:enable nesting

        /// Remove the last item from the navigation view.
        public mutating func pop() {
            _ = history.popLast()
        }

        /// Remove the last items until the active item has the specified ID.
        /// - Parameter id: The identifier.
        mutating func pop(id: UUID) {
            if history.contains(where: { $0.id == id }) {
                while true {
                    let element = history.popLast()
                    if element?.id == id || element == nil { break }
                }
            }
        }

        /// Add a new item to the navigation view.
        /// - Parameter component: The component's value.
        public mutating func push(_ component: Component) {
            history.append(.init(component: component))
        }

    }

    /// Update a navigation view.
    /// - Parameters:
    ///   - storage: The view storage.
    ///   - modifiers: The view modifiers.
    ///   - stack: The navigation stack for pushing and popping.
    ///   - views: The views.
    ///   - updateProperties: Whether to update properties.
    func updateStack<Component>(
        storage: ViewStorage,
        data: WidgetData,
        stack: Binding<NavigationStack<Component>>,
        views: ((Component) -> Body, Body),
        updateProperties: Bool
    ) {
        guard var storages = storage.content[.mainContent] else {
            return
        }
        let history = storage.fields[Self.componentID] as? [NavigationStack<Component>.Element] ?? []
        history.identifiableTransform(
            to: stack.wrappedValue.history,
            functions: .init { _ in
                if storages.count > 1 {
                    storages.removeLast()
                    if let last = history.last?.id {
                        if let index = storage.fields.firstIndex(where: { ($1 as? UUID) == last }) {
                            storage.fields.remove(at: index)
                            adw_navigation_view_pop(storage.opaquePointer)
                        }
                    }
                }
            } insert: { _, element in
                let component = element.component
                let contentStorage = views.0(component).storage(data: data, type: AdwaitaMainView.self)
                views.0(component)
                    .updateStorage(contentStorage, data: data, updateProperties: true, type: AdwaitaMainView.self)
                storage.fields[contentStorage.opaquePointer?.debugDescription ?? ""] = element.id
                storages.append(contentStorage)
                adw_navigation_view_push(
                    storage.opaquePointer,
                    adw_navigation_page_new(contentStorage.opaquePointer?.cast(), component.description)
                )
            }
        )
        storage.fields[Self.componentID] = stack.wrappedValue.history
        storage.content[.mainContent] = storages
        if let element = stack.wrappedValue.history.last, let storage = storage.content[.mainContent]?.last {
            views.0(element.component)
                .updateStorage(
                    storage,
                    data: data,
                    updateProperties: updateProperties,
                    type: AdwaitaMainView.self
                )
        } else if let storage = storage.content[.mainContent]?.first as? ViewStorage {
            views.1
                .updateStorage(
                    storage,
                    data: data,
                    updateProperties: updateProperties,
                    type: AdwaitaMainView.self
                )
        }
    }

}

/// A stack controls a navigation view.
public typealias NavigationStack = NavigationView.NavigationStack
