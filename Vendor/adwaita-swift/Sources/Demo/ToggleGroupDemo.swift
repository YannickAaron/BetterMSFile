//
//  ToggleGroupDemo.swift
//  Adwaita
//
//  Created by david-swift on 03.11.25.
//

// swiftlint:disable missing_docs no_magic_numbers

import Adwaita
import Foundation

struct ToggleGroupDemo: View {

    @State private var selection: Subview = .view1

    var view: Body {
        ToggleGroup(
            selection: $selection,
            values: Subview.allCases,
            id: \.self,
            label: \.rawValue,
            icon: \.icon
        )
        .showLabel(selection == .view1)
        .padding()
        VStack {
            Text(selection.rawValue)
                .padding()
                .padding(50, .vertical)
        }
        .card()
        .padding()
    }

    enum Subview: String, CaseIterable, Equatable {

        case view1 = "View 1"
        case view2 = "View 2"

        var icon: Icon? { .default(icon: .listAdd) }

    }

}

// swiftlint:enable missing_docs no_magic_numbers
