//
//  WrapBox.swift
//  Adwaita
//
//  Created by desbeers on 07.08.26.
//

import CAdw

/// A box-like widget that can wrap into multiple lines.
///
///
///
/// `AdwWrapBox` is similar to `Gtk.Box`, but can wrap lines when the
/// widgets cannot fit otherwise. Unlike `Gtk.FlowBox`, the children aren't
/// arranged into a grid and behave more like words in a wrapping label.
///
/// Like `GtkBox`, `AdwWrapBox` is orientable and has spacing:
///
/// - ``childSpacing(_:)`` between children in the same line;
/// - ``lineSpacing(_:)`` between lines.
///
/// > [!NOTE]
/// >     Unlike `GtkBox`, `AdwWrapBox` cannot follow the CSS `border-spacing`
/// property.
///
/// Use the ``naturalLineLength(_:)`` property to determine the
/// layout's natural size, e.g. when using it in a `Gtk.Popover`.
///
/// Normally, a horizontal `AdwWrapBox` wraps left to right and top to bottom
/// for left-to-right languages. Both of these directions can be reversed, using
/// the ``packDirection(_:)`` and ``wrapReverse(_:)``
/// properties. Additionally, the alignment of each line can be controlled with
/// the ``align(_:)`` property.
///
/// Lines can be justified using the ``justify(_:)`` property, filling
/// the entire line by either increasing child size or spacing depending on the
/// value. Set ``justifyLastLine(_:)`` to justify the last line as
/// well.
///
/// By default, `AdwWrapBox` wraps as soon as the previous line cannot fit any
/// more children without shrinking them past their natural size. Set
/// ``wrapPolicy(_:)`` to [enum@Adw.WrapPolicy.minimum] to only wrap
/// once all the children in the previous line have been shrunk to their minimum
/// size.
///
/// To make each line take the same amount of space, set
/// ``lineHomogeneous(_:)`` to `true`.
///
/// Spacing and natural line length can scale with the text scale factor, use the
/// ``childSpacingUnit(_:)``, ``lineSpacingUnit(_:)``
/// and/or ``naturalLineLengthUnit(_:)`` properties to enable that
/// behavior.
///
/// See `WrapLayout`.
///
///
public struct WrapBox<Element, Identifier>: AdwaitaWidget where Identifier: Equatable {

    #if exposeGeneratedAppearUpdateFunctions
    /// Additional update functions for type extensions.
    public var updateFunctions: [(ViewStorage, WidgetData, Bool) -> Void] = []
    /// Additional appear functions for type extensions.
    public var appearFunctions: [(ViewStorage, WidgetData) -> Void] = []
    #else
    /// Additional update functions for type extensions.
    var updateFunctions: [(ViewStorage, WidgetData, Bool) -> Void] = []
    /// Additional appear functions for type extensions.
    var appearFunctions: [(ViewStorage, WidgetData) -> Void] = []
    #endif

    /// The alignment of the children within each line.
    ///
    /// 0 means the children are placed at the start of the line, 1 means they are
    /// placed at the end of the line. 0.5 means they are placed in the middle of
    /// the line.
    ///
    /// Alignment is only used when ``justify(_:)`` is set to
    /// [enum@Adw.JustifyMode.none], or on the last line when the
    /// ``justifyLastLine(_:)`` is `false`.
    var align: Float?
    /// The spacing between widgets on the same line.
    ///
    /// See ``childSpacingUnit(_:)``.
    var childSpacing: Int?
    /// Whether the last line should be stretched to fill the entire widget.
    ///
    /// See ``justify(_:)``.
    var justifyLastLine: Bool?
    /// Whether all lines should take the same amount of space.
    var lineHomogeneous: Bool?
    /// The spacing between lines.
    ///
    /// See ``lineSpacingUnit(_:)``.
    var lineSpacing: Int?
    /// Determines the natural size for each line.
    ///
    /// It should be used to limit the line lengths, for example when used in
    /// popovers.
    ///
    /// See ``naturalLineLengthUnit(_:)``.
    var naturalLineLength: Int?
    /// Whether wrap direction should be reversed.
    ///
    /// By default, lines wrap downwards in a horizontal box, and towards the end
    /// in a vertical box. If set to `true`, they wrap upwards or towards the start
    /// respectively.
    var wrapReverse: Bool?
    /// The dynamic widget elements.
    var elements: [Element]
    /// The dynamic widget content.
    var content: (Element) -> Body
    /// The dynamic widget identifier key path.
    var id: KeyPath<Element, Identifier>

    /// Initialize `WrapBox`.
    init(_ elements: [Element], id: KeyPath<Element, Identifier>, @ViewBuilder content: @escaping (Element) -> Body) {
        self.elements = elements
        self.content = content
        self.id = id
    }

