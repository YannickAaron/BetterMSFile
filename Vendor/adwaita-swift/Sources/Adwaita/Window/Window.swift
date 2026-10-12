//
//  Window.swift
//  Adwaita
//
//  Created by david-swift on 14.09.23.
//

// swiftlint:disable discouraged_optional_collection

import CAdw
import Foundation

/// A structure representing an application window type.
///
/// Note that it may be possible to open multiple instances of a window at the same time.
public struct Window: AdwaitaSceneElement {

    /// The window's identifier.
    public var id: String
    /// The window's content.
    var content: (AdwaitaWindow) -> Body
    /// Whether an instance of the window type should be opened when the app is starting up.
    var `open`: Int
    /// The keyboard shortcuts.
    var shortcuts: [String: (AdwaitaWindow) -> Void] = [:]
    /// The keyboard shortcuts on the app level.
    var appShortcuts: [String: (AdwaitaApp) -> Void] = [:]
    /// The action to run when a file opening request has to be handled.
    var onOpen: (([URL]) -> Void)?
    /// The window's title.
    var title: String?
    /// Whether the window is resizable.
    var resizable: Bool?
    /// Whether the window is deletable.
    var deletable: Bool?
    /// The binding for the window's width.
    var width: Binding<Int>?
    /// The binding for the window's height.
    var height: Binding<Int>?
    /// The window's minimum width.
    var minWidth: Int?
    /// The window's minimum height.
    var minHeight: Int?
    /// The window's default width.
    var defaultWidth: Int?
    /// The window's default height.
    var defaultHeight: Int?
    /// Whether the window is maximized.
    var maximized: Binding<Bool>?
    /// Whether the window is fullscreen.
    var fullscreen: Binding<Bool>?
    /// Whether the window uses the development style.
    var devel: Bool?
    /// Run this function when the window should close.
    var onClose: (() -> CloseConfirmation)?

    /// Create a window type with a certain identifier and user interface.
    /// - Parameters:
    ///   - id: The identifier.
    ///   - open: The number of instances of the window type when the app is starting.
    ///   - content: The window's content.
    public init(id: String, `open`: Int = 1, @ViewBuilder content: @escaping (AdwaitaWindow) -> Body) {
        self.content = content
        self.id = id
        self.open = open
    }

    /// An AdwApplicationWindow.
    public class AdwaitaWindow {

        /// The pointer to the window.
        public let pointer: UnsafeMutablePointer<AdwApplicationWindow>?
        /// Fields for storing signal data.
        var signals: [String: SignalData] = [:]
        /// Other fields.
        public var fields: [String: Any] = [:]
        /// The App.
        let app: AdwaitaApp

        /// Initialize the application window.
        /// - Parameter app: The application.
        init(app: AdwaitaApp) {
            self.app = app
            pointer = adw_application_window_new(app.pointer)?.cast()
        }

        /// Close the window.
        public func close() {
            gtk_window_close(pointer?.cast())
        }

    }

    /// Whether to close or keep a window.
    public enum CloseConfirmation {

        /// Close the window.
        case close
        /// Cancel the closing process and keep the window.
        case cancel

    }

    /// Get the actual window template.
    /// - Parameter content: The content view.s
    /// - Returns: The window.
    func getTemplate(content: Body) -> Self {
        var windowTemplate = self
        if let view = content.first as? WindowView {
            windowTemplate = view.window(windowTemplate)
        }
        return windowTemplate
    }

    /// Set up the initial scene storages.
    /// - Parameter app: The app storage.
    public func setupInitialContainers<Storage>(app: Storage) where Storage: AppStorage {
        if let app = (app as? AdwaitaApp), app.blockInitialWindows {
            if let onOpen {
                app.onOpen = onOpen
            }
            return
        }
        for _ in 0..<open {
            let container = container(app: app)
            container.show()
            app.storage.sceneStorage.append(container)
        }
    }

    /// The scene storage.
    /// - Parameter app: The app storage.
    public func container<Storage>(app: Storage) -> SceneStorage where Storage: AppStorage {
        guard let app = app as? AdwaitaApp else {
            return .init(id: id, pointer: nil) { }
        }
        let window = AdwaitaWindow(app: app)
        let content = content(window)
        let storage = SceneStorage(id: id, pointer: window) {
            gtk_window_present(window.pointer?.cast())
        }
        let viewStorage = content
            .storage(data: .init(sceneStorage: storage, appStorage: app), type: AdwaitaMainView.self)
        adw_application_window_set_content(window.pointer?.cast(), viewStorage.opaquePointer?.cast())
        storage.content[.mainContent] = [viewStorage]
        let observeID = "destroy"
        let data = SignalData {
            storage.destroy = true
        } destroy: {
            window.signals[observeID] = nil
        }
        data.connect(pointer: window.pointer, signal: observeID, type: .noArgs)
        window.signals[observeID] = data
        let template = getTemplate(content: content)
        let width = template.width?.wrappedValue ?? template.defaultWidth ?? -1
        let height = template.height?.wrappedValue ?? template.defaultHeight ?? -1
        gtk_window_set_default_size(window.pointer?.cast(), .init(width), .init(height))
        if minWidth != nil || minHeight != nil {
            gtk_widget_set_size_request(window.pointer?.cast(), .init(minWidth ?? -1), .init(minHeight ?? -1))
        }
        storage.connectSignal(name: "close-request", id: "on-close", type: .noArgsReturnsBool) {
            (storage.fields[.windowClose] as? (() -> Bool))?() ?? false
        }
        update(storage, app: app, updateProperties: true)
        return storage
    }

