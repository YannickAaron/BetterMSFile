//
//  AlertDialog.swift
//  Adwaita
//
//  Created by david-swift on 05.04.24.
//

import CAdw
import LevenshteinTransformations

/// The message dialog widget.
public struct AlertDialog: AdwaitaWidget {

    /// The ID for the dialog's storage.
    static let dialogID = "alert-dialog"
    /// The ID for the dialog's responses' storage.
    static let responsesID = "responses"
    /// The ID for the visibility binding.
    static let visibleID = "visible"
    /// The ID for the callbacks.
    static let callbacks = "callbacks"

    /// Whether the dialog is visible.
    @Binding var visible: Bool
    /// An identifier used if multiple dialogs are on one view.
    var id: String
    /// The dialog's title.
    var heading: String
    /// The body text.
    var body: String
    /// The body view.
    var extraChild: Body?
    /// The available responses.
    var responses: [Response] = []
    /// The child view.
    var child: AnyView

    /// Initialize an alert dialog wrapper.
    /// - Parameters:
    ///     - visible: Whether the dialog is visible.
    ///     - child: The child view.
    ///     - id: A unique identifier for dialogs on the view.
    ///     - heading: The heading.
    ///     - body: The body text.
    ///     - extraChild: The body view.
    init(
        visible: Binding<Bool>,
        child: AnyView,
        id: String,
        heading: String,
        body: String,
        extraChild: Body? = nil
    ) {
        self._visible = visible
        self.child = child
        self.id = id
        self.heading = heading
        self.body = body
        self.extraChild = extraChild
    }

    /// Information about a response.
    struct Response: Identifiable {

        /// The title.
        var title: String
        /// The identifier.
        var id: String { title }
        /// The appearance.
        var appearance: ResponseAppearance
        /// The function for the keyboard shortcut, or no shortcut.
        var role: ResponseRole?
        /// The callback.
        var action: () -> Void

    }

    /// The appearance of the response.
    public enum ResponseAppearance {

        /// The regular appearance.
        case `default`
        /// The suggested appearance.
        case suggested
        /// The destructive appearance.
        case destructive

    }

    /// The role of the response, determining a keyboard shortcut.
    public enum ResponseRole {

        /// The close role.
        case close
        /// The default role.
        case `default`

    }

    /// The view storage.
    /// - Parameters:
    ///     - modifiers: Modify views before being updated.
    ///     - type: The view render data type.
    /// - Returns: The view storage.
    public func container<Data>(
        data: WidgetData,
        type: Data.Type
    ) -> ViewStorage where Data: ViewRenderData {
        child.storage(data: data, type: type)
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
        storage.fields[Self.visibleID + id] = _visible
        child.updateStorage(storage, data: data, updateProperties: updateProperties, type: type)
        defer {
            if let storage = storage.content[.extraChild]?.first, visible {
                extraChild?.updateStorage(storage, data: data, updateProperties: updateProperties, type: type)
            }
        }
        guard updateProperties else {
            return
        }
        if visible {
            var present = false
            if storage.content[Self.dialogID + id]?.first == nil {
                createDialog(storage: storage, data: data)
                present = true
            }
            let pointer = storage.content[Self.dialogID + id]?.first?.opaquePointer
            adw_alert_dialog_set_heading(pointer?.cast(), heading)
            adw_alert_dialog_set_body(pointer?.cast(), body)
            let old = storage.fields[Self.responsesID + id] as? [Response] ?? []
            old.identifiableTransform(
                to: responses,
                functions: .init { index in
                    adw_alert_dialog_remove_response(pointer?.cast(), responseID(old[safe: index]?.id))
                } insert: { _, element in
                    adw_alert_dialog_add_response(pointer?.cast(), responseID(element.id), element.title)
                }
            )
            storage.fields[Self.responsesID + id] = responses
            var handlers: [String: () -> Void] = [:]
            for response in responses {
                handlers[responseID(response.id) ?? ""] = response.action
            }
            storage.fields[Self.callbacks + id] = handlers
            responsesCosmetics(pointer: pointer)
            if present {
                gtui_alertdialog_choose(
                    pointer?.cast(),
                    .init(bitPattern: unsafeBitCast(storage, to: UInt.self)),
                    storage.opaquePointer?.cast()
                )
            }
        } else {
            if storage.content[Self.dialogID + id]?.first != nil {
                let dialog = storage.content[Self.dialogID + id]?.first?.opaquePointer
                adw_dialog_close(dialog?.cast())
                storage.content[Self.dialogID] = []
            }
        }
    }

