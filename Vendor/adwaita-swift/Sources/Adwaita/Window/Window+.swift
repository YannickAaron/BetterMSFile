//
//  Window+.swift
//  Adwaita
//
//  Created by david-swift on 30.10.25.
//

import Foundation

extension Window {

    /// Add a keyboard shortcut.
    /// - Parameters:
    ///     - shortcut: The keyboard shortcut.
    ///     - action: The closure to execute when the keyboard shortcut is pressed.
    /// - Returns: The window.
    public func keyboardShortcut(_ shortcut: String, action: @escaping (AdwaitaWindow) -> Void) -> Self {
        var newSelf = self
        newSelf.shortcuts[shortcut] = action
        return newSelf
    }

    /// Add the shortcut "<Ctrl>w" which closes the window.
    /// - Returns: The window.
    public func closeShortcut() -> Self {
        keyboardShortcut("w".ctrl()) { $0.close() }
    }

    /// Add a keyboard shortcut for the whole application.
    /// - Parameters:
    ///     - shortcut: The keyboard shortcut.
    ///     - action: The closure to execute when the keyboard shortcut is pressed.
    /// - Returns: The window.
    public func appKeyboardShortcut(_ shortcut: String, action: @escaping (AdwaitaApp) -> Void) -> Self {
        var newSelf = self
        newSelf.appShortcuts[shortcut] = action
        return newSelf
    }

    /// Add a handler for opening files.
    ///
    /// Make sure to add/show in general at least one window in this closure.
    ///
    /// - Parameter action: Handle the opening of files.
    /// - Returns: The app.
    public func onOpen(action: @escaping ([URL]) -> Void) -> Self {
        var newSelf = self
        newSelf.onOpen = action
        return newSelf
    }

    /// Add the shortcut "<Ctrl>q" which quits the application.
    /// - Returns: The window.
    public func quitShortcut() -> Self {
        appKeyboardShortcut("q".ctrl()) { $0.quit() }
    }

    /// Set the window's default size.
    /// - Parameters:
    ///     - width: The window's width.
    ///     - height: The window's height.
    /// - Returns: The window.
    public func defaultSize(width: Int? = nil, height: Int? = nil) -> Self {
        var newSelf = self
        newSelf.defaultWidth = width
        newSelf.defaultHeight = height
        return newSelf
    }

    /// Set the window's title.
    /// - Parameter title: The title.
    /// - Returns: The window.
    public func title(_ title: String?) -> Self {
        var newSelf = self
        newSelf.title = title
        return newSelf
    }

    /// Set whether the window is resizable.
    /// - Parameter resizable: The resizability.
    /// - Returns: The window.
    public func resizable(_ resizable: Bool?) -> Self {
        var newSelf = self
        newSelf.resizable = resizable
        return newSelf
    }

    /// Set whether the window is deletable.
    /// - Parameter resizable: The deletability.
    /// - Returns: The window.
    public func deletable(_ deletable: Bool?) -> Self {
        var newSelf = self
        newSelf.deletable = deletable
        return newSelf
    }

    /// Get the window's width and height.
    /// - Parameters:
    ///     - width: The window's actual width.
    ///     - height: The window's actual height.
    /// - Returns: The window.
    public func size(width: Binding<Int>? = nil, height: Binding<Int>? = nil) -> Self {
        var newSelf = self
        newSelf.width = width
        newSelf.height = height
        return newSelf
    }

    /// Set the window's minimum width and height.
    /// - Parameters:
    ///     - minWidth: The window's minimum width.
    ///     - minHeight: The window's minimum height.
    public func minSize(width: Int = -1, height: Int = -1) -> Self {
        var newSelf = self
        newSelf.minWidth = width
        newSelf.minHeight = height
        return newSelf
    }

    /// Get and set whether the window is maximized.
    /// - Parameter maximized: Whether the window is maximized.
    /// - Returns: The window.
    public func maximized(_ maximized: Binding<Bool>?) -> Self {
        var newSelf = self
        newSelf.maximized = maximized
        return newSelf
    }

    /// Get and set whether the window is fullscreen.
    /// - Parameter fullscreen: Whether the window is fullscreen.
    /// - Returns: The window.
    public func fullscreen(_ fullscreen: Binding<Bool>?) -> Self {
        var newSelf = self
        newSelf.fullscreen = fullscreen
        return newSelf
    }

    /// Whether the window used the development style.
    /// - Parameter active: Whether the style is active.
    /// - Returns: The window.
    public func devel(_ active: Bool? = true) -> Self {
        var newSelf = self
        newSelf.devel = active
        return newSelf
    }

    /// Run this closure when the window should be closed.
    /// - Parameter onClose: The closure.
    /// - Returns: The window.
    public func onClose(onClose: @escaping () -> CloseConfirmation) -> Self {
        var newSelf = self
        newSelf.onClose = onClose
        return newSelf
    }

}