    /// Update the stored content.
    /// - Parameters:
    ///     - storage: The storage to update.
    ///     - app: The app storage.
    ///     - updateProperties: Whether to update the view's properties.
    public func update<Storage>(
        _ storage: SceneStorage,
        app: Storage,
        updateProperties: Bool
    ) where Storage: AppStorage {
        self.update(storage, app: app, updateProperties: updateProperties, id: nil)
    }

    /// Update the stored content.
    /// - Parameters:
    ///     - storage: The storage to update.
    ///     - app: The app storage.
    ///     - updateProperties: Whether to update the view's properties.
    ///     - id: The update id.
    public func update<Storage>(
        _ storage: SceneStorage,
        app: Storage,
        updateProperties: Bool,
        id: String?
    ) where Storage: AppStorage {
        if Thread.isMainThread {
            privateUpdate(storage, app: app, updateProperties: updateProperties, id: id)
        } else {
            Idle {
                privateUpdate(storage, app: app, updateProperties: updateProperties, id: id)
            }
        }
    }

    /// Update the stored content.
    /// - Parameters:
    ///     - storage: The storage to update.
    ///     - app: The app storage.
    ///     - updateProperties: Whether to update the view's properties.
    ///     - id: The update id.
    private func privateUpdate<Storage>(
        _ storage: SceneStorage,
        app: Storage,
        updateProperties: Bool,
        id: String?
    ) where Storage: AppStorage {
        guard let window = storage.pointer as? AdwaitaWindow,
              let viewStorage = storage.content[.mainContent]?.first else {
            return
        }
        let content = content(window)
        content
            .updateStorage(
                viewStorage,
                data: .init(sceneStorage: storage, appStorage: app, id: id),
                updateProperties: updateProperties,
                type: AdwaitaMainView.self
            )
        let template = getTemplate(content: content)
        if let app = app as? AdwaitaApp {
            for shortcut in template.shortcuts {
                app.addKeyboardShortcut(shortcut.key, id: shortcut.key, window: window) { shortcut.value(window) }
            }
            for shortcut in template.appShortcuts {
                app.addKeyboardShortcut(shortcut.key, id: shortcut.key) { shortcut.value(app) }
            }
            app.onOpen = onOpen
        }
        if template.width != nil {
            storage.notify(name: "default-width", pointer: window.pointer?.opaque()) {
                template.width?.wrappedValue = getDefaultSize(window: window).width
            }
        }
        if template.height != nil {
            storage.notify(name: "default-height", pointer: window.pointer?.opaque()) {
                template.height?.wrappedValue = getDefaultSize(window: window).height
            }
        }
        if template.maximized != nil {
            storage.notify(name: "maximized", pointer: window.pointer?.opaque()) {
                template.maximized?.wrappedValue = gtk_window_is_maximized(window.pointer?.cast()) != 0
            }
        }
        if template.fullscreen != nil {
            storage.notify(name: "fullscreened", pointer: window.pointer?.opaque()) {
                template.fullscreen?.wrappedValue = gtk_window_is_fullscreen(window.pointer?.cast()) != 0
            }
        }
        if updateProperties {
            template.updateProperties(storage: storage, window: window)
        }
    }

    /// Update the properties of the windows.
    /// - Parameters:
    ///     - storage: The scene storage.
    ///     - window: The window.
    func updateProperties(storage: SceneStorage, window: AdwaitaWindow) {
        let previousState = storage.previousState as? Self
        if let title, previousState?.title != title {
            gtk_window_set_title(window.pointer?.cast(), title)
        }
        if let resizable, previousState?.resizable != resizable {
            gtk_window_set_resizable(window.pointer?.cast(), resizable.cBool)
        }
        if let deletable, previousState?.deletable != deletable {
            gtk_window_set_deletable(window.pointer?.cast(), deletable.cBool)
        }
        if let devel, previousState?.devel != devel {
            if devel {
                gtk_widget_add_css_class(window.pointer?.cast(), "devel")
            } else {
                gtk_widget_remove_css_class(window.pointer?.cast(), "devel")
            }
        }
        if width != nil || height != nil {
            gtk_window_set_default_size(
                window.pointer?.cast(),
                .init(width?.wrappedValue ?? -1),
                .init(height?.wrappedValue ?? -1)
            )
        }
        if let maximized = maximized?.wrappedValue {
            if maximized {
                gtk_window_maximize(window.pointer?.cast())
            } else {
                gtk_window_unmaximize(window.pointer?.cast())
            }
        }
        if let fullscreen = fullscreen?.wrappedValue {
            if fullscreen {
                gtk_window_fullscreen(window.pointer?.cast())
            } else {
                gtk_window_unfullscreen(window.pointer?.cast())
            }
        }
        if let onClose {
            storage.fields[.windowClose] = { onClose() == .cancel } as (() -> Bool)
        }
        storage.previousState = self
    }

    /// Get the window's default size.
    /// - Parameter window: The window.
    /// - Returns: The dimensions.
    func getDefaultSize(window: AdwaitaWindow) -> (width: Int, height: Int) {
        var width: Int32 = 0
        var height: Int32 = 0
        gtk_window_get_default_size(window.pointer?.cast(), &width, &height)
        return (width: .init(width), height: .init(height))
    }

}

// swiftlint:enable discouraged_optional_collection
/// An AdwApplicationWindow.
public typealias AdwaitaWindow = Window.AdwaitaWindow
