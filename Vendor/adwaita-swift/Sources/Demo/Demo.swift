//
//  Demo.swift
//  Adwaita
//
//  Created by david-swift on 25.09.23.
//

// swiftlint:disable missing_docs implicitly_unwrapped_optional no_magic_numbers

import Adwaita
import CAdw
import Foundation

@main
struct Demo: App {

    var app = AdwaitaApp(id: "io.github.AparokshaUI.Demo")

    @State private var pictureURL: URL?
    @State private var fullscreen = false

    var scene: Scene {
        Window(id: "main") { window in
            DemoContent(
                window: window,
                app: app,
                fullscreen: $fullscreen,
                pictureURL: pictureURL
            )
        }
        .fullscreen($fullscreen)
        .onOpen { print($0) }
        helperWindows
    }

    @SceneBuilder var helperWindows: Scene {
        Window(id: "content", open: 0) { _ in
            WindowsDemo.WindowContent()
        }
        .resizable(false)
        .closeShortcut()
        .defaultSize(width: 400, height: 250)
        Window(id: "toolbar-demo", open: 0) { _ in
            ToolbarDemo.WindowContent().stopModifiers()
        }
        .closeShortcut()
        .defaultSize(width: 400, height: 250)
        .title("Toolbar Demo")
        Window(id: "switcher-demo", open: 0) { _ in
            ViewSwitcherDemo.WindowContent()
        }
        .closeShortcut()
        .defaultSize(width: 600, height: 400)
        .title("View Switcher Demo")
        Window(id: "form-demo", open: 0) { _ in
            FormDemo.WindowContent()
        }
        .closeShortcut()
        .defaultSize(width: 400, height: 250)
        .title("Form Demo")
        Window(id: "password-checker-demo", open: 0) { _ in
            PasswordCheckerDemo.WindowContent()
        }
        .closeShortcut()
        .defaultSize(width: 400, height: 250)
        .title("Password Checker Demo")

        Window(id: "navigation", open: 0) { _ in
            NavigationViewDemo.WindowContent()
        }
        .closeShortcut()
        .title("Navigation View Demo")
        Window(id: "bottom-sheet", open: 0) { _ in
            BottomSheetDemo.WindowContent()
        }
        .closeShortcut()
        .defaultSize(width: 400, height: 250)
        .title("Bottom Sheet Demo")
    }

    enum WindowName: String, CaseIterable, CustomStringConvertible, Identifiable {

        case demo = "Demo"
        case alternative = "Alternative"

        var id: Self { self }

        var description: String {
            rawValue
        }

    }

    struct DemoContent: WindowView {

        @State("selection")
        private var selection: Page = .welcome
        @State private var toast: Signal = .init()
        @State private var sidebarVisible = true
        @State private var width = 650
        @State private var height = 550
        @State private var wide = true
        @State private var maximized = false
        @State private var about = false
        @State private var preferences = false
        @State private var shortcuts = false
        @State private var title: WindowName = .demo
        @State private var closeAlert = false
        @State private var destroy = false
        var window: AdwaitaWindow
        var app: AdwaitaApp!
        @Binding var fullscreen: Bool
        var pictureURL: URL?

