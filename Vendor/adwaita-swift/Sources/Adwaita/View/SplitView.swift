//
//  SplitView.swift
//  Adwaita
//
//  Created by david-swift on 19.09.2025.
//

import CAdw
import Foundation

/// A split view.
struct SplitView: AdwaitaWidget {

    /// The start widget.
    @ViewProperty(
        set: { widget, view in gtk_paned_set_start_child(.init(widget), view.cast()) },
        pointer: OpaquePointer.self,
        subview: OpaquePointer.self,
        context: AdwaitaMainView.self
    )
    var start
    /// The end widget.
    @ViewProperty(
        set: { widget, view in gtk_paned_set_end_child(.init(widget), view.cast()) },
        pointer: OpaquePointer.self,
        subview: OpaquePointer.self,
        context: AdwaitaMainView.self
    )
    var end
    /// Position of the splitter
    @BindingProperty(
        observe: { _, binding, storage in
            storage.notify(name: "position") {
                binding.wrappedValue = Int(gtk_paned_get_position(storage.opaquePointer))
            }
        },
        set: { widget, value, _ in gtk_paned_set_position(widget, Int32(value)) },
        pointer: OpaquePointer.self
    )
    var splitter: Binding<Int> = .constant(0)
    /// The orientation of the split view.
    var orientation: Orientation

    /// Initialize a split view.
    /// - Parameters:
    ///     - splitter: The position of the splitter.
    ///     - orientation: The orientation of the split view.
    ///     - start: The start widget.
    ///     - end: The end widget.
    init(
        splitter: Binding<Int>,
        orientation: Orientation,
        start: Body,
        end: Body
    ) {
        self.orientation = orientation
        self.splitter = splitter
        self.start = start
        self.end = end
    }

    /// Initialize the widget.
    func initializeWidget() -> Any {
        gtk_paned_new(orientation.gtkValue).opaque() as Any
    }

}

/// A horizontal split view.
public struct HSplitView: SimpleView {

    /// The splitter.
    @Binding var splitter: Int
    /// The start widget.
    var start: Body
    /// The end widget.
    var end: Body

    /// The view.
    public var view: Body {
        SplitView(splitter: $splitter, orientation: .horizontal, start: start, end: end)
    }

    /// Initialize a horizontal split view.
    /// - Parameters:
    ///     - splitter: The position of the splitter.
    ///     - start: The start widget.
    ///     - end: The end widget.
    public init(
        splitter: Binding<Int>,
        @ViewBuilder start: () -> Body,
        @ViewBuilder end: () -> Body
    ) {
        self._splitter = splitter
        self.start = start()
        self.end = end()
    }

}

/// A vertical split view.
public struct VSplitView: SimpleView {

    /// The splitter.
    @Binding var splitter: Int
    /// The start widget.
    var start: Body
    /// The end widget.
    var end: Body

    /// The view.
    public var view: Body {
        SplitView(splitter: $splitter, orientation: .vertical, start: start, end: end)
    }

    /// Initialize a vertical split view.
    /// - Parameters:
    ///     - splitter: The position of the splitter.
    ///     - start: The start widget.
    ///     - end: The end widget.
    public init(
        splitter: Binding<Int>,
        @ViewBuilder start: () -> Body,
        @ViewBuilder end: () -> Body
    ) {
        self._splitter = splitter
        self.start = start()
        self.end = end()
    }

}