    /// The view storage.
    /// - Parameters:
    ///     - data: Data passed to widgets.
    ///     - type: The view render data type.
    /// - Returns: The view storage.
    public func container<Data>(data: WidgetData, type: Data.Type) -> ViewStorage where Data: ViewRenderData {
        let storage = ViewStorage(adw_wrap_box_new()?.opaque())
        for function in appearFunctions {
            function(storage, data)
        }

        return storage
    }

    // swiftlint:disable function_body_length

    /// Update the stored content.
    /// - Parameters:
    ///     - storage: The storage to update.
    ///     - data: Data passed to widgets.
    ///     - updateProperties: Whether to update the view's properties.
    ///     - type: The view render data type.
    public func update<Data>(
        _ storage: ViewStorage,
        data: WidgetData,
        updateProperties: Bool,
        type: Data.Type
    ) where Data: ViewRenderData {
        // swiftlint:disable:next closure_body_length
        storage.modify { widget in

            if let align,
                updateProperties, (storage.previousState as? Self)?.align != align {
                adw_wrap_box_set_align(widget, align)
            }
            if let childSpacing,
                updateProperties, (storage.previousState as? Self)?.childSpacing != childSpacing {
                adw_wrap_box_set_child_spacing(widget, childSpacing.cInt)
            }
            if let justifyLastLine,
                updateProperties, (storage.previousState as? Self)?.justifyLastLine != justifyLastLine {
                adw_wrap_box_set_justify_last_line(widget, justifyLastLine.cBool)
            }
            if let lineHomogeneous,
                updateProperties, (storage.previousState as? Self)?.lineHomogeneous != lineHomogeneous {
                adw_wrap_box_set_line_homogeneous(widget, lineHomogeneous.cBool)
            }
            if let lineSpacing,
                updateProperties, (storage.previousState as? Self)?.lineSpacing != lineSpacing {
                adw_wrap_box_set_line_spacing(widget, lineSpacing.cInt)
            }
            if let naturalLineLength,
                updateProperties, (storage.previousState as? Self)?.naturalLineLength != naturalLineLength {
                adw_wrap_box_set_natural_line_length(widget, naturalLineLength.cInt)
            }
            if let wrapReverse,
                updateProperties, (storage.previousState as? Self)?.wrapReverse != wrapReverse {
                adw_wrap_box_set_wrap_reverse(widget, wrapReverse.cBool)
            }

            var contentStorage: [ViewStorage] = storage.content[.mainContent] ?? []
            let old = storage.fields[.element] as? [Element] ?? []
            old.transform(
                to: elements,
                id: id,
                functions: .init { index in
                    adw_wrap_box_remove(widget, contentStorage[index].opaquePointer?.cast())
                    contentStorage.remove(at: index)
                } insert: { index, element in
                    let sibling = contentStorage[safe: index - 1]
                    let child = content(element).storage(data: data, type: type)
                    adw_wrap_box_insert_child_after(
                        widget,
                        child.opaquePointer?.cast(),
                        sibling?.opaquePointer?.cast()
                    )
                    contentStorage.insert(child, at: index)
                }
            )
            storage.fields[.element] = elements
            storage.content[.mainContent] = contentStorage
            for (index, element) in elements.enumerated() {
                content(element).updateStorage(
                    contentStorage[index],
                    data: data,
                    updateProperties: updateProperties,
                    type: type
                )
            }

        }
        for function in updateFunctions {
            function(storage, data, updateProperties)
        }
        if updateProperties {
            storage.previousState = self
        }
    }

    // swiftlint:enable function_body_length

    /// The alignment of the children within each line.
    ///
    /// 0 means the children are placed at the start of the line, 1 means they are
    /// placed at the end of the line. 0.5 means they are placed in the middle of
    /// the line.
    ///
    /// Alignment is only used when ``justify(_:)`` is set to
    /// [enum@Adw.JustifyMode.none], or on the last line when the
    /// ``justifyLastLine(_:)`` is `false`.
    public func align(_ align: Float?) -> Self {
        modify { $0.align = align }
    }

    /// The spacing between widgets on the same line.
    ///
    /// See ``childSpacingUnit(_:)``.
    public func childSpacing(_ childSpacing: Int?) -> Self {
        modify { $0.childSpacing = childSpacing }
    }

    /// Whether the last line should be stretched to fill the entire widget.
    ///
    /// See ``justify(_:)``.
    public func justifyLastLine(_ justifyLastLine: Bool? = true) -> Self {
        modify { $0.justifyLastLine = justifyLastLine }
    }