        var view: Body {
            OverlaySplitView(visible: $sidebarVisible) {
                ScrollView {
                    List(Page.allCases, selection: $selection) { element in
                        Text(element.label)
                            .ellipsize()
                            .halign(.start)
                            .padding()
                    }
                    .sidebarStyle()
                }
                .hscrollbarPolicy(.never)
                .topToolbar {
                    HeaderBar.end {
                        menu
                    }
                    .headerBarTitle {
                        WindowTitle(subtitle: "", title: title.description)
                    }
                }
            } content: {
                StatusPage(
                    selection.label,
                    icon: selection.icon,
                    description: selection.description
                ) { selection.view(app: app, window: window, toast: $toast) }
                .topToolbar(fullscreen: fullscreen) {
                    HeaderBar(fullscreen: $fullscreen) {
                        Toggle(icon: .default(icon: .sidebarShow), isOn: $sidebarVisible)
                            .tooltip("Toggle Sidebar")
                        DropDown(selection: $title, values: WindowName.allCases)
                    } end: {
                        if sidebarVisible {
                            Text("").transition(.crossfade)
                        } else {
                            menu.transition(.crossfade)
                        }
                    }
                    .headerBarTitle {
                        if sidebarVisible {
                            Text("")
                                .transition(.crossfade)
                        } else {
                            WindowTitle(subtitle: title.description, title: selection.label)
                                .transition(.crossfade)
                        }
                    }
                }
                .toast("This is a toast!", signal: $toast)
            }
            .collapsed(!wide)
            .breakpoint(minWidth: 550, matches: $wide)
            .aboutDialog(
                visible: $about,
                app: "Demo",
                developer: "david-swift",
                version: "3.14159",
                icon: .default(icon: .applicationXExecutable),
                details: [
                    // swiftlint:disable:next line_length
                    .comment("<a href=\"https://adwaita-swift.aparoksha.dev/\">Adwaita for Swift</a> is a framework for creating user interfaces for GNOME with an API similar to SwiftUI."),
                    .copyright("© 2026"),
                    .developers(["david-swift"]),
                    .designers(["Antoni Gaudí"]),
                    .artists(["Vincent van Gogh"]),
                    .documenters(["William Shakespeare"]),
                    .translators(["Tower of Babel"]),
                    .creditSection(
                        [
                            "GTK https://gtk.org/",
                            "libadwaita https://gnome.pages.gitlab.gnome.org/libadwaita/",
                            "Swift https://swift.org"
                        ],
                        label: "Built with"
                    ),
                    .acknowledgementSection(
                        [
                            "GNOME https://www.gnome.org/",
                            "Swift Community https://www.swift.org/community/"
                        ],
                        label: "Thanks to"
                    ),
                    .licenseType(.mitX11),
                    .debugInfo("\(Date.now.formatted())\n\nThis application has no bugs."),
                    .debugInfoFilename("Debug Sample.txt"),
                    .releaseNotes("<p>Another great release!</p>"),
                    .releaseNotesVersion("π")
                ],
                links: [
                    .website(URL(string: "https://adwaita-swift.aparoksha.dev/")),
                    .support(URL(string: "https://forums.aparoksha.dev/")),
                    .issues(URL(string: "https://codeberg.org/aparoksha/adwaita-swift/issues")),
                    .add(URL(string: "https://swift.org"), title: "Swift")
                ]
            )
            .preferencesDialog(visible: $preferences)
            .preferencesPage("Page 1", icon: .default(icon: .audioHeadset)) { page in
                page
                    .group("General") {
                        SwitchRow()
                            .title("Hello")
                            .subtitle("World")
                        SwitchRow()
                            .title("Switch")
                            .subtitle("Row")
                    }
                    .group("Extra", description: "This is the group's description") {
                        ActionRow()
                            .title("Extra Action")
                    }
            }
            .preferencesPage("Page 2", icon: .default(icon: .faceEmbarrassed)) { page in
                page
            }
            .alertDialog(
                visible: $closeAlert,
                heading: "Close this Window?",
                body: "Nothing will be lost. This is a demo."
            )
            .response("Cancel", role: .close) { }
            .response("Close", appearance: .suggested, role: .default) {
                destroy = true
                window.close()
            }
            .shortcutsDialog(visible: $shortcuts)
            .shortcutsSection("Windows") { section in
                section
                    .shortcutsItem("New window", accelerator: "n".ctrl())
                    .shortcutsItem("Close window", accelerator: "w".ctrl())
            }
            .shortcutsSection("General") { section in
                section
                    .shortcutsItem("Show preferences", accelerator: "comma".ctrl())
                    .shortcutsItem("Show keyboard shortcuts", accelerator: "question".ctrl())
            }
            .shortcutsSection { $0.shortcutsItem("Quit Demo", accelerator: "q".ctrl()) }
        }

        var menu: AnyView {
            Menu(icon: .default(icon: .openMenu)) {
                MenuButton("New Window", window: false) {
                    app.addWindow("main")
                }
                .keyboardShortcut("n".ctrl())
                MenuButton("Close Window") {
                    window.close()
                }
                .keyboardShortcut("w".ctrl())
                MenuSection {
                    MenuButton("Fullscreen") { fullscreen.toggle() }
                        .keyboardShortcut("F11")
                }
                MenuSection {
                    MenuButton("Preferences") { preferences = true }
                        .keyboardShortcut("comma".ctrl())
                    MenuButton("Keyboard Shortcuts") { shortcuts = true }
                        .keyboardShortcut("question".ctrl())
                    MenuButton("About") { about = true }
                    MenuButton("Quit", window: false) { app.quit() }
                        .keyboardShortcut("q".ctrl())
                }
            }
            .primary()
            .tooltip("Main Menu")
        }

        func window(_ window: Window) -> Window {
            window
                .size(width: $width, height: $height)
                .maximized($maximized)
                .onClose { closeAlert = !destroy; return destroy ? .close : .cancel }
        }

    }

}

// swiftlint:enable missing_docs implicitly_unwrapped_optional no_magic_numbers
