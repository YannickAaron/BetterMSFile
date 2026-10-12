//
//  TextEditor.swift
//  Adwaita
//
//  Created by david-swift on 09.08.25.
//

import CAdw

/// A text editor widget.
public typealias TextEditor = TextView

/// A text editor widget.
public struct TextView: AdwaitaWidget {

    /// The editor's content.
    @BindingProperty(
        observe: { _, text, storage in
            if let buffer = storage.content[.buffer]?.first {
                buffer.connectSignal(name: "changed", type: .noArgs) { _ in
                    let currentText = Self.getText(buffer: buffer)
                    if text.wrappedValue != currentText {
                        text.wrappedValue = currentText
                    }
                }
            }
        },
        set: { _, text, storage in
            if let buffer = storage.content[.buffer]?.first, Self.getText(buffer: buffer) != text {
                gtk_text_buffer_set_text(buffer.opaquePointer?.cast(), text, -1)
            }
        },
        pointer: Any.self
    )
    var text: Binding<String> = .constant("")
    /// The padding between the border and the content.
    @Property(
        set: { $1.set($0) },
        pointer: OpaquePointer.self
    )
    var padding: InnerPadding?
    /// The (word) wrap mode used when rendering the text.
    @Property(
        set: { gtk_text_view_set_wrap_mode($0.cast(), $1.gtkValue) },
        pointer: OpaquePointer.self
    )
    var wrapMode: WrapMode = .none

    /// Initialize a text editor.
    /// - Parameter text: The editor's content.
    public init(text: Binding<String>) {
        self.text = text
    }

    /// The inner padding of a text view.
    struct InnerPadding {

        /// The padding.
        var padding: Int
        /// The affected edges.
        var paddingEdges: Set<Edge>

        /// Set the inner padding on a text view.
        /// - Parameter pointer: The text view.
        func set(_ pointer: OpaquePointer) {
            if paddingEdges.contains(.top) {
                gtk_text_view_set_top_margin(pointer.cast(), padding.cInt)
            }
            if paddingEdges.contains(.bottom) {
                gtk_text_view_set_bottom_margin(pointer.cast(), padding.cInt)
            }
            if paddingEdges.contains(.leading) {
                gtk_text_view_set_left_margin(pointer.cast(), padding.cInt)
            }
            if paddingEdges.contains(.trailing) {
                gtk_text_view_set_right_margin(pointer.cast(), padding.cInt)
            }
        }

    }

    /// Get the text view's content.
    /// - Parameter buffer: The text view's buffer.
    /// - Returns: The content.
    static func getText(buffer: ViewStorage) -> String {
        let startIter: UnsafeMutablePointer<GtkTextIter> = .allocate(capacity: 1)
        let endIter: UnsafeMutablePointer<GtkTextIter> = .allocate(capacity: 1)
        gtk_text_buffer_get_start_iter(buffer.opaquePointer?.cast(), startIter)
        gtk_text_buffer_get_end_iter(buffer.opaquePointer?.cast(), endIter)
        return .init(
            cString: gtk_text_buffer_get_text(buffer.opaquePointer?.cast(), startIter, endIter, true.cBool)
        )
    }

    /// Get the editor's view storage.
    /// - Parameters:
    ///     - data: The widget data.
    ///     - type: The view render data type.
    /// - Returns: The view storage.
    public func container<Data>(data: WidgetData, type: Data.Type) -> ViewStorage where Data: ViewRenderData {
        let buffer = ViewStorage(gtk_text_buffer_new(nil)?.opaque())
        let editor = ViewStorage(
            gtk_text_view_new_with_buffer(buffer.opaquePointer?.cast())?.opaque(),
            content: ["buffer": [buffer]]
        )
        initProperties(editor, data: data, type: type)
        return editor
    }

    /// Set the wrapMode for the text view.
    ///
    /// Available wrap modes are `none`, `char`, `word`, `wordChar`. Please refer to the
    /// corresponding `GtkWrapMode` documentation for the details on how they work.
    ///
    /// - Parameter mode: The `WrapMode` to set.
    public func wrapMode(_ mode: WrapMode) -> Self {
      var newSelf = self
      newSelf.wrapMode = mode
      return newSelf
    }

    /// Add padding between the editor's content and border.
    /// - Parameters:
    ///     - padding: The padding's value.
    ///     - edges: The affected edges.
    /// - Returns: The editor.
    public func innerPadding(_ padding: Int = 10, edges: Set<Edge> = .all) -> Self {
        var newSelf = self
        newSelf.padding = .init(padding: padding, paddingEdges: edges)
        return newSelf
    }

}
