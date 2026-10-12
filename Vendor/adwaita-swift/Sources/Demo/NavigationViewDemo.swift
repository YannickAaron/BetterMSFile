//
//  NavigationViewDemo.swift
//  Adwaita
//
//  Created by david-swift on 17.02.24.
//

// swiftlint:disable missing_docs

import Adwaita

struct NavigationViewDemo: View {

    var app: AdwaitaApp

    var view: Body {
        VStack {
            Button("View Demo") {
                app.showWindow("navigation")
            }
            .suggested()
            .pill()
            .frame(maxWidth: 100)
            .padding()
        }
    }

    struct WindowContent: View {

        @State private var stack = NavigationStack<Int>()
        @State private var dialog = false
        let spacing = 10

        var view: Body {
            navigationView
                .dialog(visible: $dialog) {
                    navigationView
                }
        }

        @ViewBuilder var navigationView: Body {
            NavigationView($stack, "Initial View") { component in
                VStack(spacing: spacing) {
                    Button("Add Next View") {
                        stack.push(component + 1)
                    }
                    Button("Pop View") {
                        stack.pop()
                    }
                    Button(dialog ? "Hide Dialog" : "Show Dialog") {
                        dialog.toggle()
                    }
                }
                .padding()
                .topToolbar {
                    HeaderBar.empty()
                }
            } initialView: {
                VStack {
                    Button("Add First View") {
                        stack.push(1)
                    }
                    .padding()
                }
                .topToolbar {
                    HeaderBar.empty()
                }
            }
        }

    }

}

// swiftlint:enable missing_docs
