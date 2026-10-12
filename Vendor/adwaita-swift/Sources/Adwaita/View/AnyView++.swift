//
//  AnyView++.swift
//  Adwaita
//
//  Created by david-swift on 16.10.24.
//

import CAdw
import Foundation

extension AnyView {

    /// Set the view's aspect ratio.
    /// - Parameter aspectRatio: The aspect ratio.
    public func aspectRatio(_ aspectRatio: Float) -> AspectFrame {
        .init(ratio: aspectRatio)
            .child { self }
    }

    /// Add a top toolbar to the view.
    /// - Parameters:
    ///   - toolbar: The toolbar's content.
    ///   - visible: Whether the toolbar is visible.
    /// - Returns: A view.
    public func topToolbar(visible: Bool = true, @ViewBuilder _ toolbar: @escaping () -> Body) -> ToolbarView {
        .init()
            .content { self }
            .top(toolbar)
            .revealTopBars(visible)
    }

    /// Add a top toolbar to the view that is hidden while fullscreen.
    /// - Parameters:
    ///   - fullscreen: Whether the window is fullscreen.
    ///   - toolbar: The toolbar's content.
    /// - Returns: A ToolbarView.
    ///
    /// When the mouse moves to the top of the screen the toolbar will be
    /// revealed. When moving away; it will hide again.
    public func topToolbar(
        fullscreen: Bool,
        @ViewBuilder _ toolbar: @escaping () -> Body
    ) -> ToolbarView {
        var toolbar = ToolbarView()
            .content { self }
            .top(toolbar)
            .topBarStyle(fullscreen ? .raised : .flat)
        toolbar.appearFunctions.append { storage, _ in
            let motion = gtk_event_controller_motion_new()
            storage.connectSignal(
                name: "motion",
                id: "motion",
                type: .doubleDouble,
                pointer: motion
            ) { args in
                guard let fullscreen = storage.fields[.fullscreen] as? Bool,
                    fullscreen, let yValue = args.last as? Double else {
                    return
                }
                let toolbarHeight = Double(adw_toolbar_view_get_top_bar_height(storage.opaquePointer))
                var revealTopBar = storage.fields[.revealTopBar] as? Bool ?? true
                let range: Double = revealTopBar ? toolbarHeight : 2
                revealTopBar = yValue < range ? true : false
                adw_toolbar_view_set_reveal_top_bars(storage.opaquePointer, revealTopBar.cBool)
                storage.fields[.revealTopBar] = revealTopBar
            }
            gtk_widget_add_controller(storage.opaquePointer?.cast(), motion)
        }
        toolbar.updateFunctions.append { storage, _, _ in
            storage.fields[.fullscreen] = fullscreen
            let reveal = storage.fields[.revealTopBar] as? Bool ?? false
            if fullscreen {
                adw_toolbar_view_set_reveal_top_bars(storage.opaquePointer, reveal.cBool)
                adw_toolbar_view_set_extend_content_to_top_edge(storage.opaquePointer, true.cBool)
            } else {
                adw_toolbar_view_set_reveal_top_bars(storage.opaquePointer, true.cBool)
                adw_toolbar_view_set_extend_content_to_top_edge(storage.opaquePointer, false.cBool)
            }
        }
        return toolbar
    }

    /// Add a bottom toolbar to the view.
    /// - Parameters:
    ///   - toolbar: The toolbar's content.
    ///   - visible: Whether the toolbar is visible.
    /// - Returns: A view.
    public func bottomToolbar(visible: Bool = true, @ViewBuilder _ toolbar: @escaping () -> Body) -> ToolbarView {
        .init()
            .content { self }
            .bottom(toolbar)
            .revealBottomBars(visible)
    }

    /// Add an overlay view.
    /// - Parameters:
    ///     - overlay: The overlay view.
    /// - Returns: A view.
    public func overlay(@ViewBuilder _ overlay: @escaping () -> Body) -> Overlay {
        .init()
            .child { self }
            .overlay(overlay)
    }

