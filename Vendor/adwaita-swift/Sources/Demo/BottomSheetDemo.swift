//
//  BottomBarDemo.swift
//  Adwaita
//
//  Created by david-swift on 05.04.24.
//

// swiftlint:disable missing_docs

import Adwaita

struct BottomSheetDemo: View {

    var app: AdwaitaApp

    var view: Body {
        VStack {
            Button("View Demo") {
                app.showWindow("bottom-sheet")
            }
            .suggested()
            .pill()
            .frame(maxWidth: 100)
            .padding()
        }
    }

    struct WindowContent: View {

        @State private var sheet = false

        var view: Body {
            VStack {
                Button(sheet ? "Hide Bottom Bar" : "Reveal Bottom Bar") {
                    sheet.toggle()
                }
                .valign(.center)
                .halign(.center)
                .vexpand()
                .padding()
            }
            .topToolbar {
                HeaderBar()
            }
            .bottomSheet {
                Text("Hello")
                    .padding(50)
                    .topToolbar {
                        HeaderBar()
                    }
            } bottomBar: {
                Text("Pull up here")
                    .frame(minHeight: 50)
            }
            .revealBottomBar(sheet)
        }
    }

}

// swiftlint:enable missing_docs
