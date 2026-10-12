//
//  SplitViewDemo.swift
//  Adwaita
//
//  Created by david-swift on 16.09.25.
//

// swiftlint:disable missing_docs

import Adwaita

struct SplitViewDemo: View {

    @State private var splitter = 200

    var view: Body {
        HSplitView(splitter: $splitter) {
            Text("\(splitter) Pixels")
        } end: {
            Text("View 2")
        }
        .frame(minHeight: 200)
        .card()
        .padding()
    }

}

// swiftlint:enable missing_docs
