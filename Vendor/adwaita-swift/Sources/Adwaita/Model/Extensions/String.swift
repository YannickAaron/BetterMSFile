//
//  String.swift
//  Adwaita
//
//  Created by david-swift on 09.09.23.
//

nonisolated
extension String {

    /// A label for the transition data in a widget's fields.
    public static var transition: Self { "transition" }
    /// A label for the navigation label in a widget's fields.
    public static var navigationLabel: Self { "navigation-label" }
    /// A field label for bindings.
    public static var binding: Self { "binding" }
    /// A field label for callbacks.
    public static var callbacks: Self { "callbacks" }
    /// A field label for elements.
    public static var element: Self { "element" }
    /// A field label for a child.
    public static var child: Self { "child" }
    /// A field label for an extra child.
    public static var extraChild: Self { "extra-child" }
    /// A field label for a suffix.
    public static var suffix: Self { "suffix" }
    /// A field label for a prefix.
    public static var prefix: Self { "prefix" }
    /// A field label for a buffer.
    public static var buffer: Self { "buffer" }
    /// A field label for data.
    public static var data: Self { "data" }
    /// A field label for a file path.
    public static var filePath: Self { "file-path" }
    /// A label for the ``AnyView/onClick`` controller.
    static var clickController: Self { "controller" }
    /// A label for the ``AnyView/onClick`` handler.
    static var clickHandler: Self { "click-handler" }
    /// A label for the ``AnyView/dropTarget`` controller.
    static var dropTargetController: Self { "drop-target-controller" }
    /// A label for the ``AnyView/dropTarget`` handler.
    static var dropTargetHandler: Self { "drop-target-handler" }
    /// A label for the breakpoint bin condition.
    static var binCondition: Self { "condition" }
    /// A label for the breakpoint bin's breakpoint.
    static var binBreakpoint: Self { "breakpoint" }
    /// A label for the dialog result.
    static var dialogResult: Self { "result" }
    /// A label for the dialog cancel action.
    static var dialogCancel: Self { "cancel" }
    /// A label for the toast button.
    static var toastButton: Self { "button" }
    /// A label for the toast handler.
    static var toastHandler: Self { "handler" }
    /// A label for the sidebar page.
    static var sidebarPage: Self { "sidebar-page" }
    /// A label for the main page.
    static var mainPage: Self { "main-page" }
    /// A label for the switcher stack.
    static var switcherStack: Self { "switcher-stack" }
    /// A label for the window close action.
    static var windowClose: Self { "on-close" }
    /// A label for the activatable widget.
    static var activatableWidget: Self { "activatable-widget" }
    /// The widget orientation label.
    static var orientation: Self { "orientation" }
    /// The widget spacing label.
    static var spacing: Self { "spacing" }
    /// A field label for fullscreen state.
    static var fullscreen: Self { "fullscreen" }
    /// A field label for revealing the top bar.
    static var revealTopBar: Self { "reveal-top-bar" }

    /// A label for the preferences dialog.
    static func preferencesDialogIndex(index: Int) -> Self {
        "preferences-\(index)"
    }

    /// A label for the shortcuts dialog.
    static func shortcutsDialogIndex(index: Int) -> Self {
        "shortcuts-\(index)"
    }

    /// Add the Ctrl key to a shortcut.
    /// - Returns: The shortcut.
    public func ctrl() -> String { "<Ctrl>\(self)" }

    /// Add the Shift key to a shortcut.
    /// - Returns: The shortcut.
    public func shift() -> String { "<Shift>\(self)" }

    /// Add the Alt key to a shortcut.
    /// - Returns: The shortcut.
    public func alt() -> String { "<Alt>\(self)" }

    /// Add the Meta key to a shortcut.
    /// - Returns: The shortcut.
    public func meta() -> String { "<Meta>\(self)" }

    /// Add the Super key to a shortcut.
    /// - Returns: The shortcut.
    public func `super`() -> String { "<Super>\(self)" }

    /// Add the Hyper key to a shortcut.
    /// - Returns: The shortcut.
    public func hyper() -> String { "<Hyper>\(self)" }

}