    /// Style the responses and add shortcuts if required.
    /// - Parameter pointer: The pointer.
    func responsesCosmetics(pointer: OpaquePointer?) {
        for element in responses {
            switch element.appearance {
            case .default:
                adw_alert_dialog_set_response_appearance(
                    pointer?.cast(),
                    responseID(element.id),
                    .ADW_RESPONSE_DEFAULT
                )
            case .suggested:
                adw_alert_dialog_set_response_appearance(
                    pointer?.cast(),
                    responseID(element.id),
                    .ADW_RESPONSE_SUGGESTED
                )
            case .destructive:
                adw_alert_dialog_set_response_appearance(
                    pointer?.cast(),
                    responseID(element.id),
                    .ADW_RESPONSE_DESTRUCTIVE
                )
            }
        }
        if let closeResponse = responses.first(where: { $0.role == .close }) ?? responses.first {
            adw_alert_dialog_set_close_response(pointer?.cast(), responseID(closeResponse.id))
        }
        if let defaultResponse = responses.first(where: { $0.role == .default }) {
            adw_alert_dialog_set_default_response(pointer?.cast(), responseID(defaultResponse.id))
        }
    }

    /// Create a new instance of the dialog.
    /// - Parameters:
    ///     - storage: The wrapped view's storage.
    ///     - data: The widget data.
    func createDialog(storage: ViewStorage, data: WidgetData) {
        let pointer = adw_alert_dialog_new(nil, nil)
        let dialog = ViewStorage(pointer?.opaque())
        storage.content[Self.dialogID + id] = [dialog]
        if let extraChild {
            let child = extraChild.storage(data: data, type: AdwaitaMainView.self)
            extraChild.updateStorage(child, data: data, updateProperties: true, type: AdwaitaMainView.self)
            let childPointer = child.pointer as? OpaquePointer
            storage.content[.extraChild] = [child]
            adw_alert_dialog_set_extra_child(pointer?.cast(), childPointer?.cast())
        }
    }

    /// Get the identifier of a response which is combined with the dialog's id.
    /// - Parameter id: The response identifier.
    /// - Returns: The new identifier.
    func responseID(_ id: String?) -> String? {
        if let id {
            return self.id + "...." + id
        }
        return nil
    }

    /// Add a response to the alert dialog.
    /// - Parameters:
    ///     - title: The response.
    ///     - appearance: The response's appearance.
    ///     - role: The response's shortcut, if any.
    ///     - action: The
    public func response(
        _ title: String,
        appearance: ResponseAppearance = .default,
        role: ResponseRole? = nil,
        action: @escaping () -> Void
    ) -> Self {
        var newSelf = self
        newSelf.responses.append(.init(title: title, appearance: appearance, role: role, action: action))
        return newSelf
    }

}

/// Run when an alert dialog closes.
/// - Parameters:
///   - ptr: The pointer.
///   - answer: The identifier of the answer.
///   - userData: The alert dialog data.
@_cdecl("alertdialog_on_close_cb")
func alertdialog_on_close_cb(
    ptr: UnsafeMutableRawPointer,
    answer: UnsafePointer<CChar>?,
    userData: UnsafeMutableRawPointer
) {
    let storage = Unmanaged<ViewStorage>.fromOpaque(userData).takeUnretainedValue()
    var id = ""
    if let answer {
        let answer = String(cString: answer)
        id = .init(answer.components(separatedBy: "....").first ?? "")
        (storage.fields[AlertDialog.callbacks + id] as? [String: () -> Void])?[answer]?()
    }
    storage.content[AlertDialog.dialogID + id] = []
    storage.fields[AlertDialog.responsesID + id] = []
    if let visible = storage.fields[AlertDialog.visibleID + id] as? Binding<Bool>, visible.wrappedValue {
        visible.wrappedValue = false
    }
}
