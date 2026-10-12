//
//  PopoverDemo.swift
//  Adwaita
//
//  Created by david-swift on 10.02.24.
//

// swiftlint:disable missing_docs

import Adwaita

struct PopoverDemo: View {

    @State private var visible = false
    @State private var menuVisible = false

    var view: Body {
        VStack(spacing: 10) {
            Button("Present Popover") {
                visible = true
            }
            .suggested()
            .pill()
            .popover(visible: $visible) {
                CounterDemo()
            }
            Button("Present Menu Popover") {
                menuVisible = true
            }
            .pill()
            .menuPopover(visible: $menuVisible) {
                MenuButton("Test") { print("Test") }
                Submenu("Hello") { MenuButton("Cool") { print("Cool") } }
            }
        }
        .frame(maxWidth: 100)
    }

}

// swiftlint:enable missing_docs
