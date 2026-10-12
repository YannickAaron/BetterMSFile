//
//  ViewStack.swift
//  Adwaita
//
//  Created by david-swift on 30.12.23.
//

import CAdw

/// A widget showing one of two widgets based on a condition.
public struct EitherView: SimpleView, Meta.EitherView {

    /// Whether the first view is visible.
    var condition: Bool
    /// The first view.
    var view1: Body
    /// The second view.
    var view2: Body

    /// The view's content.
    public var view: Body {
        if condition {
            return [ViewStack(id: true) { _ in BoxWrapper { view1 }.inspect(addTransition) }.homogeneous(false)]
        } else {
            return [ViewStack(id: false) { _ in BoxWrapper { view2 }.inspect(addTransition) }.homogeneous(false)]
        }
    }

    /// Initialize the either view.
    /// - Parameters:
    ///     - condition: Whether the first view is visible-
    ///     - view1: The first view, visible if true.
    ///     - view2: The second view, visible if false.
    public init(
        _ condition: Bool,
        @ViewBuilder view1: () -> Body,
        @ViewBuilder else view2: () -> Body
    ) {
        self.condition = condition
        self.view1 = view1()
        self.view2 = view2()
    }

    /// Add the transition in the content view to the box wrappers.
    /// - Parameters:
    ///     - storage: The wrapper box storage.
    ///     - data: The widget data.
    ///     - updateProperties: Whether to update the properties.
    func addTransition(storage: ViewStorage, data: WidgetData, updateProperties: Bool) {
        if updateProperties,
           let transition = storage.content["append"]?.first?.fields[.transition] {
            storage.fields[.transition] = transition
        }
    }

}
