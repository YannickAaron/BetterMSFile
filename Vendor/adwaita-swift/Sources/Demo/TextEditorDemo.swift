//
//  TextEditorDemo.swift
//  Adwaita
//
//  Created by david-swift on 09.08.25.
//

// swiftlint:disable missing_docs

import Adwaita
import Foundation

struct TextEditorDemo: View {

    @State private var text = "Hello, world!"

    var view: Body {
        VStack(spacing: 20) {
            TextEditor(text: $text)
                .innerPadding(20)
                .frame(minHeight: 60)
                .card()
            VStack {
                Text(text)
                    .selectable()
                    .wrap()
                    .hexpand()
                    .padding(20)
                    .halign(.fill)
            }
            .card()
        }
        .frame(maxWidth: 500)
    }

}

// swiftlint:enable missing_docs
