//
//  TextLabelDemo.swift
//  Adwaita
//
//  Created by desbeers on 06.08.26.
//

// swiftlint:disable missing_docs

import Adwaita
import Foundation

struct TextLabelDemo: View {

    @State private var justify: Justification = .left
    @State private var ellipsize: Bool = false

    // swiftlint:disable:next line_length
    let text = "This is a very long text label that does not fit on one line and can be ellipsized or wrapped into more than one line and justified to your liking with the options you can see above. "

    var view: Body {
        ToggleGroup(
            selection: $justify,
            values: Justification.allCases,
            id: \.self,
            label: \.label
        )
        .insensitive(ellipsize)
        .padding()
        Text(text)
            .wrap()
            .ellipsize(ellipsize)
            .justify(justify)
            .frame(maxWidth: 500)
        Toggle("Ellipsize the text label", isOn: $ellipsize)
            .padding()
            .halign(.center)
    }

}

extension Justification {

    var label: String {
        switch self {
        case .left:
            "Left"
        case .right:
            "Right"
        case .center:
            "Center"
        case .fill:
            "Fill"
        }
    }

}

// swiftlint:enable missing_docs