    /// Whether all lines should take the same amount of space.
    public func lineHomogeneous(_ lineHomogeneous: Bool? = true) -> Self {
        modify { $0.lineHomogeneous = lineHomogeneous }
    }

    /// The spacing between lines.
    ///
    /// See ``lineSpacingUnit(_:)``.
    public func lineSpacing(_ lineSpacing: Int?) -> Self {
        modify { $0.lineSpacing = lineSpacing }
    }

    /// Determines the natural size for each line.
    ///
    /// It should be used to limit the line lengths, for example when used in
    /// popovers.
    ///
    /// See ``naturalLineLengthUnit(_:)``.
    public func naturalLineLength(_ naturalLineLength: Int?) -> Self {
        modify { $0.naturalLineLength = naturalLineLength }
    }

    /// Whether wrap direction should be reversed.
    ///
    /// By default, lines wrap downwards in a horizontal box, and towards the end
    /// in a vertical box. If set to `true`, they wrap upwards or towards the start
    /// respectively.
    public func wrapReverse(_ wrapReverse: Bool? = true) -> Self {
        modify { $0.wrapReverse = wrapReverse }
    }

}

extension WrapBox where Element: Identifiable, Identifier == Element.ID {

    /// Initialize `WrapBox`.
    public init(_ elements: [Element], @ViewBuilder content: @escaping (Element) -> Body) {
        self.elements = elements
        self.content = content
        self.id = \.id
    }
}

// swiftlint:disable:next no_grouping_extension
extension WrapBox {

    /// The orientation of the `WrapBox`.
    /// - Parameter orientation: Set the orientation to horizontal or vertical.
    /// - Returns: A modified `WrapBox`.
    public func orientation( _ orientation: Orientation) -> WrapBox {
        var newSelf = self
        newSelf.updateFunctions.append { storage, _, _ in
            gtk_orientable_set_orientation(storage.opaquePointer, orientation.gtkValue)
        }
        return newSelf
    }

    /// The justify mode of the `WrapBox`.
    /// - Parameter justifyMode: How each complete line should be stretched to fill the entire widget.
    /// - Returns: A modified `WrapBox`.
    public func justify( _ justifyMode: JustifyMode) -> WrapBox {
        var newSelf = self
        newSelf.updateFunctions.append { storage, _, _ in
            adw_wrap_box_set_justify(storage.opaquePointer, justifyMode.gtkValue)
        }
        return newSelf
    }

    /// The line wrapping policy of the `WrapBox`.
    /// - Parameter wrapPolicy: Wrap at minimum or natural size of the children.
    /// - Returns: A modified `WrapBox`.
    public func wrapPolicy( _ wrapPolicy: WrapPolicy) -> WrapBox {
        var newSelf = self
        newSelf.updateFunctions.append { storage, _, _ in
            adw_wrap_box_set_wrap_policy(storage.opaquePointer, wrapPolicy.gtkValue)
        }
        return newSelf
    }

    /// The child packing behavior of the `WrapBox`.
    /// - Parameter packDirection: The direction of the child packing.
    /// - Returns: A modified `WrapBox`.
    public func packDirection( _ packDirection: PackDirection) -> WrapBox {
        var newSelf = self
        newSelf.updateFunctions.append { storage, _, _ in
            adw_wrap_box_set_pack_direction(storage.opaquePointer, packDirection.gtkValue)
        }
        return newSelf
    }

    /// The length unit for child spacing.
    /// - Parameter lengthUnit: The length unit.
    /// - Returns: A modified `WrapBox`.
    public func childSpacingUnit( _ lengthUnit: LengthUnit) -> WrapBox {
        var newSelf = self
        newSelf.updateFunctions.append { storage, _, _ in
            adw_wrap_box_set_child_spacing_unit(storage.opaquePointer, lengthUnit.gtkValue)
        }
        return newSelf
    }

    /// The length unit for line spacing.
    /// - Parameter lengthUnit: The length unit.
    /// - Returns: A modified `WrapBox`.
    public func lineSpacingUnit( _ lengthUnit: LengthUnit) -> WrapBox {
        var newSelf = self
        newSelf.updateFunctions.append { storage, _, _ in
            adw_wrap_box_set_line_spacing_unit(storage.opaquePointer, lengthUnit.gtkValue)
        }
        return newSelf
    }

    /// The length unit for natural line lenght.
    /// - Parameter lengthUnit: The length unit.
    /// - Returns: A modified `WrapBox`.
    public func naturalLineLengthUnit( _ lengthUnit: LengthUnit) -> WrapBox {
        var newSelf = self
        newSelf.updateFunctions.append { storage, _, _ in
            adw_wrap_box_set_natural_line_length_unit(storage.opaquePointer, lengthUnit.gtkValue)
        }
        return newSelf
    }

}