    /// Set the view's transition.
    /// - Parameter transition: The transition.
    /// - Returns: A view.
    public func transition(_ transition: Transition) -> AnyView {
        inspect { storage, updateProperties in
            if updateProperties {
                storage.fields[.transition] = transition
            }
        }
    }

    /// Set the view's navigation title.
    /// - Parameter label: The navigation title.
    /// - Returns: A view.
    public func navigationTitle(_ label: String) -> AnyView {
        inspect { storage, updateProperties in
            if updateProperties {
                storage.fields[.navigationLabel] = label
            }
        }
    }

    /// Make a button or similar widget use accent colors.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func suggested(_ active: Bool = true) -> AnyView {
        style("suggested-action", active: active)
    }

    /// Make a button or similar widget use destructive colors.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func destructive(_ active: Bool = true) -> AnyView {
        style("destructive-action", active: active)
    }

    /// Make a button or similar widget use flat appearance.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func flat(_ active: Bool = true) -> AnyView {
        style("flat", active: active)
    }

    /// Make a button or similar widget use the regular appearance instead of the flat one.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func raised(_ active: Bool = true) -> AnyView {
        style("raised", active: active)
    }

    /// Make a button or similar widget round.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func circular(_ active: Bool = true) -> AnyView {
        style("circular", active: active)
    }

    /// Make a button or similar widget use round appearance.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func round(_ active: Bool = true) -> AnyView {
        style("round", active: active)
    }

    /// Make a button or similar widget appear as a pill.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func pill(_ active: Bool = true) -> AnyView {
        style("pill", active: active)
    }

    /// Make the view partially transparent.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func dimLabel(_ active: Bool = true) -> AnyView {
        style("dim-label", active: active)
    }

    /// Use a title typography style.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func title1(_ active: Bool = true) -> AnyView {
        style("title-1", active: active)
    }

    /// Use a title typography style.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func title2(_ active: Bool = true) -> AnyView {
        style("title-2", active: active)
    }

    /// Use a title typography style.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func title3(_ active: Bool = true) -> AnyView {
        style("title-3", active: active)
    }

    /// Use a title typography style.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func title4(_ active: Bool = true) -> AnyView {
        style("title-4", active: active)
    }

    /// Use the heading typography style.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func heading(_ active: Bool = true) -> AnyView {
        style("heading", active: active)
    }

    /// Use the body typography style.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func body(_ active: Bool = true) -> AnyView {
        style("body", active: active)
    }

    /// Use the caption heading typography style.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func captionHeading(_ active: Bool = true) -> AnyView {
        style("caption-heading", active: active)
    }

    /// Use the caption typography style.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func caption(_ active: Bool = true) -> AnyView {
        style("caption", active: active)
    }

    /// Use the monospace typography style.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func monospace(_ active: Bool = true) -> AnyView {
        style("monospace", active: active)
    }

    /// Use the numeric typography style.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func numeric(_ active: Bool = true) -> AnyView {
        style("numeric", active: active)
    }

    /// Apply the accent color.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func accent(_ active: Bool = true) -> AnyView {
        style("accent", active: active)
    }

    /// Apply the success color.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func success(_ active: Bool = true) -> AnyView {
        style("success", active: active)
    }

    /// Apply the warning color.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func warning(_ active: Bool = true) -> AnyView {
        style("warning", active: active)
    }

    /// Apply the error color.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func error(_ active: Bool = true) -> AnyView {
        style("error", active: active)
    }

    /// Apply the card style.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func card(_ active: Bool = true) -> AnyView {
        style("card", active: active)
    }

    /// Apply an icon dropshadow.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    ///
    /// Use for icons larger than 32x32 pixels.
    public func iconDropshadow(_ active: Bool = true) -> AnyView {
        style("icon-dropshadow", active: active)
    }

    /// Use for icons smaller than or equal to 32x32 pixels.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func lowresIcon(_ active: Bool = true) -> AnyView {
        style("lowres-icon", active: active)
    }

    /// Use the OSD style class.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func osd(_ active: Bool = true) -> AnyView {
        style("osd", active: active)
    }

    /// Give a view the default window background and foreground colors.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func backgroundStyle(_ active: Bool = true) -> AnyView {
        style("background", active: active)
    }

    /// Give a view the default view background and foreground colors.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func viewStyle(_ active: Bool = true) -> AnyView {
        style("view", active: active)
    }

    /// Give a view the default border.
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func frameStyle(_ active: Bool = true) -> AnyView {
        style("frame", active: active)
    }

    /// Bind to the view's focus.
    /// - Parameter focus: Whether the view is focused.
    /// - Returns: A view.
    public func focused(_ focused: Binding<Bool>) -> AnyView {
        let focus = "focus"
        return inspectOnAppear { storage in
            let controller = gtk_event_controller_focus_new()
            storage.content[focus] = [.init(controller)]
            gtk_widget_add_controller(storage.opaquePointer?.cast(), controller)
        }
        .inspect { storage, _ in
            guard let controller = storage.content[focus]?.first else {
                return
            }
            controller.notify(name: "contains-focus", id: "focused") {
                let newValue = gtk_event_controller_focus_contains_focus(controller.opaquePointer) != 0
                if focused.wrappedValue != newValue {
                    focused.wrappedValue = newValue
                }
            }
            if gtk_event_controller_focus_contains_focus(controller.opaquePointer) == 0, focused.wrappedValue {
                gtk_widget_grab_focus(storage.opaquePointer?.cast())
            }
        }
    }

    /// Bind a signal that focuses the view.
    /// - Parameter focus: Whether the view is focused.
    /// - Returns: A view.
    public func focus(_ signal: Binding<Signal>) -> AnyView {
        inspect { storage, data, _ in
            data.stateManager.withBlockedUpdates {
                if signal.wrappedValue.update {
                    gtk_widget_grab_focus(storage.opaquePointer?.cast())
                }
            }
        }
    }

    /// Run a function when the view appears for the first time.
    /// - Parameter closure: The function.
    /// - Returns: A view.
    public func onAppear(_ closure: @escaping () -> Void) -> AnyView {
        inspectOnAppear { _ in closure() }
    }

    /// Add CSS classes to the app as soon as the view appears.
    /// - Parameters:
    ///     - scheme: The color scheme.
    ///     - getString: Get the CSS.
    /// - Returns: A view.
    public func css(scheme: InterfaceColorScheme? = nil, getString: @escaping () -> String) -> AnyView {
        wrap { storage, updateProperties in
            let cssID = "internal-css"
            let previous = storage.fields[cssID] as? String
            let string = getString()
            if updateProperties, string != previous {
                let providerID = "internal-css-provider"
                let provider = gtk_css_provider_new()
                if let scheme {
                    gtui_cssprovider_set_prefers_color_scheme(provider?.cast(), scheme.gtkValue)
                }
                gtk_css_provider_load_from_string(
                    provider,
                    string
                )
                let display = gdk_display_get_default()
                gtk_style_context_add_provider_for_display(
                    display,
                    provider?.opaque(),
                    .init(GTK_STYLE_PROVIDER_PRIORITY_APPLICATION)
                )
                g_object_unref(provider)
                storage.fields[cssID] = string
                if let oldProvider = storage.fields[providerID] as? OpaquePointer {
                    gtk_style_context_remove_provider_for_display(
                        display,
                        oldProvider
                    )
                }
                storage.fields[providerID] = provider?.opaque()
            }
        }
    }

    /// Whether the view has a width higher or equal to its natural width.
    /// - Parameters:
    ///     - matches: Whether the content view matches the breakpoint.
    ///     - padding: Increase the natural width by a certain padding.
    public func naturalWidth(matches: Binding<Bool>, padding: Int = 0) -> AnyView {
        BreakpointBin(condition: .naturalWidth(padding: padding), matches: matches) { self }
    }

    /// Whether the view has a height higher or equal to its natural height.
    /// - Parameters:
    ///     - matches: Whether the content view matches the breakpoint.
    ///     - padding: Increase the natural height by a certain padding.
    public func naturalHeight(matches: Binding<Bool>, padding: Int = 0) -> AnyView {
        BreakpointBin(condition: .naturalHeight(padding: padding), matches: matches) { self }
    }

}
