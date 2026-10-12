//
//  SymbolDemo.swift
//  Adwaita
//
//  Created by Marquis Kurt on 23.10.25.
//

// swiftlint:disable missing_docs

import Adwaita

struct SymbolDemo: View {

    var view: Body {
        HStack {
            Symbol(icon: .default(icon: .goNext))
                .pixelSize(64)
            Symbol(icon: .default(icon: .goPrevious))
                .pixelSize(64)
            Separator()
                .spacer()
                .padding(.horizontal)
            Symbol(icon: .default(icon: .airplaneMode))
                .pixelSize(64)
        }
        .halign(.center)
        .hexpand()
    }
}

// swiftlint:enable missing_docs
